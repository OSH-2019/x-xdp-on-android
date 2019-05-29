/*
 * Copyright (C) 2018 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include "netd.h"
#include <linux/bpf.h>
SEC("cgroupskb/ingress/stats")
int bpf_cgroup_ingress(struct __sk_buff* skb) {
    return bpf_traffic_account(skb, BPF_INGRESS);
}
SEC("cgroupskb/egress/stats")
int bpf_cgroup_egress(struct __sk_buff* skb) {
    return bpf_traffic_account(skb, BPF_EGRESS);
}
SEC("skfilter/egress/xtbpf")
int xt_bpf_egress_prog(struct __sk_buff* skb) {
    uint32_t key = skb->ifindex;
    bpf_update_stats(skb, &iface_stats_map, BPF_EGRESS, &key);
    return BPF_MATCH;
}
SEC("skfilter/ingress/xtbpf")
int xt_bpf_ingress_prog(struct __sk_buff* skb) {
    uint32_t key = skb->ifindex;
    bpf_update_stats(skb, &iface_stats_map, BPF_INGRESS, &key);
    return BPF_MATCH;
}
SEC("skfilter/whitelist/xtbpf")
int xt_bpf_whitelist_prog(struct __sk_buff* skb) {
    uint32_t sock_uid = get_socket_uid(skb);
    if (is_system_uid(sock_uid)) return BPF_MATCH;
    uint8_t* whitelistMatch = find_map_entry(&uid_owner_map, &sock_uid);
    if (whitelistMatch) return *whitelistMatch & HAPPY_BOX_MATCH;
    return BPF_NOMATCH;
}
SEC("skfilter/blacklist/xtbpf")
int xt_bpf_blacklist_prog(struct __sk_buff* skb) {
    uint32_t sock_uid = get_socket_uid(skb);
    uint8_t* blacklistMatch = find_map_entry(&uid_owner_map, &sock_uid);
    if (blacklistMatch) return *blacklistMatch & PENALTY_BOX_MATCH;
    return BPF_NOMATCH;
}
struct bpf_map_def SEC("maps") uid_permission_map = {
    .type = BPF_MAP_TYPE_HASH,
    .key_size = sizeof(uint32_t),
    .value_size = sizeof(uint8_t),
    .max_entries = UID_OWNER_MAP_SIZE,
};
SEC("cgroupsock/inet/creat")
int inet_socket_create(struct bpf_sock* sk) {
    uint64_t gid_uid = bpf_get_current_uid_gid();
    /*
     * A given app is guaranteed to have the same app ID in all the profiles in
     * which it is installed, and install permission is granted to app for all
     * user at install time so we only check the appId part of a request uid at
     * run time. See UserHandle#isSameApp for detail.
     */
    uint32_t appId = (gid_uid & 0xffffffff) % PER_USER_RANGE;
    uint8_t* internetPermission = find_map_entry(&uid_permission_map, &appId);
    if (internetPermission) return *internetPermission & ALLOW_SOCK_CREATE;
    return NO_PERMISSION;
}
char _license[] SEC("license") = "Apache 2.0";
