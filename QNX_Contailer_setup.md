# QNX Containers 構築・起動手順書

**対象環境：AWS EC2 / QNX OS 8.0 / ARM64**  
作成日：2026年11月6日  
検証結果：Hello World Container 起動成功

---

## 1. 概要

本書では、QNX ContainersをAWS EC2上のQNX OSに導入し、Hello Worldアプリケーションをコンテナとして実行するまでの手順を説明する。

作業は次の順序で行う。

1. QNX Containersのインストール
2. 必要な実行ファイル・ライブラリの転送
3. Container RuntimeおよびManagerの起動
4. QNXアプリケーションのクロスコンパイル
5. QNX Containerのベースイメージ作成
6. アプリケーションイメージのビルド
7. OCIイメージのAWSへの転送・インポート
8. PodおよびContainerの作成
9. Hello Worldの実行・確認

## 2. 検証環境

| 項目 | 構成 |
|---|---|
| 開発ホスト | Ubuntu Linux |
| QNX SDK | QNX SDP 8.0（Containers対応版） |
| QNX Containers | 1.0 |
| クラウド | AWS EC2 |
| インスタンス | c7g.xlarge |
| CPU | AWS Graviton3 |
| アーキテクチャ | AArch64 / aarch64le |
| ターゲットOS | QNX OS 8.0 AMI |
| コンテナイメージ形式 | OCI |
| イメージ作成ツール | Docker |
| コンテナランタイム | qrunc |
| コンテナ管理 | qcmgr |
| CLI | qcmctl |

QNX Containersでは、ホストのQNXカーネルを共有しながら、QNXアプリケーションをコンテナとして実行する。

Linux用Dockerイメージをそのまま実行することはできない。

## 3. QNX Containersの構成

```text
Ubuntu Linux
  |
  +-- QNX SDP 8.0
  |     |
  |     +-- qcc
  |     +-- QNX libraries
  |     +-- QNX Containers binaries
  |
  +-- Docker
  |     |
  |     +-- qnx-base-aarch64:800
  |     +-- qnx-hello-arm64:v1
  |
  +-- SCP
        |
        v
AWS EC2 c7g.xlarge
  |
  +-- QNX OS 8.0
        |
        +-- qrunc
        +-- qcmgr
        +-- qcmctl
        |
        +-- Pod: hello-pod
              |
              +-- Container: hello1
                    |
                    +-- /hello
```

## 4. QNX Containersのインストール

Ubuntu開発ホストのQNX Software Centerから、QNX SDP 8.0 Containersパッケージをインストールする。

インストール後、QNX SDP環境を設定する。

```bash
source ~/qnx800/qnxsdp-env.sh
```

インストールされたバイナリを確認する。

```bash
find "$QNX_TARGET/aarch64le" \
  \( -name qrunc \
  -o -name qcmgr \
  -o -name qcmctl \)
```

## 5. 必要なファイル

今回のAWS QNX環境では、次の10ファイルを転送して動作させた。

パスはすべて以下からの相対パスである。

```text
/home/audrey/qnx800/target/qnx/aarch64le/
```

| ファイル | 相対パス |
|---|---|
| qrunc | usr/bin/qrunc |
| qcmgr | usr/bin/qcmgr |
| qcmctl | usr/bin/qcmctl |
| jail | usr/sbin/jail |
| libqrunc.so.1 | usr/lib/libqrunc.so.1 |
| libqcmgr.so.1 | usr/lib/libqcmgr.so.1 |
| libcontainer.so.1 | lib/libcontainer.so.1 |
| libjson.so.1 | lib/libjson.so.1 |
| libcurl.so.12 | usr/lib/libcurl.so.12 |
| libcares.so.8 | usr/lib/libcares.so.8 |

これらは今回のAMIで不足していたファイルであり、必要な依存ファイルの総数を示すものではない。

### 5.1 一括転送スクリプト

Ubuntuホストに`deploy_qnx_containers.sh`を作成する。

```bash
#!/usr/bin/env bash
set -euo pipefail

QNX_ROOT="${QNX_ROOT:-$HOME/qnx800}"
ARCH="${ARCH:-aarch64le}"
TARGET="$QNX_ROOT/target/qnx/$ARCH"

KEY="${KEY:-$HOME/.ssh/yogihara-keypair.pem}"
HOST="${HOST:?Set HOST=qnxuser@EC2_PUBLIC_IP}"
DEST="${DEST:-/tmp}"

files=(
    usr/bin/qrunc
    usr/bin/qcmgr
    usr/bin/qcmctl
    usr/sbin/jail
    usr/lib/libqrunc.so.1
    usr/lib/libqcmgr.so.1
    lib/libcontainer.so.1
    lib/libjson.so.1
    usr/lib/libcurl.so.12
    usr/lib/libcares.so.8
)

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

for file in "${files[@]}"; do
    src="$TARGET/$file"
    test -f "$src" || {
        echo "Missing: $src" >&2
        exit 1
    }
    cp -L "$src" "$STAGING/$(basename "$file")"
done

scp -i "$KEY" "$STAGING"/* "$HOST:$DEST/"
```

実行する。

```bash
chmod +x deploy_qnx_containers.sh

HOST=qnxuser@<EC2_PUBLIC_IP> \
  ./deploy_qnx_containers.sh
```

共有ライブラリはシンボリックリンクの場合があるため、`cp -L`で実体をコピーしている。

### 5.2 AWS QNX側への配置

SSHでログインする。

```bash
ssh -i ~/.ssh/yogihara-keypair.pem \
  qnxuser@<EC2_PUBLIC_IP>
```

転送先の`/tmp`から、実行ファイルを適切な実行ディレクトリに、ライブラリをライブラリ検索パスに配置する。

検証では既存のAMIのファイルを不用意に上書きせず、追加配置する。

共有ライブラリが独自ディレクトリにある場合は、例えば次のように設定する。

```sh
export LD_LIBRARY_PATH=/data/qnxcontainers/lib:$LD_LIBRARY_PATH
```

必要に応じて`PATH`も設定する。

依存ライブラリを確認する。

```sh
ldd $(which qrunc)
ldd $(which qcmgr)
ldd $(which qcmctl)
```

未解決の依存関係がないことを確認する。

## 6. Container Runtimeの起動

AWS QNXターゲットでroot権限を使用する。

### 6.1 qruncの起動

```sh
qrunc -l "locations=slog2,slogpages=8,verbosity=info" &
```

確認：

```sh
pidin ar | grep qrunc
```

### 6.2 qcmgrの起動

```sh
qcmgr -l "locations=slog2,slogpages=8,verbosity=info" &
```

今回は外部ネットワークを使用しないHello Worldのため、Pod専用ネットワークブリッジは設定しない。

確認：

```sh
pidin ar | grep qcmgr
```

### 6.3 CLIの動作確認

```sh
qcmctl image list
qcmctl pod list
qcmctl container list
```

エラーなく一覧が取得できれば、Container Managerの初期動作確認は完了する。

## 7. Hello Worldアプリケーションの作成

Ubuntuホストで作業する。

```bash
source ~/qnx800/qnxsdp-env.sh

mkdir -p ~/qnx-container-hello
cd ~/qnx-container-hello
```

`hello.c`を作成する。

```c
#include <stdio.h>
#include <unistd.h>

int main(void)
{
    setbuf(stdout, NULL);

    while (1) {
        printf("Hello from QNX Container!\n");
        sleep(1);
    }

    return 0;
}
```

### 7.1 クロスコンパイル

```bash
qcc -Vgcc_ntoaarch64le hello.c -o hello
```

確認：

```bash
file hello
```

ARM64/AArch64向けのELF実行ファイルであることを確認する。

## 8. QNXベースイメージの作成

QNX Containersでは、QNXの共有ライブラリや実行環境を含むベースイメージを作成する。

QNX公式ドキュメントのベースイメージ作成スクリプトを使用する。

対象アーキテクチャは`aarch64`を指定する。

```bash
./build_qnx_base.sh -a aarch64
```

ここで`build_qnx_base.sh`は、公式ドキュメントのサンプルを保存したファイル名である。

作成後に確認する。

```bash
docker images
```

期待するイメージ：

```text
REPOSITORY         TAG
qnx-base-aarch64   800
```

主な収録ファイルは以下である。

- QNX Cランタイムライブラリ
- QNX動的ローダー
- QNX用基本コマンド
- ksh
- アプリケーションが必要とする共有ライブラリ

## 9. アプリケーションイメージの作成

`Dockerfile`を作成する。

```dockerfile
FROM qnx-base-aarch64:800

ENV PATH=/proc/boot:/system/bin:/usr/bin
ENV LD_LIBRARY_PATH=/proc/boot:/system/lib

COPY hello /hello

CMD ["/hello"]
```

Dockerイメージを作成する。

```bash
docker build \
  --platform linux/arm64 \
  --provenance=false \
  --sbom=false \
  -t qnx-hello-arm64:v1 .
```

`linux/arm64`はOCIイメージのプラットフォーム指定であり、格納される実行ファイルはQNX向けである。

### 9.1 イメージを保存

```bash
docker save \
  -o qnx-hello-arm64.tar \
  qnx-hello-arm64:v1
```

## 10. AWS QNXへ転送する

```bash
scp -i ~/.ssh/yogihara-keypair.pem \
  qnx-hello-arm64.tar \
  qnxuser@<EC2_PUBLIC_IP>:/tmp/
```

## 11. QNX Containerイメージのインポート

AWS QNXで実行する。

```sh
qcmctl image import \
  -n local/qnx-hello-arm64:v1 \
  /tmp/qnx-hello-arm64.tar
```

確認：

```sh
qcmctl image list
```

今回の実際の確認結果：

```text
REPOSITORY             TAG  IMAGE ID       SIZE
local/qnx-hello-arm64  v1   945357692c82   4.23MB
```

## 12. Podの作成

Podは、1つ以上のコンテナをまとめて管理する単位である。

今回はネットワークアクセスを必要としないため、ネットワーク分離モード`NONE`を使用する。

`/tmp/pod.json`を作成する。

```json
{
  "config": {
    "metadata": {
      "name": "hello-pod"
    },
    "qnx": {
      "network_namespace": 4
    }
  }
}
```

`network_namespace`の値は次の意味を持つ。

| 値 | モード | 内容 |
|---|---|---|
| 0 | POD | Pod専用ネットワーク |
| 2 | HOST | ホストのネットワークを共有 |
| 4 | NONE | 外部ネットワーク接続なし |

Podを作成する。

```sh
qcmctl pod create -I /tmp/pod.json
```

確認する。

```sh
qcmctl pod list
qcmctl pod status hello-pod
```

`Ready`になっていれば正常である。

## 13. Containerの作成

`/tmp/container.json`を作成する。

```json
{
  "config": {
    "metadata": {
      "name": "hello1"
    },
    "image": {
      "image": "local/qnx-hello-arm64:v1"
    },
    "qnx": {
      "security_context": {
        "run_as_user": 0,
        "run_as_group": 0
      }
    }
  }
}
```

rootでの実行は今回の動作確認用設定である。

Containerを作成する。

```sh
qcmctl container create \
  -I /tmp/container.json \
  -p hello-pod
```

## 14. Containerの起動

```sh
qcmctl container start hello1
```

状態確認：

```sh
qcmctl container status hello1
```

今回の実際の結果：

```text
FIELD         VALUE
Name          hello1
Id            9c5903c451d42efca9ae6c4ca1873e190b8ea48c2aa3552fe45b8450eebc2b0d
State         Running
Created       1970-01-01 00:58:32
Started       1970-01-01 01:00:03
PID           1847319
Stop Signal   SIGTERM
```

`State = Running`を確認できた。

作成・起動時刻が1970年になっているのは、当時のQNXシステム時計が未設定だった可能性があるため、別途時刻同期を確認する。

## 15. 実行プロセスの確認

QNXホストから以下を実行する。

```sh
pidin ar | grep hello
```

コンテナのメインプロセス`/hello`が表示されることを確認する。

QNX ContainersはホストのQNXカーネルを共有するため、コンテナ内のプロセスもホスト側のプロセス管理ツールから確認できる。

## 16. ログ出力の確認

```sh
qcmctl container logs -f hello1
```

期待する出力：

```text
Hello from QNX Container!
Hello from QNX Container!
Hello from QNX Container!
Hello from QNX Container!
```

今回、このログ出力を確認できた。

## 17. コンテナ内でコマンドを実行

```sh
qcmctl container exec -it hello1 -- /proc/boot/ksh
```

シェルがイメージに含まれていれば、コンテナ内部に入ることができる。

例えば以下を実行する。

```sh
pwd
ls /
```

ホスト側とコンテナ内のファイルシステムを比較できる。

## 18. Containerの停止・削除

停止：

```sh
qcmctl container stop hello1
```

削除：

```sh
qcmctl container remove hello1
```

Podの削除：

```sh
qcmctl pod remove hello-pod
```

## 19. 主なトラブルシューティング

| 症状 | 確認内容 |
|---|---|
| qruncが起動しない | 依存ライブラリ・権限 |
| qcmgrが起動しない | qrunc・設定・ログ |
| qcmctlが接続できない | qcmgrの起動状態 |
| Image import失敗 | OCI形式・CPUアーキテクチャ |
| Container作成失敗 | Pod・JSON構文・イメージ名 |
| Container起動失敗 | 動的ローダー・共有ライブラリ |
| ログが表示されない | プロセス実行状態・stdout flush |

ログ確認に使用するコマンド：

```sh
qcmctl container status hello1
qcmctl container logs hello1
slog2info
pidin ar
```

## 20. 検証結果

今回の検証では以下が成功した。

| 検証内容 | 結果 |
|---|---|
| QNX Containersのバイナリ転送 | 成功 |
| qrunc / qcmgr動作 | 成功 |
| AArch64 OCIイメージのインポート | 成功 |
| Pod作成 | 成功 |
| Container作成 | 成功 |
| Container起動 | 成功 |
| Container状態確認 | Running |
| `/hello`プロセス確認 | 成功 |
| Hello Worldログ確認 | 成功 |

**結論：AWS Graviton3（c7g.xlarge）上のQNX OS 8.0で、QNX Containersを使用したARM64アプリケーションの実行に成功した。**

今回確認できた範囲は、コンテナの基本実行機能である。ネットワーク分離、ファイルシステム分離、セキュリティ制限、再起動時の自動起動などは今後の検証項目とする。

## 21. 参考資料

- QNX Containers User's Guide  
  https://www.qnx.com/developers/docs/8.0/com.qnx.doc.containers.user_guide/

- Building a base QNX Container image  
  https://www.qnx.com/developers/docs/8.0/com.qnx.doc.containers.user_guide/topic/u_qhost_01_build_base_image.html

- qcmctl Command Reference  
  https://www.qnx.com/developers/docs/8.0/com.qnx.doc.containers.user_guide/topic/appendix_qcmctl.html

- Pod Sandbox Configuration  
  https://www.qnx.com/developers/docs/8.0/com.qnx.doc.containers.user_guide/topic/appendix_pod_config.html

