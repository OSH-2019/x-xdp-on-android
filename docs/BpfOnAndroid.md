# BPF/eBPF Architecture on Android

Android 上的 eBPF 的文档也十分不全面，基本上我们也是一边阅读 Android 中存在的 BPF 程序源码，一边读 Android BPF 的实现源码来搞懂的。

## Android BPF C++ Wrapper

Android 自己在 BPF/eBPF 外面用 C++ 包了一层，提供了一些接口。这部分编译生成的库的名字叫做 `libbpf_android` ，可以在文件夹 `system/bpf/libbpf_android ` 中找到。比较重要的一个是定义了 `BpfMap`，它和底层的 bpf map 结构紧密相连，实际上就是提供了一个访问顶层 bpf map 的抽象 C++ OOP 接口，比较好用。关于对这部分的代码解释可以在我**阅读源码的[笔记](../notes/rtfs.md)**中找到。

以下是我们通过阅读源码记录的内容。

### BpfMap

BpfMap 定义在 `system/bpf/libbpf_android/include/bpf/BpfMap.h` 中（C++ Template 直接定义在头文件中）。它的构造函数定义如下：

```c++
BpfMap<Key, Value>() : mMapFd(-1){};
explicit BpfMap<Key, Value>(int fd) : mMapFd(fd){};
BpfMap<Key, Value>(bpf_map_type map_type, uint32_t max_entries, uint32_t map_flags) {
    int map_fd = createMap(map_type, sizeof(Key), sizeof(Value), max_entries, map_flags);
    if (map_fd < 0) {
        mMapFd.reset(-1);
    } else {
        mMapFd.reset(map_fd);
    }
}
```

它实际上是接受一个文件描述符（`mMapFd`），这个文件描述符通过 `bpf_obj_get` 得到，这个描述符的内容指向的是 `SEC("map")`（即BPF 程序 map section）中的 bpf map 底层数据结构。这个 BpfMap 提供了一个一致的接口，用于通过高级操作访问底层数据结构。

也可以通过 `.init` 来初始化，用法为：

```cp
mCookieTagMap.init(COOKIE_TAG_MAP_PATH)
```

其中 `COOKIE_TAG_MAP_PATH` 实际就是底层 bpf map 的路径，例如：

`./netd/libnetdbpf/include/netdbpf/bpf_shared.h: #define COOKIE_TAG_MAP_PATH BPF_PATH "/map_netd_cookie_tag_map"`。

### Loader.cpp

安卓上的 BpfLoader 定义在 `system/bpf/libbpf_android/Loader.cpp` 中，这里是安卓自己定义的 BPF 的加载工具。

首先可以看出，BPF 会被加载到 `/sys/fs/bpf` 中：

```c++
#define BPF_FS_PATH "/sys/fs/bpf/"
```

仔细阅读源码，可以发现，在加载函数的过程中，既可以自己调用函数，并给出各个 Section 的 BPF 程序类型属性等等，也可以选择由 Android 默认选择。Android 开机即加载 BPF 程序的功能就是通过默认选择实现的。默认对应关系为：

```c++
sectionType sectionNameTypes[] = {
    {"kprobe", BPF_PROG_TYPE_KPROBE},
    {"tracepoint", BPF_PROG_TYPE_TRACEPOINT},
    {"skfilter", BPF_PROG_TYPE_SOCKET_FILTER},
    {"cgroupskb", BPF_PROG_TYPE_CGROUP_SKB},
    {"schedcls", BPF_PROG_TYPE_SCHED_CLS},
    {"cgroupsock", BPF_PROG_TYPE_CGROUP_SOCK},

    /* End of table */
    {"END", BPF_PROG_TYPE_UNSPEC},
};
```

这里就不详细讲每个程序类别是做什么的了。

## Compile and Run BPF Programs

为了将 bpf 程序编译入 Android，并运行起来，我们需要在某个地方写个 bpf 程序，例如 `bpf_example.c` ，然后在该模块中的 `Android.bp` （关于 `Android.bp` 的一些记录，可以看 [这里](../notes/Android_bp.md))，增添这样的内容:

```json
bpf {
    srcs: [
        "bpf_example.c",
    ],
    name: "bpf_example.o",
}
```

（bpf 属性，我们猜测，会指定这个程序的目标文件放到哪个文件夹，如何进行编译，增加一些额外的编译选项等内容。）

这样，程序会被编译到 `out/target/product/generic_x86_64/system/bpf/bpf_example.o` 中，这样，最后我们可以在运行 Android 的 /`system/bpf ` 中找到。值得一提的是，我们在使用 `m all` 或 `mma` 进行编译之后，需要在顶层目录输入 `make snod`，否则二进制文件可能不会打包到镜像中。`make snod` 的作用是重新打包生成 `system.img` 镜像。

置于确认此程序是否运行起来，可以看 `/sys/fs/bpf`。因为 bpf 会打开文件描述符，并将加载的程序放在那里。这和 linux 上的是一致的。

## Difference between BPF on Android and Linux

Android 上的 BPF 有一些变化。

Android 上的 BPF 源文件中的每个函数需要放在特定 section 中，每个函数相当于一个 BPF 程序。可以通过在函数定义前添加 `SEC` 来实现。例如`SEC("skfilter/ingress/xtbpf")`.

- Android 上的 BPF 程序类型（`bpf_prog_type`）相对 linux 上的有限制，每个 BPF_PROG_TYPE 都需要用固定的 section 名字（关于这一点，我详细阅读了源码。源码中会根据 section 的名字推断出默认的程序类型，你也可以任意命名，但那样的话就只能用一些更低级的系统调用完成 Bpf 程序的加载，并需要自己指定程序类型）。分为 `kprobe`, `tracepoint`, `skfilter`, `schedcls`, `cgroupskb`, `cgroupsock`。分别对应：`BPF_PROG_TYPE_KPROBE`, `BPF_PROG_TYPE_TRACEPOINT`, `BPF_PROG_TYPE_SOCKETK_FILTER`, `BPF_PROG_TYPE_SCHED_CLS`, `BPF_PROG_TYPE_CGROUP_SKB`, `BPF_PROG_TYPE_CGROUP_SOCK`。我们需要在其中添加 `BPF_PROG_TYPE_XDP`。关于每种类型的程序提供的参数是什么，返回的结果应是什么，作用是什么，我们找到了这篇博客：[notes-on-bpf](<https://blogs.oracle.com/linux/notes-on-bpf-1>).

- 由于 BpfMap 经过了包装，同时 `Android` 又通过 `BpfUtils.cpp` 提供了一些工具函数，所以实际写的代码也会有所不同。比如定义 bpf map 时：

  可以通过这种方式定义 map：

  ```c
  struct bpf_map_def SEC("maps") iface_stats_map = {
      .type = BPF_MAP_TYPE_HASH,
      .key_size = sizeof(uint32_t),
      .value_size = sizeof(struct stats_value),
      .max_entries = IFACE_STATS_MAP_SIZE,
  };
  ```

  也可以：

  ```c
  DEFINE_BPF_MAP(name_of_my_map, ARRAY, int, uint32_t, 10);
  ```

  在代码中访问时，可以用 `android::bpf::BpfMap`。`BpfMap` 的构造函数接受一个文件描述符作为参数。安卓的 `bpfloader` 在加载 BPF 程序的过程中，会将 map 对应的 section 放在 `/sys/fs/bpf/map_name_of_map` 中，所以可以通过 `bpf_obj_get` 得到该路径对应的 bpf 对象，再将其传给 BpfMap，就能通过 BpfMap 的高级类方法访问底层数据结构。
