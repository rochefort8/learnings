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
