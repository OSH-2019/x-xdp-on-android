# Research report

   * [Research report](#research-report)
      * [Team members](#team-members)
      * [Introduction](#introduction)
      * [Background](#background)
         * [C10K and C10M](#c10k-and-c10m)
            * [Introduction](#introduction-1)
            * [Solution](#solution)
            * [C10M is coming](#c10m-is-coming)
         * [Linux networking stack](#linux-networking-stack)
            * [Network stack](#network-stack)
            * [Core linux network architecture](#core-linux-network-architecture)
            * [kernel network core structures](#kernel-network-core-structures)
            * [The journey of a packet through linux network stack](#the-journey-of-a-packet-through-linux-network-stack)
         * [OS Kernel is insufficient](#os-kernel-is-insufficient)
         * [Programmable packet processing](#programmable-packet-processing)
            * [BPF](#bpf)
               * [Introduction](#introduction-2)
               * [Instruction set](#instruction-set)
               * [Example](#example)
            * [eBPF](#ebpf)
            * [Kernel-bypass solution](#kernel-bypass-solution)
               * [Why kernel-bypass](#why-kernel-bypass)
               * [DPDK](#dpdk)
               * [Snabb](#snabb)
               * [OpenOnload](#openonload)
               * [Drawback](#drawback)
            * [In-kernel solution](#in-kernel-solution)
               * [Why in-kernel](#why-in-kernel)
               * [XDP](#xdp)
         * [XDP](#xdp-1)
            * [How it works](#how-it-works)
               * [The XDP Driver Hook](#the-xdp-driver-hook)
         * [Programmatic usage](#programmatic-usage)
            * [A glance of XDP code](#a-glance-of-xdp-code)
               * [XDP Data structure](#xdp-data-structure)
               * [XDP Program return codes](#xdp-program-return-codes)
            * [Example](#example-1)
            * [Environment building](#environment-building)
         * [XDP vs DPDK](#xdp-vs-dpdk)
            * [General Design](#general-design)
            * [Programmability](#programmability)
            * [Device Support](#device-support)
            * [Performance](#performance)
            * [Pros of XDP](#pros-of-xdp)
            * [Production Use of XDP](#production-use-of-xdp)
      * [Related work (XDP)](#related-work-xdp)
      * [Importance &amp; Significance](#importance--significance)
         * [Android Background](#android-background)
            * [Mobile CPU Classification](#mobile-cpu-classification)
            * [android系统架构](#android系统架构)
            * [HIDL](#hidl)
               * [网络堆栈配置工具](#网络堆栈配置工具)
         * [Android的网络通信](#android的网络通信)
            * [Netd](#netd)
            * [android 平台提供的API](#android-平台提供的api)
               * [http.client接口](#httpclient接口)
            * [java.net 接口](#javanet-接口)
               * [socket](#socket)
            * [android wifi 流程](#android-wifi-流程)
               * [wifi的基本架构](#wifi的基本架构)
               * [wifi 在android中如何工作](#wifi-在android中如何工作)
         * [HAL](#hal)
            * [为什么有HAL](#为什么有hal)
         * [Network performance load stress tests](#network-performance-load-stress-tests)
            * [Linux(raw), XDP, DPDK](#linuxraw-xdp-dpdk)
            * [Android packet processing performance](#android-packet-processing-performance)
               * [Conclusion](#conclusion)
            * [Conclusion](#conclusion-1)
         * [Future of Network (2017-2022)](#future-of-network-2017-2022)
            * [Global networking devices](#global-networking-devices)
            * [IP data traffic](#ip-data-traffic)
            * [Network flow](#network-flow)
            * [About 5G](#about-5g)
         * [Conclusion](#conclusion-2)
      * [Related work](#related-work)
      * [Reference](#reference)

##	Team members
*	龚平 
*	王怡萱
*	魏剑宇
*	黄展翔
*	罗极羽

## Introduction

**该项目是将XDP移植至安卓平台，并进一步通过XDP在安卓上实现网络处理相关的应用。**
XDP是linux内核中一个强大、可编程、高效的网络数据通路。XDP在网络栈的最底层，以软件的方式实现了包处理和过滤，能运行在裸金属机器上。它在保持linux原本网络栈的情况下，提供了高效可编程的解决方案，相当于在linux网络栈中增加了预处理的一层。

考虑到网络的飞速发展和Android设备在5G时代不可替代的作用，Android设备的网络处理能力至关重要。CPU的包处理能力在如今来看已逐渐表现出不足。我们考虑将XDP移植至Android平台，从而实现移动设备高效的网络处理能力，并实现一些通过XDP能达成的高级功能。

## Background

### C10K and C10M

高性能网络处理需求（从C10K到C10M）

> C10K：单机1万个并发连接
> C10M：单机1千万个并发连接

#### Introduction

互联网的基础就是网络通信，早期的互联网可以说是一个小群体的集合。互联网还不够普及，用户也不多，一台服务器同时在线100个用户估计在当时已经算是大型应用了，所以并不存在什么 C10K 的难题。互联网的爆发期应该是在www网站，浏览器，雅虎出现后。最早的互联网称之为Web1.0，互联网大部分的使用场景是下载一个HTML页面，用户在浏览器中查看网页上的信息，这个时期也不存在C10K问题。

Web2.0时代到来后就不同了，一方面是普及率大大提高了，用户群体几何倍增长。另一方面是互联网不再是单纯的浏览万维网网页，逐渐开始进行交互，而且应用程序的逻辑也变的更复杂，从简单的表单提交，到即时通信和在线实时互动，C10K的问题才体现出来。因为每一个用户都必须与服务器保持TCP连接才能进行实时的数据交互，诸如Facebook这样的网站同一时间的并发TCP连接很可能已经过亿。

这时候问题就来了，最初的服务器都是基于进程/线程模型的，新到来一个TCP连接，就需要分配1个进程（或者线程）。而进程又是操作系统最昂贵的资源，一台机器无法创建很多进程。如果是C10K就要创建1万个进程，那么单机而言操作系统是无法承受的（往往出现效率低下甚至完全瘫痪）。如果是采用分布式系统，维持1亿用户在线需要10万台服务器，成本巨大，也只有Facebook、Google、雅虎等巨头才有财力购买如此多的服务器。

基于上述考虑，如何突破单机性能局限，是高性能网络编程所必须要直面的问题。这些局限和问题最早被Dan Kegel 进行了归纳和总结，并首次成系统地分析和提出解决方案，后来这种普遍的网络现象和技术局限都被大家称为 C10K 问题。

#### Solution

多年大量的实践证明，异步处理和基于事件（即epoll，kqueue和iocp）的响应方式成为处理这类问题的事实上标准方法。虽然epoll 已经可以较好的处理 C10K 问题，但是如果要进一步的扩展，例如支持 10M 规模的并发连接，原有的技术就无能为力了。

#### C10M is coming

十几年后，当摩尔定律在硬件上的理论提升有1000倍时，有人对并发数量提出了更高的要求，"C10K"升级为"C10M"问题，即每秒应对10M个客户端的同时访问。

最早提出"C10M"问题的Robert Graham认为，减少开销的关键之一在于绕过操作系统，即"kernel bypass"，因为我们使用的操作系统在设计之初并没有考虑高并发的场景，而I/O路径上的大部分例程又在内核空间中，大量无谓的消耗花在了内核空间和用户空间上下文的切换上。解决的方法就是将I/O路径（对于网络请求来讲，就是驱动和网络协议栈）全部实现在用户空间，这样可以最大程度的减少内核的干预，并且通过轮询(polling)而不是硬件中断的方法来获取网卡上的请求（而对于存储器来讲，就是complete信息）。再结合其他优化方法，例如协程和零拷贝技术，可以将并发性能优化到极致。

基于这样的背景，一种未来的趋势是出更多的硬件驱动将在用户空间中实现，而这种趋势似乎正在慢慢成为现实。例如Intel的***DPDK相关的技术***，以及***XDP技术***。

### Linux networking stack

这一节将主要大致描述 linux 网络栈的组成并且为何只靠内核的网络栈进行处理是低效率的。

#### Network stack

网络栈分为以下5层：

![linux-network-stack](assets/ANS-figure1.gif)

#### Core linux network architecture

这一节将讲述linux是如何实现上述网络栈的模型的。如下，是 linux 的网络架构。

![img](assets/ANS-figure2.gif)

- System call interface：这个为应用程序获取内核的网络系统提供了接口。
- Protocol agnostic interface：为和各种传输层协议的网络交互提供的一层公共接口。
- Network protocals：对各种传输层协议的实现，如TCP、UDP、IP等。
- Device agnostic interface：为各种底层网络设备抽象出的公共接口。
- Device drivers：与各种网络设备交互的驱动实现。

从上可以看出，linux的网络架构经过了层层抽象，在为开发带来便利的同时也将带来一定程度上的低效率。

#### kernel network core structures

- `sk_buff`：即套接字缓存 *socket buffer*，贯穿于整个 linux 协议栈，代表一个要发送或处理的报文。

  当一个报文通过了网卡引起终端之后，每一个报文都会在内存中分配一块区域，称为`sk_buff`。

- `net_device`：表示NIC。

#### The journey of a packet through linux network stack

这一节基于上面的基础，将概括一个报文到底是如何通过 linux 网络层到达用户应用程序的。

1. 当NIC收到一个帧（匹配本机MAC地址或者是一个链路层的广播），将通过DMA将报文移到环形缓冲区。
2. NIC引起硬件中断。
3. 硬件中断的handler将引起软件中断。
4. 驱动将处理这个中断，它将报文从环形缓冲区溢出，在内存中分配一个`skb`。并调用`netif_rx(skb)`，此例程归属于[上述](#core-linux-network-architecture)的Device agnostic interface。
5. 此`skb`将放入cpu处理报文的队列中。如果队列满了此包将丢掉。到这为止中断就处理结束了。
6. cpu处理到此报文时，调用`net_rx_action()`，这是此报文将从cpu的接受队列中移除。
7. 之后再进行与报文协议相关的高级处理。包括ip地址、校验和等等。

可以看出，一个报文从到达网卡至cpu可以处理此报文至进一步处理需要许多步骤。

在这里我们可以看出，对一个包的处理，哪怕这个包最后只是需要DROP掉或REDIRECT，也需要进行很多原本不必要的操作。

[这里](https://blog.cloudflare.com/kernel-bypass/)有一个测试。对linux在极限情况下进行报文处理速度的测试，即在最早的时间里drop掉该报文：

```shell
$ sudo iptables -t raw -I PREROUTING -p udp --dport 4321 --dst 192.168.254.1 -j DROP
$ sudo ethtool -X eth2 weight 1
$ watch 'ethtool -S eth2|grep rx'
     rx_packets:       12.2m/s
     rx-0.rx_packets:   1.4m/s
     rx-1.rx_packets:   0/s
     ...
```

结果发现，当网卡已12.2m pps(*packets per second*)的速度收取报文时，cpu的最高处理速度只能达到1.4m pps。linux严重限制了报文处理速度。

### OS Kernel is insufficient

这一节承接上一节，详细描述 linux kernel 在报文处理上的不足。

**中断处理**：当网络中大量数据包到来时，会产生频繁的硬件中断请求，这些硬件中断可以打断之前较低优先级的软中断或者系统调用的执行过程，如果这种打断频繁的话，将会产生较高的性能开销。

**内存拷贝**：正常情况下，一个网络数据包从网卡到应用程序需要经过如下的过程：数据从网卡通过 DMA 等方式传到内核开辟的缓冲区，然后从内核空间拷贝到用户态空间，在 Linux 内核协议栈中，这个耗时操作甚至占到了数据包整个处理流程的 57.1%。

**上下文切换**：频繁到达的硬件中断和软中断都可能随时抢占系统调用的运行，这会产生大量的上下文切换开销。另外，在基于多线程的服务器设计框架中，线程间的调度也会产生频繁的上下文切换开销，同样，锁竞争的耗能也是一个非常严重的问题。

**局部性失效**：如今主流的处理器都是多个核心的，这意味着一个数据包的处理可能跨多个 CPU 核心，比如一个数据包可能中断在 cpu0，内核态处理在 cpu1，用户态处理在 cpu2，这样跨多个核心，容易造成 CPU 缓存失效，造成局部性失效。如果是 NUMA 架构，更会造成跨 NUMA 访问内存，性能受到很大影响。

**内存管理**：传统服务器内存页为 4K，为了提高内存的访问速度，避免 cache miss，可以增加 cache 中映射表的条目，但这又会影响 CPU 的检索效率。

我们可以先设想一下：如果一个包刚刚被启动从环形缓冲区中取出，就进行用户定义的包过滤/处理操作，那将能显著提升效率。事实上这就是下面将详细介绍的XDP几乎能赶上DPDK都能kernel bypass解决方案的基本原理。也可以说，它在linux的网络栈中加了新的一层。

### Programmable packet processing

kernel的网络处理是一套集成、完整、通用的包处理方式，但对用户而言，这种通用化的方式可能不够用。在软件层面自己实现包处理将带来低效，于是可编程的包处理方案应运而生。

#### BPF

##### Introduction

BPF，及伯克利包过滤器Berkeley Packet Filter，最初构想提出于 1992 年，其目的是为了提供一种过滤包的方法，并且要避免从内核空间到用户空间的无用的数据包复制行为。它最初是由从用户空间注入到内核的一个简单的字节码构成，它在那个位置利用一个校验器进行检查 —— 以避免内核崩溃或者安全问题 —— 并附着到一个套接字上，接着在每个接收到的包上运行。几年后它被移植到 Linux 上，并且应用于一小部分应用程序上（例如，`tcpdump`）。其简化的语言以及存在于内核中的即时编译器（JIT），使 BPF 成为一个性能卓越的工具。

##### Instruction set

它通过底层的一个BPF虚拟机执行字节码。BPF的字节码本质是一个RISC指令集。能通过书写高级语言，并使用编译后端将其编译为C（主要是LLVM）。这里的高级语言是C语言特性的一个子集。之后虚拟机将通过一个JIT编译器来将字节码翻译为指令来执行。

##### Example

```c
#include <linux/bpf.h>

#ifndef __section
# define __section(NAME)                  \
   __attribute__((section(NAME), used))
#endif

#ifndef __inline
# define __inline                         \
   inline __attribute__((always_inline))
#endif

static __inline int foo(void)
{
    return XDP_DROP;
}

__section("prog")
int xdp_drop(struct xdp_md *ctx)
{
    return foo();
}

char __license[] __section("license") = "GPL";

```

#### eBPF

eBPF是对cBPF（即classic BPF，指BPF，相对于eBPF）的拓展。它扩充了BPF的功能，丰富了BPF的指令集，并提供了一些新的hook。

BPF提供两个选项，BPF的基本思想是对用户提供两种`SOCKET`选项：`SO_ATTACH_FILTER`和`SO_ATTACH_BPF`，允许用户在`sokcet`上添加自定义的`filter`，只有满足该`filter`指定条件的数据包才会上发到用户空间。`SO_ATTACH_FILTER`插入的是`cBPF`代码，`SO_ATTACH_BPF`插入的是`eBPF`代码。

#### Kernel-bypass solution

##### Why kernel-bypass

从上面的[linux网络栈](#Linux-networking-stack)可以看出，linux内核对包的处理十分复杂。每个报文的处理过多，降低了整个系统的效率。为了达到高效率，绕过内核的想法就自然地产生了。

这种解决方案是越过整个内核的处理过程，全权交给应用。通过整个CPU来进行包处理。显著地提供了效率。

##### DPDK

DPDK是intel提供的x86平台上的一套完整的可编程高效包处理的工具包。

在X86结构中，处理数据包的传统方式是CPU中断方式，即网卡驱动接收到数据包后通过中断通知CPU处理，然后由CPU拷贝数据并交给协议栈。在数据量大时，这种方式会产生大量CPU中断，导致CPU无法运行其他程序。

而DPDK则采用[轮询](https://zh.wikipedia.org/wiki/%E8%BC%AA%E8%A9%A2)方式实现数据包处理过程：DPDK重载了网卡驱动，该驱动在收到数据包后不中断通知CPU，而是将数据包通过[零拷贝](https://zh.wikipedia.org/wiki/%E9%9B%B6%E6%8B%B7%E8%B4%9D)技术存入内存，这时应用层程序就可以通过DPDK提供的接口，直接从内存读取数据包。

这种处理方式节省了CPU中断时间、内存拷贝时间，并向应用层提供了简单易行且高效的数据包处理方式，使得网络应用的开发更加方便。但同时，由于需要重载网卡驱动，因此该开发包目前只能用在部分采用Intel网络处理芯片的网卡中。

由于通过轮询的方式，DPDK也带来了CPU的高负荷。DPDK一般运行于一整个CPU核上，并将占用100%的CPU。

##### Snabb

[Snabb](https://github.com/snabbco/snabb)是一个简单快速的网络工具包。它通过Lua语言编写。Snabb会编译为可执行文件`snabb`，能运行在linux x86/64平台上。

Snabb具有高扩展性、虚拟化特性。它同样也可以在container中使用。

##### OpenOnload

[OpenOnload](https://www.openonload.org/)是Softflare提出的一个高效的网络栈。它基于标准的BSD sockets API，不需要修改应用就可以使用。它能显著提高信息传输速率，降低延迟。它在用户层运行，同样越过了整个linux内核。

##### Drawback

Kernel-bypass在带来高效的同时，也带来了一些问题。

- 它们跳过了整个操作系统，全权交给应用，因此带来安全上的问题。
- 它们难以与现有的系统集成，应用必须重新实现一些本来由操作系统网络栈提供的功能。
- 操作系统提供的工具和部署策略无法使用。
- 提升了系统复杂性，模糊了安全上本来由操作系统控制的边界。

#### In-kernel solution

##### Why in-kernel

正是在kernel-bypass问题的基础上，in-kernel体现了其重要性。

并且它置身于内核，用户不需要安装第三方工具即可使用，并且由于在linux内核中，用户不需要配置新的开发环境。

##### XDP

然而，正是因为linux内核对报文做了过多的处理降低了效率，我们才需要跳过内核。如果这个工具本身就在内核中，效率不是很慢吗？

XDP完美的解决了这个问题。它相当于在linux网络栈中加了新的一层。在报文到达CPU的最早时刻进行处理，甚至避免了`skb`的分配，从而减少了内存拷贝上的负荷。同时，XDP又提供了一套完整的、可编程的报文处理方案。

下面将详细介绍XDP。

### XDP

#### How it works

XDP设计背后的理念是在保证安全性和系统其余部分完整性的前提下，与操作系统内核协同，进行高性能包处理。图一显示了XDP是如何集成进操作系统内核的。

![figure 1](assets/figure1.PNG)

**figure1**：XDP与Linux网络堆栈的集成。在数据包到达时，在触摸数据包数据之前，设备驱动程序在主XDP挂钩中执行eBPF程序。该程序可以选择丢弃数据包;将它们发回到收到的同一界面；通过special AF_XDP套接字将它们重定向到另一个接口或用户空间；或者允许它们继续进行整体网络堆栈，其中一个单独的TC BPF挂钩可以执行进一步处理，然后进行数据包队列传输。不同的eBPF程序可以通过使用相互之间和用户空间进行通信。 

图2显示了典型XDP程序的执行流程。主要有四个XDP系统的组件：

+ XDP driver hook 是XDP的主要入口点程序，并在从收到数据包时执行硬件。
+ The eBPF virtual machine 执行的字节代码XDP程序，及时编译它以增加性能。
+ BPF map 用作主要的key/map存储通信通道到系统的其余部分。
+ The eBPF verifier eBPF验证程序在它们之前静态验证程序加载,以确保它们不会崩溃或损坏运行内核。

![figure 2](assets/figure2.PNG)

##### The XDP Driver Hook

每次包到来时，XDP程序由网络设备驱动中的hook 运行。执行程序的基础设施是作为库函数包含在内核中，这意味着程序直接在设备驱动程序中执行，没有上下文切换到用户空间。如图1所示，程序在收到数据包后的最早时刻执行硬件，在内核分配每个包的sk_buff数据之前构造或执行包的任何解析。

图2显示了通常通过XDP程序执行的各种处理步骤。当程序有一个context object时程序开始执行。这个对象包含指向原始包的指针数据，以及描述是从哪个接口和的接收队列获得的数据包的元数据。

程序通常从解析包数据开始，并且可以因此，通过tail调用将控件传递给另一个XDP程序将处理划分为逻辑子单元(例如，基于IP header version)。

在解析包数据之后，XDP程序可以使用上下文对象来读取与包关联的元数据fields(描述数据包从什么接口和接收队列来)。上下文对象还可以访问特殊的内存区域(位于存储器中的分组数据), XDP程序可以使用此内存将自己的元数据附加到数据包，当它穿过系统时将随身携带。

除了每个数据包的元数据，XDP程序还可以定义和访问自己的持久数据结构（通过BPF map），它可以通过各种帮助功能访问内核设施。map允许该程序与系统的其余部分进行通信，并且帮助者允许它有选择地利用现有的内核功能（如路由表），且无需通过完整的内核
网络堆栈。新的辅助功能由内核开发社区不断提供，从而不断扩展XDP程序可以使用的功能。

最后，程序可以对包数据的任何部分进行写操作，包括扩展或缩小数据包缓冲区来添加或删除头文件。这允许它执行封装或解封装。比如，各种内核辅助函数可以用于协助类似校验和计算修改后的操作包的功能。

这三个步骤（阅读，元数据处理和写作分组数据）对应于图2左侧的浅灰色框.由于XDP程序可以包含任意指令，因此不同的步骤可以以任意方式交替和重复。

在处理结束时，XDP程序最终发布对于数据包的判定。

### Programmatic usage

#### A glance of XDP code

##### XDP Data structure

XDP会将 packet 以数据的形式传给BPF（以下的BPF指eBPF）程序，packet在XDP中的数据结构为：

```c
struct xdp_buff {
    void *data;
    void *data_end;
    void *data_meta;
    void *data_hard_start;
    struct xdp_rxq_info *rxq;
};
```

这里，`data`指向报文数据的开始，`data_end`指向报文数据的结束。

`data_hard_start`，是由于`headroom`的存在，报文的header空间已经提前分配了，`data_hard_start`指向当前报文header的开始。当包经过再封装时（即加入了新的header），通过`bpf_xdp_adjust_head()`，`data`会离`data_hard_start`更近。

`data_meta`最开始和`data`指向同一处，通过`bpf_xdp_adjust_meta()`，`data_meta`会指向元数据信息。这串信息对linux的网络栈是不可见的，但能被BPF程序所用。这样，指针的大小顺序就是：`data_hard_start` <= `data_meta` <= `data` < `data_end`。

`rxq `是rx queue的一串数据，它存在于`ring`的建立期。`xdp_rxq_info`的数据结构如下：

```c
struct xdp_rxq_info {
    struct net_device *dev;
    u32 queue_index;
    u32 reg_state;
} ____cacheline_aligned;
```

##### XDP Program return codes

XDP程序的返回值如下：

```c
enum xdp_action {
    XDP_ABORTED = 0,
    XDP_DROP,
    XDP_PASS,
    XDP_TX,
    XDP_REDIRECT,
};
```

此返回值会告诉网卡驱动接下来如何处理报文。

`XDP_DROP`表示接下来会直接丢掉该packet。与软件上的实现不同，此`DROP`不会消耗任何资源，甚至不会为该packet分配`skb_buff`，用这个能大大加快效率。（从这里可以看出，XDP十分适合用于防范DDoS攻击）。

`XDP_PASS`表示该packet会被交给Linux内核[一般的网络栈处理](#linux-networking-stack)。

`XDP_TX`表示该packet会被传输出刚刚到达的NIC。通过这个能在对该packet进行一些处理后，传输出该网卡。这个在做load balancing上十分有用。

`XDP_REDIRECT`表示packet会被传输给其它的NIC。这个与`XDP_TX`配合使用，能构造出高效的load balancing。

`XDP_ABORTED`大致行为与`XDP_PASS`相似，不过他还会引起`trace_xdp_exception`，这个能用于监测错误行为。

#### Example

```c
/* map used to count packets; key is IP protocol, value is pkt count */
struct bpf_map_def SEC("maps") rxcnt = {
    .type = BPF_MAP_TYPE_PERCPU_ARRAY,
    .key_size = sizeof(u32),
    .value_size = sizeof(long),
    .max_entries = 256,
};

/* swaps MAC addresses using direct packet data access */
static void swap_src_dst_mac(void *data)
{
    unsigned short *p = data;
    unsigned short dst[3];
    dst[0] = p[0];
    dst[1] = p[1];
    dst[2] = p[2];
    p[0] = p[3];
    p[1] = p[4];
    p[2] = p[5];
    p[3] = dst[0];
    p[4] = dst[1];
    p[5] = dst[2];
}

static int parse_ipv4(void *data, u64 nh_off, void *data_end)
{
    struct iphdr *iph = data + nh_off;
    if (iph + 1 > data_end)
        return 0;
    return iph->protocol;
}

SEC("xdp1") /* marks main eBPF program entry point */
int xdp_prog1(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    struct ethhdr *eth = data;
    int rc = XDP_DROP;
    long *value;
    u16 h_proto;
    u64 nh_off;
    u32 ipproto;

    nh_off = sizeof(*eth);
    if (data + nh_off > data_end)
        return rc;

    h_proto = eth->h_proto;

    /* check VLAN tag; could be repeated to support double-tagged VLAN */
    if (h_proto == htons(ETH_P_8021Q) || h_proto == htons(ETH_P_8021AD))
    {
        struct vlan_hdr *vhdr;

        vhdr = data + nh_off;
        nh_off += sizeof(struct vlan_hdr);
        if (data + nh_off > data_end)
            return rc;
        h_proto = vhdr->h_vlan_encapsulated_proto;
    }

    if (h_proto == htons(ETH_P_IP))
        ipproto = parse_ipv4(data, nh_off, data_end);
    else if (h_proto == htons(ETH_P_IPV6))
        ipproto = parse_ipv6(data, nh_off, data_end);
    else
        ipproto = 0;

    /* lookup map element for ip protocol, used for packet counter */
    value = bpf_map_lookup_elem(&rxcnt, &ipproto);
    if (value)
        *value += 1;

    /* swap MAC addrs for UDP packets, transmit out this interface */
    if (ipproto == IPPROTO_UDP)
    {
        swap_src_dst_mac(data);
        rc = XDP_TX;
    }
    return rc;
}
```

为了展示上面描述的功能，上面显示了一个一个简单的XDP程序的例子。该程序将解析数据包头文件，并通过交换源和目标MAC地址来反映所有UDP数据包。虽然这显然是一个非常简单的例子，但是这个程序的确代表了现实中非常有用的XDP程序的大部分特点。

+ BPF地图（第1-7行）以保持统计数据处理的数据包数量。地图以IP协议号为基础，并且每个值只是一个简单的包计数（在第60-62行更新）。用户空间程序可以轮询它，以在XDP程序运行时输出数据。
+ 指向数据包开始和结束的指针从
  上下文对象读取（第30-31行），用于直接包数据访问。
+ 检查data_end指针可确保没有数据读出界限（第22,36和47行）。验证者确保甚至跨指针副本的正确性（如第21-22行）。
+ 程序必须处理任何数据包解析本身，包括诸如VLAN头之类的东西（第41-50行）
+ 直接分组数据访问用于修改分组报头（第14-16行）。
+ 内核公开的映射查找辅助函数（在第60行上调用）。这是唯一真正的函数调用程序;所有其他函数都在编译时内联，包括像`htons()`这样的帮助器。
+ 最终的数据包判决由程序传达返回码（第69行）。

当程序被安装在接口上时，首先被编译为eBPF字节码，然后由 verifier 检查。值得注意的事情在这种情况下由 verifier 检查以下几项

- 循环的展开和程序的总大小
- 报文数据进行了数组边界检查
- 传递给`bpf_map` 的参数大小符合定义
- `bpf_map` 的返回值不是`NULL`

#### Environment building

为了编译XDP/eBPF的代码，需要llvm提供的BPF后端。环境要求如下：

- clang >= version 3.4.0
- llvm >= version 3.7.1

安装开发环境，键入如下命令：

```shell
$ sudo apt-get install -y make gcc libssl-dev bc libelf-dev libcap-dev \
  clang gcc-multilib llvm libncurses5-dev git pkg-config libmnl bison flex \
  graphviz
```

### XDP vs DPDK

#### General Design

DPDK采取的是一种越过操作系统内核的方式（kernel bypass）。下图是DPDK的原理图。![pr-3303](assets/PR-3303.png)

包处理完全通过用户空间的程序来处理，在提升效率的同时，操作系统内核的程序隔离、安全机制也不再起作用，导致了不安全性。同样的，一些基于内核功能的成熟的部署、管理和配置工具也不再起作用。

为了提高效率，DPDK采用轮询的方式，无论在何种情况下，都需要一整个CPU来处理，CPU占用率一直是100%。

XDP直接集成在内核中。由于直接运行在内核中，内核提供了一个安全的执行环境。这样它保证了内核安全性，不需要更改网络配置，不需要硬件的特殊支持，只需要在网卡的驱动中实现XDP hook。因而为packet processing提供了一个更轻量级的解决方案。

![](assets/xdp-packet-processing-1024x560.png)

一般而言通过了内核效率可能会成为问题，而XDP为了缩小与DPDK的效率，它在更早的阶段处理包——即packet刚到达，在CPU所能进行处理的最早阶段。

> XDP is a further step in evolution and enables to run a specific flavor of BPF programs from the network driver with direct access to the packet's DMA buffer. This is, by definition, the earliest possible point in the software stack, where programs can be attached to in order to allow for a programmable, high performance packet processor in the Linux kernel networking data path.
>
> At this point in the fast-path the driver just picked up the packet from its receive rings, without having done any expensive operations such as allocating an `skb` for pushing the packet further up the networking stack, without having pushed the packet into the GRO engine, etc. Thus, the XDP BPF program is executed at the earliest point when it becomes available to the CPU for processing. 

这样，XDP跳过了一些网络处理层，在很早的阶段对packet进行了处理。它直接操作DMA(Direct Memory Access) buffer，还没有为packet分配skb空间。同时XDP没有内存分配，进一步提高了效率。

#### Programmability

XDP通过eBPF提供了一套十分灵活的可编程解决方案。它将可编程性直接植入操作系统的网络栈中。XDP在运行过程中，不需要对网络进行任何操作，而可以直接替换XDP运行的eBPF程序。

> Can be dynamically re-programmed without any service interruption, which means that features can be added on the fly or removed completely when they are not needed without interruption of network traffic,and that processing can react dynamically to conditions in other parts of the system.

DPDK则是提供一套包处理库，程序员在软件层面、跳过操作系统内核编写包处理程序。

#### Device Support

相对来说，DPDK支持更多的网卡驱动。由于DPDK是一套已经成熟的工业解决方案，它几乎支持所有的intel网卡。而XDP还在不断地开发中，仍有部分网卡没有充分支持。

#### Performance

- packet drop![](assets/figure5.png)

- packet forwarding![](assets/figure6.png)

可以看出，DPDK的总体效率更高，但在单核的情况下， packet forwarding的效率已相差无几，且在扩展性上面XDP更好。

#### Pros of XDP

- 用户应用程序透明
- 不需要整个CPU进行轮询
- 由于使用eBPF，eBPF程序将编译为byte code，因此在不同机器上XDP的程序**不需要重新编译**即可直接使用。
- 和操作系统内核紧密地结合，提供了安全性，也更方便部署。

#### Production Use of XDP

[katran](https://github.com/facebookincubator/katran)

[cilium](https://github.com/cilium/cilium)

## Related work (XDP)

* XDP的首届峰会直到2016年才举行，它正处于方兴未艾的发展阶段，正适合做进一步的研究和应用。

  XDP的相关使用场景：

* DDoS过滤：通过CloudFlare实现内核绕过，单个RX队列绕过Netmap，使用eBPF过滤丢弃坏包并重新注入好的数据包。XDP可以避免使用eBPF重新注入好数据包时解析数据包“inline”，目前还可以进行进一步优化。
* 负载平衡：对于不是localhost的数据包，XDP_TX转发到负责终止流量的服务器，需要与Tunnel标头decap/encap结合使用。
* 路由器：在eBPF中实现路由器/转发数据平面，但由于多端口TX尚未实现，目前主要是DPDK在做这项工作。
* L2 learning bridge：在多端口TX实现的前提下，则可通过XDP程序访问端口设计。

## Importance & Significance

### Android Background
#### Mobile CPU Classification

**AP应用处理器：**

手机CPU中最主要的一部分，手机的系统运作还有APP的运行，靠的都是AP应用处理器。例如：苹果A9处理器指的就是AP。

![CPU Architecture and design](assets/20160428035427396.jpg)

**BP基带处理器：**

基带处理器管理的是手机一切无线信号（除了wifi，蓝牙，NFC等等），一款手机支持多少种网络模式，支持4G还是3G，都是由基带部分决定的。BP做的最有名的是高通，其实高通发家靠的就是优秀的BP基带处理器，而不是AP应用处理器。

![CPU Architecture and design](assets/20160428035450269.jpg)

**CP多媒体加速器：**

其实每个厂商对CP都有不同的名字，比如苹果把它叫做协处理器，高通820叫做“低功率岛”。在早期CP只用于解码视频和处理音频等等简单任务。

![CPU Architecture and design](assets/20160428035503146.jpg)

但是各大厂商发现，CP的性能其实也可以很高，于是开始处理的东西越来越多。现在的CP已经可以处理虚拟现实，增强现实，图像处理，HIFI，HDR，传感器等等。

![CPU Architecture and design](assets/20160428035509228-1554018510247.jpg)



#### android系统架构

![](assets/architecture.png)



- **应用框架**。应用框架最常被应用开发者使用。作为硬件开发者，您应该非常了解开发者 API，因为很多此类 API 都可以直接映射到底层 HAL 接口，并可提供与实现驱动程序相关的实用信息。
- **Binder IPC**。Binder 进程间通信 (IPC) 机制允许应用框架跨越进程边界并调用 Android 系统服务代码，这使得高级框架 API 能与 Android 系统服务进行交互。在应用框架级别，开发者无法看到此类通信的过程，但一切似乎都在“按部就班地运行”。
- **系统服务**。系统服务是专注于特定功能的模块化组件，例如窗口管理器、搜索服务或通知管理器。 应用框架 API 所提供的功能可与系统服务通信，以访问底层硬件。Android 包含两组服务：“系统”（诸如窗口管理器和通知管理器之类的服务）和“媒体”（与播放和录制媒体相关的服务）。
- **硬件抽象层 (HAL)**。HAL 可定义一个标准接口以供硬件供应商实现，这可让 Android 忽略较低级别的驱动程序实现。借助 HAL，您可以顺利实现相关功能，而不会影响或更改更高级别的系统。HAL 实现会被封装成模块，并会由 Android 系统适时地加载。
- **Linux 内核**。开发设备驱动程序与开发典型的 Linux 设备驱动程序类似。Android 使用的 Linux 内核版本包含几个特殊的补充功能，例如：Low Memory Killer（一种内存管理系统，可更主动地保留内存）、唤醒锁定（一种 [`PowerManager`](https://developer.android.google.cn/reference/android/os/PowerManager.html) 系统服务）、Binder IPC 驱动程序以及对移动嵌入式平台来说非常重要的其他功能。这些补充功能主要用于增强系统功能，不会影响驱动程序开发。您可以使用任意版本的内核，只要它支持所需功能（如 Binder 驱动程序）即可。不过，我们建议您使用 Android 内核的最新版本。
#### HIDL

HAL 接口定义语言（简称 HIDL，发音为“hide-l”）是用于指定 HAL 和其用户之间的接口的一种接口描述语言 (IDL)。HIDL 允许指定类型和方法调用（会汇集到接口和软件包中）。从更广泛的意义上来说，HIDL 是用于在可以独立编译的代码库之间进行通信的系统。

HIDL 旨在用于进程间通信 (IPC)。进程之间的通信[*经过 Binder 化*](https://source.android.google.cn/devices/architecture/hidl/binder-ipc)。对于必须与进程相关联的代码库，还可以使用[直通模式](https://source.android.google.cn/devices/architecture/hidl#passthrough)（在 Java 中不受支持）。

HIDL 可指定数据结构和方法签名，这些内容会整理归类到接口（与类相似）中，而接口会汇集到软件包中。尽管 HIDL 具有一系列不同的关键字，但 C++ 和 Java 程序员对 HIDL 的语法并不陌生。此外，HIDL 还使用 Java 样式的注释。

##### 网络堆栈配置工具

Android 操作系统中包含标准的 Linux 网络实用程序，例如 `ifconfig`、`ip` 和 `ip6tables`。这些实用程序位于系统映像中，并支持对整个 Linux 网络堆栈进行配置。在运行 Android 7.x 及更低版本的设备上，供应商代码可以直接调用此类二进制文件，这会导致以下问题：

- 由于网络实用程序在系统映像中更新，因此无法提供稳定的实现。
- 网络实用程序的范围非常广泛，因此难以在保证行为可预测的情况下不断改进系统映像。

在运行 Android 8.0 的设备上，供应商分区可在系统分区接收更新时保持不变。为了实现这一点，Android 8.0 不仅提供定义稳定的带版本接口的功能，同时还使用了 SELinux 限制，以便在供应商映像与系统映像之间保持已知良好的相互依赖关系。

供应商可以使用平台提供的网络配置实用程序来配置 Linux 网络堆栈，但这些实用程序并未包含 HIDL 接口封装容器。为定义这类接口，Android 8.0 中纳入了 `netutils-wrapper-1.0` 工具。

### Android的网络通信

#### Netd

Netd是Android系统中专门负责网络管理和控制的后台daemon程序，其功能主要分三大块：

- 设置防火墙（Firewall）、网络地址转换（NAT）、带宽控制、无线网卡软接入点（Soft Access Point）控制，网络设备绑定（Tether）等。 
- Android系统中DNS信息的缓存和管理。 
- 网络服务搜索（Net Service Discovery，简称NSD）功能，包括服务注册（Service Registration）、服务搜索（Service Browse）和服务名解析（Service Resolve）等。 

Netd的工作流程和Vold类似，其工作可分成两部分： 
1. Netd接收并处理来自Framework层中NetworkManagementService或NsdService的命令。这些命令最终由Netd中对应的Command对象去处理。 
2. Net接收并解析来自Kernel的UEvent消息，然后再转发给Framework层中对应Service去处理。

Netd位于Framework层和Kernel层之间，它是Android系统中网络相关消息和命令转发及处理的中枢模块。

#### android 平台提供的API
![](assets/API1.jpg)

![](assets/API2.jpg)

##### http.client接口
首先，介绍一下通过http包工具进行通信，分get和post两种方式，两者的区别是：

1，post请求发送数据到服务器端，而且数据放在html header中一起发送到服务器url，数据对用户不可见，get请求是把参数值加到url的队列中，这在一定程度上，体现出post的安全性要比get高

2，get传送的数据量小，一般不能大于2kb，post传送的数据量大，一般默认为不受限制。

访问网络要加入权限 <uses-permission android:name="android.permission.INTERNET" />

下面是get请求HttpGet时的示例代码：

```vbscript
 1 // 创建DefaultHttpClient对象
 2 HttpClient httpClient = new DefaultHttpClient();
 3 // 创建一个HttpGet对象
 4                 HttpGet get = new HttpGet(
 5                     "http://192.168.1.88:8888/foo/secret.jsp");
 6                 try
 7                 {
 8                     // 发送GET请求
 9                     HttpResponse httpResponse = httpClient.execute(get);
10                     HttpEntity entity = httpResponse.getEntity();
11                     if (entity != null)
12                     {
13                         // 读取服务器响应
14                         BufferedReader br = new BufferedReader(
15                             new InputStreamReader(entity.getContent()));
16                         String line = null;
17                         response.setText("");
18                         while ((line = br.readLine()) != null)
19                         {
20                             // 使用response文本框显示服务器响应
21                             response.append(line + "\n");
22                         }
23                     }
24                 }
25                 catch (Exception e)
26                 {
27                     e.printStackTrace();
28                 }
29             }
```

post请求HttpPost的示例代码：

```vbscript
 1 HttpClient httpClient=new DefaultHttpClient();
 2 HttpPost post = new HttpPost(
 3                                     "http://192.168.1.88:8888/foo/login.jsp");
 4                                 // 如果传递参数个数比较多的话可以对传递的参数进行封装
 5                                 List<NameValuePair> params = new ArrayList<NameValuePair>();
 6                                 params.add(new BasicNameValuePair("name", name));
 7                                 params.add(new BasicNameValuePair("pass", pass));
 8                                 try
 9                                 {
10                                     // 设置请求参数
11                                     post.setEntity(new UrlEncodedFormEntity(
12                                         params, HTTP.UTF_8));
13                                     // 发送POST请求
14                                     HttpResponse response = httpClient
15                                         .execute(post);
16                                     // 如果服务器成功地返回响应
17                                     if (response.getStatusLine()
18                                         .getStatusCode() == 200)
19                                     {
20                                         String msg = EntityUtils
21                                             .toString(response.getEntity());
22                                         // 提示登录成功
23                                         Toast.makeText(HttpClientTest.this,
24                                             msg, 5000).show();
25                                     }
26                                 }
27                                 catch (Exception e)
28                                 {
29                                     e.printStackTrace();
30                                 }
31                             }
```

#### java.net 接口
其次，介绍使用java包的工具进行通信，也分get和post方式

默认使用get方式，示例代码：

```vbscript
 1 try
 2         {
 3             String urlName = url + "?" + params;
 4             URL realUrl = new URL(urlName);
 5             // 打开和URL之间的连接或者HttpUrlConnection
 6             URLConnection conn =realUrl.openConnection();
 7             // 设置通用的请求属性
 8             conn.setRequestProperty("accept", "*/*");
 9             conn.setRequestProperty("connection", "Keep-Alive");
10             conn.setRequestProperty("user-agent",
11                 "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)");
12             // 建立实际的连接
13             conn.connect();
14             // 获取所有响应头字段
15             Map<String, List<String>> map = conn.getHeaderFields();
16             // 遍历所有的响应头字段
17             for (String key : map.keySet())
18             {
19                 System.out.println(key + "--->" + map.get(key));
20             }
21             // 定义BufferedReader输入流来读取URL的响应
22             in = new BufferedReader(
23                 new InputStreamReader(conn.getInputStream()));
24             String line;
25             while ((line = in.readLine()) != null)
26             {
27                 result += "\n" + line;
28             }
29         }
30         catch (Exception e)
31         {
32             System.out.println("发送GET请求出现异常！" + e);
33             e.printStackTrace();
34         }
35         // 使用finally块来关闭输入流
```

使用post的示例代码：

```vbscript
 1 try
 2         {
 3             URL realUrl = new URL(url);
 4             // 打开和URL之间的连接
 5             URLConnection conn = realUrl.openConnection();
 6             // 设置通用的请求属性
 7             conn.setRequestProperty("accept", "*/*");
 8             conn.setRequestProperty("connection", "Keep-Alive");
 9             conn.setRequestProperty("user-agent",
10                 "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)");
11             // 发送POST请求必须设置如下两行
12             conn.setDoOutput(true);
13             conn.setDoInput(true);
14             // 获取URLConnection对象对应的输出流
15             out = new PrintWriter(conn.getOutputStream());
16             // 发送请求参数
17             out.print(params);
18             // flush输出流的缓冲
19             out.flush();
20             // 定义BufferedReader输入流来读取URL的响应
21             in = new BufferedReader(
22                 new InputStreamReader(conn.getInputStream()));
23             String line;
24             while ((line = in.readLine()) != null)
25             {
26                 result += "\n" + line;
27             }
28         }
29         catch (Exception e)
30         {
31             System.out.println("发送POST请求出现异常！" + e);
32             e.printStackTrace();
33         }
```


从以上知，get请求只需要`conn.connect().post`请求时，必须设`conn.setDoOutput(true)`,`conn.setDoinput(true)`,还必须获取`URLConnection`的输出流`getOutputStream()`

##### socket
最后，使用套接字（soket）进行通信分为两种形式：面向连接的（tcp）和无连接的（udp 数据报）

tcp连接示例：

```vbscript
//服务器端
//创建一个ServerSocket，用于监听客户端Socket的连接请求
       ServerSocket ss = new ServerSocket(30000);
        //采用循环不断接受来自客户端的请求
        while (true)
        {
            //每当接受到客户端Socket的请求，服务器端也对应产生一个Socket
            Socket s = ss.accept();
            OutputStream os = s.getOutputStream();
            os.write("您好，您收到了服务器的消息！\n"
                .getBytes("utf-8"));
            //关闭输出流，关闭Socket
            os.close();
            s.close();
        }

//客户端

Socket socket = new Socket("192.168.1.88" , 30000);
            //将Socket对应的输入流包装成BufferedReader
            BufferedReader br = new BufferedReader(
                new InputStreamReader(socket.getInputStream()));
            //进行普通IO操作
            String line = br.readLine();
            show.setText("来自服务器的数据：" + line);            
            br.close();
            socket.close();   
```

udp连接示例：

```vbscript
 1 服务器端:
 2     try {
 3                 //创建一个DatagramSocket对象，并指定监听的端口号
 4                 DatagramSocket socket = new DatagramSocket(4567);
 5                 byte data [] = new byte[1024];
 6                 //创建一个空的DatagramPacket对象
 7                 DatagramPacket packet = new DatagramPacket(data,data.length);
 8                 //使用receive方法接收客户端所发送的数据
 9                 socket.receive(packet);
10                 String result = new String(packet.getData(),packet.getOffset(),packet.getLength());
11                 System.out.println("result--->" + result);
12             } catch (Exception e) {
13                 // TODO Auto-generated catch block
14                 e.printStackTrace();
15 
16 
17 客户端：
18 
19 try {
20             //首先创建一个DatagramSocket对象
21             DatagramSocket socket = new DatagramSocket(4567);
22             //创建一个InetAddree
23             InetAddress serverAddress = InetAddress.getByName("192.168.1.104");
24             String str = "hello";
25             byte data [] = str.getBytes();
26             //创建一个DatagramPacket对象，并指定要讲这个数据包发送到网络当中的哪个地址，以及端口号
27             DatagramPacket packet = new DatagramPacket(data,data.length,serverAddress,4567);
28             //调用socket对象的send方法，发送数据
29             socket.send(packet);
30         } catch (Exception e) {
31             // TODO Auto-generated catch block
32             e.printStackTrace();
33         }
```

#### android wifi 流程

##### wifi的基本架构

1. wifi用户空间的程序和库: 
   external/wpa_supplicant/ 
    生成库libwpaclient.so和守护进程wpa_supplicant。

2. hardware/libhardware_legary/wifi/是wifi管理库。

3. JNI部分： 
    frameworks/base/core/jni/android_net_wifi_Wifi.cpp

4. JAVA部分： 
     frameworks/base/services/java/com/android/server/    

     frameworks/base/wifi/java/android/net/wifi/

5. WIFI Settings应用程序位于： 
   packages/apps/Settings/src/com/android/settings/wifi/

##### wifi 在android中如何工作

Android使用一个修改版`wpa_supplicant`作为daemon来控制WIFI，代码位于external/  wpa_supplicant。wpa_supplicant通过socket hardware/libhardware_legacy/wifi/wifi.c通信。UI通过android.net.wifi package （frameworks/base/wifi/java/android/net/wifi/）发送命令给wifi.c。 相应的JNI实现位于frameworks/base/core/jni/android_net_wifi_Wifi.cpp。 更高一级的网络管理位于frameworks/base/core/java/android/net。 

### HAL

Android的硬件抽象层，简单来说，就是对Linux内核驱动程序的封装，向上提供接口，屏蔽低 层的实现细节。也就是说，把对硬件的支持分成了两层，一层放在用户空间（User Space）， 一层放在内核空间（Kernel Space），其中，硬件抽象层运行在用户空间，而linux内核驱动程序运行在内核空间。

#### 为什么有HAL

为什么要把对硬件的支持分两块来实现？把硬件抽象层和内核驱动整合在一起放在内核空间不可行吗？从技术实现的角度来看，是可以的，然而从商业的角度来看，把对硬件的支持 逻辑都放在内核空间，可能会损害厂家的利益。

- 我们知道，Linux内核源代码版权遵循GNU License，而android源代码版权遵循Apache License，前者在发布产品时，必须公布源代码，而 后者无须发布源代码。如果把对硬件支持的所有代码都放在Linux驱动层，那就意味着发布时要公开驱动程序的源代码，而公开源代码就意味着把硬件的相关参数和实现都公开了，在手机市场竞争激烈的今天，这对厂家来说，损害非常大。

- 内核驱动层只提供简单的访问硬件逻辑，例如读写硬件寄存器的通道，至于从硬件中读到了什么值或者写了什么值到硬件中的逻辑，都放在硬件抽象层中去了，这样就可以把商业秘密隐藏起来了。也正是由于这个分层的原因，Android被踢出了Linux内核主线代码树中。

- Android放在内核空间的驱动程序对硬件的支持是不完整的，把Linux内核移植到别的机器上去时，由于缺乏硬件抽象层的支持，硬件就完全不 能用了，这也是为什么说Android是开放系统而不是开源系统的原因。

### Network performance load stress tests

#### Linux(raw), XDP, DPDK

![Linux，XDP，DPDK.png](assets/5c9f5f11a4362.png)

(此结果运行于Xeon E5-1650 V4@3.7Hz 单个核心上)

通过查询文献可以发现，基于内核的传统的数据传输性能并不是非常强，最高性能只为5Mpps。而采用了DPDK和XDP技术，单个核心的包处理能力得到了显著提升。我们可以从表中得出以下结论：

* Linux下CPU负担和包处理能力成比较好的线性关系。
* 相同CPU负载下，XDP提升单个核心至少两倍包处理能力；在CPU高负载情况下，提升包处理能力近5倍。
* DPDK采用轮询策略，始终占用百分之百的CPU利用率。
* 当包处理量不大的情况下，XDP相比DPDK效率更高，但DPDK对CPU高性能网络处理能力提升作用更为显著。

千兆网络大约需要CPU具有1.4Mpps的包处理能力，从图表上我们可以知道在没有XDP或者DPDK技术加持下，CPU负担大约为30%左右。但是对于智能手机的CPU，其性能相对于桌面CPU、服务器CPU性能更为孱弱，处理千兆网络无疑将会占用其大部分CPU资源。

我们通过简单的测试验证了我们的猜想。

#### Android packet processing performance

我们选取了一位组员的Android设备（SoC：骁龙625）进行比较简单的网络负担测试，分别测试了4GLTE、WIFI、流量转发下CPU占用率。

* 4GLTE网络下

![4G+LTE.png](assets/5c9f641d96818.png)

（其中前半段位下载，后半段为上传）

在下载11.95Mbps、上传29.21Mbps条件下，CPU平均使用率为40.13%。相同待机条件下CPU使用率仅为21.27%，CPU使用率提高了18.86%。

* WIFI网络下

![wifi.png](assets/5c9f6546c1bfe.png)

（其中前半段位下载，后半段为上传）

在下载23.28Mbps，上传22.38Mbps条件下，CPU平均使用率为35.68%；相同待机条件下，CPU平均使用率为19.81%，CPU使用率提高16.87%

* 流量转发

![wifi热点转发2.png](assets/5c9f69664cd9d.png)（其中前半段位下载，后半段为上传）

在进行数据处理性能测试的同时，我们还进行了数据转发的性能测试。使用在WIFI热点转发流量状态，下载14.73Mbps，上传14.93Mbps的情况CPU平均使用率为12.56%，而相同条件，设备待机CPU使用率仅为6.74%。

##### Conclusion

* 骁龙625处理器在处理20Mbps的的数据会吃点近五分之一的CPU资源，转发15Mbps会占用百分之六的CPU使用率
* 根据流量处理和CPU使用率的线性关系，我们可以推测出，骁龙625能够比较好的处理百兆网络，但是对于跑满千兆网络可能会非常吃力，甚至做不到。
* 根据我们的测试结果，上传相比下载占用CPU资源更少。
* 数据出现大的波动是因为难以保持测试环境的纯净性。

#### Conclusion

目前4G和WIFI网络传输速率普遍不会超过百兆，手机SoC还是能够处理的。但是当5G来临，手机SoC不得不具备千兆网络的处理能力。我们测试的骁龙625尽管不是目前最强的android设备SoC，但是还是可以推断出，千兆网络处理将占据大部分手机CPU资源。而在linux上采用XDP技术，处理相同的网络数据，可以显著的降低CPU占用率，所以我们打算将XDP技术移植到Android上以提高移动设备千兆网络的处理能力。



### Future of Network (2017-2022)

#### Global networking devices

根据Cisco公司的的预测，在全球范围内，在网设备数目将会继续飞速增长。其中支持物联网（IoT）应用的M2M联接，例如智能电表、视频监控、医疗监控、运输、包裹或资产跟踪，数量增长速度最为瞩目，其数量将从2016年的171亿增长为2021年的271亿；从34%的占比达到51%的占比。

智能手机的增长是第二快速的，达到百分之九的复合年增长率。

![1553950700535](assets/1553950700535.png)

#### IP data traffic

全球的IP的流量也将持续并高速的增长，达到26%的复合年增长率。在2017年底，智能手机对IP流量的贡献仅为18%，而预计到2022年44%的IP流量将会来自智能手机。

![1553950689773](assets/1553950689773.png)

#### Network flow

同样的，在接下来的五年中，全球网络流量也将会高速的增长。随着移动互联网的发展，视频设备将对全球流量产生更高的贡献。一台可以上网的高清电视每天可以从互联网上获取2小时的内容，它所产生的网络流量相当于今天整个家庭的网络流量。随着智能手机和平板电脑视频观看量的增长，来自这些设备的流量占互联网总流量的比例也在增长。随着到2022年，个人电脑在全球互联网流量中所占的份额将从2017年的49%下降至19%。到2022年，智能手机将占全球互联网流量的50%，高于目前的23%

![1553951059371](assets/1553951059371.png)

#### About 5G

在思科的报告中，也提到了5G。全球5G设备将占全球移动设备和连接的3％以上。

到2022年，全球移动设备将从2017年的86亿增长到2022年的123亿 - 其中超过4.22亿的设备具有5G上网能力。到2022年，全球移动流量的近12％将用于5G蜂窝连接。

到2022年，全球平均5G连接每月将产生21 GB的流量。

> **Global 5G mobile highlights** 
>
> **5G devices and connections will be over 3 percent of global mobile devices and connections by 2022.**
>
> By 2022, global mobile devices will grow from 8.6 billion in 2017 to 12.3 billion by 2022 - over 422 million of those will be 5G capable.
>
> **Nearly twelve percent of global mobile traffic will be on 5G cellular connectivity by 2022.** 
>
> Globally, the average 5G connection will generate 21 GB of traffic per month by 2022.

### Conclusion

我们根据一些国际知名数据公司的预测，以及移动通信技术的发展趋势，可以明了的判断出在接下来的数年，智能手机将会越来越多，智能手机产生和处理的网络流量将会越来越大，但这也对手机网络处理能力提出了不小的挑战。而基于OS内核的传统数据传输存在不小的弊端，使得网络处理对CPU资源开销较大。

> 基于OS内核的传统数据传输存在的弊端：
>
> - **中断处理**：当网络中大量数据包到来时，会产生频繁的硬件中断请求，这些硬件中断可以打断之前较低优先级的软中断或者系统调用的执行过程，如果这种打断频繁的话，将会产生较高的性能开销。
> - **内存拷贝**：正常情况下，一个网络数据包从网卡到应用程序需要经过如下的过程：数据从网卡通过 DMA 等方式传到内核开辟的缓冲区，然后从内核空间拷贝到用户态空间，在 Linux 内核协议栈中，这个耗时操作甚至占到了数据包整个处理流程的 57.1%。
> - **上下文切换**：频繁到达的硬件中断和软中断都可能随时抢占系统调用的运行，这会产生大量的上下文切换开销。另外，在基于多线程的服务器设计框架中，线程间的调度也会产生频繁的上下文切换开销，同样，锁竞争的耗能也是一个非常严重的问题。
> - **局部性失效**：如今主流的处理器都是多个核心的，这意味着一个数据包的处理可能跨多个 CPU 核心，比如一个数据包可能中断在 cpu0，内核态处理在 cpu1，用户态处理在 cpu2，这样跨多个核心，容易造成 CPU 缓存失效，造成局部性失效。如果是 NUMA 架构，更会造成跨 NUMA 访问内存，性能受到很大影响。
> - **内存管理**：传统服务器内存页为 4K，为了提高内存的访问速度，避免 cache miss，可以增加 cache 中映射表的条目，但这又会影响 CPU 的检索效率。



随着移动通信技术和移动互联网的发展，移动设备网络带宽得到显著提高，移动手机产生、处理越来越多的网络流量，囿于基于OS kernel的传统网络数据包处理的弊端，高性能网络处理占用了大量的CPU资源，尤其是在CPU计算资源受限制的移动设备上。我们计划为android移动设备搭建一个高效的XDP应运开发平台，为android提供一个高性能、可编程的网络数据通路。



## Related work

[Android上eBPF的流量监控](Android-eBPF-flow-monitor.md)

## Reference

- [Network stack](https://www.cs.dartmouth.edu/~sergey/netreads/path-of-packet/Network_stack.pdf)
- [Linux network stack](https://www.linux.org/threads/linux-network-stack.9065/)
- [Performance Analysis of packet processing](https://people.cs.clemson.edu/~westall/853/tcpperf.pdf)
- [The journey of a packet through linux network stack](http://www.cookinglinux.org/pub/netdev_docs/packet-journey-2.4.html)
- [Queueing in the linux network stack](https://www.linuxjournal.com/content/queueing-linux-network-stack)
- [kernel bypass](https://blog.cloudflare.com/kernel-bypass/)
- [XDP Paper](https://dl.acm.org/citation.cfm?id=3281443)
- [eBPF](https://tonydeng.github.io/sdn-handbook/linux/bpf/)
- [BPF](https://qmonnet.github.io/whirl-offload/2016/09/01/dive-into-bpf/)
- [Cilium: BPF & XDP](https://cilium.readthedocs.io/en/stable/bpf/)
- [DPDK](https://zh.wikipedia.org/wiki/DPDK)
- [Cisco visual networking index](https://www.cisco.com/c/en/us/solutions/service-provider/visual-networking-index-vni/index.html#~complete-forecast)














