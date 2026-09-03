# QNX を Raspberry Pi 5 で起動する手順

## 概要

Raspberry Pi 5 では、QNX 8.0 系の BSP を使うことで QNX を起動できます。

重要なのは、Raspberry Pi 4 用 BSP ではなく、**Raspberry Pi 5 / BCM2712 向け BSP** を使うことです。

```text
Raspberry Pi 4: BCM2711
Raspberry Pi 5: BCM2712
```

そのため、Pi 4 向けの BSP を Pi 5 に流用するのではなく、Pi 5 専用の BSP を使用します。

---

## 対象環境

対象は以下です。

```text
Board: Raspberry Pi 5
SoC: Broadcom BCM2712
QNX: QNX SDP 8.0.3
Architecture: 64-bit only
RAM: 4GB / 8GB
```

---

## 必要なもの

以下を用意します。

```text
QNX SDP 8.0.3
QNX Software Center
Raspberry Pi 5
microSD card
Raspberry Pi 5 Power Supply
Raspberry Pi Debug Probe
Ethernet cable
Ubuntu host machine
```

UART で boot log を確認するため、Raspberry Pi Debug Probe があると便利です。

---

## 使用する BSP

Raspberry Pi 5 用 BSP の Package ID は以下です。

```text
com.qnx.qnx800.bsp.hw.raspberrypi_bcm2712_rpi5
```

この BSP には、Raspberry Pi 5 向けに以下のような機能が含まれます。

```text
Startup
I2C
Network
SD/MMC
Serial
SPI
PCI
USB OTG host
Watchdog
```

---

## 全体の流れ

作業の流れは以下です。

```text
QNX SDP 8.0.3 をインストール
↓
QNX Software Center で Raspberry Pi 5 BSP を取得
↓
BSP を展開
↓
IFS image をビルド
↓
microSD card を準備
↓
bootfs に ifs-rpi5.bin をコピー
↓
config.txt を編集
↓
UART console で boot log を確認
↓
QNX shell prompt を確認
```

---

# 1. QNX 環境を有効化する

Ubuntu host 上で、QNX SDP の環境設定スクリプトを読み込みます。

```bash
source ~/qnx/sdp/8.0/qnxsdp-env.sh
```

インストール先が異なる場合は、自分の環境に合わせてパスを変更します。

確認します。

```bash
echo $QNX_TARGET
echo $QNX_HOST
qconfig
```

---

# 2. BSP を展開する

QNX Software Center で Raspberry Pi 5 BSP を取得します。

その後、任意の作業ディレクトリに展開します。

```bash
mkdir -p ~/qnx_bsp/bsp-raspberrypi-bcm2712-rpi5
cd ~/qnx_bsp/bsp-raspberrypi-bcm2712-rpi5

unzip /path/to/BSP_raspberrypi-bcm2712-rpi5_be-800_*.zip -d .
export BSP_ROOT_DIR=$PWD
```

以降、この `$BSP_ROOT_DIR` を作業ディレクトリとして使います。

---

# 3. IFS image をビルドする

BSP のディレクトリでビルドします。

```bash
cd $BSP_ROOT_DIR/images
make clean

cd $BSP_ROOT_DIR
make
```

ビルドが成功すると、以下のような IFS image が生成されます。

```text
$BSP_ROOT_DIR/images/ifs-rpi5.bin
```

この `ifs-rpi5.bin` が、Raspberry Pi 5 の bootloader から読み込まれる QNX の起動イメージです。

---

# 4. microSD card を準備する

一番簡単な方法は、Raspberry Pi Imager を使って、一度 Raspberry Pi OS 64-bit を microSD card に書き込む方法です。

これにより、boot partition に以下のような Raspberry Pi 5 用 boot files が用意されます。

```text
config.txt
start*.elf
fixup*.dat
*.dtb
overlays/
```

QNX の IFS image は、この boot partition に追加します。

---

# 5. bootfs に QNX IFS をコピーする

microSD card を Ubuntu host に挿入し、boot partition を mount します。

例：

```bash
cd $BSP_ROOT_DIR/images
cp ifs-rpi5.bin /media/$USER/bootfs/
```

mount point は環境によって異なります。

確認します。

```bash
ls /media/$USER/bootfs/
```

以下のファイルが見えれば OK です。

```text
ifs-rpi5.bin
```

---

# 6. config.txt を編集する

microSD card の boot partition にある `config.txt` を編集します。

以下を追加します。

```ini
[rpi5]
enable_uart=1
force_turbo=1
kernel=ifs-rpi5.bin
```

意味は以下です。

| 設定 | 意味 |
|---|---|
| `enable_uart=1` | UART console を有効化する |
| `force_turbo=1` | 起動時の周波数変動を抑える |
| `kernel=ifs-rpi5.bin` | QNX の IFS image を起動対象にする |

---

# 7. UART を接続する

Raspberry Pi Debug Probe を Raspberry Pi 5 の UART connector に接続します。

シリアル設定は以下です。

```text
Baud rate: 115200
Data bits: 8
Parity: none
Stop bits: 1
Flow control: none
```

Ubuntu host 側でデバイスを確認します。

```bash
ls /dev/ttyACM*
```

`screen` を使う場合：

```bash
screen /dev/ttyACM0 115200
```

`minicom` を使う場合：

```bash
minicom -D /dev/ttyACM0 -b 115200
```

---

# 8. Raspberry Pi 5 を起動する

microSD card を Raspberry Pi 5 に挿入し、電源を入れます。

UART console に boot log が表示されます。

正常に起動すると、以下のような表示になります。

```text
Welcome to QNX 8.0.0 on RaspberryPi5 !
Starting networking ...
Starting DHCP client ...
Starting SSH daemon ...
Starting shell ...
#
```

最後に `#` prompt が出れば、QNX が起動しています。

---

# 確認ポイント

## QNX shell が出るか

まず確認すべきなのは、HDMI 出力ではなく UART console です。

```text
#
```

この prompt が出れば、QNX の shell が起動しています。

---

## ネットワークが起動しているか

QNX shell 上で以下を確認します。

```sh
ifconfig
```

DHCP が有効であれば、Ethernet に IP address が付与されている可能性があります。

---

## プロセスを確認する

```sh
pidin
```

QNX の各プロセスやドライバが起動しているか確認できます。

---

# よくあるトラブル

## UART に何も出ない

以下を確認します。

```text
config.txt に enable_uart=1 があるか
UART の TX/RX が逆になっていないか
115200 8N1 で接続しているか
Raspberry Pi Debug Probe が認識されているか
```

---

## QNX が起動せず Raspberry Pi OS が起動する

`config.txt` の以下を確認します。

```ini
kernel=ifs-rpi5.bin
```

また、`ifs-rpi5.bin` が boot partition に存在するか確認します。

```bash
ls /media/$USER/bootfs/ifs-rpi5.bin
```

---

## Pi 4 用 BSP を使っている

Raspberry Pi 5 では Pi 4 用 BSP は使いません。

```text
Pi 4: BCM2711
Pi 5: BCM2712
```

Pi 5 では必ず以下の BSP を使います。

```text
com.qnx.qnx800.bsp.hw.raspberrypi_bcm2712_rpi5
```

---

---

# 9. Hello World をビルドする

QNX が Raspberry Pi 5 上で起動できたら、次に簡単なユーザーアプリケーションをビルドして実行します。

Raspberry Pi 5 は AArch64（ARM 64-bit）なので、QNX の AArch64 向けクロスコンパイラを使用します。

まず Ubuntu host 上で QNX SDP の環境を有効化します。

```bash
source ~/qnx/sdp/8.0/qnxsdp-env.sh
```

確認します。

```bash
echo $QNX_HOST
echo $QNX_TARGET
which qcc
```

`hello.c` を作成します。

```c
#include <stdio.h>

int main(void)
{
    printf("Hello, QNX World!\n");
    return 0;
}
```

Raspberry Pi 5 向けにビルドします。

```bash
qcc -Vgcc_ntoaarch64le -Wall -g hello.c -o hello
```

C++ の場合は `q++` を使用します。

```bash
q++ -Vgcc_ntoaarch64le -Wall -g hello.cpp -o hello
```

生成されたバイナリを確認します。

```bash
file hello
```

AArch64 の ELF バイナリとして認識されれば OK です。

```text
ELF 64-bit LSB executable, ARM aarch64, ...
```

Hello World のようなユーザーアプリケーションでは、Raspberry Pi 4 と Raspberry Pi 5 で基本的なコンパイルターゲットは同じ AArch64 です。

違いが大きいのは OS を起動するための BSP であり、Raspberry Pi 5 では BCM2712 用 BSP を使用します。

```text
QNX OS image:
    Raspberry Pi 5 / BCM2712 BSP を使用

Application binary:
    qcc -Vgcc_ntoaarch64le ...
```

---

# 10. 実行ファイルを Raspberry Pi 5 に転送する

最も簡単なのは、Ethernet 経由で `scp` / `ssh` を使う方法です。

## 10.1 Raspberry Pi 5 の IP address を確認する

QNX shell 上で確認します。

```sh
ifconfig
```

例：

```text
inet 192.168.1.50
```

Ubuntu host から疎通確認します。

```bash
ping 192.168.1.50
```

---

## 10.2 SSH daemon を確認する

QNX 側で `sshd` が動作しているか確認します。

```sh
pidin ar | grep sshd
```

Ubuntu host から直接接続して確認しても構いません。

```bash
ssh root@192.168.1.50
```

BSP の設定によっては `root` ではなく別ユーザーを使用する場合があります。

* User/Password
  * qnxuser/qnxuser
  * ログイン後 su - でパスワードroot でroot になれる

---

## 10.3 scp で実行ファイルをコピーする

Ubuntu host 上で以下を実行します。

```bash
scp hello root@192.168.1.50:/tmp/
```

その後、QNX にログインします。

```bash
ssh root@192.168.1.50
```

QNX 側で実行します。

```sh
chmod +x /tmp/hello
/tmp/hello
```

正常に動作すれば、以下が表示されます。

```text
Hello, QNX World!
```

---

## 10.4 SSH が起動していない場合

QNX 側で `sshd` が存在するか確認します。

```sh
which sshd
```

存在する場合は起動します。

```sh
sshd
```

または環境によっては以下です。

```sh
/usr/sbin/sshd
```

host key が無い場合は生成します。

```sh
ssh-keygen -A
sshd
```

必要に応じて runtime directory を作成します。

```sh
mkdir -p /var/run
sshd
```

`sshd`、設定ファイル、host key が IFS image に含まれていない場合は、BSP の buildfile を変更して QNX image に追加する必要があります。

---

## 10.5 qconn を使う方法

QNX の開発ツールを使う場合は `qconn` も利用できます。

QNX 側で確認します。

```sh
pidin ar | grep qconn
```

起動していなければ、以下で起動します。

```sh
qconn
```

通常は TCP port 8000 を使用します。

```text
192.168.1.50:8000
```

QNX Momentics IDE や QNX Toolkit から接続すると、ファイル転送、remote execution、debug などを行えます。

---

## 10.6 ビルドから実行までを一度に行う

開発時は、以下の流れを繰り返すことになります。

```text
Ubuntu host
    |
    | qcc
    v
QNX AArch64 executable
    |
    | scp
    v
Raspberry Pi 5 / QNX
    |
    | ssh
    v
Execute / Debug
```

コマンド例：

```bash
qcc -Vgcc_ntoaarch64le -Wall -g hello.c -o hello
scp hello root@192.168.1.50:/tmp/
ssh root@192.168.1.50 'chmod +x /tmp/hello && /tmp/hello'
```

この方法で、Ubuntu host 上でビルドした QNX アプリケーションを Raspberry Pi 5 上へ簡単に deploy できます。


# まとめ

Raspberry Pi 5 で QNX を起動するには、以下の流れで進めます。

```text
QNX SDP 8.0.3 install
↓
QNX Software Center で Pi 5 BSP install
↓
BSP unzip
↓
make
↓
ifs-rpi5.bin 作成
↓
Raspberry Pi OS 64-bit を microSD に書き込み
↓
bootfs に ifs-rpi5.bin をコピー
↓
config.txt に kernel=ifs-rpi5.bin を設定
↓
UART 115200 で boot log 確認
↓
QNX shell prompt を確認
```

重要ポイントは以下です。

```text
Pi 5 専用 BSP を使う
QNX SDP 8.0.3 を使う
IFS image は ifs-rpi5.bin
bootfs/config.txt で kernel=ifs-rpi5.bin を指定する
最初の確認は HDMI ではなく UART console で行う
```

Raspberry Pi 5 で QNX を動かす場合、まずは UART console で `#` prompt が出るところまで確認するのが最初のゴールです。