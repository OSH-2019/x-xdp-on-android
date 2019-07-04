# Android.bp

Google 关于 soong 编译的文档少的可怜，从引进 soong 编译系统到现在 google 似乎一点也没有想要完善他们那残缺的几页文档。所以基本上，我们只能通过阅读 Android 源码中已有的 `Android.bp` 文件，猜测每个属性/类别的意思，来解决跨平台编译过程中碰到的各种各样的问题。

可以通过 soong build 生成一个简单的文档，其中对一些内容有简单粗略的记录。

这里做一下简单的记录（基本上都是猜测）：

Android.bp 文件基本上是 Json 文件格式，对于每个 module，顶层首先是一个属性，标志这个模块生成的目标类型。例如 `cc_library` 表示将生成 C/C++ 库。`cc_library_headers` 表示将生成头文件库。每个库的子属性又有不同（所以不要看到一个觉得可能有用的属性就移到其它模块去）。

- `shared_libs`：链接动态库，如：

  ```json
  cc_library {
      shared_libs: [
          "libelf",
      ],
  }
  ```

- `static_libs`：链接动态库

- `include_dirs`：基本上和 `gcc -I` 的效果相同，路径是相对于根目录（即 Android 源码的根目录）（不过似乎不推荐使用）

  - `export_include_dirs`: 路径相对于此模块，对其它模块的引用。

  - `local_include_dirs`: 路径相对于此模块，对内部的引用，常用的例如:

    ```json
    cc_library {
        local_include_dirs: [
            "include",
            ".",
        ],
    }
    ```

- 每个模块都需要有一个属性 `name`。例如 `name: libelf`，这个名字将成为唯一的 identifier。

- `visibility`: 似乎是指此模块对其它某个模块是否可见。因为这个属性导致了我们某个编译报错。卡了我们很久。

  ```json
  visibility: [
      "external/iproute2/lib",
  ]
  ```

- `subdirs`: 是一级属性。soong 默认会查找该模块目录下的所有子目录看有没有 `Android.bp` 来进行编译。但如果指定了 `subdirs`，soong 就只会从那些目录里寻找。我们在做的时候，在 `external/elfutils/Android.bp` 里看到了这个属性。当时我们正解决 `libelf` 的编译问题，发现 `elfutils` 中有很多 lib，但它的 `Android.bp` 中又有 `subdirs: ["libelf"]`。我们推测只有这个库会被编译。

- `target.android.shared.enabled`, `target.host.shared.enabled`: 默认情况下，每个库会编译出动态和静态库（这个是我们通过看编译后的得到的 `*.so` 和 `*.a` 发现的）。但如果将这两个值设成 false，就不会生成动态库了。这也导致了我们编译过程中的一些问题。

  其中，`android` 和 `host` 的意思是：soong 会分别编译出主机上和 Android 上的目标文件。

- 可以通过修改 `target.android.shared_libs` 和 `target.android.static_libs` 和 `target.host.shared_libs` ... 来控制在每个目标架构上，分别以怎样的方式链接库。
