# Load Test

我们在将 XDP 移植到了 Android 上后，也做了一个性能测试。我们考虑测试 XDP_DROP 的包处理速率。

由于 Android 上当然没有 Linux 上丰富的网络性能测试工具（例如 ethtool 就没有），所以我们的工具只能自己写。如下：

```shell
#!/system/bin/sh
INTERVAL=1

IF=$1

while true
do
        R1=`cat /sys/class/net/$1/statistics/rx_packets`
        T1=`cat /sys/class/net/$1/statistics/tx_packets`
        sleep $INTERVAL
        R2=`cat /sys/class/net/$1/statistics/rx_packets`
        T2=`cat /sys/class/net/$1/statistics/tx_packets`
        TXPPS=`expr $T2 - $T1`
        RXPPS=`expr $R2 - $R1`
        echo "TX $1: $TXPPS pkts/s RX $1: $RXPPS pkts/s"
done
```

这个脚本的作用是每隔一秒输出当前的包处理速率。其中 `/sys/class/net/${interface_name}/statistics/rx_packets` 记录了收到包的数量。然后我们通过 `adb push` 将这个脚本传到了运行的 Android 文件系统中。

这样我们就能通过 `netspeed.sh lo` 来测试 lo 设备上当前的包处理速率。

通过这个脚本，我们实际测试了并对比了使用 XDP 和不使用 XDP Drop 包的速率。

## Comparison

由于 android 上也没有负载测试工具，所以我们使用 c 写了两个程序 `udp_sender`, `udp_receiver` 分别不停发送和接受 udp 包。然后将它们运行在后台。

### Linux kernel
首先考虑第一种情况：linux kernel 进行包处理的速率极限，通过：
```shell
iptables -t raw -I PREROUTING -p udp --dport 8000 -j DROP
```
iptables 能设置网络栈的规则，这里的意思是在 linux 网络栈用户所能操作的最早阶段就将所有 udp 包丢掉，这应该是 linux 上的速率极限了。我们得到的结果是：
![](assets/CFH8TATGM4%7D%60ZXWYNY~~8%25F.png)

### XDP Drop

接下来我们对比以下 XDP Drop 和 linux kernel Drop 的性能差距。
首先通过 `iptables -F` 删除上述的规则，之后加载 xdp 程序到网卡上：
```shell
iptables -F
ip link set dev xdp obj xdp_example.o
```

得到的结果是：
![](assets/G0X%24S3X4~FZU~CO68CD4%7B3D.png)

## Conclusion

可以发现性能有了很大改观。由于数据量还不错，如上图可以看出网络包处理速率也非常稳定，所以可以认为我们的测试结果有不错的可信性。

证明我们除了将 XDP 移植到 Android 平台上，也维持了 XDP 的性能优势。
