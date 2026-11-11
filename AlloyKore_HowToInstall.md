# Foundation Vehicle Software Platform 0.3.0 (Alloy Kore EA3) インストール・ビルド手順

以下は Ubuntu 24.04 で、`$HOME/qnx800_ak3` にインストールする例です。
インストール先が異なる場合は、各コマンドのパスを読み替えてください。

## 1. QNX SDP 8.0.5 のインストール

QNX Software Center のディレクトリで実行します。
`myqnx.options` は、myQNX の認証情報を記載したオプションファイルです。

```bash
cd "$HOME/qnx/qnxsoftwarecenter"

./qnxsoftwarecenter_clt @myqnx.options \
  -mirrorBaseline qnx800 \
  -destination "$HOME/qnx800_ak3" \
  -installBaseline com.qnx.qnx800.patchset805/8.0.5.00390T202606231321L
```

新規インストール先には、存在しないディレクトリ、または空のディレクトリを指定します。

## 2. Foundation Vehicle Software Platform 0.3.0 のインストール

同じ QNX Software Center のディレクトリで、既存の SDP に追加します。

```bash
./qnxsoftwarecenter_clt @myqnx.options \
  -mirrorBaseline qnx800 \
  -destination "$HOME/qnx800_ak3" \
  -installPackage com.qnx.qnx800.target.fvsp.group/0.3.0.00139T202607291301L
```

インストールされたパッケージを確認します。

```bash
./qnxsoftwarecenter_clt -offline \
  -destination "$HOME/qnx800_ak3" \
  -listInstalledRoots
```

## 3. ベース部分のビルドと起動（QEMU）

QNX SDP の環境設定を読み込み、Image Builder のディレクトリへ移動します。

```bash
source "$HOME/qnx800_ak3/qnxsdp-env.sh"
cd "$HOME/qnx800_ak3/host/common/fsp/image_builder"

./build_image.sh -b qemu -i 1 -c build
```

ビルド成功後、QEMU で起動します。

```bash
./build_image.sh -b qemu -i 1 -c run
```

## 4. Reference App のビルド

ビルドには Bazel と Cargo を使用します。Bazel は事前にプロジェクト指定のバージョンを用意してください。

### Cargo の準備（Ubuntu 24.04）

Reference App は Rust 2024 Edition を使用するため、Cargo 1.85.0 以上が必要です。
Ubuntu 標準の `/usr/bin/cargo` が 1.75.0 の場合、次のエラーでビルドが停止します。

```text
feature `edition2024` is required
```

QNX 向けのビルドには SDP 付属の `rustc`（この環境では 1.85.1-dev）を使用します。
Cargo の更新に伴って、Ubuntu 付属の `rustc` に切り替えないでください。

まず、バージョン付きの Cargo パッケージが利用可能か確認してインストールします。
`Candidate` が `(none)` の場合は、この手順ではインストールできません。

```bash
sudo apt update
apt-cache policy cargo-1.85
sudo apt install cargo-1.85
cargo-1.85 --version
```

Makefile は `cargo build` を実行するため、`cargo-1.85` のインストールだけでは
古い `cargo` が引き続き呼び出される場合があります。
QNX SDP の環境設定を読み込んだ後、以下を実行して使用する Cargo と rustc を指定します。

```bash
# インストール先が異なる場合は、このパスを変更する
source "$HOME/qnx800_ak3/qnxsdp-env.sh"

mkdir -p "$HOME/.local/qnx-cargo/bin"
ln -sfn "$(command -v cargo-1.85)" "$HOME/.local/qnx-cargo/bin/cargo"
export PATH="$HOME/.local/qnx-cargo/bin:$PATH"
export RUSTC="$QNX_HOST/usr/bin/rustc"
hash -r

command -v cargo
cargo --version
"$RUSTC" -vV
```

`cargo` が上記のリンクを指し、バージョンが 1.85.x、`rustc` が QNX SDP 付属の
1.85.1-dev であることを確認し、同じターミナルからビルドを実行します。
新しいターミナルでは、環境設定を再実行してください。
`Cargo.toml` に `cargo-features = ["edition2024"]` を追加する必要はありません。

Makefile の `overriding recipe` 警告は、この Cargo のバージョンエラーとは別のものです。

参考: [Rust 1.85.0 / Rust 2024](https://blog.rust-lang.org/2025/02/20/Rust-1.85.0.html)、
[Ubuntu の Rust 提供バージョン](https://ubuntu.com/developers/docs/reference/availability/rust/)

### ビルドの実行

上記の Cargo 設定を行ったターミナルで実行します。
`LIBCLANG_PATH` は LLVM 18 のライブラリ配置に合わせて変更してください。

```bash
cd "$HOME/qnx800_ak3/src/fsp/ref_apps"
export LIBCLANG_PATH=/usr/lib/llvm-18/lib/

bazel build ref_apps
```


## 5. Reference App のイメージへの取り込み

Image Builder のディレクトリで、Reference App を含めてイメージを再ビルドします。

```bash
cd "$HOME/qnx800_ak3/host/common/fsp/image_builder"

./build_image.sh -b qemu -i 1 -c build \
  -z "$HOME/qnx800_ak3/src/fsp/ref_apps/content/aarch64le/ref_apps.tar.gz"
```

## 6. 起動後の確認

起動ログとサービス・アプリの状態の確認例です。

```text
---> Starting misc
Loading ComDaemon io-sock module
Setting IP address in ComDaemon configuration file(s): 192.168.122.2
Adding multicast route for SOME/IP: route -n add 224.0.0.17 192.168.122.2
add host 224.0.0.17: gateway 192.168.122.2
Mounting mods-io-sam-someipd module (ComDaemon)
---> Starting plms (launch Platform Orchestrator)

To exit QEMU, type <ctrl>a x

Process count:25
Startup complete
QNX noname 8.0.0 2026/06/05-16:21:14EDT QEMU_virt aarch64le
-i services listall
plmsctrl: component                      status   pid
plmsctrl: fsp_apps_plms                  STARTED  602114
plmsctrl: fsp_plato                      STARTED  573462
plmsctrl: diagd                          STARTED  598039
plmsctrl: hmd                            STARTED  598036
plmsctrl: ipcsdd                         STARTED  581660
plmsctrl: logd                           STARTED  581659
plmsctrl: scstore                        STARTED  581657
plmsctrl: tsyncd                         STARTED  581658
# plmsctrl -i appss listall
plmsctrl: Not able to connect to plms
# plmsctrl -i apps listall
plmsctrl: component                      status   pid
plmsctrl: ref_comab_client               IDLE     -1
plmsctrl: ref_comab_server               IDLE     -1
plmsctrl: ref_comab_zc_client_1          IDLE     -1
plmsctrl: ref_comab_zc_client_2          IDLE     -1
plmsctrl: ref_comab_zc_server            IDLE     -1
plmsctrl: ref_comab_ed_client            IDLE     -1
plmsctrl: ref_comab_ed_server            IDLE     -1
plmsctrl: ref_comab_ed_zc_client_1       IDLE     -1
plmsctrl: ref_comab_ed_zc_client_2       IDLE     -1
plmsctrl: ref_comab_ed_zc_server         IDLE     -1
plmsctrl: ref_comab                      IDLE     -1
plmsctrl: ref_diag_generic               IDLE     -1
plmsctrl: ref_energy                     IDLE     -1
plmsctrl: ref_hm_supervised_executable   IDLE     -1
plmsctrl: ref_hm_watchdog                STARTED  602141
plmsctrl: ref_kvs_executable_schema1     IDLE     -1
plmsctrl: ref_kvs_executable_schema2     IDLE     -1
plmsctrl: ref_log                        IDLE     -1
plmsctrl: ref_observability              IDLE     -1
plmsctrl: ref_plms                       IDLE     -1
plmsctrl: ref_qcrypto                    IDLE     -1
plmsctrl: ref_scstore                    IDLE     -1
plmsctrl: ref_sensor_processing          IDLE     -1
plmsctrl: ref_sensor_recording           IDLE     -1
plmsctrl: ref_sensor_display             IDLE     -1
plmsctrl: ref_sm_statemanager            STARTED  602136
plmsctrl: ref_socom_someip_consumer      IDLE     -1
plmsctrl: ref_socom_someip_provider      IDLE     -1
plmsctrl: ref_socom_someip               IDLE     -1
plmsctrl: ref_virtualization             IDLE     -1
# QEMU: Terminated
```
