# Link iproute2 against libelf on Android

## What's iproute2?

> iproute2 is a collection of userspace utilities for controlling and monitoring various aspects of networking in the Linux kernel, including routing, network interfaces, tunnels, traffic control, and network-related device drivers.

总的来说，iproute2 管理着 linux 网络栈的方方面面。

## Why we need iproute2?

iproute2 提供了一些非常有用的工具，能够加载 XDP 程序，并将 XDP 程序挂到网卡上。我们选择它作为 Android 上 XDP 的作为工具链之一，主要是因为它部分存在于 Android 内核中。

## Where did the difficulty reside?

- Android 关于 soong 编译系统的文档实在少的可怜，我们不得不参考 Android 源码中已有的例子来猜测一些选项及属性的意思。这给我们的跨平台编译造成了很大困难和阻碍。因此我们做了一个 Android.bp 的笔记，你可以在[Android.bp笔记](../notes/Android_bp.md)找到它。
- Android 源码的代码结构不敢恭维。部分头文件和源文件被拷贝得到处都是，而且版本还不同。

## How we find and solve the problem step by step?

### `HAVE_ELF`

在 Android 上完成 iproute2 是一个痛苦的过程。iproute2 的源码位于 `external/iproute2` 中。安卓中其实已经有 iproute2，但只包含了一些基础功能，部分功能以模块的形式存在。

在试错的过程中，我们使用 iproute2 加载 xdp 程序，报了一些错，我们在源码中找到对应的错误，发现最主要的是没有定义 `HAVE_ELF`。

`HAVE_ELF` 未定义的根源是，Android 没有链接 libelf 库，而 `HAVE_ELF` 则控制了一些函数的实现（指，有 libelf 的情况下功能如何实现，没有 libelf 的情况下功能如何实现，或者单纯只是报个错误）。

### Try #1: Add "-DHAVE_ELF" to cflags

既然它说没有，那么我们就加上。我们在 `external/iproute2/Android.bp` 中加上如下内容：

```diff
cc_defaults {
    name: "iproute2_defaults",
    // --snippet--
    cflags: [
        // --snippet--
+       "-DHAVE_ELF",
    ]
    
}
```

之后输入 `mma` 进行编译。很自然的，我们得到了一些新的错误：**对未声明符号的引用**。我们搜索这些符号，发现这些函数都是 libelf 中的内容。

于是我们修改`external/iproute2/Android.bp`:

```diff
cc_defaults {
    // --snippet--
+   include_dirs: ["external/elfutils/libelf"],
}
```

这个选项的意思是很明显的。

之后我们又得到未定义引用的错误，和我们的预想情况相同，因为源码中当然会有很多对 libelf 中函数的引用，在加上 `-DHAVE_ELF` 后，这些引用重见天日，但由于我们还没有链接这个库，当然就出现了问题。因此下一步就是在 iproute2 的编译设置中链接 libelf。

**关于 libelf：**

> 'Libelf' lets you read, modify or create ELF files in an architecture-independent way. The library takes care of size and endian issues, e.g. you can process a file for SPARC processors on an Intel-based system.

总的来说，libelf 能够用来修改 ELF 程序。由于 BPF/eBPF 程序本质上是置于 ELF Section 中的一些字节码，所以 XDP 需要 libelf 来完成加载。这和是否使用 iproute2 无关，哪怕我们自己写加载 XDP 程序的工具，也需要用到 libelf。

因此下一步就是将 libelf 编译入 Android 内核中。

输入如下命令：

```shell
> grep "name: \"libelf\"" -r . --include=Android.bp 
```

很幸运地，我们在 `external/elfutils/` 中找到了 libelf 的某个版本。值得一提的是，`external/elfutils/Android.bp` 中的 Anroid.bp 有这样的内容：

```
subdirs = ["libelf"]
```

它表示只有 `libelf` 子目录下的内容会参与编译（详情请阅读[Android.bp笔记](../notes/Android_bp.md)。因此我们只需要考虑修改 `libelf` 里的内容。

### Try #2: Link iproute2 against libelf by adding `shared_libs`

同样也只是试错，我们直接修改 blueprints 文件添加 `shared_libs` 选项。

为了将 libelf 链接到 iproute2，我们首先修改 `/external/iproute2/Android.bp`:

```diff
cc_defaults {
    name: "iproute2_defaults",
    // --snippet--
+   shared_libs: [
+       "libbpf",
+   ]
    
}
```

这样将 libelf 动态链接入 iproute2 的所有库中。得到了一些 soong 的模块间链接错误：

```
error: external/iproute2/misc/Android.bp:1:1: dependency "libelf" of "..." missing available variant:
arch:android_x86_64, link:shared
available variants:
arch:android_x86_64, link:static, image:core
arch:android_x86, link:shared, image:core
arch:android_x86, link:static, image:core
arch:linux_x86_64, link:shared, image:core
arch:linux_x86_64, link:shared, image:core
...
error: external/iproute2/tc/Android.bp:1:1: dependency "libelf" of "..." missing variant
available
arch:android_x86_64, link:shared
...
```

我们发现有许多模块都突然添加了对 libelf 的依赖。于是阅读了 iproute2 几个子目录的 Android.bp 文件，发现子目录中将顶层目录的配置通过 `defaults` 属性默认地包含了进来。例如：

```
cc_library_shared {
    name: "libiprouteutil",
    defaults: ["iproute2_defaults"],
}
```

这种情况下，我们仔细考察了编译依赖关系，确认只有 `externals/iproute2/lib` 中的 `libiprouteutil` 对 libelf 有依赖关系。因此将 shared_libs 从 `/external/iproute2/Android.bp` 中删除，而只修改 `/external/iproute2/lib/Android.bp` 的内容：

```diff
cc_defaults {
    name: "libiprouteutil",
    // --snippet--
+   shared_libs: [
+       "libbpf",
+   ]
    
}
```

同时我们观察到只缺少变体 `android_x86_64_shared` ，其它变体都有。下一步我们将进一步阅读和修改 Android.bp 文件。

### Try #3: edit `target` property to link properly

考察 `external/elfutils/libelf/Android.bp` 的内容：

```
    target: {
        darwin: {
            enabled: false,
        },
        android: {
            cflags: [
                "-D_FILE_OFFSET_BITS=64",
                "-include AndroidFixup.h",
            ],
            shared: {
                enabled: false,
            },
        },
    },
```

发现有一个属性 `target.android.shared.enabled` 被设置成了 false。我们猜测它控制了 Android 目标架构下动态链接库的生成。之后我们在生成的目标文件夹中进行确认，发现确实只有 `libelf.a` 而没有 `libelf.so`，因此肯定了我们的猜测。

再次进行试错，我们修改 `external/elfutils/libelf/Android.bp` 的内容：

```diff
cc_library {
    // --snippet--
    target: {
        darwin: {
            enabled: false,
        },
        android: {
            cflags: [
                "-D_FILE_OFFSET_BITS=64",
                "-include AndroidFixup.h",
            ],
            shared: {
-               enabled: false,
+               enabled: true,
            },
        },
    },
}
```

得到了一大堆错误。这也和我们预测的一致——它在 Android 架构下不编译成动态库肯定是有原因的，可能是一些依赖和这个库的可移植性的问题，我们不考虑解决这些问题，而决定换一条路。

我们修改 `external/iproute2/lib/Android.bp` （注意文件夹和之前的不同）的内容：

```diff
cc_library_shared {
    // --snippet--
-   shared_libs: [
-       "libelf",
-   ],
+   target: {
+       android: {
+           cflags: ["-DAndroid"],
+           static_libs: ["libelf"],
+	    },
+       host: {
+           shared_libs: ["libelf"],
+       },
+   },
}
```

这样做的意思是，在 android 架构下通过静态链接链接 libelf，在 host 架构下通过动态链接链接 libelf。这样做之后我们得到了新的报错：

```
module 'libiprouteutil' variant 'android_x86_64_static': depends on 'libelf' which is not visible to this module
```

在解决这个报错的过程中我们走了许多歪路，就不提了。下面直接描述正确的做法：

### Try #4: edit `visibility` property to change visibility

我们一直忽视的一个属性是 `visibility`（主要是 Android.bp 的文档实在是不全，`visibility` 又很少用到）。我们最后在 `external/elfutils/libelf/Android.bp` 中看到了 `visibility` 这个属性，推测应该就是这个属性和我们最后一个报错相关：

```diff
cc_library {
    visibility: [
        "//device/google/contexthub/util/nanoapp_postprocess",
        "//external/mesa3d",
        "//external/perf_data_converter",
+       "//external/iproute2/lib",
    ],
}
```

一切解决。

### Fix some minor bugs in Android source code

值得一提的是，Android 的 iproute2 源码中有一些小 bug。在链接了 libelf 后，这些 bug 由于 `-DHAVE_ELF` 的定义暴露了出来。大概 Android 的开发者由于并没有考虑链接这两者，所以也没有进行代码测试吧。我们修改了这些小 bug，最后 iproute2 正常运行。 