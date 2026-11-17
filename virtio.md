# VirtIO（Virtual I/O Device）

## 1. VirtIOとは

VirtIO（Virtual I/O Device）は、

> **Guest OSとHypervisorの間で、仮想デバイスを扱うための標準インターフェース**

である。

例えばHypervisor上でLinuxやAndroidを動かす場合、Guest OSが物理EthernetやStorageを直接操作する代わりに、VirtIOを通して仮想デバイスを利用できる。

```text
Linux / Android Guest
        │
        │ VirtIO
        ↓
    Hypervisor
        │
        ↓
   Physical HW
```

代表的なVirtIO Deviceには、

- `virtio-net`：Network
- `virtio-blk`：Block Storage
- `virtio-console`：Console
- `virtio-gpu`：GPU

などがある。


## 2. VirtIOはQNX独自技術ではない

VirtIOはQNX独自のインターフェースではない。

元々Linuxの仮想化技術の発展の中から生まれ、その後広く利用されるようになり、現在は**OASISのVIRTIO Technical Committeeによって標準化**されている。

そのため、QNXが「industry-standard VirtIO」と表現する場合、

> **QNX独自の仮想I/O方式ではなく、広く利用されている標準VirtIO仕様に対応している**

という意味になる。


## 3. VirtIOの歴史

2000年代、Virtualization技術が普及し始めた頃は、Hypervisorごとに異なる仮想I/O方式が存在していた。

例えば、

```text
VMware
   ↓
VMware独自Virtual Device

Xen
   ↓
Xen独自Virtual Device

KVM
   ↓
KVM系Virtual Device
```

というような状態で、Guest OS側にはHypervisorごとに異なるDriverが必要になる問題があった。

そこで2007年頃、Linux Kernel DeveloperのRusty Russellによって、

> **HypervisorごとにVirtual Device Driverを作るのではなく、共通のVirtual I/O Interfaceを作ろう**

という考え方からVirtIOが開発された。

初期VirtIOはLinux / KVMを中心として発展した。

```text
Linux Guest
     │
   VirtIO
     │
     KVM
```

その後、

- Linux
- Android
- FreeBSD
- Windows
- その他のGuest OS
- 複数のHypervisor

などへ採用範囲が拡大した。

そして、Linux / KVM固有の仕組みという位置付けを超え、OASISで標準化されるようになった。


## 4. LinuxとVirtIO

LinuxはVirtIOに本格的に対応している。

Linux KernelにはVirtIO関連のDriverが存在し、例えば以下のようなものがある。

```text
virtio_net
virtio_blk
virtio_pci
virtio_ring
```

それぞれ、

| Driver | 用途 |
|---|---|
| `virtio_net` | 仮想Network Device |
| `virtio_blk` | 仮想Block Device |
| `virtio_pci` | PCI TransportによるVirtIO |
| `virtio_ring` | virtqueue / Ringの処理 |

となる。

そのためLinuxをHypervisor上のGuest OSとして動かした場合、

```text
Linux Guest
    │
virtio_net
    │
  VirtIO
    │
Hypervisor
    │
Physical NIC
```

のような構成を取ることができる。


## 5. AndroidとVirtIO

AndroidもVirtIOを利用できる。

AndroidはLinux Kernelをベースとしているため、Linux KernelのVirtIO機能を利用できる。

例えばQNX Hypervisor上でAndroidをGuest OSとして動かした場合、

```text
          SoC
           │
     QNX Hypervisor
           │
        VirtIO
           │
     Android Guest
           │
     Android Apps
```

という構成を取ることができる。

ただし、

> **Androidは常にVirtIOを使う**

という意味ではない。

VirtIOが特に登場するのは、AndroidをVMのGuestとして動作させ、HypervisorからVirtual Deviceを提供する場合である。


## 6. QNX HypervisorとVirtIO

QNX HypervisorもVirtIOをサポートしている。

典型的には、

```text
Linux / Android Guest
        │
        │ virtio-net
        │ virtio-blk
        ↓
     VirtIO
        ↓
   QNX Hypervisor
        ↓
   QNX HW Driver
        ↓
   Physical HW
```

という構成になる。

Guest側から見ると、

> 「QNX独自Virtual Device」

ではなく、

> 「標準VirtIO Device」

として見える。

LinuxやAndroid側で標準VirtIO Driverを利用できるため、QNX Hypervisor専用のGuest Driverを作る必要性を減らせる点が大きなメリットとなる。


## 7. VirtIOのシンプルな例：virtio-net

最も分かりやすい例がVirtual Network Deviceである。

例えばAndroid GuestがNetwork通信する場合、

```text
Android Application
        │
        ↓
   TCP/IP Stack
        │
        ↓
 virtio-net Driver
        │
        ↓
     VirtIO
        │
        ↓
   QNX Hypervisor
        │
        ↓
 QNX Network Driver
        │
        ↓
 Physical Ethernet
```

という経路になる。

Android側は、

> 「実際のPhysical Ethernet ControllerがどのVendorのDeviceか」

を意識する必要がない。

Guest OSから見えるのは、

```text
virtio-net
```

という標準的なVirtual Network Deviceである。


## 8. virtqueueとは

VirtIOの重要な仕組みが、

> **virtqueue**

である。

virtqueueは、

> **Guest OSとHypervisor / Virtual Deviceの間でI/O Requestを効率的に受け渡すためのQueue**

と考えると分かりやすい。

例えばNetwork Packetを送信する場合、

```text
Guest
  │
Packet作成
  ↓
virtio-net Driver
  ↓
TX virtqueue
  ↓
Hypervisor
  ↓
Physical NIC
```

となる。


## 9. virtqueueによるPacket送信

例えばLinux / Android GuestからEthernet Packetを1個送信する場合を考える。

まずGuest側ApplicationからNetwork Dataが送信される。

```text
Application
     ↓
TCP/IP Stack
     ↓
virtio-net Driver
```

virtio-net Driverは送信するPacketをGuest Memory上に用意する。

例えば、

```text
Guest Memory

0x1000
┌─────────────────────┐
│ Ethernet Packet     │
│                     │
│ "Hello..."          │
└─────────────────────┘
```

virtqueueには大量のPacketそのものをコピーするというより、

> **「このMemory Addressに、この長さのDataがあります」**

という情報を登録する。

概念的には、

```text
TX virtqueue

┌─────────────────────┐
│ Address = 0x1000    │
│ Length  = 1500      │
│ Flags   = ...       │
└─────────────────────┘
```

というイメージになる。


## 10. GuestからHypervisorへの通知

virtio-net DriverがvirtqueueへRequestを登録すると、

> 「virtqueueに新しいRequestを追加した」

ことをHypervisor側へ通知する。

概念的には、

```text
Guest
   │
   │ Add Request
   ↓
virtqueue
   │
   │ Notification / Kick
   ↓
Hypervisor
```

となる。

Hypervisor側のVirtual Deviceはvirtqueueを確認し、Guest Memory上のDataを処理する。

```text
TX virtqueue
      │
      ↓
Hypervisor
      │
      ↓
Network Backend
      │
      ↓
Physical NIC
```

処理が完了するとHypervisor側からGuest側へCompletionが通知され、GuestはそのBufferを再利用できる。


## 11. virtqueueのイメージ

全体を簡単にすると、

```text
Guest                         Hypervisor

Packet作成
   │
   ↓
virtqueueへ登録
   │
   ├──── Notification ───────→
   │                              │
   │                         Queue確認
   │                              │
   │                         Packet処理
   │                              │
   │←──── Completion ─────────────┤
   │
Buffer再利用
```

となる。

つまりvirtqueueは、

> **大量のDataそのものを単純にQueueへコピーする仕組みではなく、Memory上のBufferを効率的に記述・受け渡す仕組み**

と理解するとよい。


## 12. VirtIOを使わずにPhysical HWへ直接アクセスする方法

VirtIOを使うことは必須ではない。

Hypervisor環境では、

> **Device Passthrough**

によってPhysical Deviceを特定Guestへ直接割り当てることもできる。

VirtIOの場合：

```text
Linux Guest
      │
virtio-net
      │
 VirtIO
      │
Hypervisor
      │
Physical NIC
```

Passthroughの場合：

```text
Linux Guest
      │
Physical NIC Driver
      │
      ↓
Physical NIC
```

HypervisorはDeviceの割当やIsolationを管理するが、Guest OSがPhysical Device用Driverを使用してHWを直接的に制御する。


## 13. VirtIOとDevice Passthroughの違い

| 項目 | VirtIO | Device Passthrough |
|---|---|---|
| Guestから見えるもの | Virtual Device | Physical Device |
| Guest Driver | VirtIO Driver | 実HW Driver |
| HW依存性 | 小さい | 大きい |
| Device共有 | しやすい | 基本的に専有 |
| GuestとHWの分離 | 強い | HWと密結合 |
| Flexibility | 高い | 低め |
| Performance | Virtualization Overheadあり | 高性能にしやすい |

考え方としては、

```text
共有・抽象化・Portability
        ↓
      VirtIO


特定VMにHWを専有させる
        ↓
 Device Passthrough
```

という使い分けになる。


## 14. QNX Hypervisor + Yocto Linux

YoctoはOSそのものというより、

> **組込みLinux Distributionを作成するためのBuild System / Project**

である。

したがってQNX Hypervisor上にYoctoで作成したLinuxをGuestとして動かした場合、

```text
        Yocto Linux Guest
              │
       ┌──────┴──────┐
       │             │
  virtio-net     virtio-blk
       │             │
       └──────┬──────┘
              ↓
           VirtIO
              ↓
       QNX Hypervisor
              ↓
             HW
```

という構成を取ることができる。

一方、一部DeviceをPassthroughすることも可能であり、

```text
            Yocto Linux
          ┌─────┼───────┐
          │     │       │
       Network Storage  Device
          │     │       │
       VirtIO VirtIO Passthrough
```

のような混在構成も考えられる。

そのため、

> 「QNX Hypervisor上のYocto LinuxはすべてVirtIO経由でHWへアクセスする」

とは限らない。

DeviceごとにVirtIO、Passthrough、その他の方式を選択できる。


## 15. Raspberry PiとVirtIO

Raspberry PiでLinuxを直接Bare Metalで動かしている場合、通常VirtIOは必要ない。

```text
Raspberry Pi
     │
   Linux
     │
RPi HW Driver
     │
Physical HW
```

この場合Linuxが直接Hardwareを制御しているため、VirtIOを挟む理由がない。

一方、Raspberry Pi上でHypervisorを動かし、その上にLinux Guestを動かす場合はVirtIOが登場する。

```text
Raspberry Pi HW
       │
   Hypervisor
       │
     VirtIO
       │
 Linux Guest
```

つまり、

> **Raspberry PiだからVirtIOを使うのではなく、VM Guestとして動作するとVirtIOを使う可能性がある**

という理解が重要。


## 16. DockerとVirtIO

Docker ContainerとVMは異なる。

VirtIOは基本的に、

> **Guest OS ↔ Hypervisor**

のVirtual Device Interfaceである。

Docker Containerは通常、Host LinuxとKernelを共有する。

```text
Docker Container
       │
       ↓
   Host Linux
       │
   virtio-net
       │
       ↓
   Hypervisor
       │
       ↓
      HW
```

そのためDocker Container自身がVirtIO Deviceを持っているというより、**Dockerの下で動いているHost LinuxがVirtIO Deviceを使用している**と考える方が正確。

重要な違いは、

```text
VM
 ↓
Virtual HWがある
 ↓
VirtIOが登場する


Docker Container
 ↓
Host Kernelを共有
 ↓
基本的に独立したVirtual HWを持たない
```

という点。


## 17. LinuxでVirtIOを確認する方法

Linux GuestがVirtIOを使用しているかは、実際にCommandで確認できる。


### PCI Deviceの確認

```bash
lspci | grep -i virtio
```

Driverまで確認する場合：

```bash
lspci -nnk | grep -i -A3 virtio
```


### Kernel Moduleの確認

```bash
lsmod | grep virtio
```

例えば、

```text
virtio_net
virtio_blk
virtio_pci
virtio_ring
virtio
```

などが表示される可能性がある。


### Kernel Logの確認

```bash
dmesg | grep -i virtio
```

Permissionが必要な場合：

```bash
sudo dmesg | grep -i virtio
```


### Network Driverの確認

まずNetwork Interfaceを確認する。

```bash
ip link
```

例えば`eth0`を確認する場合：

```bash
ethtool -i eth0
```

結果が、

```text
driver: virtio_net
```

なら、そのNetwork InterfaceがVirtIO Network Deviceを使用していることが確認できる。


## 18. lsmodだけで判断しない

Linux KernelではVirtIO DriverがLoadable Kernel Moduleではなく、

```text
CONFIG_xxx=y
```

としてKernel Built-inになっている場合がある。

その場合、

```bash
lsmod | grep virtio
```

に何も表示されなくても、VirtIOを使用している可能性がある。

そのため、

```bash
lspci
dmesg
ethtool
lsmod
```

などを組み合わせて確認することが重要。


## 19. VirtIOの全体像

VirtIOを一枚の図で整理すると、

```text
             Application
                  │
                  ↓
          Linux / Android
                  │
              Driver
                  │
          ┌───────┴───────┐
          │               │
     virtio-net       virtio-blk
          │               │
          └───────┬───────┘
                  │
             virtqueue
                  │
             VirtIO
                  │
                  ↓
             Hypervisor
                  │
                  ↓
            Physical HW
```

となる。


## 20. VirtIOを一言でまとめると

VirtIOは、

> **仮想環境における標準的なDevice I/O Interface**

と理解すると分かりやすい。

さらに役割を分解すると、

```text
VirtIO
  ↓
「GuestとHypervisor間のVirtual Deviceの共通仕様」


virtio-net
  ↓
「Network用Virtual Device」


virtio-blk
  ↓
「Storage用Virtual Device」


virtqueue
  ↓
「GuestとHypervisorがI/O Requestを
  効率的に受け渡す仕組み」


Device Passthrough
  ↓
「VirtIOを使わずPhysical Deviceを
  Guestへ直接割り当てる方式」
```

となる。


## まとめ

VirtIOは、Linux / AndroidなどのGuest OSとHypervisorの間でVirtual Deviceを扱うための標準インターフェースである。

元々はLinux Virtualizationの世界から生まれ、Hypervisorごとに異なるVirtual Device Driverを用意する問題を解決する目的で発展した。

現在はOASISで標準化され、Linux / Androidだけでなく複数のOSやHypervisorで利用されている。

QNX HypervisorもVirtIOをサポートすることで、

```text
Linux / Android
       │
 Standard VirtIO Driver
       │
       ↓
     VirtIO
       │
       ↓
 QNX Hypervisor
       │
       ↓
      HW
```

という標準化された構成を取ることができる。

したがってVirtIOの最大のポイントは、

> **Guest OSを特定HypervisorやPhysical HWの実装から切り離し、標準的なVirtual Device InterfaceでI/Oを提供できること**

である。