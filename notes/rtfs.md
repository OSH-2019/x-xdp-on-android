# BPF On Android

*此笔记不是为了充当我阅读代码后写的文档，只是为了之后自己看见这篇笔记能回忆起安卓bpf代码的结构。所以看不懂这篇文档很正常，下面的内容很多都没有说人话。*

- `./external/kernel-headers/original/uapi/linux/bpf.h`: original linux headers
- `./bionic/libc/kernel/uapi/linux/bpf.h`: generated automatically, just a duplicate, no need to modify it
- `./external/bcc`: BPF Compiler Collection
- linux kernel (including BPF) is prebuilt into Android

### `netd.c`

- `ifindex`: interface index
- 

### Android BPF Running Process: `netd` as example

- `netd.h`: Define BPF Map by using `bpf_map_def` or `DEFINE_BPF_MAP` in `SEC("map")` (which are defined in `bpf_helpers.h`).
  For example: 
  ```c
  struct bpf_map_def SEC("maps") iface_stats_map = {
      .type = BPF_MAP_TYPE_HASH,
      .key_size = sizeof(uint32_t),
      .value_size = sizeof(struct stats_value),
      .max_entries = IFACE_STATS_MAP_SIZE,
  };
  ```

- `netd.c`: 定义各种程序。这些程序会被 `bpfloader` 加载，并置于特定的 section 中。这些程序会修改定义的 BPF Map。
- 用户程序: 通过读取 BPF Map 来获取信息。同时需要事先将......详情阅读[this post](https://blogs.oracle.com/linux/notes-on-bpf-1).

#### Userspace Programs

- `TrafficController.cpp`: 类似于 `mCookieTagMap` 是一个 C++ 的 Wrapper。它将底层的 Bpf Map 包装起来
  例如，`mCookieTagMap.init(COOKIE_TAG_MAP_PATH)`, `COOKIE_TAG_MAP_PATH` 的定义为 `./netd/libnetdbpf/include/netdbpf/bpf_shared.h: #define COOKIE_TAG_MAP_PATH BPF_PATH "/map_netd_cookie_tag_map"`
- C++的一个高层抽象的Class `BpfMap` 定义在`/system/bpf/libbpf_android/include/bpf/BpfMap.h`
- `#define XT_BPF_INGRESS_PROG_PATH BPF_PATH "/prog_netd_skfilter_ingress_xtbpf"`

