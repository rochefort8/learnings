# QNXのinit処理概要

対象：QNX SDP 8.0 / Raspberry Pi 4 BSP  
開発ホスト：Ubuntu Linux

## 1. 概要

QNXのシステム初期化処理（init）は、Linuxとは異なる構造になっている。

Linuxでは、カーネル起動後に通常 `systemd` などのinitプロセスが起動し、デバイスやサービス、アプリケーションの起動を管理する。

一方、QNXでは、マイクロカーネルとProcess Managerを含む `procnto` が、IFS（Image Filesystem）内のBoot Scriptを直接実行する。

**QNXではLinuxの `init` や `systemd` に相当する独立したプロセスを必ずしも必要としない。**

主な特徴は以下のとおり。

- `startup-*` がハードウェアの初期化を行う。
- `procnto` がQNXマイクロカーネルとして動作する。
- `procnto` がIFS内のBoot Scriptを実行する。
- Boot Scriptからデバイスドライバや各種サービスを起動する。
- 必要に応じてSLMやQPLMSによるプロセス管理を利用できる。

## 2. QNXの起動シーケンス

QNXの一般的な起動シーケンスは以下のとおり。

```text
Power ON / Reset
       │
       ▼
Boot ROM
       │
       ▼
Bootloader / IPL
       │
       ▼
startup-*
       │
       ▼
procnto
       │
       ▼
Boot Script
       │
       ├── Device Drivers
       │
       ├── Filesystem Services
       │
       ├── Network Services
       │
       ├── SLM / QPLMS（必要に応じて）
       │
       └── User Applications
```

### 2.1 Boot ROM

SoCに内蔵されている初期起動プログラム。

電源投入後にCPUが実行を開始し、次段のBootloaderをロードする。

### 2.2 Bootloader / IPL

QNXのIFSイメージをメモリにロードし、startupプログラムへ制御を渡す。

使用するBootloaderはプラットフォームによって異なり、U-BootやQNX IPLなどが利用される。

### 2.3 startup-*

QNX BSP（Board Support Package）に含まれるハードウェア初期化プログラム。

主な役割は以下のとおり。

- CPUの初期化
- メモリ情報の設定
- MMUの初期化に必要な設定
- 割り込みコントローラの設定
- システムタイマーの設定
- System Page（syspage）の構築
- `procnto` への制御移行

この段階では、QNXの通常のプロセス管理やスケジューリングはまだ動作していない。

### 2.4 procnto

QNXのマイクロカーネルおよびProcess Managerを含む中核コンポーネント。

主な機能は以下のとおり。

- スレッドスケジューリング
- プロセス・スレッド管理
- メモリ管理
- メッセージパッシング（IPC）
- 割り込み処理機構
- 同期制御
- Boot Scriptの実行

**QNXのマイクロカーネルとしての動作は、`procnto` の起動から始まる。**

## 3. Linuxのinitとの違い

### Linuxの場合

```text
Linux Kernel
     │
     ▼
systemd (PID 1)
     │
     ├── Network Service
     ├── SSH Service
     ├── Other Services
     └── Applications
```

### QNXの場合

```text
procnto
     │
     ▼
Boot Script
     │
     ├── Device Drivers
     ├── Network Service
     ├── SSH Service
     │
     └── SLM（オプション）
           ├── Application A
           └── Application B
```

| 項目 | Linux | QNX 8.0 |
|---|---|---|
| OSの中核 | Linux Kernel | procnto |
| 初期起動処理 | init / systemd | procnto + Boot Script |
| サービス管理 | systemdなど | SLM / QPLMSなど |
| 起動設定 | unitファイルなど | IFS buildfileなど |
| デバイスドライバ | カーネル内・モジュールなど | 多くがユーザー空間 |
| 起動設定の変更 | 設定ファイル変更 | IFS再ビルドが必要な場合がある |

QNXのBoot Scriptは独立した常駐プロセスではない。

## 4. IFSとBoot Script

QNXでは、OSの起動に必要なプログラムや設定をIFS（Image Filesystem）に格納する。

IFSには通常、以下のようなコンポーネントが含まれる。

```text
IFS
│
├── Startup Header
│
├── startup-*
│
├── procnto
│
├── Boot Script
│
└── Files
     ├── Device Drivers
     ├── Libraries
     ├── Shell
     └── Applications
```

IFSは、開発ホスト上で `mkifs` により生成する。

```bash
mkifs board.build ifs.bin
```

ここで、`board.build` はIFSの内容を定義するbuildfileである。

## 5. Raspberry Pi 4 BSPにおけるBoot Script

今回確認したRaspberry Pi 4向けQNX 8.0環境では、Ubuntu上の以下のファイルがIFSの定義ファイルとなっている。

```text
images/rpi4.build
```

このbuildfileを `mkifs` が解析し、IFSイメージを生成する。

Boot Script部分はバイナリ形式に変換され、IFSに格納される。

実機上では、以下のファイルとして確認できた。

```text
/proc/boot/startup-script
```

### 5.1 buildfileとstartup-scriptの関係

```text
Ubuntu Development Host
│
├── images/rpi4.build
│       │
│       ▼
│     mkifs
│       │
│       ▼
│     IFS Image
│       ├── startup-*
│       ├── procnto-smp-instr
│       ├── startup-script
│       └── Other files
│
│
▼
Raspberry Pi 4
│
├── startup-*
│       │
│       ▼
├── procnto-smp-instr
│       │
│       ▼
└── /proc/boot/startup-script
        │
        ├── Device Drivers
        ├── Network Services
        ├── SSH Service
        └── Shell
```

重要なのは、`rpi4.build` 全体が `startup-script` に変換されるわけではないという点である。

buildfileには、主に以下の情報が含まれる。

| 定義 | 内容 |
|---|---|
| `.bootstrap` | startupとprocntoの指定 |
| `[+script] startup-script` | Boot Scriptの定義 |
| その他 | IFSに格納するプログラムやライブラリ |

例えば、次のように記述される。

```text
[+script] startup-script = {
    display_msg "Starting QNX..."

    slogger2 &

    io-sock &
}
```

この `[+script]` 部分が、起動時に `procnto` によって実行されるBoot Scriptとなる。

## 6. Boot Scriptの特徴

QNXのBoot Scriptは、通常のシェルスクリプトではない。

`mkifs` がbuildfile内のBoot Scriptを解析し、実行用の形式に変換する。

そのため、通常の `/bin/sh` や `ksh` のスクリプトとは異なる。

例えば、次のようなBoot Script固有の命令を利用する。

| 命令 | 機能 |
|---|---|
| `display_msg` | 起動メッセージの表示 |
| `waitfor` | 指定パスが出現するまで待機 |
| `reopen` | 標準入出力の接続先変更 |
| `procmgr_symlink` | シンボリックリンクの作成 |
| `&` | バックグラウンド実行 |
| `[pri=20f]` | 優先度20、FIFOスケジューリング |
| `[cpu=0]` | CPU 0への割り当て |

Boot Scriptでは、通常のシェルの `if`、`for`、パイプなどをそのまま利用することはできない。

必要であれば、Boot Scriptから `ksh` などを起動し、通常のシェルスクリプトを実行する。

## 7. Raspberry Pi 4実機のBoot Script

今回、実際のQNX環境で以下を確認した。

```sh
ls -al /proc/boot/
```

主なファイルは以下のとおり。

```text
/proc/boot/
│
├── procnto-smp-instr
├── ldqnx-64.so.2
│
├── startup-script
│
├── customize_startup.sh
├── .ssh-server.sh
├── .storage-server.sh
└── usb_start.sh
```

`startup-script` の内容を確認するために、

```sh
cat /proc/boot/startup-script
```

を実行すると、通常のテキストとしては正しく表示されなかった。

これはBoot Scriptが `mkifs` によってバイナリ形式に変換されているためである。

### 7.1 確認できた起動処理

取得した `startup-script` の内容から、以下の処理を確認できた。

```text
procnto-smp-instr
    │
    ▼
startup-script
    │
    ├── Dynamic Linker設定
    │
    ├── Welcome Message
    │
    ├── slogger2
    │
    ├── dumper
    │
    ├── mqueue
    │
    ├── random
    │
    ├── wdtkick
    │
    ├── i2c-bcm2711
    │
    ├── pci-server
    │
    ├── devc-serminiuart
    │
    ├── spi-bcm2711
    │
    ├── devb-sdmmc-bcm2711
    │
    ├── usb_start.sh
    │
    ├── .storage-server.sh
    │
    ├── io-sock
    │
    ├── dhcpcd
    │
    ├── .ssh-server.sh
    │
    ├── devc-pty
    │
    ├── qconn
    │
    ├── customize_startup.sh
    │
    └── ksh
```

これはBoot Scriptに記録された処理の概略であり、起動完了順序を保証するものではない。

## 8. customize_startup.sh

今回のRaspberry Pi 4 BSPでは、Boot Scriptの後半で以下のファイルが実行される。

```text
/proc/boot/customize_startup.sh
```

実際の内容は以下のとおりだった。

```sh
#!/bin/ksh

if [ -e /scripts/board_startup.sh ]; then
    echo "Starting board customize script ..."
    ksh /scripts/board_startup.sh
fi
```

このスクリプトは、`/scripts/board_startup.sh` が存在する場合にのみ実行される。

つまり、BSP側で用意された起動カスタマイズ用のフックである。

### 8.1 現在の実機状態

以下のコマンドを実行した。

```sh
ls -al /scripts
```

結果：

```text
ls: /scripts: No such file or directory
```

したがって、現在の環境では `board_startup.sh` は実行されない。

実際の起動シーケンスは以下となる。

```text
procnto-smp-instr
    │
    ▼
startup-script
    │
    ├── Device Drivers
    ├── Network / SSH
    ├── qconn
    │
    ▼
customize_startup.sh
    │
    ▼
/scripts/board_startup.sh
    │
    └── 存在しないためスキップ
    │
    ▼
ksh
```

将来、`/scripts/board_startup.sh` を用意すれば、独自アプリケーションの自動起動などに利用できる可能性がある。

ただし、起動時に `/scripts` が利用可能であり、ファイルが永続ストレージ上に存在することが必要となる。

## 9. SLMによるサービス管理

QNXでは、Boot Scriptから直接プロセスを起動するだけでなく、SLM（System Launch and Monitor）を利用することもできる。

SLMは、サービスやアプリケーションの起動・監視を管理する仕組みである。

```text
procnto
    │
    ▼
Boot Script
    │
    ▼
SLM
    │
    ├── Service A
    ├── Service B
    ├── Application A
    └── Application B
```

SLMでは、XML設定ファイルを利用して以下を管理できる。

- プロセスの起動
- 起動順序
- プロセス間の依存関係
- プロセスの監視
- 異常終了時の再起動

QNX 8.0では、QPLMS（QNX Process Launch and Monitor Service）も提供される。

ただし、SLMやQPLMSは必須ではない。

今回のRaspberry Pi 4実機で確認したBoot Scriptでは、SLMによる起動管理は確認されていない。

## 10. Boot Scriptの確認・変更方法

### 10.1 QNX実機で確認

IFS内のファイルを確認する。

```sh
ls -la /proc/boot
```

実行中のプロセスを確認する。

```sh
pidin ar
```

### 10.2 Ubuntu開発ホストで確認

BSP内のbuildfileを探す。

```bash
find . -type f \
    \( -name "*.build" -o -name "*.bld" \)
```

Boot Script定義を探す。

```bash
grep -Rn '\[+script\]' .
```

IFSイメージの内容を確認する。

```bash
dumpifs -v ifs.bin
```

元のbuildfileを編集する場合、Raspberry Pi 4では以下が対象となる。

```text
images/rpi4.build
```

編集後、`mkifs` によりIFSイメージを再生成する。

```bash
mkifs images/rpi4.build ifs.bin
```

実際のBSPでは、既存のビルド手順やオプションに従って生成する。

### 10.3 起動処理の変更

基本的には以下の手順となる。

1. Ubuntu上の `images/rpi4.build` を編集する。
2. Boot Scriptの起動コマンドを変更する。
3. `mkifs` でIFSを再生成する。
4. 新しいIFSをRaspberry Pi 4へ配置する。
5. 再起動して変更内容を確認する。

なお、Boot Scriptから外部ストレージ上のシェルスクリプトを呼び出す方式にすれば、IFSを再ビルドせずにアプリケーションの起動処理を変更できる場合もある。

## 11. まとめ

QNX 8.0のinit処理は、Linuxのような独立したinitプロセスを必須とせず、`procnto` によるBoot Scriptの実行で実現されている。

今回のRaspberry Pi 4 BSPでは、以下の関係が確認できた。

```text
Ubuntu
│
└── images/rpi4.build
          │
          ▼
        mkifs
          │
          ▼
        IFS
          │
          ▼
Raspberry Pi 4
│
├── startup-*
│       │
│       ▼
├── procnto-smp-instr
│       │
│       ▼
└── startup-script
        │
        ├── Device Drivers
        ├── Filesystem Services
        ├── Network Services
        ├── SSH Service
        ├── qconn
        │
        └── customize_startup.sh
                  │
                  └── board_startup.sh
                      （存在する場合のみ）
```

特に重要なのは以下の3点である。

**1. `startup-*` はカーネル起動前のハードウェア初期化を担当する。**

**2. `procnto` はQNXのマイクロカーネルとして機能し、Boot Scriptを実行する。**

**3. Ubuntu上の `images/rpi4.build` に記述したBoot Scriptが、`mkifs` によって変換され、実機上の `/proc/boot/startup-script` になる。**

この仕組みが、QNX 8.0におけるinit処理の基本構造である。

## 12. 参考資料

- [QNX 8.0 — The boot process](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.building/topic/intro/intro_startup_sequence.html)
- [QNX 8.0 — The script file](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.building/topic/buildfiles/nto_script.html)
- [QNX 8.0 — mkifs](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/m/mkifs.html)
- [QNX 8.0 — slm](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/s/slm.html)