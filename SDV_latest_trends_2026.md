# SDV 最新動向（2026年8月時点）

2026年時点で見ると、SDV（Software-Defined Vehicle）は「構想段階」からかなり明確に**実装・量産段階**へ移っています。

特に大きな変化は、以下です。

- **Central / Zonal Architecture**
- **Software Platform の共通化**
- **Cloud-native 開発**
- **OTA / CI/CD**
- **AI-Defined Vehicle（AIDV）への拡張**

---

## 1. ECU統合 → Zonal + Central Compute

従来の車載アーキテクチャは、

```text
機能
 ↓
専用ECU
 ↓
CAN
```

という構成が一般的でした。

現在は、より集約された

```text
Sensor / Actuator
      ↓
Zone Controller
      ↓
Automotive Ethernet
      ↓
Central HPC
```

という方向へ移っています。

イメージとしては以下です。

```text
┌───────────────────────┐
│ Central Compute / HPC │
│ ADAS │ Body │ IVI │ Apps │
└──────────┬────────────┘
           │
    Automotive Ethernet
      ┌────┼────┐
      │    │    │
    Zone  Zone  Zone
     ECU   ECU   ECU
      │     │     │
   Sensor Actuator Sensor
```

この変化の目的は単なる配線削減ではありません。

重要なのは、

- ECU数の削減
- ハードウェア抽象化
- ソフトウェアの再利用
- OTAによる機能更新
- Central Compute上での機能統合

です。

---

## 2. SOA / Middleware がSDVの中心になる

Central Compute化が進むと、アプリケーションが

> どのECUにセンサーが接続されているか

を直接意識しない設計が重要になります。

そこで使われるのが、

**Service-Oriented Architecture（SOA）**

です。

```text
Application
    ↓
Service API
    ↓
Middleware
    ↓
SOME/IP / DDS / Zenoh
    ↓
Automotive Ethernet
    ↓
Zone Controller
```

特に重要な要素は、

- SOME/IP
- DDS
- Zenoh
- Vehicle Service
- Hardware Abstraction Layer
- Service Discovery

です。

SDVでは、通信プロトコルそのものよりも、

> 車両機能を「Service」として抽象化する

という考え方が非常に重要になります。

---

## 3. AUTOSARが「仕様」から「コード」へ

2026年の大きな変化の1つが、

**AUTOSAR CAPI（Common Adaptive Platform Implementation）**

です。

従来のAUTOSAR Adaptive Platformは主に、

```text
Specification
      ↓
Vendor Implementation
```

という形でした。

つまりAUTOSARは、

> 「このように実装してください」

という仕様を定義する組織でした。

一方でCAPIでは、

```text
AUTOSAR Adaptive
      ↓
CAPI
      ↓
Common Implementation
      ↓
Executable Software
```

という方向へ進んでいます。

これはSDVにとって非常に重要です。

### AUTOSARの位置づけ

```text
AUTOSAR Classic
    ↓
Traditional ECU

AUTOSAR Adaptive
    ↓
HPC / POSIX OS

CAPI
    ↓
Common Adaptive Platform Implementation
```

今後は、

**AUTOSAR Adaptive + CAPI + POSIX OS**

という組み合わせがCentral Computeで重要になる可能性があります。

---

## 4. QNX / Linux / Android の役割分担

SDVでは、

> 車載OSを1種類に統一する

というより、

**複数OSを用途ごとに使い分ける**

方向が現実的です。

代表的な構成は以下です。

```text
┌────────────────────────┐
│ Android Automotive     │
│ IVI / Apps / UI        │
├────────────────────────┤
│ Linux                  │
│ Services / AI / Cloud  │
├────────────────────────┤
│ QNX / Safety RTOS      │
│ Safety / Real-time     │
├────────────────────────┤
│ Hypervisor             │
├────────────────────────┤
│ SoC                    │
└────────────────────────┘
```

### Android Automotive

主な役割：

- IVI
- HMI
- Navigation
- Media
- App Platform

### Linux

主な役割：

- Vehicle Service
- AI
- Cloud連携
- Gateway
- Middleware

### QNX

主な役割：

- Safety-critical処理
- Real-time処理
- Instrument Cluster
- ADAS関連
- Hypervisor

このような構成を、

**Mixed Criticality Architecture**

と呼びます。

---

## 5. QNX Hypervisor / Containers

SDVでは、1つのSoC上に複数OSを動かす構成が増えています。

例えば、

```text
                SoC
                 │
          QNX Hypervisor
        ┌────────┼─────────┐
        │        │         │
       QNX      Linux     Android
      Safety   Service     IVI
```

という構成です。

さらにQNXでは、

**OCI準拠コンテナ**

の活用も進んでいます。

これにより、

```text
Cloud Container
      ↓
Vehicle Container
```

というCloud-native型の開発モデルが実現しやすくなります。

---

## 6. Android Automotive がIVIの外へ

従来Android Automotive OS（AAOS）は、

> Infotainment OS

という位置づけが中心でした。

しかし現在は、

**SDV Platformの一部**

としてVehicle Domainへ広がる方向が見えています。

イメージすると、

```text
AAOS Apps
   ↓
Vehicle Service Layer
   ↓
Vehicle Middleware
   ↓
QNX / Linux / AUTOSAR
   ↓
Vehicle Hardware
```

という構成です。

今後重要になるのは、

- Vehicle HAL
- Vehicle Service
- VHAL
- Vehicle API
- Service Oriented Vehicle Architecture

です。

---

## 7. Cloud-native / Virtual ECU / Shift-left

従来の車載開発では、

```text
ECU完成
 ↓
Software開発
 ↓
実機評価
```

という流れが多くありました。

SDVではこれでは開発速度が追いつきません。

そこで、

**Virtual ECU**

が重要になります。

```text
Git
 ↓
CI/CD
 ↓
Container
 ↓
Virtual ECU
 ↓
SIL
 ↓
HIL
 ↓
Vehicle
```

という開発モデルです。

### Shift-left

実車評価より前に、

- Unit Test
- SIL
- Virtual ECU
- Cloud Simulation

で問題を検出します。

これを、

**Shift-left Development**

と呼びます。

---

## 8. OTAがSDVの前提になる

Software-Defined Vehicleでは、

車両販売後もソフトウェアを更新します。

```text
Cloud
  ↓
OTA Server
  ↓
Vehicle Gateway
  ↓
Central Computer
  ↓
ECU / Zone Controller
```

OTA対象は、

- Infotainment
- ADAS
- Battery Management
- Vehicle Control
- Diagnostics
- Security Fix

などへ拡大しています。

そのため、

**Cyber Security**

も非常に重要になります。

---

## 9. SDV → AIDV（AI-Defined Vehicle）

最近では、

**AIDV = AI-Defined Vehicle**

という言葉も使われるようになっています。

AIは単なる音声アシスタントではありません。

利用領域は、

- ADAS
- Driver Monitoring
- Sensor Fusion
- Predictive Maintenance
- Battery Management
- Energy Management
- Diagnostics
- Personalization

などです。

将来的には、

```text
SDV
 ↓
Data Driven Vehicle
 ↓
AI Defined Vehicle
```

という流れが進む可能性があります。

---

## 10. 2026年のSDV全体像

SDVを一枚で表現すると、以下のようになります。

```text
                       Cloud
              ┌──────────────────┐
              │ CI/CD            │
              │ Digital Twin     │
              │ OTA              │
              │ Fleet Data       │
              │ AI / DevOps      │
              └────────┬─────────┘
                       │
                 Vehicle Cloud API
                       │
          ┌────────────▼────────────┐
          │    Central Compute HPC   │
          │                          │
          │ ADAS │ Body │ IVI │ Apps│
          │      Service Layer       │
          │ AUTOSAR AP / Middleware  │
          ├──────────────────────────┤
          │ QNX │ Linux │ Android    │
          │ Hypervisor / Containers  │
          └────────────┬─────────────┘
                       │
                Automotive Ethernet
             ┌─────────┼─────────┐
             │         │         │
             ▼         ▼         ▼
          Zone ECU  Zone ECU  Zone ECU
             │         │         │
          Sensors   Actuators   Sensors
```

---

# SDVを理解するための重要技術

2026年時点で特に追っておきたい技術は以下です。

1. **Zonal Architecture**
2. **Central Compute / HPC**
3. **AUTOSAR Adaptive**
4. **AUTOSAR CAPI**
5. **QNX Hypervisor**
6. **QNX Containers**
7. **Android Automotive**
8. **SOME/IP / DDS / Zenoh**
9. **Virtual ECU / Cloud-native Development**
10. **AI-Defined Vehicle**

---

# SDVとは何か

重要なのは、

**SDV = Android Automotive**

ではないということです。

SDVは、

```text
SDV
 =
E/E Architecture
 +
Vehicle OS
 +
Middleware
 +
Cloud
 +
OTA
 +
DevOps
 +
Cyber Security
 +
AI
```

という総合的なアーキテクチャです。

---

# 2026年のSDVを一言で表すと

これまでのSDVは、

> 「Software Defined Vehicleとは何か」

を議論する段階でした。

現在は、

> **「SDVを量産可能なSoftware Platformとしてどう実装するか」**

という段階へ移っています。

特に重要なのは、

- Central / Zonal Architecture
- AUTOSAR Adaptive / CAPI
- QNX / Linux / Androidの共存
- SOA / Middleware
- Virtual ECU
- Cloud-native
- OTA
- AI

です。

このあたりを理解すると、現在のSDVの全体像がかなり見えやすくなります。

---

# SDV化に成功した自動車ベンダー

2026年時点では、SDV化に「かなり成功している」と評価しやすいベンダーと、まだ移行途上のベンダーが分かれてきています。

代表例は、

- Tesla
- Rivian
- Mercedes-Benz
- BMW
- NIO / XPeng などの中国系EVメーカー

です。

一方でVolkswagenは、非常に重要な「苦戦と再構築」の事例です。

---

## ベンダー別のSDV成熟度

| ベンダー | SDV化の成熟度 | 特徴 |
|---|---:|---|
| Tesla | ★★★★★ | Central Compute、OTA、垂直統合 |
| Rivian | ★★★★★ | Zonal Architecture、自社Software Stack |
| Mercedes-Benz | ★★★★☆ | MB.OS、中央コンピュータ化 |
| BMW | ★★★★☆ | Neue Klasse、4 Superbrains + Zonal |
| NIO / XPeng | ★★★★☆ | OTA、中央Compute、短いSW開発サイクル |
| Volkswagen | ★★☆☆☆ → ★★★☆☆ | CARIADで苦戦後、Rivian型へ再構築 |

---

## 1. Tesla：最も明確な成功例

TeslaはSDVの先駆者といえます。

特徴は、

```text
Vehicle Hardware
       ↓
Central Computing
       ↓
Tesla Software Platform
       ↓
Cloud
       ↓
OTA
```

という構造をかなり早い段階から成立させたことです。

重要なのはOTAだけではありません。

Teslaは、

- Vehicle Hardware
- E/E Architecture
- Software
- Cloud
- OTA

を強く垂直統合しています。

従来型OEMでは、

```text
ECU Supplier
OS Vendor
Middleware Vendor
Cloud Vendor
OEM
```

と複数の企業が関わりますが、Teslaはそれらの多くを自社主導で統合しています。

これがSDV化で非常に強かった理由の1つです。

---

## 2. Rivian：Zonal Architectureの代表例

Rivianは、SDVアーキテクチャを学ぶうえで非常に重要なベンダーです。

Rivianの車両では、

- Zonal Network Architecture
- 自社Software Stack
- Cloud連携
- OTA
- 車両制御
- ADAS

を統合しています。

概念的には、

```text
       Central Compute
       /           \
   Zone ECU       Zone ECU
      |              |
   Sensors        Actuators
```

という構成です。

特に象徴的なのが、

> VolkswagenがRivianのArchitecture / Software Stackを取り込む方向へ動いた

ことです。

大手OEMが新興EVメーカーのSDVアーキテクチャを導入するという点で、非常に重要な事例です。

---

## 3. Mercedes-Benz：MB.OSによるSDV化

Mercedes-Benzは、

**MB.OS**

を中心にSDV化を進めています。

構造としては、

```text
Applications
     ↓
MB.OS
     ↓
Central Compute
     ↓
Vehicle Hardware
```

という方向です。

Mercedesの特徴は、すべてを自社開発するのではなく、

- NVIDIA
- Google
- Microsoft
- Qualcomm

などと連携しながら、

**Vehicle ArchitectureとSoftware Platformの主導権をOEM側に残す**

方針を取っていることです。

Teslaの完全垂直統合とは異なる、既存OEM型のSDVアプローチです。

---

## 4. BMW：Neue Klasseで本格SDVへ

BMWはNeue KlasseでSDV化を大きく進めています。

特徴的なのが、

```text
4 Superbrains
+
4 Zones
```

という考え方です。

High Performance Computerが主に、

- Infotainment
- Automated Driving
- Driving Dynamics
- Body / Comfort

を担当します。

Zonal Architectureと組み合わせることで、

- ECU統合
- 配線削減
- Hardware / Software開発の分離
- Software Update
- 世代をまたぐSoftware再利用

を実現しやすくしています。

概念的には、

```text
           Cloud
             |
       4 Superbrains
      /   /   \   \
    Zone Zone Zone Zone
```

という構成です。

BMWは、

> SDVを単一モデルだけでなく、将来の車種全体へ展開する

方向に進んでいます。

---

## 5. Volkswagen：失敗から学ぶSDV

Volkswagenは「成功例」というより、

**SDV化の難しさを示す非常に重要な事例**

です。

当初はCARIADを中心に、ソフトウェアの大規模な内製化を進めました。

しかしVW Groupは、

```text
VW Group
 ├ VW
 ├ Audi
 ├ Porsche
 ├ Skoda
 └ ...
```

と多数のブランドを抱えています。

そのため、

- 異なるE/E Architecture
- 異なるECU
- 異なるSoftware Platform
- 異なるSupplier
- 異なる開発組織

を統合する必要があり、Software Platform統合が非常に複雑になりました。

その後、

```text
VW
 ↓
Rivian + VW
 ↓
Zonal Architecture
 ↓
Central Compute
 ↓
Common Software Platform
```

という方向へ再構築しています。

この事例は、

> SDV化は単なるSoftware開発ではなく、OrganizationとArchitectureの変革である

ことをよく示しています。

---

# なぜTesla / RivianはSDV化しやすかったのか

TeslaやRivianのような新興ベンダーは、

```text
Software Architecture
        ↓
E/E Architecture
        ↓
Vehicle
```

という順番で設計できます。

一方、従来OEMは、

```text
既存ECU
既存Supplier
既存CAN
既存Platform
既存Organization
       ↓
SDV化
```

という移行になります。

つまり最大の違いは、

**Legacy**

です。

従来OEMでは、技術だけでなく、

- 組織
- 開発プロセス
- Supplier構造
- 製品世代
- 品質保証
- Safety Process

まで変える必要があります。

---

# SDVはOrganization Architectureでもある

SDVは単なる車載Software技術ではありません。

組織構造もSoftware Architectureに大きく影響します。

これは、

**Conway's Law**

とも密接に関係しています。

```text
Organization Structure
        ↓
Communication Structure
        ↓
Software Architecture
```

つまり、

> 分散した組織からは分散したSoftware Architectureが生まれやすい

ということです。

SDV化では、Central Compute化だけでなく、

**Software組織そのもののCentralization / Platform化**

も必要になります。

---

# SDVベンダーを世代で見る

SDVの進化をベンダー別に分類すると、次のように整理できます。

```text
第1世代
Tesla
  ↓
最初からSoftware Companyとして車を設計

第2世代
Rivian / NIO / XPeng
  ↓
Zonal + OTA + Cloud-native前提

第3世代
Mercedes-Benz / BMW
  ↓
既存OEMが本格的SDVへ移行

第4世代
Volkswagen / Toyota / GMなど
  ↓
巨大なLegacyを抱えながら移行
```

---

# SDV成功例を見るときのポイント

SDV化の成功を評価するときは、単にOTAができるかを見るだけでは不十分です。

重要なのは、

1. **Central Compute化**
2. **Zonal Architecture**
3. **Hardware / Software Separation**
4. **Service-Oriented Architecture**
5. **OTA**
6. **Cloud連携**
7. **Software Platform共通化**
8. **CI/CD**
9. **Virtual ECU / Simulation**
10. **Software組織の統合**

です。

その意味では、

- Tesla：SDV完成形を見る
- Rivian：Zonal Architectureを見る
- BMW：既存OEMのSDV移行を見る
- Mercedes-Benz：OEM主導Platformを見る
- Volkswagen：SDV移行の難しさを見る

という見方をすると、非常に理解しやすくなります。

---

# まとめ

2026年時点でSDV化に最も成功している代表的な企業は、

```text
Tesla
Rivian
Mercedes-Benz
BMW
```

と考えられます。

ただしSDVに「唯一の正解」はありません。

Teslaのような垂直統合型もあれば、

Mercedes-BenzやBMWのように、

```text
OEM
+
OS Vendor
+
SoC Vendor
+
Cloud Vendor
+
Middleware Vendor
```

を組み合わせながらSoftware Platformを構築する方法もあります。

今後の自動車産業では、

> 「車を作る会社」

から、

> **「車両Software Platformを持つ会社」**

へ進化できるかどうかが、SDV時代の競争力を大きく左右すると考えられます。

