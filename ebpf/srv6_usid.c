#include <stdbool.h>
#include <arpa/inet.h>
#include <linux/bpf.h>
#include <linux/ipv6.h>
#include <linux/seg6.h>

#include "bpf_helpers.h"

#define __u128 __uint128_t

#define USID_END_OF_CONTAINER 0x0000

static volatile const __u16 USID_BLOCK_LENGTH = 32;
static const __u16 USID_LENGTH = 16;
static const __u16 USID_LIST_MAX = 7;
static const __u16 MAX_SEGMENTS_LENGHT = 15;

static volatile const bool ENABLE_SEG6_FLAVOR_PSP = true;
static volatile const bool ENABLE_SEG6_FLAVOR_USP = true;

static volatile const bool ENABLE_STATS = true;

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

  struct ipv6hdr *ipv6 = get_ipv6(skb);
  struct ipv6_sr_hdr *srh;
  if (ipv6)
  {
    if (ipv6->nexthdr == IPPROTO_ROUTING)
    {
      srh = (void *)ipv6 + sizeof(*ipv6);
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

  struct ipv6hdr *ipv6 = get_ipv6(skb);
  struct ipv6_sr_hdr *srh = get_srh(skb);
  if (ipv6 != NULL && srh != NULL)
  {
    unsigned long long pkt_len = data_end - data;
    unsigned long long srh_len = 1 + srh->hdrlen;

    ipv6->nexthdr = srh->nexthdr;
    ipv6->payload_len -= srh_len;

    long r = bpf_skb_change_tail(skb, pkt_len - srh_len, 0);
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
  struct ipv6hdr *ipv6 = get_ipv6(skb);
  struct ipv6_sr_hdr *srh = get_srh(skb);
  if (ipv6 != NULL && srh != NULL)
  {
    if (srh->segments_left > 0)
    {
      // update segment
      srh->segments_left--;
      __u16 next_seg_i = (__u16)srh->first_segment - (__u16)srh->segments_left;
      if (MAX_SEGMENTS_LENGHT > next_seg_i && next_seg_i >= 0)
      {
        __u128 *next_seg = (void *)&srh->segments + sizeof(__u128) * next_seg_i;
        if ((void *)next_seg >= data && (void *)next_seg + sizeof(*next_seg) <= data_end)
        {
          __builtin_memcpy(&ipv6->daddr, next_seg, sizeof(__u128));
          update_segs = true;
        }
      }
    }

    // Flavors
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

static __always_inline int usid_behavior_uN(struct __sk_buff *skb, __u16 usid_bolck_length)
{
  void *data_end = (void *)(long)skb->data_end;

  if (usid_bolck_length <= 0 || usid_bolck_length <= USID_LENGTH)
  {
    return BPF_DROP;
  }

  struct ipv6hdr *ipv6 = get_ipv6(skb);
  struct ipv6_sr_hdr *srh = get_srh(skb);
  if (ipv6 != NULL && srh != NULL)
  {
    __u16 *usid_list = (void *)&ipv6->daddr;
    __u16 *usid_list_end = (void *)&ipv6->daddr + sizeof(ipv6->daddr);

    __u16 usid_pointer = usid_bolck_length / USID_LENGTH;
    if (usid_pointer > 0 && usid_pointer <= 7)
    {
      __u16 *next_usid = NULL;
      // get next usid
      if (usid_pointer < 7)
      {
        next_usid = &usid_list[usid_pointer + 1];
        if ((void *)next_usid + sizeof(*next_usid) > (void *)usid_list_end || (void *)next_usid + sizeof(*next_usid) > data_end)
        {
          increment_stats(BPF_DROP);
          return BPF_DROP;
        }
      }

      // end behavior
      if ((next_usid != NULL && *next_usid == htons(USID_END_OF_CONTAINER)) || usid_pointer == 7)
      {
        if (!seg6local_end(skb))
        {
          increment_stats(BPF_DROP);
          return BPF_DROP;
        }
        ipv6 = get_ipv6(skb);
        if (ipv6 == NULL)
        {
          increment_stats(BPF_DROP);
          return BPF_DROP;
        }
        increment_stats(BPF_LWT_REROUTE);
        return BPF_LWT_REROUTE;
      }

      // update usid
      // The reason the loop starts at index 1 is to expand the loop.
#pragma clang loop unroll(full)
      for (int i = 1; i < 7; i++)
      {
        if (i >= usid_pointer)
        {
          __builtin_memcpy(&usid_list[i], &usid_list[i + 1], sizeof(__u16));
        }
      }

      __u16 end_of_container = htons(USID_END_OF_CONTAINER);
      __builtin_memcpy(&usid_list[USID_LIST_MAX], &end_of_container, sizeof(__u16));
      increment_stats(BPF_LWT_REROUTE);
      return BPF_LWT_REROUTE;
    }
  }
  increment_stats(BPF_DROP);
  return BPF_DROP;
}

SEC("lwt_xmit/usid_uN")
int do_usid_uN(struct __sk_buff *skb)
{
  return usid_behavior_uN(skb, USID_BLOCK_LENGTH);
}

SEC("lwt_xmit/usid_uD")
int do_usid_uD(struct __sk_buff *skb)
{
  // TODO
  return BPF_LWT_REROUTE;
}

char _license[] SEC("license") = "GPL";
