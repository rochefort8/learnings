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
grep -m1 'vmx|svm' /proc/cpuinfo
```

Intel CPU の場合は `vmx` が見えれば VT-x 対応です。

今回の環境では以下も確認できました。

- `vmx`
- `ept`
- `vpid`

これらが存在していれば、Intel VT-x / Extended Page Tables を利用できる可能性が高いです。

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
