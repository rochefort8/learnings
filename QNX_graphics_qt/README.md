# Raspberry Pi 5 + QNX 8.0 + Qt 6 構築手順まとめ

**対象:** Ubuntu Linux x86-64 / QNX SDP 8.0 / Raspberry Pi 5 / Qt 6.12

本書はQNX本体がRaspberry Pi 5ですでに起動しているところから、Graphics（Screen / OpenGL ES）を整備し、Qt Quick / QMLアプリケーションを実行するまでの手順をまとめたものです。

- **Part 1：QNX Graphicsの構築** — Screen、GPUドライバー、OpenGL ES、永続ストレージおよび接続の整備
- **Part 2：Qt 6の構築** — UbuntuでのQt環境、QNX向けクロスビルド、Qt Quickアプリの転送と起動

> **注意:** 各種パス・IPアドレス・IFS buildfileは環境依存です。`192.168.1.100` は例示用IPです。SDカードのパーティション操作前には必ずバックアップと領域の確認を行ってください。画面描画用ドライバーのIFS統合例は抜粋であり、配布BSPの公式手順に沿って全依存ファイルを追加する必要があります。

---

# Part 1：Raspberry Pi 5でQNX Graphicsを動かす

## 1. 開発環境

| 項目 | 構成 |
|---|---|
| 開発ホスト | Ubuntu Linux x86-64 |
| ターゲット | Raspberry Pi 5 |
| OS | QNX SDP 8.0 |
| CPUアーキテクチャ | AArch64 (`aarch64le`) |
| BSP | QNX Raspberry Pi 5 BSP |
| Graphics | QNX Screen + Mesa3D |
| GPUドライバー | `drm-rpi5` |
| ディスプレイ | HDMI |
| ストレージ | microSDカード（約32GB） |
| 接続 | UARTシリアルコンソール / SSH |

QNX本体の起動は完了しているものとします。

## 2. QNX Software CenterでGraphicsをインストール

Ubuntu上のQNX Software Center（QSC）で次を確認・インストールします。

| パッケージ | Package ID |
|---|---|
| Screen Base Graphics | `com.qnx.qnx800.target.screen.base` |
| Raspberry Pi Screen Board Support | `com.qnx.qnx800.target.screen.board.rpi` |
| Screen Demo Applications | `com.qnx.qnx800.target.screen.demos` |

Pi 5用Board SupportにはMesa、DRMなどの依存パッケージがあるため、QSCの依存関係も導入します。

### 2.1 QSC CLIで一覧を確認

```bash
qnxsoftwarecenter_clt -listInstalled
qnxsoftwarecenter_clt -listInstalled | grep -Ei 'screen|graphics|mesa|demo'
qnxsoftwarecenter_clt -listAccessible | grep -Ei 'screen|graphics|mesa|demo'
```

### 2.2 QNX SDP 8.0.6について

今回、QSCの利用可能パッケージ一覧には次が表示されました。

```text
com.qnx.qnx800.patchset806=8.0.6.00398T202611040724L
```

次のコマンドの `com.qnx.qnx800` は **8.0.6を明示する指定ではありません**。

```bash
qnxsoftwarecenter_clt \
  -destination "$HOME/qnx806" \
  -setPolicy=conservative \
  -installBaseline com.qnx.qnx800
```

実際のログでは `8.0.0.00141T202311271501L` が選ばれ、`ncurses` およびXilinx関連パッケージの取得時に `Artifact not found` が発生しました。使用するSDPが正常にインストールされていることを確かめます。

```bash
source ~/qnx806/qnxsdp-env.sh
qconfig
echo "$QNX_HOST"
echo "$QNX_TARGET"
```

8.0.6が未導入の場合は、既存の正常に動くSDP環境のスクリプトを読み込んでください。

## 3. Graphics関連のバイナリを確認

Ubuntu側：

```bash
find "$QNX_TARGET/aarch64le" \
  \( -name 'screen' \
  -o -name 'drm-rpi5' \
  -o -name 'gles2-gears' \
  -o -name 'gles3-gears' \
  -o -name 'graphics-rpi5-*.conf' \) -print
```

| ファイル | 用途 |
|---|---|
| `screen` | QNX Screenサーバー |
| `drm-rpi5` | Pi 5用DRMドライバー |
| `gpu_rpi5.so` | GPUサポート |
| `EGL-mesa.so` | EGL実装 |
| `GLESv2-mesa.so` | OpenGL ES |
| `v3d_dri.so` | Broadcom GPU用Mesaドライバー |
| `libWFDrpi5.so` | ディスプレイ管理 |
| `screen-alloc-rpi5.so` | Screenバッファ割当 |
| `gles2-gears` | OpenGL ES 2動作確認 |
| `gles3-gears` | OpenGL ES 3動作確認 |

デモ実行ファイルがない場合はScreen Demoパッケージとインストールした版での実行ファイル名を確認します。版によっては `disp-gles2-gears` などの別名のユーティリティもあります。

## 4. ScreenをBSPへ組み込む

すでにIFS内でScreenが起動している場合はこの工程は不要です。

QNX側：

```sh
pidin ar | grep -E 'screen|drm-rpi5'
ls -l /dev/screen
```

なければUbuntu側でbuildfileを探します。

```bash
find ~/rpi5-qnx/bsp -name '*.build'
```

### 4.1 buildfileへのファイル追加

以下は**主要エントリの抜粋**です。

```text
/sbin/screen=screen
/sbin/drm-rpi5=drm-rpi5
/usr/bin/gles2-gears=gles2-gears
/usr/bin/gles3-gears=gles3-gears
/usr/lib/graphics/drm-rpi5/gpu_rpi5.so=graphics/drm-rpi5/gpu_rpi5.so
/usr/lib/graphics/drm-rpi5/EGL-mesa.so=graphics/drm-rpi5/EGL-mesa.so
/usr/lib/graphics/drm-rpi5/GLESv2-mesa.so=graphics/drm-rpi5/GLESv2-mesa.so
/usr/lib/graphics/drm-rpi5/graphics-rpi5-hdmi1.conf=graphics/drm-rpi5/graphics-rpi5-hdmi1.conf
```

これだけでは動作しません。DRM、Mesa、Screenの追加ライブラリ、各種依存サービスと起動順序が必要です。QNX公式のPi 5 Screen BSP Integrationセクションを参照して、使用するBSPのbuildfileへ統合してください。

### 4.2 Screenの起動

前提となるドライバーが起動した後、必要に応じて手動起動します。

```sh
export LD_LIBRARY_PATH=/proc/boot:/lib:/usr/lib:/lib/dll:/usr/lib/graphics/drm-rpi5
screen -c /usr/lib/graphics/drm-rpi5/graphics-rpi5-hdmi1.conf &
ls -l /dev/screen
```

HDMI1以外を使用するなら該当する設定ファイルを選択します。

## 5. OpenGL ESの動作確認

QNX Targetで：

```sh
gles2-gears
gles3-gears
```

版によって実行ファイル名が異なる場合は、実際にインストールされたデモを実行します。歯車が表示されればScreenと該当OpenGL ES描画経路の基本動作を確認できます。

## 6. QNX Targetに書き込み可能なストレージを作成

Qtのライブラリやアプリケーションを配置するため、IFSとは別に永続的な書き込み領域を用意します。

### 6.1 今回の実機の状態

```text
ifs             72M   72M      0  100%  /
/dev/fs9p0      16M   37K    16M    1%  /var
/dev/sd0       5.7G  5.7G      0  100%  /dev/sd0t131
/dev/sd0       512M  512M      0  100%  /dev/sd0t12
/dev/sd0        29G   29G      0  100%
```

`/data` は存在せず、`/usr` は空ディレクトリでした。これらの `100%` 表示だけで通常のファイルシステムの空き容量は判断できません。SDカードのパーティションテーブルを別途確認してください。

目標構成：

```text
microSD
├── FAT32 boot         /dev/sd0t12
├── Linux              /dev/sd0t131
└── QNX6 Power-Safe    新規パーティション
    └── /data
        ├── qt/
        └── apps/
```

### 6.2 fdiskを入手

QNX Targetに `fdisk` がなかったため、UbuntuのQNX SDPから探します。

```bash
find "$QNX_TARGET/aarch64le" \
  \( -name fdisk -o -name mkqnx6fs -o -name 'fs-qnx6.so' \) -print
```

見つかったQNX AArch64用 `fdisk` を、利用可能な一時的書き込み領域へ転送します。

```bash
scp /path/to/qnx/fdisk root@192.168.1.100:/var/fdisk
```

QNX側：

```sh
chmod +x /var/fdisk
/var/fdisk /dev/sd0 show
```

### 6.3 QNX6パーティションを作成

**SDカードのバックアップ、未割り当て領域、パーティションスロットの確認が済んだ場合だけ**、次のようなコマンドを使用します。

```sh
fdisk /dev/sd0 add -t 179 -p 100
```

| オプション | 意味 |
|---|---|
| `-t 179` | QNX6 Power-Safeパーティションタイプ |
| `-p 100` | 最大の連続未割り当て領域の100%を使用 |

既存の `/dev/sd0t12` や `/dev/sd0t131` に対してフォーマットを実施しないでください。タイプ177、178、179はいずれもQNX6 Power-Safeで利用できます。

### 6.4 フォーマット・マウント

新しく作成したパーティションが実際に `/dev/sd0t179` であると確認できた場合の例：

```sh
mount -e /dev/sd0
mkqnx6fs /dev/sd0t179
mkdir -p /data
mount -t qnx6 /dev/sd0t179 /data
```

`mkqnx6fs` は対象のデータを消去します。`/` がIFSで読み取り専用の場合、`mkdir -p /data` が失敗するため、既存のマウントポイントを使うか、buildfile内に `/data` を作成してIFSを再ビルドしてください。

動作確認：

```sh
touch /data/test
ls -l /data/test
rm /data/test
mkdir -p /data/qt /data/apps
```

## 7. SSHのrootログイン設定

QNX上で設定を確認：

```sh
ls /etc/ssh/sshd_config
```

公開鍵認証のみ許可する場合：

```text
PermitRootLogin prohibit-password
PubkeyAuthentication yes
```

検証環境でパスワード認証も許可する場合：

```text
PermitRootLogin yes
PasswordAuthentication yes
```

IFSが読み取り専用なら設定を一時的に書き込み可能な領域へコピーします。

```sh
cp /etc/ssh/sshd_config /var/sshd_config
```

設定編集後：

```sh
sshd -t -f /var/sshd_config
```

接続を維持できるシリアルコンソールから、ポート競合に注意して新しい設定を反映させます。必要に応じて `sshd -f /var/sshd_config` で起動します。

Ubuntuから：

```bash
ssh root@192.168.1.100
```

## 8. minicomによるシリアルコンソール

Ubuntuで一般ユーザーを `dialout` に追加します。

```bash
sudo usermod -aG dialout "$USER"
```

再ログイン後：

```bash
groups
ls -l /dev/ttyUSB0
minicom -s
```

設定例：

| 項目 | 設定 |
|---|---|
| Serial Device | `/dev/ttyUSB0` |
| Baud rate | 115200 |
| Data bits | 8 |
| Parity | None |
| Stop bits | 1 |
| Hardware Flow Control | No |
| Software Flow Control | No |

`Save setup as dfl` で保存し、次回から `minicom` で起動します。

---

# Part 2：UbuntuおよびQNXでQt 6を動かす

## 9. Qtの開発構成

3つの役割を分離します。

| 環境 | 目的 |
|---|---|
| Ubuntu用Qt | Ubuntu上でGUIを実行 |
| Qt Host Tools | QNXクロスビルド時にホストで使う `moc` / `rcc` / `qsb` など |
| QNX用Qt | Raspberry Pi 5上で使うQtライブラリとQNX QPA Plugin |

Ubuntu用QtとQNX用Qtの成果物は、別ディレクトリで管理します。

## 10. UbuntuのQt開発環境

```bash
sudo apt update
sudo apt install -y \
    qt6-base-dev qt6-declarative-dev qt6-tools-dev qtcreator \
    qml6-module-qtquick qml6-module-qtquick-window \
    qml6-module-qtquick-controls \
    cmake ninja-build build-essential
qmake6 -v
```

Ubuntu 24.04標準のQtは6.4.2系列です。Qt 6.5以降のAPIを使う場合は、別途Qt 6.12を準備します。

### 10.1 `QtQuick.Window` エラー

```text
QQmlApplicationEngine failed to load component
module "QtQuick.Window" is not installed
```

対応するQMLランタイムを導入します。

```bash
sudo apt install qml6-module-qtquick-window
```

## 11. Qt 6.12のソース取得

```bash
cd ~/projects/Qt
git clone https://code.qt.io/qt/qt5.git qt-src
cd qt-src
git checkout v6.12.0
./init-repository --module-subset=qtbase,qtdeclarative,qtshadertools
```

| モジュール | 用途 |
|---|---|
| `qtbase` | Core、Gui、Widgets、QPA |
| `qtdeclarative` | QML、Qt Quick |
| `qtshadertools` | Shader Tools |

## 12. Qt Host Toolsのビルド

```bash
cd ~/projects/Qt
mkdir -p build-host
cd build-host
../qt-src/configure \
    -developer-build \
    -nomake tests \
    -nomake examples \
    -submodules qtbase,qtdeclarative,qtshadertools \
    -- -G Ninja
cmake --build . --target host_tools --parallel 4
```

生成されたホストツールを確認します。

```bash
find . -type f \
    \( -name moc -o -name rcc -o -name qsb -o -name qmlcachegen \)
```

## 13. QNX AArch64用CMake Toolchain

`~/projects/Qt/qnx-aarch64.cmake` を作成します。

```cmake
set(CMAKE_SYSTEM_NAME QNX)
set(CMAKE_SYSTEM_VERSION 800)
set(CMAKE_SYSTEM_PROCESSOR aarch64le)

set(arch gcc_ntoaarch64le)

set(CMAKE_C_COMPILER qcc)
set(CMAKE_C_COMPILER_TARGET ${arch})

set(CMAKE_CXX_COMPILER q++)
set(CMAKE_CXX_COMPILER_TARGET ${arch})

set(CMAKE_FIND_ROOT_PATH
    "$ENV{QNX_TARGET}"
    "$ENV{QNX_TARGET}/aarch64le"
)

set(CMAKE_SYSROOT "$ENV{QNX_TARGET}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
```

環境設定とコンパイラの確認：

```bash
source ~/qnx806/qnxsdp-env.sh
q++ -V
printf 'int main(){return 0;}\n' > /tmp/qnx-test.cpp
q++ -Vgcc_ntoaarch64le /tmp/qnx-test.cpp -o /tmp/qnx-test
file /tmp/qnx-test
```

## 14. QNX向けQt 6.12クロスビルド

```bash
cd ~/projects/Qt
mkdir -p build-target
cd build-target
../qt-src/configure \
    -release \
    -nomake tests \
    -nomake examples \
    -submodules qtbase,qtdeclarative,qtshadertools \
    -skip qtremoteobjects \
    -skip qtinterfaceframework \
    -qt-host-path "$HOME/projects/Qt/build-host" \
    -extprefix "$HOME/projects/Qt/qnx-install" \
    -prefix /data/qt \
    -- -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$HOME/projects/Qt/qnx-aarch64.cmake" \
    -DCMAKE_SYSTEM_VERSION=800
```

ここでの `-prefix /data/qt` は最終配置先を表す例です。すでに `-prefix /qt` で構築したQtでは、実際のprefixとターゲット配置先を合わせてください。

### 14.1 CMakeターゲット確認

`CMakeCache.txt` のgrepが空の場合でも、次でOS・アーキテクチャを確認できます。

```bash
grep -E \
  'CMAKE_SYSTEM_NAME|CMAKE_SYSTEM_PROCESSOR|CMAKE_SYSTEM_VERSION' \
  CMakeFiles/*/CMakeSystem.cmake
```

実際に確認した出力：

```cmake
set(CMAKE_SYSTEM_NAME "QNX")
set(CMAKE_SYSTEM_VERSION "800")
set(CMAKE_SYSTEM_PROCESSOR "aarch64le")
```

C++コンパイラも確認します。

```bash
grep -E 'CMAKE_CXX_COMPILER|CMAKE_CXX_COMPILER_TARGET' \
  CMakeFiles/*/CMakeCXXCompiler.cmake
```

### 14.2 ビルドとインストール

```bash
cmake --build . --parallel 4
cmake --install .
```

```bash
find ~/projects/Qt/qnx-install \
  \( -name 'libQt6Core.so*' -o -name 'libQt6Gui.so*' \
  -o -name 'libQt6Qml.so*' -o -name 'libQt6Quick.so*' \)
find ~/projects/Qt/qnx-install/plugins/platforms -type f
```

## 15. Qtのサードパーティ依存ライブラリ

Qtのconfigure構成や使用機能によっては、次のライブラリが必要になります。

| ライブラリ | 機能 |
|---|---|
| `libfontconfig` | フォント管理 |
| `libfreetype` | フォントレンダリング |
| `libiconv` | 文字コード変換 |
| `libicui18n` | ICU国際化 |
| `libicudata` | ICUデータ |
| `libicuuc` | ICU Unicode |
| `libpng16` | PNG画像 |
| `libxml2` | XML |
| `libsqlite3` | SQLite |
| `libssl` | TLS/SSL |
| `libcrypto` | 暗号化 |
| `libzstd` | 圧縮 |

QNX SDP内で検索：

```bash
for lib in fontconfig freetype iconv icui18n icudata icuuc \
           png16 xml2 sqlite3 ssl crypto zstd
do
    echo "=== $lib ==="
    find "$QNX_TARGET/aarch64le" -name "lib${lib}.so*" -print
done
```

アプリ・ライブラリの動的依存関係を確認：

```bash
readelf -d ~/projects/Qt/cluster/build-qnx/ev-cluster | grep NEEDED
readelf -d ~/projects/Qt/qnx-install/lib/libQt6Quick.so.6 | grep NEEDED
```

## 16. EV Digital Clusterアプリケーション

```text
~/projects/Qt/cluster/
├── main.cpp
├── Main.qml
├── Gauge.qml
└── CMakeLists.txt
```

### 16.1 main.cpp

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.loadFromModule("EvCluster", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
```

### 16.2 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.21)
project(EvCluster LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(ev-cluster main.cpp)
qt_add_qml_module(ev-cluster
    URI EvCluster
    VERSION 1.0
    QML_FILES Main.qml Gauge.qml
)
target_link_libraries(ev-cluster PRIVATE Qt6::Quick)
```

`Main.qml` は画面全体を構成し、`Gauge.qml` は左右のメーターに使い回します。主なQML要素は `Window`、`Canvas`、`Rectangle`、`Text`、`Timer`、`Repeater` です。QMLコードは先に作成した `Main.qml` と `Gauge.qml` を利用します。

## 17. UbuntuでのQt実行とXCBの修正

Ubuntu側のQt Hostで作ったアプリが以下のエラーになりました。

```text
qt.qpa.plugin: Could not find the Qt platform plugin "xcb" in ""
Available platform plugins are: minimal.
```

確認：

```bash
find ~/projects/Qt/build-host -name libqxcb.so
ldd ~/projects/Qt/cluster2/build-host/ev-cluster | grep Qt6
```

実際のライブラリ参照先には次がありました。

```text
/home/audrey/projects/Qt/build-host/qtbase/lib/libQt6Gui.so.6
/home/audrey/projects/Qt/build-host/qtbase/lib/libQt6Qml.so.6
/home/audrey/projects/Qt/build-host/qtbase/lib/libQt6Core.so.6
```

つまりQNX用Host Toolsとして用意したQtにはUbuntuでGUI表示するための `xcb` Platform Pluginがありませんでした。

### 17.1 XCB開発パッケージ

```bash
sudo apt install -y \
    libx11-xcb-dev libxcb1-dev libxcb-cursor-dev \
    libxcb-image0-dev libxcb-keysyms1-dev \
    libxcb-render-util0-dev libxcb-shape0-dev \
    libxcb-xfixes0-dev libxcb-randr0-dev \
    libxcb-sync-dev libxcb-xkb-dev \
    libxkbcommon-x11-dev libxcb-icccm4-dev
```

### 17.2 Qt Hostの再configure

```bash
cd ~/projects/Qt/build-host
../qt-src/configure \
    -developer-build \
    -xcb \
    -nomake tests \
    -nomake examples \
    -- -G Ninja
```

プラグインのビルド：

```bash
cmake --build . --target qxcb --parallel 4
```

上記ターゲットが存在しない場合：

```bash
ninja -t targets all | grep -i xcb
cmake --build . --parallel 4
```

存在確認：

```bash
find ~/projects/Qt/build-host -name libqxcb.so
```

必要に応じて実際の配置先に合わせて：

```bash
export QT_QPA_PLATFORM_PLUGIN_PATH="$HOME/projects/Qt/build-host/qtbase/plugins/platforms"
```

この修正後、Ubuntu上でアプリが正常動作したことを確認しました。

## 18. EV ClusterのQNX向けビルド

```bash
source ~/qnx806/qnxsdp-env.sh
export QT_QNX="$HOME/projects/Qt/qnx-install"
cd ~/projects/Qt/cluster

"$QT_QNX/bin/qt-cmake" -S . -B build-qnx -G Ninja
cmake --build build-qnx --parallel 4
file build-qnx/ev-cluster
```

QNX AArch64向け実行ファイルになっていることを確認します。

## 19. QtランタイムとアプリをQNXへ転送

書き込み可能な `/data` がマウントされていることを前提とします。

```bash
ssh root@192.168.1.100 'mkdir -p /data/qt /data/apps'
cd "$QT_QNX"
scp -r lib plugins qml root@192.168.1.100:/data/qt/
scp ~/projects/Qt/cluster/build-qnx/ev-cluster \
    root@192.168.1.100:/data/apps/
```

必要なQNX AArch64用の依存ライブラリは追加配置します。SONAMEとシンボリックリンクの整合を維持してください。

## 20. QNXでのQt実行

QNXコンソール上で：

```sh
export LD_LIBRARY_PATH=/data/qt/lib:/lib:/usr/lib:/lib/dll:/proc/boot:/usr/lib/graphics/drm-rpi5
export QT_PLUGIN_PATH=/data/qt/plugins
export QML_IMPORT_PATH=/data/qt/qml
export QT_DEBUG_PLUGINS=1
export QSG_INFO=1
pidin ar | grep screen
ls /dev/screen
/data/apps/ev-cluster
```

## 21. フォントの配置

QNX実行時に次のメッセージが出ました。

```text
QFontDatabase: Cannot find font directory /data/qt/lib/fonts.
Note that Qt no longer ships fonts.
```

Ubuntu側で：

```bash
sudo apt install fonts-dejavu-core
ls /usr/share/fonts/truetype/dejavu/
ssh root@192.168.1.100 'mkdir -p /data/qt/lib/fonts'
scp /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
    root@192.168.1.100:/data/qt/lib/fonts/
```

QNX側で：

```sh
export QT_QPA_FONTDIR=/data/qt/lib/fonts
/data/apps/ev-cluster
```

日本語の表示には日本語グリフを備えた別途フォントが必要です。

## 22. 起動用スクリプト

`/data/run-ev-cluster.sh` の例：

```sh
#!/bin/sh
export PATH=/data/qt/bin:/usr/bin:/bin:/sbin:/proc/boot
export LD_LIBRARY_PATH=/data/qt/lib:/lib:/usr/lib:/lib/dll:/proc/boot:/usr/lib/graphics/drm-rpi5
export QT_PLUGIN_PATH=/data/qt/plugins
export QML_IMPORT_PATH=/data/qt/qml
export QT_QPA_FONTDIR=/data/qt/lib/fonts
export QT_LOGGING_TO_CONSOLE=1
cd /data/apps
exec ./ev-cluster
```

```sh
chmod +x /data/run-ev-cluster.sh
/data/run-ev-cluster.sh
```

起動時にデータ領域のマウントとScreenの起動が完了してからスクリプトを実行します。

## 23. 公式ドキュメント

### QNX Graphics

- [Raspberry Pi 5 BSP User's Guide](https://www.qnx.com/developers/docs/BSP8.0/com.qnx.doc.bsp_raspberrypi.bcm2712.rpi5_8.0/topic/about.html)
- [Raspberry Pi Screen Board Support Release Notes](https://www.qnx.com/developers/docs/BSP8.0/com.qnx.doc.bsp.releasenotes/topic/rel_gfx.sdp80.PUA2025-010.bsp.broadcom.rpi5.bcm2712.html)
- [Getting Started with BSP Screen](https://www.qnx.com/developers/docs/BSP8.0/com.qnx.doc.bsp.referencenotes/topic/bsp_graphics.html)
- [QNX fdisk](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/f/fdisk.html)
- [QNX mkqnx6fs](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/m/mkqnx6fs.html)

### Qt 6 / QNX

- [Building Qt for QNX](https://doc.qt.io/qt-6/building-qt-for-qnx.html)
- [Qt for QNX Runtime Target Requirements](https://doc.qt.io/qt-6/qnx-target-requirements.html)
- [qt_add_qml_module](https://doc.qt.io/qt-6/qt-add-qml-module.html)
- [Qt Quick Canvas](https://doc.qt.io/qt-6/qml-qtquick-canvas.html)

---

UbuntuでQML HMIを開発し、Qt Host ToolsとQNX AArch64向けQtを使ってクロスビルドし、Raspberry Pi 5のQNX Screen上で実行する構成です。
