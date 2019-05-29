### eBPF on Android

#### 概览

在Android上包含一个 eBPF 加载程序和库，它会在 Android 启动时加载 eBPF 程序以扩展内核功能，这可用于从内核收集统计信息，进行监控或调试。

eBPF是一个内核内部的虚拟机，可运行用户提供的 eBPF 程序。这些程序可以通过 hook 接入内核中的探测点或事件、收集有用的统计信息，并将结果存储在多个数据结构中。程序通过 `bpf(2)` 系统调用加载到内核中，并作为 eBPF 机器指令的二进制 blob 由用户提供。Android 编译系统支持使用简单编译文件语法将 C 程序编译到 eBPF。

#### 实现

Android对eBPF程序的加载通过以下三个过程实现：

1. eBPF C程序

   编写eBPF C程序，其格式如下：

   ```
   #include <bpf_helpers.h>
   
   <... define one or more maps in the maps section, ex:
   /* Define a map of type array, with 10 entries */
   struct bpf_map_def SEC("maps") MY_MAPNAME = {
           .type = BPF_MAP_TYPE_ARRAY,
           .key_size = sizeof(int),
           .value_size = sizeof(uint32_t),
           .max_entries = 10,
   };
   ... >
   
   SEC("PROGTYPE/PROGNAME")
   int PROGFUNC(..args..) {
      <body-of-code
       ... read or write to MY_MAPNAME
       ... do other things
      >
   }
   
   char _license[] SEC("license") = "GPL"; // or other license
   ```

   对于函数`PROGFUNC`, 编译时，将函数放在一个section中，其名称为`PROGTYPE/PROGNAME`的格式，`PROGNAME`的类型可在程序的[源代码](https://android.googlesource.com/platform/system/bpf/+/4845288a6e42e13b1bb8063923b24371c9e93397/libbpf_android/Loader.cpp)中找到。

2. Android.bp文件

   为了使 Android 编译系统能编译 eBPF .c 程序，必须在项目的 Android.bp 文件中输入内容。

   ```
   bpf {
       name: "bpf.o",
       srcs: ["bpf.c"],
       cflags: [
           "-Wall",
           "-Werror",
       ],
   }
   ```

   用于C编译器，涵盖变异和汇编两个步骤，其中`bpf.c`会被编译并生成`bpf.o`，放到`/system/etc/bpf/`中去

3. 加载

   所有类似`bpf.o`的eBPF程序会在Android启动期间被系统加载（这些程序就是 Android 编译系统根据 C 程序和 Android 源代码树中的 Android.bp 文件编译而成的二进制对象），创建程序所需的映射，并将加载的程序及其映射固定到 bpf 文件系统，这些文件之后可用于与 eBPF 程序进一步交互或读取映射。

   系统会创建并固定以下文件：

   - 对于任何已加载的程序，假设 `PROGNAME` 是程序的名称，而 `FILENAME`是 eBPF C 文件的名称，则 Android 加载程序会创建每个程序并将其固定到 `/sys/fs/bpf/prog_FILENAME_PROGTYPE_PROGNAME`。
   - 对于任何已创建的映射，假设 `MAPNAME` 是映射的名称，而 `PROGNAME`是 eBPF C 文件的名称，则 Android 加载程序会创建每个映射并将其固定到 `/sys/fs/bpf/map_FILENAME_MAPNAME`。
   - Android BPF 库中的 `bpf_obj_get()` 可用于从这些固定的 `/sys/fs/bpf` 文件中获取文件描述符。此函数会返回文件描述符，该描述符可用于进一步执行操作（例如读取映射或将程序附加到跟踪点）。

#### Android BPF库

Android BPF 库名为 `libbpf_android.so`，属于系统映像的一部分。该库向用户提供了一些 eBPF 功能：

- 创建和读取映射
- 创建探测点、跟踪点、性能缓冲区

##### 将程序附加到跟踪点和 kprobe

跟踪点和 kprobe 程序加载完成后（如前所述，会在启动时自动完成），需要激活。要激活它们，首先使用 `bpf_obj_get()` API 从固定文件的位置获取程序 fd，接下来，调用 BPF 库中的 `bpf_attach_tracepoint()` API，将程序 fd 和跟踪点名称传递给该 API。

##### 从映射中读取数据

BPF 映射支持任意复杂的键和值结构或类型。Android BPF 库包含一个 `android::BpfMap` 类，该类利用 C++ 模板根据相关映射的键和值类型来实例化 `BpfMap`。

#### 示例：eBPF在Android上的流量监控

> eBPF网络流量工具即是eBPF C程序的一个示例：`netd`.
>
> 该工具收集的统计数据存储在称为`eBPF maps`的内核数据结构中，并且相应结果可供`NetworkStatsService`等服务用于提供自设备上次启动以来的持久流量统计数据。

- 配置

  内核配置需要开启以下配置：

  - `CONFIG_CGROUP_BPF=y`
  - `CONFIG_BPF=y`
  - `CONFIG_BPF_SYSCALL=y`
  - `CONFIG_NETFILTER_XT_MATCH_BPF=y`
  - `CONFIG_INET_UDP_DIAG=y`

- 实现过程

  [netd的源代码，包括netd.h, need.c, Android.bp](https://android.googlesource.com/platform/system/bpf/+/4845288a6e42e13b1bb8063923b24371c9e93397/progs)

  `trafficController` 设计基于 `per-cgroup` eBPF 过滤器以及内核中的 `xt_bpf` netfilter 模块。

  当数据包 tx/rx 通过 eBPF 过滤器时，系统会对其应用相应过滤器。`cgroup` eBPF 过滤器位于传输层中，负责根据套接字 UID 和用户空间设置对正确的 UID 计算流量。`xt_bpf` netfilter 连接在 `bw_raw_PREROUTING` 和 `bw_mangle_POSTROUTING` 链上，负责对正确的接口计算流量。

  在设备启动时，用户空间进程 `trafficController` 会创建用于收集数据的 eBPF 映射，并将所有映射作为虚拟文件固定在 `sys/fs/bpf`。然后，特权进程 `bpfloader` 将预编译的 eBPF 程序加载到内核中，并将其附加到正确的 `cgroup`。所有流量都对应于同一个根 `cgroup`，因此默认情况下，所有进程都应包含在该 `cgroup` 中。

  在系统运行时，`trafficController` 可以通过写入到 `traffic_cookie_tag_map` 和 `traffic_uid_counterSet_map`，对套接字进行标记/取消标记。`NetworkStatsService` 可以从 `traffic_tag_stats_map`、`traffic_uid_stats_map` 和 `traffic_iface_stats_map` 中读取流量统计数据。除了流量统计数据收集功能外，`trafficController` 和 `cgroup` eBPF 过滤器还负责根据手机设置屏蔽来自特定 UID 的流量。基于 UID 的网络流量屏蔽功能取代了内核中的 `xt_owner` 模块，详细模式可以通过写入到 `traffic_powersave_uid_map`、`traffic_standby_uid_map` 和 `traffic_dozable_uid_map` 来进行配置。