# QNX 製品ラインアップ概要

## 1. はじめに

QNX の製品群は、単なるリアルタイム OS だけではなく、OS を中心として、仮想化、安全認証、コンテナ、車載向けプラットフォーム、音響、クラウド開発環境、BSP までを含む広いソフトウェアスタックとして構成されています。

全体像は以下のように整理できます。

```text
車載・産業向け完成プラットフォーム
 ├─ Alloy Kore
 ├─ QNX Cabin
 ├─ QNX Sound
 └─ QNX General Embedded Development Platform

クラウド・開発環境
 ├─ QNX Accelerate
 ├─ QNX Momentics IDE
 └─ QNX Toolkit for Microsoft VS Code

仮想化・コンテナ
 ├─ QNX Hypervisor
 ├─ QNX Hypervisor for Safety
 └─ QNX Containers

OS・基盤
 ├─ QNX SDP 8.0
 │    └─ QNX OS 8.0
 └─ QNX OS for Safety 8.0

ハードウェア対応
 ├─ BSP
 └─ デバイスドライバー
```

---

# 2. QNX Software Development Platform（SDP）

## 2.1 QNX SDP 8.0

QNX の基本となる開発製品です。

QNX SDP は OS 単体ではなく、QNX ベースの組み込みシステムを開発するために必要なソフトウェア一式を含んだ開発環境です。

主な構成要素は以下です。

- QNX OS 8.0
- コンパイラ
- リンカー
- デバッガ
- IDE
- コマンドライン開発ツール
- システム解析ツール
- プロファイラ
- ファイルシステム
- ネットワークスタック
- ライブラリ
- ヘッダーファイル
- BSP 開発環境

QNX OS 8.0 はマイクロカーネル方式のハードリアルタイム OS であり、Armv8、Armv9、x86-64 などを対象としています。

### SDP と OS の違い

| 名称 | 意味 |
|---|---|
| QNX OS 8.0 | ターゲット機器上で動作する OS 本体 |
| QNX SDP 8.0 | OS、コンパイラ、IDE、ライブラリなどを含む開発環境一式 |
| QNX Momentics | QNX の IDE・解析ツール群 |
| BSP | 特定 SoC / ボード上で QNX を起動するためのソフトウェア |

開発 PC にインストールするのは通常 QNX SDP であり、その中のツールを使用してターゲット向け QNX イメージを作成します。

参考:

- https://qnx.software/en/software/products-and-solutions/qnx-software-development-platform

---

# 3. QNX OS for Safety

QNX OS をベースに、機能安全規格に対応するための認証・成果物を追加した安全認証版 OS です。

主な用途は以下です。

- 自動車
- ADAS
- デジタルメーター
- 車両制御
- 産業機器
- ロボット
- 医療機器
- 鉄道
- 航空・防衛

代表的な安全規格として以下に対応します。

- ISO 26262 ASIL D
- IEC 61508 SIL 3
- IEC 62304 Class C

## 3.1 各規格の意味

| 規格 | 主な対象 | レベル |
|---|---|---|
| ISO 26262 | 自動車 | ASIL D |
| IEC 61508 | 産業機器 | SIL 3 |
| IEC 62304 | 医療機器ソフトウェア | Class C |

ASIL D は自動車分野で最も厳しい安全度水準です。

IEC 61508 SIL 3 は、高い安全性が必要な産業制御・安全システムを対象とします。

IEC 62304 Class C は、ソフトウェア故障によって死亡または重傷につながる可能性がある医療機器向けクラスです。

## 3.2 通常版との関係

```text
QNX SDP 8.0
   └─ QNX OS 8.0
         ↓
QNX OS for Safety 8.0
```

QNX OS for Safety では、安全認証済みバイナリだけでなく、Safety Manual や安全分析資料なども提供されます。

ただし、QNX OS for Safety を採用しただけで、製品全体が自動的に ASIL D になるわけではありません。

アプリケーション、ドライバー、ハードウェア、システム構成などを含めた安全設計と検証が別途必要です。

参考:

- https://blackberry.qnx.com/en/products/safety-certified/qnx-os-for-safety

---

# 4. QNX Hypervisor

QNX Hypervisor は、1 台の SoC 上で複数の OS を同時に実行するための仮想化製品です。

車載システムでは、例えば以下の構成が考えられます。

```text
QNX Hypervisor
 ├─ QNX
 │   ├─ メーター
 │   ├─ 車両制御
 │   └─ 安全関連処理
 │
 ├─ Android Automotive OS
 │   ├─ IVI
 │   ├─ ナビゲーション
 │   └─ アプリ
 │
 └─ Linux
     ├─ AI
     ├─ 画像処理
     └─ データ処理
```

CPU、メモリ、割り込み、デバイスなどをゲスト OS ごとに分離できます。

## 4.1 製品の種類

| 製品 | 用途 |
|---|---|
| QNX Hypervisor | 一般的な仮想化、OS 統合 |
| QNX Hypervisor for Safety | Mixed-Criticality、安全系と非安全系の統合 |

QNX Hypervisor for Safety は、安全系ドメインと Android や Linux などの非安全系ドメインを同一 SoC 上に配置する用途で重要です。

参考:

- https://blackberry.qnx.com/en/products/foundation-software/qnx-hypervisor

---

# 5. QNX Containers

QNX OS 上でアプリケーションを分離・配布するためのコンテナ技術です。

Linux の Docker と似た目的を持ちますが、QNX のリアルタイム性や組み込み用途を考慮した設計になっています。

主な用途は以下です。

- アプリケーション単位の分離
- ソフトウェア更新
- チーム・サプライヤー単位の責務分離
- ECU 内アプリケーションのデプロイ
- SDV における機能更新

## 5.1 Hypervisor との違い

| 項目 | QNX Hypervisor | QNX Containers |
|---|---|---|
| 分離単位 | OS | アプリケーション |
| 複数 OS | 可能 | 基本的に同一 QNX OS を共有 |
| Android / Linux | ゲスト OS として実行可能 | OS としてそのまま実行するものではない |
| オーバーヘッド | 比較的大きい | 比較的小さい |
| 主用途 | OS 統合 | アプリ分離・更新 |

参考:

- https://qnx.software/en/software/products-and-solutions/qnx-containers

---

# 6. QNX Cabin

QNX Cabin は、車載デジタルコックピット向けのリファレンスプラットフォームです。

完成した IVI 製品そのものではなく、自動車メーカーや Tier 1 がコックピットシステムを短期間で構築するための事前統合ソフトウェア基盤です。

構成例:

```text
QNX Cabin
 ├─ QNX OS / QNX OS for Safety
 ├─ QNX Hypervisor
 ├─ Android Automotive OS
 ├─ Linux
 ├─ デジタルメーター
 ├─ IVI
 ├─ カメラ
 ├─ オーディオ
 └─ VirtIO
```

安全性の高いメーターや警告表示を QNX で動作させながら、IVI を Android Automotive OS で動かすような構成を実現できます。

## 6.1 AAOS との関係

QNX Cabin は Android Automotive OS と競合する OS ではありません。

むしろ、

> QNX を安全・仮想化基盤として、その上または隣で Android Automotive OS を動作させるためのコックピット基盤

と考えると理解しやすくなります。

参考:

- https://qnx.software/en/software/products-and-solutions/qnx-cabin

---

# 7. Alloy Kore

Alloy Kore は QNX と Vector が共同で提供する SDV 向け車両基盤ソフトウェアプラットフォームです。

QNX の OS・仮想化技術と Vector の車載通信ミドルウェアを統合した基盤として位置づけられます。

```text
車両アプリケーション
────────────────────
Vector 車載ミドルウェア
通信・データ処理・サービス
────────────────────
QNX OS / Hypervisor
────────────────────
SoC / ECU
```

主な目的は以下です。

- ECU 基盤ソフトウェアの共通化
- SoC 間でのソフトウェア再利用
- HPC への展開
- ゾーン ECU への展開
- SDV アーキテクチャ対応
- 安全認証対応
- 開発期間短縮

## 7.1 AAOS との違い

| 項目 | Alloy Kore | Android Automotive OS |
|---|---|---|
| 主目的 | 車両基盤 | IVI・アプリ・UX |
| 主な層 | OS、仮想化、通信ミドルウェア | Android Framework、System UI、アプリ |
| 主対象 | HPC、ゾーン ECU、車両制御 | IVI、デジタルコックピット |
| Google サービス | 直接の対象ではない | GAS 搭載構成あり |

Alloy Kore は AAOS の代替というより、車両全体の下位基盤として使われるソフトウェアです。

参考:

- https://qnx.software/en/software/products-and-solutions/foundational-vehicle-software-platform

---

# 8. QNX Sound

QNX Sound は、車両内の音響機能をソフトウェア化・統合するためのプラットフォームです。

対象となる機能は以下です。

- メディア再生
- ナビゲーション音声
- ハンズフリー通話
- 音声認識
- マルチゾーンオーディオ
- 車内通話
- 警告音
- チャイム
- EV 走行音
- エンジンサウンド生成
- Active Noise Control
- Road Noise Cancellation

従来は複数のアンプや専用 ECU に分散していた音響処理を、中央コンピュータへ集約することを狙います。

## 8.1 LiveAMP

QNX Sound には LiveAMP という音響信号処理設計・調整環境があります。

GUI 上で信号処理ブロックを接続し、車両オーディオ処理を構築・調整できます。

参考:

- https://blackberry.qnx.com/en/products/automotive/qnx-sound

---

# 9. QNX General Embedded Development Platform（GEDP）

QNX General Embedded Development Platform は、車載以外も含めた汎用組み込みシステム向けプラットフォームです。

主な対象分野:

- ロボット
- 産業オートメーション
- 医療機器
- エネルギー
- 航空・防衛
- 自律システム
- 高信頼組み込み機器

GEDP は単一の OS 製品ではなく、複数の QNX 製品・ミドルウェアを組み合わせたモジュール型プラットフォームです。

代表的な構成要素:

- QNX OS
- QNX OS for Safety
- QNX Hypervisor
- QNX Containers
- BSP
- デバイスドライバー
- ミドルウェア
- クラウド開発環境
- サンプル・リファレンス

DDS、TSN、PROFINET、EtherCAT、CANopen、Zenoh、Modbus などの産業向け技術との統合も想定されています。

参考:

- https://qnx.software/en/software/products-and-solutions/qnx-general-embedded-development-platform

---

# 10. QNX Accelerate

QNX Accelerate は、QNX 開発環境やターゲット環境をクラウド上で利用するための仕組みです。

主な目的は以下です。

- 実機 SoC 到着前の先行開発
- 仮想ターゲットを利用した開発
- CI/CD
- 自動テスト
- 並列テスト
- 開発環境の共有
- ハードウェア依存の軽減

概念的には以下のようになります。

```text
Developer PC
     ↓
Cloud
 ├─ QNX Target
 ├─ Hypervisor Target
 ├─ Test Environment
 └─ CI/CD
```

参考:

- https://qnx.software/en/software/products-and-solutions/qnx-accelerate

---

# 11. BSP とデバイスドライバー

## 11.1 BSP（Board Support Package）

BSP は、QNX を特定の SoC や評価ボードで起動するためのソフトウェアパッケージです。

一般的には以下を含みます。

- Startup コード
- IPL
- ブートローダー関連設定
- メモリマップ
- 割り込みコントローラー設定
- タイマー
- UART
- Ethernet
- SD / eMMC
- USB
- OS イメージ生成設定

QNX は複数の SoC ベンダー向け BSP を提供しています。

例:

- Qualcomm
- NXP
- Renesas
- Texas Instruments
- Intel
- AMD

ターゲットボード上で QNX を起動するには、

```text
QNX SDP
   +
対応 BSP
   +
必要なデバイスドライバー
   =
ターゲット用 QNX OS イメージ
```

という構成になります。

参考:

- https://qnx.software/en/developers/get-started/board-support-packages

---

# 12. 開発ツール

## 12.1 QNX Momentics IDE

QNX の統合開発環境です。

主な機能:

- C / C++ 開発
- クロスコンパイル
- リモートデバッグ
- プロセス・スレッド確認
- CPU 負荷解析
- メモリ解析
- システムプロファイリング

## 12.2 QNX Toolkit for Microsoft VS Code

Microsoft Visual Studio Code から QNX アプリケーション開発を行うためのツールです。

近年は、従来の Momentics IDE に加えて VS Code を利用する開発フローも提供されています。

---

# 13. 用途別の製品選択

| やりたいこと | 主に使用する QNX 製品 |
|---|---|
| QNX アプリを開発する | QNX SDP |
| QNX OS を評価ボードで起動する | QNX SDP + BSP |
| 安全認証製品を開発する | QNX OS for Safety |
| QNX と Android / Linux を同居させる | QNX Hypervisor |
| 安全系と非安全系を統合する | QNX Hypervisor for Safety |
| アプリを分離・更新する | QNX Containers |
| デジタルコックピットを構築する | QNX Cabin |
| SDV 車両基盤を構築する | Alloy Kore |
| 車両音響機能を統合する | QNX Sound |
| ロボット・産業・医療向けシステムを構築する | QNX GEDP |
| クラウド上で QNX 開発を行う | QNX Accelerate |

---

# 14. QNX 製品群の階層

QNX の製品を大きく 3 層に分けると理解しやすくなります。

## 14.1 基礎製品

```text
QNX SDP
 ├─ QNX OS
 ├─ QNX OS for Safety
 ├─ BSP
 └─ Drivers
```

## 14.2 システム統合技術

```text
QNX Hypervisor
QNX Hypervisor for Safety
QNX Containers
QNX Accelerate
```

## 14.3 用途別プラットフォーム

```text
QNX Cabin
Alloy Kore
QNX Sound
QNX General Embedded Development Platform
```

---

# 15. 車載 SDV における位置づけ

QNX 製品群を車載 SDV 全体の構成として見ると、以下のように整理できます。

```text
┌───────────────────────────────────┐
│ Android / Native Applications     │
│ IVI / Navigation / Media / Apps   │
├───────────────────────────────────┤
│ Android Automotive OS / Linux     │
├───────────────────────────────────┤
│ Alloy Kore / QNX Cabin /          │
│ Vehicle Middleware                │
├───────────────────────────────────┤
│ QNX Containers                    │
├───────────────────────────────────┤
│ QNX Hypervisor                    │
├───────────────────────────────────┤
│ QNX OS / QNX OS for Safety        │
├───────────────────────────────────┤
│ BSP / Device Drivers              │
├───────────────────────────────────┤
│ SoC / ECU Hardware                │
└───────────────────────────────────┘
```

QNX は特に、

- リアルタイム性
- 機能安全
- OS 分離
- Mixed-Criticality
- SoC 統合
- 車両基盤ソフトウェア

の領域を強みとしています。

一方、Android Automotive OS は主として IVI、アプリケーション、ユーザーエクスペリエンスを担当します。

そのため将来の車載 HPC では、

```text
QNX
  = Safety / Real-time / Hypervisor

AAOS
  = IVI / Applications / UX

Linux
  = AI / Cloud / Data Processing
```

という役割分担が代表的な構成の一つになります。

---

# 16. まとめ

QNX の製品ラインアップは、単一の RTOS 製品ではなく、以下をカバーする統合ソフトウェアプラットフォームです。

- リアルタイム OS
- 機能安全 OS
- Hypervisor
- Containers
- BSP
- 開発ツール
- クラウド開発
- 車載コックピット
- SDV 車両基盤
- 車載音響
- ロボット・産業・医療機器向け基盤

最も基本となるのは **QNX SDP + QNX OS** です。

その上に、

```text
Safety
Virtualization
Containers
Vehicle Middleware
Cabin
Sound
Cloud Development
```

といった機能を積み重ねることで、車載 HPC や SDV、産業機器、ロボットなどの大規模な組み込みシステムを構築できるようになっています。
