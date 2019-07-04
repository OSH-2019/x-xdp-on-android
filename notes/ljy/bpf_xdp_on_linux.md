# eBPF&XDP on linux
## bpf架构简介
* 指令集
    * BPF是一个通用的RISC指令集，它由11个64位寄存器和32位子寄存器，一个程序计数器和一个512字节的大BPF堆栈空间组成。

    * [指令集规范参考](https://github.com/iovisor/bpf-docs/blob/master/eBPF.md)

* MAP(重点)
![map](http://docs.cilium.io/en/stable/_images/bpf_map.png)

    * map是驻留在内核空间的键/值对，可以通过bpf访问，以便在多个bpf中共享。其实现由内核空间提供

* 尾调用(Tail call)
    * 在程序结尾调用另一bpf程序并且不再返回

* BPF to BPF Call
    * 新添加的功能，和函数调用类似

## 编写
通过llvm/clang可以将C语言程序（受限）转化为bpf代码。

ubuntu的安装（17.04以上）：

```
$ sudo apt-get install -y make gcc libssl-dev bc libelf-dev libcap-dev \
  clang gcc-multilib llvm libncurses5-dev git pkg-config libmnl-dev bison flex \
  graphviz
```

其与常规的C语言程序的差异大体如下（摘自[此处](http://docs.cilium.io/en/stable/bpf/)）：

* 所有内容都需要内联，没有函数调用（在较旧的LLVM版本上）可用
* 不允许全局变量（但有其他方法代替，如使用map）
* 不允许使用const字符串或数组
* 最大512字节的堆栈空间
* 尾调用
* ......

更多详细内容见上述[网页](http://docs.cilium.io/en/stable/bpf/)

## 调试
写好代码后用clang编译,例如:

```
$ clang -O2 -Wall -target bpf -c xdp-example.c -o xdp-example.o
```
or(根据不同的工具链更改参数)

```
$ clang -O2 -Wall -target bpf -I../libbpf/src/ -I/root/usr/include/ -I../headers/  -c test_xdp_kern.c -o test_xdp_kern.o

```


如果遇到语法错误，clang会进行提示

编译通过后的debug有几种的方法：

### 直接输出
```
#define bpf_debug(fmt, ...)						\
		({							\
			char ____fmt[] = fmt;				\
			bpf_trace_printk(____fmt, sizeof(____fmt),	\
				     ##__VA_ARGS__);			\
		})
		
......

bpf_debug("Debug: eth_type:0x%x\n", ntohs(eth_type));//输出
```

这里的bpf_debug相当于c语言中的printf，将想要确认的内容进行输出到/sys/kernel/debug/tracing/trace，达到调试的目的
（define中的bpf_trace_printk()函数的定义可以去[bpf.h](./example/files/kernel/include/uapi/linux/bpf.h)头文件中查找，包括后文常用的 bpf_map_lookup_elem()等函数在其中均有介绍）

### 阅读汇编代码调试
```
clang -O2 -S -Wall -target bpf -c xdp-example.c -o xdp-example.S
```
通过上述的命令可生成汇编代码

### ***BPFTOOL***
bpftool是围绕BPF的主要调试工具，并与Linux内核树一起开发和发布tools/bpf/bpftool/

该工具可以转储当前在系统中加载的所有BPF程序和映射,开发者可以通过这个工具方便的调试bpf代码。

构建bpftool：
```
$ cd <kernel-tree>/tools/bpf/bpftool/
$ make
Auto-detecting system features:
...                        libbfd: [ on  ]
...        disassembler-four-args: [ OFF ]

  CC       xlated_dumper.o
  CC       prog.o
  CC       common.o
  CC       cgroup.o
  CC       main.o
  CC       json_writer.o
  CC       cfg.o
  CC       map.o
  CC       jit_disasm.o
  CC       disasm.o
make[1]: Entering directory '/home/foo/trees/net/tools/lib/bpf'

Auto-detecting system features:
...                        libelf: [ on  ]
...                           bpf: [ on  ]

  CC       libbpf.o
  CC       bpf.o
  CC       nlattr.o
  LD       libbpf-in.o
  LINK     libbpf.a
make[1]: Leaving directory '/home/foo/trees/bpf/tools/lib/bpf'
  LINK     bpftool
$ sudo make install

```

关于bpftool的更多功能，例如可视化（visual）转储模式参考[这里](http://docs.cilium.io/en/stable/bpf/)

## 加载
bpf程序完成后需要特定的方法加载到内核中，常见的前端有***bcc，perf，iproute2***等。Linux内核源代码树还提供了一个用户空间库tools/lib/bpf/，主要由perf使用和驱动，用于将BPF程序加载到内核。但是，***库本身是通用的***

### 库依赖
***大多数的加载方式使用的都是libbpf库***

***这里给出github[链接](https://github.com/libbpf/libbpf/)***

bpf相关的头文件：
```
#include <bpf/bpf.h>
//#include <linux/bpf.h>
#include <bpf/libbpf.h>
```

网络相关的头文件：
```
#include <net/if.h>
#include <linux/if_link.h>
......
```

***注：不同的加载方式的头文件可能不完全相同，有一套自己的工具链***



下面简单介绍一些常用的加载前端

### BCC(BPF Compiler Collection)
由于xdp的示例较少，并非本文重点，放在另一[文档](./bcc.md)中

### iproute2
这是linux用于管理网络的工具包，利用这个工具能直接将文件加载到内核中，示例如下：
```
sudo ip link set lo xdpgeneric object test_xdp_kern.o sec xdp
```

lo：设备名称（可以通过`ip link`查看）

test_xdp_kern.o:要加载的内容(上文编译的结果)

sec xdp：这与代码本身的内容有关

想要将设备上的xdp代码卸下也很简单

```
ip link set lo xdpgeneric off
```
这方法虽然好用，但有一定的缺陷。

***其与bpf中的map可能无法兼容，会对xdp代码本身有所限制***

### tools/lib/bpf/（手写加载器）
Linux内核源代码树提供的一个用户空间库：tools/lib/bpf/，主要由perf使用和驱动

用户自己编写加载器，例如

xdp_kern.c为需要加载到内核的程序

xdp_user.c为加载器



接下来会用两个例子展示从编译到加载的全部过程

## Example
***详细见[example](./example.md)***

## 学习资料

[深入理解BPF](https://linux.cn/article-9507-1.html)

[BPF and XDP Reference Guide](http://docs.cilium.io/en/stable/bpf/#bpf-architecture)

[xdp教程](https://github.com/xdp-project/xdp-tutorial)