# Ubuntu + QEMU/KVM で QNX Hypervisor 8.x と QNX Guest を動かす手順

## 概要

本ドキュメントは、Ubuntu Linux 上で QEMU/KVM を使い、QNX Hypervisor 8.x を起動し、その上で QNX Guest OS を動作させるまでの手順をまとめたものです。

最終構成は以下です。

```text
Ubuntu Linux
   |
   v
KVM + QEMU
   |
   v
QNX Hypervisor Host
   |
   +-- qvm-vmx
          |
          v
       QNX Guest
```

今回の環境では、通常の `mkqnximage --run` では Nested Virtualization に必要な CPU 機能が QNX Host 側へ十分に見えなかったため、QEMU を `--enable-kvm -cpu host` 付きで直接起動しました。

---

## 1. Ubuntu 側で CPU 仮想化機能を確認する

まず、CPU がハードウェア仮想化に対応していることを確認します。

```bash
$ lscpu | grep -i virtualization
Virtualization:                          VT-x
```

Intel CPU の場合は `vmx` が見えれば VT-x 対応です。

---

## 2. KVM を確認する

```bash
lsmod | grep kvm
```

今回の環境では以下が表示されました。

```text
kvm_intel
kvm
irqbypass
```

さらに `/dev/kvm` が存在することも確認できます。

```bash
ls -l /dev/kvm
```

---

## 3. Nested Virtualization を確認する

Intel CPU の場合：

```bash
cat /sys/module/kvm_intel/parameters/nested
```

期待値：

```text
Y
```

今回の環境では `Y` となっており、Nested Virtualization が有効でした。

---

## 4. QNX Hypervisor Host イメージを作成する

Host 用ディレクトリを作ります。

```bash
mkdir -p ~/projects/qnx/hypervisor
cd ~/projects/qnx/hypervisor
```

QNX Hypervisor Host 用イメージを生成します。

```bash
mkqnximage \
  --type=qemu \
  --arch=x86_64 \
  --qvm=yes
```

設定を確認します。

```bash
mkqnximage --options
```

---

## 5. `mkqnximage --run` では Nested Virtualization が通らなかった

通常は以下で QEMU を起動できます。

```bash
mkqnximage --run
```

しかし今回、実際に起動された QEMU は以下のようになっていました。

```text
qemu-system-x86_64
  -smp 2
  --cpu max
  ...
```

QNX Host 側で以下を実行すると、

```sh
qvm-check
```

最初は以下のような結果になりました。

```text
SVM Features ...

Some required features are not implemented by the hardware.
```

これは、物理 CPU が Intel であるにもかかわらず、QNX 側からは QEMU の仮想 CPU が見えており、必要な CPU virtualization feature が十分に提供されていなかったためです。

---

## 6. QEMU を KVM + host CPU で直接起動する

まず、`mkqnximage --run` で起動している QEMU を停止します。

```bash
mkqnximage --stop
```

その後、Host ディレクトリで QEMU を直接起動します。

```bash
sudo qemu-system-x86_64 \
  --enable-kvm \
  -cpu host \
  -smp 2 \
  -m 1G \
  -drive file=output/disk-qemu.vmdk,if=ide,id=drv0 \
  -netdev bridge,br=br0,id=net0 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:db:51:63 \
  -pidfile output/qemu.pid \
  -nographic \
  -kernel output/ifs.bin \
  -serial mon:stdio \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-pci,rng=rng0
```

重要なのは以下です。

```bash
--enable-kvm
-cpu host
```

これにより、ホスト CPU の VMX / EPT などの機能を QNX 側へ見せます。

---

## 7. QNX Host 側で Hypervisor を確認する

QNX にログイン後、以下を確認します。

```sh
grep virtualization /proc/config
```

期待値：

```text
virtualization:enabled
```

続いて、

```sh
qvm-check
```

今回の成功時の結果は以下でした。

```text
CPU supports hypervisor operation
```

さらに以下の警告も出ました。

```text
The following may cause performance issues:

secondary procbased controls can not turn on 0x400

PROCBASED2_PAUSELOOPEXITING
```

これは性能上の警告であり、Hypervisor の必須 CPU feature チェック自体は通っています。

---

## 8. QNX Guest イメージを作成する

Ubuntu 側で Guest 用ディレクトリを作ります。

```bash
mkdir -p ~/projects/qnx/guest
cd ~/projects/qnx/guest
```

QNX Guest 用イメージを生成します。

```bash
mkqnximage \
  --type=qvm \
  --arch=x86_64
```

確認：

```bash
mkqnximage --options | grep type
```

期待値：

```text
Target type: qvm
--type='qvm'
```

Guest 側で生成された主な成果物：

```text
output/ifs.bin
output/disk-qvm
output/disk-qvm.vmdk
```

---

## 9. Guest を Hypervisor Host に組み込む

Host 側へ戻ります。

```bash
cd ~/projects/qnx/hypervisor
```

Guest ディレクトリを指定します。

```bash
mkqnximage \
  --qvm=yes \
  --guest=$HOME/projects/qnx/guest
```

設定確認：

```bash
mkqnximage --options | grep guest
```

今回の環境では以下が確認できました。

```text
--guest='/home/audrey/projects/qnx/guest'
```

---

## 10. Guest の組み込み定義を確認する

Host 側で以下を確認します。

```bash
cat output/option_files/data_files.opt_guest
```

今回、以下のような定義が生成されていました。

```text
[dperms=555 type=dir] hypervisor
[dperms=555 type=dir] hypervisor/guest

hypervisor/guest/ifs.bin=__OPT_GUEST__/output/ifs.bin
hypervisor/guest/disk-qvm=__OPT_GUEST__/output/disk-qvm
```

さらに Guest 用の起動スクリプトも生成されていました。

```sh
[perms=555] /hypervisor/start_guest = {
#!/bin/sh

if [ ! -e /dev/qvmdisk0 ]; then
   echo "Setting up block devices for guest"
   devb-loopback loopback blksz=512,prefix=qvmdisk,fd=/data/hypervisor/guest/disk-qvm

   echo "Setting up networking devices for guest"
   ifconfig vp0 create 192.168.10.1/24 up

   vpctl vp0 peer=/dev/qvm/mkqnximage-guest/network bind=/dev/vdevpeers/vp0
fi

qvm @/data/hypervisor/guest/guest.conf
}
```

Guest 設定ファイルも生成されます。

```text
/data/hypervisor/guest/guest.conf
```

代表的な内容：

```text
system mkqnximage-guest

ram 0xa0000
rom 0xc0000,0x40000
ram 512M

cpu
cpu

load /data/hypervisor/guest/ifs.bin

vdev ioapic
vdev ser8250
vdev virtio-console
vdev timer8254
vdev mc146818
vdev shmem
vdev pckeyboard

vdev virtio-net
        name network
        peerfeats 0x0382
        peer /dev/vdevpeers/vp0

vdev virtio-blk
        hostdev /dev/qvmdisk0
        name virtio-blk_qvmdisk0

vdev 8259
        loc 0x20

vdev 8259
        loc 0xa0

vdev hpet
vdev wdt-ib700
```

---

## 11. Host を再ビルドする

```bash
cd ~/projects/qnx/hypervisor

mkqnximage --clean
mkqnximage
```

その後、再び `mkqnximage --run` ではなく、先ほど成功した QEMU の直接起動方法を使います。

```bash
sudo qemu-system-x86_64 \
  --enable-kvm \
  -cpu host \
  -smp 2 \
  -m 1G \
  -drive file=output/disk-qemu.vmdk,if=ide,id=drv0 \
  -netdev bridge,br=br0,id=net0 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:db:51:63 \
  -pidfile output/qemu.pid \
  -nographic \
  -kernel output/ifs.bin \
  -serial mon:stdio \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-pci,rng=rng0
```

---

## 12. Guest ファイルを確認する

QNX Host 起動後、

```sh
ls -al /data/hypervisor
ls -al /data/hypervisor/guest
```

以下のような Guest 関連ファイルが存在することを確認します。

```text
start_guest
guest/
guest/ifs.bin
guest/disk-qvm
guest/guest.conf
```

---

## 13. Intel 環境では `qvm-vmx` が必要

最初に以下を実行したところ、

```sh
/data/hypervisor/start_guest
```

次のエラーが発生しました。

```text
qvm: execvp(qvm-vmx): No such file or directory
```

Intel x86-64 環境では、Hypervisor 実体として `qvm-vmx` が必要です。

Host 側で以下を確認します。

```bash
grep -n qvm output/build/data.build
grep -n qvm output/build/system.build
```

必要に応じて、

```text
qvm
```

を、

```text
qvm-vmx
```

へ変更します。

例えば Guest 起動側は、

```sh
qvm-vmx @/data/hypervisor/guest/guest.conf
```

となるようにします。

修正後は、生成した buildfile を消さないよう `--clean` せず、

```bash
mkqnximage --build
```

で再ビルドします。

---

## 14. Guest を起動する

QNX Hypervisor Host 起動後、

```sh
/data/hypervisor/start_guest
```

を実行します。

今回、この手順で QNX Guest の起動に成功しました。

---

## 15. Host と Guest を見分ける

Host も Guest も QNX なので、プロンプトだけでは非常に分かりにくいです。

### Host 側の確認

```sh
grep virtualization /proc/config
```

Host では、

```text
virtualization:enabled
```

になります。

さらに、

```sh
pidin | grep qvm
```

を実行すると、Guest を動かしている `qvm-vmx` プロセスが見えます。

つまり、

```text
qvm-vmx が見える側
    =
Hypervisor Host
```

と考えると分かりやすいです。

---

## 16. hostname を変更して区別する

Host：

```sh
hostname qnx-host
```

Guest：

```sh
hostname qnx-guest
```

これにより、Host / Guest の区別がしやすくなります。

---

# 今回の重要ポイント

今回特に重要だった点は以下の3つです。

```text
1. mkqnximage --run は --cpu max で QEMU を起動していた

2. Nested Virtualization を利用するため、
   QEMU を以下で直接起動する必要があった

       --enable-kvm
       -cpu host

3. Intel x86-64 では qvm-vmx が必要だった
```

特に、

```text
CPU supports hypervisor operation
```

まで到達すれば、QNX Hypervisor Host としての CPU virtualization 機能は利用可能な状態です。

---

# トラブルシューティング

## `Some required features are not implemented by the hardware`

QNX Host 上で、

```sh
qvm-check
```

を実行した際、

```text
Some required features are not implemented by the hardware.
```

と表示される場合、QEMU が CPU virtualization feature を十分に Guest へ公開していない可能性があります。

今回の解決方法：

```bash
--enable-kvm
-cpu host
```

---

## `SVM Features` と表示される

物理 CPU が Intel なのに `qvm-check` が、

```text
SVM Features
```

を表示している場合、QEMU の generic CPU model が使われている可能性があります。

`-cpu host` を使い、物理 CPU の feature を passthrough します。

---

## `qvm: execvp(qvm-vmx): No such file or directory`

Intel 環境で `qvm-vmx` が Host image に含まれていない可能性があります。

Host buildfile の `qvm` 関連定義を確認します。

```bash
grep -n qvm output/build/data.build
grep -n qvm output/build/system.build
```

Intel 用の `qvm-vmx` が含まれるよう修正し、

```bash
mkqnximage --build
```

で再ビルドします。

---

# 最終確認

Host 側：

```sh
grep virtualization /proc/config
qvm-check
pidin | grep qvm
```

期待値：

```text
virtualization:enabled

CPU supports hypervisor operation

qvm-vmx ...
```

Guest 起動：

```sh
/data/hypervisor/start_guest
```

これで以下の構成になります。

```text
Physical Intel CPU
   |
   +-- VMX / EPT
   |
Ubuntu Linux
   |
   +-- KVM
   |
   +-- QEMU
          |
          +-- QNX Hypervisor Host
                 |
                 +-- qvm-vmx
                        |
                        +-- QNX Guest
```

---

# Appendix A: VMX / SVM / KVM の整理

## VMX とは

VMX は Intel CPU のハードウェア仮想化機能です。

一般には Intel VT-x と呼ばれる機能群の一部で、QNX Hypervisor から見ると Intel CPU 上では VMX を使って Guest VM を実行します。

Linux Host 側では以下で確認できます。

```bash
grep -m1 'vmx' /proc/cpuinfo
```

`vmx` が表示されれば、Intel のハードウェア仮想化機能が CPU から公開されています。

QNX Hypervisor 8.x の Intel x86-64 環境では、Hypervisor 実体として基本的に以下を使用します。

```text
qvm-vmx
```

構成イメージ：

```text
Intel CPU
   |
   +-- VT-x / VMX
          |
          v
       Linux KVM
          |
          v
        QEMU
          |
          v
QNX Hypervisor Host
          |
          +-- qvm-vmx
                 |
                 v
              Guest OS
```

## SVM とは

SVM は AMD CPU のハードウェア仮想化機能です。一般には AMD-V と呼ばれます。

Intel の VMX とほぼ同じ役割です。

| CPU Vendor | Hardware Virtualization | QNX Hypervisor |
|---|---|---|
| Intel | VMX / VT-x | `qvm-vmx` |
| AMD | SVM / AMD-V | `qvm-svm` |

Linux Host 側では AMD CPU の場合、以下で確認できます。

```bash
grep -m1 'svm' /proc/cpuinfo
```

今回使用した PC は Intel CPU で `vmx` が確認できているため、使用すべきものは `qvm-vmx` です。`qvm-svm` は AMD CPU 向けです。

## KVM とは

KVM は **Kernel-based Virtual Machine** の略で、Linux カーネルに含まれるハードウェア仮想化機能です。

QEMU は CPU をソフトウェアだけでエミュレーションすることもできますが、KVM を有効にすると、Intel VMX や AMD SVM といった物理 CPU の仮想化支援機能を利用できます。

今回の QEMU 起動では以下を使用しました。

```bash
--enable-kvm
-cpu host
```

意味は次の通りです。

```text
--enable-kvm
    QEMU から Linux KVM を利用する

-cpu host
    物理 CPU の CPU feature を QEMU Guest 側へ公開する
```

今回 QNX Hypervisor を QEMU の中で動かしているため、構成は Nested Virtualization になります。

```text
Physical Intel CPU
        |
        +-- VMX / EPT
        |
Ubuntu Linux
        |
        +-- KVM
        |
        +-- QEMU
               |
               +-- QNX Hypervisor Host
                        |
                        +-- qvm-vmx
                               |
                               +-- QNX Guest
```

Nested Virtualization が有効かどうかは、Intel CPU の場合以下で確認できます。

```bash
cat /sys/module/kvm_intel/parameters/nested
```

期待値：

```text
Y
```

## `qvm-check` で SVM Features が表示された場合

今回、最初に `mkqnximage --run` で QEMU を起動した際は、QEMU が `--cpu max` を使用していました。

その状態で QNX Host 上から、

```sh
qvm-check
```

を実行すると、

```text
SVM Features
...
Some required features are not implemented by the hardware.
```

となりました。

物理 CPU は Intel であるにもかかわらず SVM が表示されたため、QEMU の generic CPU model が QNX 側に公開されていたことが分かります。

対策として QEMU を、

```bash
--enable-kvm
-cpu host
```

で起動しました。

その結果、

```sh
qvm-check
```

は、

```text
CPU supports hypervisor operation
```

となり、QNX Hypervisor が必要とする CPU virtualization feature のチェックを通過しました。

---

# Appendix B: Ubuntu Host から QNX Hypervisor Host へ SSH 接続する

## 目的

QEMU のシリアルコンソールを Guest OS 用に使いながら、QNX Hypervisor Host を Ubuntu から SSH で管理できるようにします。

```text
Ubuntu Host
   |
   | SSH
   v
QNX Hypervisor Host
   |
   +-- qvm-vmx
          |
          v
       QNX Guest
```

## QEMU user networking と port forwarding を使う

今回の Ubuntu Host では `br0` が存在していましたが `state DOWN` だったため、単純な SSH 用途では QEMU user networking と port forwarding を使う方法が扱いやすいです。

QEMU のネットワーク指定を以下にします。

```bash
-netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
-device virtio-net-pci,netdev=net0,mac=52:54:00:db:51:63 \
```

QEMU の起動例：

```bash
sudo qemu-system-x86_64 \
  --enable-kvm \
  -cpu host \
  -smp 2 \
  -m 1G \
  -drive file=output/disk-qemu.vmdk,if=ide,id=drv0 \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:db:51:63 \
  -pidfile output/qemu.pid \
  -nographic \
  -kernel output/ifs.bin \
  -serial mon:stdio \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-pci,rng=rng0
```

この設定は、

```text
Ubuntu 127.0.0.1:2222
        |
        | TCP port forwarding
        v
QEMU user network
        |
        | TCP/22
        v
QNX Hypervisor Host
```

という意味です。

## Ubuntu から SSH 接続する

Ubuntu 側から以下を実行します。

```bash
ssh -p 2222 root@127.0.0.1
```

ポート番号は `:` ではなく `-p` で指定します。

誤り：

```bash
ssh 127.0.0.1:2222
```

正しい指定：

```bash
ssh -p 2222 root@127.0.0.1
```

## QNX 側で sshd を確認する

SSH 接続が拒否される場合は、QNX Hypervisor Host 側で sshd が動作しているか確認します。

```sh
pidin | grep sshd
```

sshd が起動していなければ、インストールされている QNX イメージの sshd の場所と設定を確認して起動します。

## Host / Guest のコンソールを分ける

SSH が使えるようになると、次のように役割を分けられます。

```text
QEMU serial console
        |
        +-- Guest QNX 操作用

Ubuntu terminal + SSH
        |
        +-- QNX Hypervisor Host 管理用
```

Host 側の確認：

```sh
grep virtualization /proc/config
pidin | grep qvm
qvm-check
```

Guest 起動：

```sh
/data/hypervisor/start_guest
```

この構成にすると、Guest のコンソールを使用中でも Host 側から `qvm-vmx` の状態、ネットワーク、Guest process などを確認できます。

---

# Appendix C: `guest.conf` の主要設定

`guest.conf` は、QNX Hypervisor 上で起動する Guest VM の仮想ハードウェア構成を定義するファイルです。

## VM 名

```text
system mkqnximage-guest
```

Guest VM の識別名です。Host 側では、この名前が `/dev/qvm/...` のパス生成にも使われます。

## メモリ

```text
ram 0xa0000
rom 0xc0000,0x40000
ram 512M
```

x86 互換の低位メモリ領域、ROM 領域、Guest 用メイン RAM を定義します。主 RAM は `ram 1024M` のように変更できます。

## vCPU

```text
cpu
cpu
```

`cpu` 1 行につき 1 vCPU です。上記は 2 vCPU 構成です。

## Guest IFS

```text
load /data/hypervisor/guest/ifs.bin
```

QNX Guest の IFS をロードします。

## 主な virtual device

```text
vdev ioapic
vdev ser8250
vdev virtio-console
vdev timer8254
vdev mc146818
vdev shmem
vdev pckeyboard
vdev virtio-net
vdev virtio-blk
vdev 8259
vdev hpet
vdev wdt-ib700
```

- `ioapic`: 割り込みルーティング
- `ser8250`: 互換 UART。初期 boot log 用
- `virtio-console`: 高速な para-virtualized console
- `timer8254`: 互換 timer
- `mc146818`: RTC
- `shmem`: 共有メモリ
- `pckeyboard`: PC keyboard controller
- `virtio-net`: Guest NIC
- `virtio-blk`: Guest block device
- `8259`: legacy PIC
- `hpet`: High Precision Event Timer
- `wdt-ib700`: watchdog timer

## VirtIO Block

Guest 定義:

```text
vdev virtio-blk
        hostdev /dev/qvmdisk0
        name virtio-blk_qvmdisk0
```

Host 側では `start_guest` 内で:

```sh
devb-loopback loopback blksz=512,prefix=qvmdisk,fd=/data/hypervisor/guest/disk-qvm
```

により `/data/hypervisor/guest/disk-qvm` を `/dev/qvmdisk0` として公開し、それを VirtIO block device として Guest に渡します。

---

# Appendix D: Guest `/data` が Read-only になる問題

Guest 起動時に以下のエラーが発生しました。

```text
random: Unable to write seed file /data/var/random/rnd-seed: Input/output error
random: Could not initialize seed - Input/output error
Unable to access /dev/random
```

調査すると、

```sh
echo test > /data/test.txt
```

が、

```text
Read-only file system
```

となりました。mount 状態は:

```text
ifs on / type ifs
/dev/hd0t179 on /data type qnx6
/dev/hd0t178 on /system type qnx6
/dev/hd0t177 on /boot type qnx6
/dev/shmem on /dev/shmem type shmem
```

`/data` は QNX6 filesystem ですが read-only でマウントされていました。

## 対策

Guest の boot 時 mount 設定を、

```sh
mount -t qnx6 /dev/hd0t179 /data
```

から、

```sh
mount -t qnx6 -o sync=optional /dev/hd0t179 /data
```

へ変更しました。

Ubuntu 上で mount 定義を探すには:

```bash
cd ~/projects/qnx/guest
grep -R "/data" output/build output/option_files output/inc
```

修正後:

```bash
mkqnximage --build
```

で Guest image を再生成します。これにより `/data` へ書き込み可能になり、`random` の seed 初期化エラーも解消しました。

---

# Appendix E: `virtio-net` で Host ↔ Guest 通信

Host 側の `start_guest` では:

```sh
ifconfig vp0 create 192.168.10.1/24 up
vpctl vp0 peer=/dev/qvm/mkqnximage-guest/network bind=/dev/vdevpeers/vp0
```

Guest 側の `guest.conf` は:

```text
vdev virtio-net
        name network
        peerfeats 0x0382
        peer /dev/vdevpeers/vp0
```

構成:

```text
QNX Hypervisor Host
   vp0 : 192.168.10.1
       |
       | vdevpeer / virtio-net
       |
QNX Guest
   vtnet0 : 192.168.10.2
```

Guest 側で IPv4 address を設定します。

```sh
ifconfig vtnet0 192.168.10.2 netmask 255.255.255.0 up
```

Guest → Host:

```sh
ping 192.168.10.1
```

Host → Guest:

```sh
ping 192.168.10.2
```

双方向 ping が通れば、Host ↔ Guest 間の VirtIO network は正常です。

---

# 現在までに確認できた構成

```text
Physical Intel CPU
   |
   +-- VMX / EPT
   |
Ubuntu Linux
   |
   +-- KVM
   |
   +-- QEMU
          |
          +-- QNX Hypervisor Host
                 |
                 +-- qvm-vmx
                 +-- vp0 : 192.168.10.1
                 |
                 +-- QNX Guest
                        +-- vtnet0 : 192.168.10.2
                        +-- /data writable
```

確認済み:

```text
QNX Hypervisor Host 起動        OK
Nested Virtualization           OK
qvm-check                       OK
QNX Guest 起動                  OK
qvm-vmx                         OK
Guest /data writable            OK
random service 初期化問題解消   OK
virtio-net Host ↔ Guest ping    OK
```

