# Tools

这里提供了一些编写的用于报告、虚拟机部署的脚本。

## qemu-install.sh, qemu-run.sh

用于安装并运行 QEMU-KVM 上的 Android 虚拟机。已在 Centos 上测试通过。

### Prerequisites

请先在[android-x86](http://www.android-x86.org)上下载 `android-x86_64-8.1-r1.iso`，并安装 qemu 相关工具。

### Usage

#### `qemu-install.sh`, `qemu-run.sh`

```shell
./qemu-install.sh android.x86_64.iso android.img
./qemu-run.sh android.img
```

这样将创建 `android.img` 的硬盘镜像，进入系统安装界面后，你可能需要先进入 debug mode 对镜像进行分区，并将 android 安装到该分区中。

运行 `qemu-run.sh` 之后，终端的输入将成为 qemu 的控制器，并且将在 5900 号端口上运行 VNC Server。你需要 VNC Client 来获取图形界面。

例如 Centos 上的 `vncviewer`。

#### `connect_vnc.sh`

若不想自己搭建，可以通过此脚本使用我在服务器上已经搭好的虚拟机。

此脚本使用了 remmina 作为 VNC Client，因为 remmina 在 Ubuntu 上是默认的 VNC Client。若你使用其它操作系统，请自行修改脚本。

```shell
./connect_vnc.sh username domain
```

之后只用在弹出的 remmina 界面中选择 VNC 作为协议，并输入 `localhost:5900` 即可。

若无法连接到服务器，需要在运行脚本之前，将 ssh 公钥拷贝到远程服务器上。推荐使用：

```shell
# if you haven't generated your key pair before
ssh-keygen

ssh-copy-id username@domain
```
