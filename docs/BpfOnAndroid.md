# BPF on Android

Android 上的 eBPF 的文档也十分不全面，基本上我们也是一边对照官方残缺的文档，一边阅读 Android 中存在的 BPF 程序源码，一边读 Android BPF 的实现源码来搞懂的。

Android 自己在 BPF/eBPF 外面用 C++ 包了一层，提供了一些接口。这部分编译生成的库的名字叫做 `libbpf_android` ，可以在文件夹 `system/bpf/libbpf_android ` 中找到。比较重要的一个是定义了 `BpfMap`，它和底层的 bpf map 结构紧密相连，实际上就是提供了一个访问顶层 bpf map 的抽象 C++ OOP 接口，比较好用。关于对这部分的代码解释可以在我阅读源码的[笔记](../notes/rtfs.md)中找到。

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

置于确认此程序是否运行起来，可以看 `/sys/fsbpf`。因为 bpf 会打开文件描述符，并将加载的程序放在那里。这和 linux 上的是一致的。

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
