# Ubuntu 24.04 で Yocto Linux をビルドして QEMU で起動する

## 実行環境・結果

- ホスト OS：Ubuntu Linux 24.04
- 作業ディレクトリ：`~/projects/yocto/poky`
- Yocto：Scarthgap（5.0 系）を使用する手順
- ターゲット：`qemux86-64`
- イメージ：`core-image-minimal`
- ビルド時間：約30分（今回の実測。マシン性能・ネットワーク・キャッシュにより変わる）
- 結果：QEMU で起動できた

以下は Ubuntu マシン上で実行する。ビルドは通常ユーザーで行い、`bitbake` に `sudo` を付けない。

## 1. 必要なパッケージをインストール

```bash
sudo apt update
sudo apt install -y build-essential chrpath cpio debianutils diffstat \
  file gawk gcc git iputils-ping libacl1 liblz4-tool locales \
  python3 python3-git python3-jinja2 python3-pexpect python3-pip \
  python3-subunit socat texinfo unzip wget xz-utils zstd

sudo locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
```

参考：Yocto 5.0 系の公式手順では、空きディスク容量90 GB以上、メモリ8 GB以上を目安としている。

## 2. Poky を取得してビルド環境を設定

```bash
mkdir -p ~/projects/yocto
cd ~/projects/yocto
git clone -b scarthgap https://git.yoctoproject.org/poky
cd poky
source oe-init-build-env
```

最後のコマンドにより、作業ディレクトリは `poky/build` に移動する。

既存の環境を使う場合、再度 clone する必要はない。

## 3. ターゲットを設定

`build/conf/local.conf` に以下を設定する。既に設定済みなら追加は不要。

```conf
MACHINE = "qemux86-64"
```

初回にコマンドで追記する場合：

```bash
echo 'MACHINE = "qemux86-64"' >> conf/local.conf
```

## 4. 遭遇したエラーへの対処

### `.netrc` のアクセス権限

エラー：

```text
~/.netrc access too permissive: access permissions must restrict access to only the owner
```

所有者だけが読み書きできるように変更する。

```bash
chmod 600 ~/.netrc
ls -l ~/.netrc
```

先頭が `-rw-------` ならよい。`.netrc` には認証情報が含まれる場合があるため、中身を公開しない。

### AppArmor によるユーザー名前空間の制限

エラー：

```text
ERROR: User namespaces are not usable by BitBake, possibly due to AppArmor.
```

Ubuntu 24.04 の制限に対し、BitBake の実行パスにユーザー名前空間の利用を許可する。

ビルド環境を設定したターミナルで、パスを確認する。

```bash
bitbake_path="$(readlink -f "$(command -v bitbake)")"
echo "$bitbake_path"
```

`/home/audrey/projects/yocto/poky/bitbake/bin/bitbake` のような絶対パスが表示されることを確認してから、以下を実行する。

```bash
sudo tee /etc/apparmor.d/yocto-bitbake >/dev/null <<EOF
abi <abi/4.0>,
include <tunables/global>

profile yocto-bitbake "$bitbake_path" flags=(unconfined) {
    userns,
}
EOF

sudo apparmor_parser -r /etc/apparmor.d/yocto-bitbake
```

Poky の配置場所を変更した場合は、プロファイルのパスも更新する。

## 5. 最小構成の Linux をビルド

`poky/build` で実行する。

```bash
bitbake core-image-minimal
```

今回のビルド時間は約30分。エラー対処後も同じコマンドで再開でき、完了済みの処理は再利用される。

## 6. QEMU で起動

**今回、実際に起動できたコマンド：**

```bash
runqemu qemux86-64 nographic slirp
```

- `nographic`：GUI ウィンドウを使わず、ターミナルにコンソールを表示する。
- `slirp`：ユーザーモードのネットワークを使う。

以下のようにイメージ名を指定したコマンドでは、今回の環境でエラーになった。

```bash
runqemu qemux86-64 core-image-minimal nographic slirp
```

```text
runqemu - ERROR - IMAGE_LINK_NAME wasn't set to find corresponding .qemuboot.conf file
```

イメージ名 `core-image-minimal` を省いた起動コマンドで解消した。

## 7. ログインと確認

標準の開発用設定では、ユーザー名 `root`、パスワードなしでログインする。

ゲスト Linux 内で次を実行すると、OS とカーネル情報を確認できる。

```bash
cat /etc/os-release
uname -a
```

QEMU を終了するには、**Ctrl+A を押して離し、その後 X** を押す。

## 次回からの起動

新しいターミナルでは、最初にビルド環境を読み込む。

```bash
cd ~/projects/yocto/poky
source oe-init-build-env
runqemu qemux86-64 nographic slirp
```

イメージを変更していなければ、起動のたびにビルドする必要はない。

## 参考資料

- [TechLabo 参考記事](https://techlabo.rers-grp.com/article/26022514_1354.html)
- [Yocto 5.0 系 Quick Build](https://docs.yoctoproject.org/5.0.13/brief-yoctoprojectqs/index.html)
- [Yocto 5.0.14 のシステム要件・Ubuntu 24.04 対応](https://docs.yoctoproject.org/5.0.14/ref-manual/system-requirements.html)
- [Ubuntu 24.04：ユーザー名前空間の制限](https://documentation.ubuntu.com/release-notes/24.04/#unprivileged-user-namespace-restrictions)

※ Scarthgap は会話で案内した取得ブランチ。実際のチェックアウトは `git -C ~/projects/yocto/poky branch --show-current` で確認できる。
