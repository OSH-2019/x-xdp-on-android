# Tools

这里提供了一些编写的用于报告、虚拟机部署的脚本。

## qemu-install.sh, qemu-run.sh

用于安装并运行 QEMU-KVM 上的 Android 虚拟机。已在 Centos 上测试通过。

### Prerequisites

请先在[android-x86](http://www.android-x86.org)上下载 `android-x86_64-8.1-r1.iso`，并安装 qemu 相关工具。

### Usage

```shell
./qemu-install.sh android.x86_64.iso android.img
./qemu-run.sh android.img
```

这样将创建 `android.img` 的硬盘镜像，进入系统安装界面后，你可能需要先进入 debug mode 对镜像进行分区，并将 android 安装到该分区中。

运行 `qemu-run.sh` 之后，终端的输入将成为 qemu 的控制器，并且将在 5900 号端口上运行 VNC Server。你需要 VNC Client 来获取图形界面。

例如 Centos 上的 `vncviewer`。
