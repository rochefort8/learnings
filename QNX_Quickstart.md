
# QNX SDP 8.0 開発環境構築手順
## Ubuntu + VMware Workstation + VS Code QNX Toolkit

## 1. 概要

Ubuntu Linux上でVMware Workstationを使用してQNX OS 8.0の仮想マシンを起動し、VS CodeのQNX Toolkitから接続・監視・デバッグするための手順をまとめる。

### システム構成

```text
Ubuntu Linux (x86-64)
│
├── QNX SDP 8.0
│   ├── qcc
│   ├── GDB
│   └── mkqnximage
│
├── Visual Studio Code
│   └── QNX Toolkit
│       ├── QNX TARGETS
│       ├── Target Navigator
│       ├── Processes Monitoring
│       └── Remote Debugging
│
└── VMware Workstation
    └── QNX OS 8.0 (x86-64)
        ├── qconn (TCP 8000)
        ├── pdebug
        └── Applications
```

通信経路：

```text
VS Code / QNX Toolkit
        |
        | TCP/IP (port 8000)
        |
        v
    QNX qconn
        |
        +-- Process Monitoring
        +-- Filesystem
        +-- Remote Execution
        +-- Remote Debugging
```

## 2. 事前準備

### 必要なソフトウェア

- Ubuntu Linux (x86-64)
- VMware Workstation
- QNX SDP 8.0
- QNX Software Center
- Visual Studio Code
- QNX Toolkit Extension
- Microsoft C/C++ Extension

QNX SDPを使用するため、有効なQNXライセンスが必要。

### QNX SDP環境の確認

SDPのインストール先を `~/qnx800` と仮定する。

```bash
source ~/qnx800/qnxsdp-env.sh

echo "$QNX_HOST"
echo "$QNX_TARGET"

qcc -V
```

`QNX_HOST` と `QNX_TARGET` が設定されていることを確認する。

## 3. VS Code QNX Toolkitの設定

1. VS Codeを起動する
2. ExtensionsでQNX Toolkitをインストールする
3. 左側のQNXアイコンを選択する
4. QNX ToolkitのWalkthroughを開く
5. QNX SDPのインストールパスを設定する
6. QNX Projects Rootを設定する

設定例：

```json
{
  "qnx.sdpPath": "/home/USER/qnx800"
}
```

実際のユーザー名とSDPのインストール先に合わせる。

## 4. QNX VMの作成

QNX ToolkitからVMware用のQNX OSイメージを作成する。

### 操作

1. VS CodeのQNXアイコンを選択
2. QNX TARGETSを開く
3. `+` をクリック
4. `Add new QNX Virtual Target` を選択
5. 仮想マシンの種類に `vmware` を指定
6. CPUアーキテクチャに `x86_64` を指定
7. 必要に応じてmkqnximageオプションを設定
8. VMイメージを生成する

### VMの起動

QNX TARGETSで作成したVMを右クリックし、

`Run VM`

を選択する。

VMware WorkstationでQNX OSが起動する。

## 5. QNX VMのネットワーク設定

### QNX側のIPアドレス確認

QNX VMのコンソールで実行する。

```sh
ifconfig
```

出力例：

```text
inet 192.168.122.100 netmask 0xffffff00
```

この例では、QNX VMのIPアドレスは `192.168.122.100`。

実際のIPアドレスは環境によって異なる。

### qconnの確認

```sh
pidin ar | grep qconn
```

起動していない場合：

```sh
qconn &
```

qconnは通常TCP 8000番を使用する。

> 注意：qconnは開発・デバッグ用の強力なアクセス機能を持つため、信頼できる隔離ネットワークでのみ使用する。

### Ubuntu側から接続確認

```bash
ping -c 3 192.168.122.100
```

続いて：

```bash
nc -vz 192.168.122.100 8000
```

接続できなければ、VMwareのネットワーク設定、VMのIPアドレス、qconnの起動状態を確認する。

## 6. VS CodeからQNX VMへ接続

### Target Connectionの設定

QNX Toolkitで以下の操作を行う。

1. QNX TARGETSを開く
2. 対象のVMを選択する
3. Editアイコンをクリック
4. `Edit target name / IP : port` を開く
5. QNX VMのIPアドレスとポートを入力

例：

```text
192.168.122.100:8000
```

ここで指定するIPアドレスはUbuntuホストではなく、QNX Guest側のアドレス。

必要であれば、`Add new QNX Target Connection` から接続を新規作成する。

## 7. System Informationの表示

### Start Monitoring

VMへの接続ができたら、次の操作を実行する。

1. QNX TARGETSを開く
2. VMを右クリック
3. `Start Monitoring` を選択
4. VM名の左にある矢印をクリックして展開する

表示例：

```text
QNX TARGETS
└── QNX VM
    ├── PROPERTIES
    ├── PROCESSES
    ├── FILESYSTEM
    ├── CORES
    ├── PHYSICAL MEMORY
    └── DASHBOARDS
```

表示される項目はQNX Toolkitのバージョンや接続状態により異なる。

### PROCESSESの表示

`PROCESSES` を展開すると、QNX VM上で動作中のプロセスを確認できる。

Start Monitoringでは、通常5秒間隔でターゲット情報が更新される。

### 今回の確認結果

以下の操作が成功した。

- VMware上でQNX VMを起動
- QNX VMへのTarget Connection設定
- IPアドレスとTCPポートの指定
- Start Monitoring
- PROCESSESの表示

## 8. C/C++アプリケーションのビルド

### テストプログラム

`hello.c`：

```c
#include <stdio.h>
#include <unistd.h>

int main(void)
{
    for (int i = 0; i < 10; i++) {
        printf("Hello QNX: %d\n", i);
        fflush(stdout);
        sleep(1);
    }
    return 0;
}
```

### コンパイル

Ubuntu側：

```bash
source ~/qnx800/qnxsdp-env.sh

qcc -V gcc_ntox86_64 -g -o hello hello.c
```

生成ファイル確認：

```bash
file hello
```

VMと同じx86-64アーキテクチャ向けであることを確認する。

### VS Codeから実行

QNX ToolkitのQNXプロジェクトとして構成した場合：

1. プロジェクトを開く
2. QNX TARGETSでVMを選択
3. プロジェクトをビルド
4. QNXアプリケーションとして起動する

実行にはプロジェクトとLaunch Configurationの設定が必要になる場合がある。

## 9. GDB Remote Debugging

### 方式A：VS Code QNX Toolkit

1. QNXプロジェクトを開く
2. Debug Buildを作成する
3. QNX VMに接続する
4. Debug Configurationを設定する
5. ブレークポイントを設定する
6. デバッグを開始する

実行中のプロセスに対してAttachすることもできる。

### 方式B：コマンドラインGDB

Ubuntu側：

```bash
source ~/qnx800/qnxsdp-env.sh

ntox86_64-gdb ./hello
```

GDB内：

```gdb
target qnx 192.168.122.100:8000
upload hello /tmp/hello
break main
run
```

`target qnx` はQNX独自のデバッグ接続方式である。

GDBのバージョン、SDPの構成、ターゲットのデバッグエージェントによって使用方法が異なる場合がある。

> このGDB手順は今回まだ実機検証していない。

## 10. トラブルシューティング

### Host IP not set

症状：

```text
Host IP not set
```

対処：

1. QNX VMのIPアドレスを確認
2. QNX TARGETSの接続設定を確認
3. IPアドレスとポートを指定
4. VMとホストのネットワーク設定を確認

### PROCESSESが表示されない

対処：

1. QNX TARGETSを開く
2. 対象VMを右クリック
3. `Start Monitoring` を選択
4. VM名を展開する

今回、この方法で解決した。

### qconnに接続できない

QNX側：

```sh
pidin ar | grep qconn
```

Ubuntu側：

```bash
nc -vz <QNX_VM_IP> 8000
```

VMwareのNATまたはBridged接続の設定も確認する。

### ビルドできない

確認項目：

```bash
echo "$QNX_HOST"
echo "$QNX_TARGET"
qcc -V
```

加えて、QNX SDPのライセンスが有効であることを確認する。

## 11. 作業状況

### 確認済み

- [x] VS Code QNX Toolkitの導入
- [x] QNX VMの起動
- [x] QNX Target Connection
- [x] IPアドレスとポートの設定
- [x] Start Monitoring
- [x] PROCESSESの表示

### 今後の検証

- [ ] C/C++アプリケーションのビルド
- [ ] QNX VM上でのアプリケーション実行
- [ ] GDB Remote Debugging
- [ ] ブレークポイントでの停止
- [ ] スレッド情報の確認
- [ ] CPU使用率の監視
- [ ] System ProfilerによるKernel Event Trace解析

## 12. QNX公式ドキュメント

### QNX SDP 8.0

https://www.qnx.com/developers/docs/8.0/

### QNX Toolkit - Managing Targets

https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxtoolkit.user_guide/topic/managing_targets.html

### QNX Toolkit - Quickstart

https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxtoolkit.user_guide/topic/quickstart_guide.html

### Creating the QNX OS Target System

https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxsdp.quickstart/topic/create_target_system.html

### Launching an Application

https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxtoolkit.user_guide/topic/launching_an_application.html

---

## 13. まとめ

今回確認した開発環境：

```text
Ubuntu Linux
    |
    +-- QNX SDP 8.0
    |
    +-- VS Code
    |    |
    |    +-- QNX Toolkit
    |         |
    |         +-- QNX TARGETS
    |         +-- Start Monitoring
    |         +-- PROCESSES
    |
    +-- VMware Workstation
         |
         +-- QNX OS 8.0
              |
              +-- qconn (TCP 8000)
              +-- Applications
```

VMの起動からQNX Toolkitによるプロセス監視まで動作確認済み。

今後は、QNXアプリケーションのビルド、実行、GDBリモートデバッグまで検証する。
