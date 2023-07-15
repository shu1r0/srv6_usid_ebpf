
#include <stdbool.h>
#include <arpa/inet.h>
#include <linux/bpf.h>
#include <linux/in.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/ip.h>
#include <linux/ipv6.h>
#include <linux/in6.h>
#include <linux/seg6.h>
#include <linux/seg6_local.h>

#include <linux/pkt_cls.h>

#include "bpf_helpers.h"

#define __u128 __uint128_t

#define USID_END_OF_CONTAINER 0x0000

static volatile const __u16 USID_BLOCK_LENGTH = 48;
static volatile const __u16 USID_LENGTH = 16;

static volatile const bool ENABLE_SEG6_FLAVOR_PSP = true;
static volatile const bool ENABLE_SEG6_FLAVOR_USP = true;

static volatile const bool ENABLE_STATS = true;

struct metadata
{
  __u16 cookie;
  __u16 pkt_len;
} __attribute__((packed));

struct bpf_map_def SEC("maps") stats = {
    .type = BPF_MAP_TYPE_ARRAY,
    .key_size = sizeof(int),
    .value_size = sizeof(__u32),
    .max_entries = 128,
};

static __always_inline void increment_stats(int counter_key)
{
  if (ENABLE_STATS)
  {
    __u32 *counter = bpf_map_lookup_elem(&stats, &counter_key);
    if (counter)
    {
      (*counter)++;
    }
  }
}

static __always_inline struct ipv6hdr *get_ipv6(struct __sk_buff *skb)
{
  void *data_end = (void *)(long)skb->data_end;
  void *data = (void *)(long)skb->data;

  struct ipv6hdr *ipv6 = data;
  if ((void *)ipv6 + sizeof(*ipv6) <= data_end)
  {
    return ipv6;
  }
  return NULL;
}

static __always_inline struct ipv6_sr_hdr *get_srh(struct __sk_buff *skb)
{
  void *data_end = (void *)(long)skb->data_end;
  void *data = (void *)(long)skb->data;

  struct ipv6hdr *ipv6 = data;
  if ((void *)ipv6 + sizeof(*ipv6) <= data_end)
  {
    if (ipv6->nexthdr == IPPROTO_ROUTING)
    {
      struct ipv6_sr_hdr *srh = (void *)ipv6 + sizeof(*ipv6);
      if ((void *)srh + sizeof(*srh) <= data_end)
      {
        return srh;
      }
    }
  }
  return NULL;
}

static __always_inline bool pop_srh(struct __sk_buff *skb)
{
  void *data_end = (void *)(long)skb->data_end;
  void *data = (void *)(long)skb->data;

  struct ipv6hdr *ipv6 = data;
  struct ipv6_sr_hdr *srh = get_srh(skb);
  if (srh != NULL)
  {
    unsigned long long pkt_len = data_end - data;
    unsigned long long ipv6_len = sizeof(*ipv6);
    unsigned long long srh_len = 1 + srh->hdrlen;

    ipv6->nexthdr = srh->nexthdr;
    ipv6->payload_len -= srh_len;

    int r = bpf_skb_change_tail(skb, pkt_len - srh_len, 0);
    if (r == 0)
    {
      return true;
    }
  }
  return false;
}

static __always_inline bool seg6local_end(struct __sk_buff *skb)
{
  void *data_end = (void *)(long)skb->data_end;
  void *data = (void *)(long)skb->data;

  bool update_segs = false;
  struct ipv6hdr *ipv6 = data;
  struct ipv6_sr_hdr *srh = get_srh(skb);
  if (srh != NULL && (void *)srh + sizeof(*srh) + sizeof(__u128) <= data_end)
  {
    if (srh->segments_left != 0)
    {
      srh->segments_left--;
      __u16 next_seg_i = srh->first_segment - srh->segments_left;
      if (next_seg_i >= 0 && (void *)&srh->segments + sizeof(struct in6_addr) * (next_seg_i + 1) <= data_end)
      {
        void *next_seg = &srh->segments[next_seg_i];
        __builtin_memcpy(&ipv6->daddr, next_seg, sizeof(__u128));
        update_segs = true;
      }
    }

    if (srh->segments_left == 0)
    {
      if ((ENABLE_SEG6_FLAVOR_USP && !update_segs) || (ENABLE_SEG6_FLAVOR_PSP && update_segs))
      {
        if (!pop_srh(skb))
        {
          return false;
        }
      }
    }
    return true;
  }
  return false;
}

static __always_inline int usid_behavior_uN(struct __sk_buff *skb)
{
  void *data_end = (void *)(long)skb->data_end;
  void *data = (void *)(long)skb->data;

  struct ipv6hdr *ipv6 = data;
  struct ipv6_sr_hdr *srh = get_srh(skb);
  if (srh != NULL)
  {
    __u16 *usid_list = &ipv6->daddr;
    __u16 usid_pointer = USID_BLOCK_LENGTH / USID_LENGTH;
    if (usid_pointer >= 0 && usid_pointer <= 7)
    {
      if ((usid_pointer < 7 && usid_list[usid_pointer + 1] == USID_END_OF_CONTAINER) || usid_pointer == 7)
      {
        if (!seg6local_end(skb))
        {
          increment_stats(BPF_DROP);
          return BPF_DROP;
        }
        // reset
        data_end = (void *)(long)skb->data_end;
        data = (void *)(long)skb->data;
        ipv6 = data;
        srh = get_srh(skb);
        if (srh == NULL)
        {
          return true;
        }
        usid_list = &ipv6->daddr;
      }

      // update usid
      for (int i = usid_pointer; i < 7; i++)
      {
        usid_list[i] = usid_list[i + 1];
      }
      usid_list[7] = USID_END_OF_CONTAINER;
      increment_stats(BPF_OK);
      return BPF_OK;
    }
  }
  increment_stats(BPF_DROP);
  return BPF_DROP;
}

SEC("lwt_xmit/usid_uN")
int do_usid_uN(struct __sk_buff *skb)
{
  return usid_behavior_uN(skb);
}

SEC("lwt_xmit/usid_uD")
int do_usid_uD(struct __sk_buff *skb)
{
  // TODO

  return BPF_OK;
}

char _license[] SEC("license") = "GPL";
