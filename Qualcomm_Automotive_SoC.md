# Qualcomm車載SoC 学習メモ

## 1. Qualcomm車載SoCは3系統で考える

Qualcommの車載向けチップセットは、まず以下の3系統に分けて理解すると分かりやすい。

```text
Qualcomm Automotive
│
├── Cockpit / IVI
│
├── ADAS / Autonomous Driving
│
└── Connectivity / TCU / V2X
```

すべての型番を覚える必要はなく、各系統の代表SoCと役割を理解する方が重要。

---

# 2. 勉強しておきたい代表的なSoC

| 優先度   | SoC     | 主用途                | 主な学習ポイント                              |
| ----- | ------- | ------------------ | ------------------------------------- |
| ★★★★★ | SA8295P | Cockpit / IVI      | AAOS、QNX、Hypervisor、GPU、Display、Audio |
| ★★★★★ | SA8775P | Cockpit + ADAS     | ADAS、AI、Safety、Mixed Criticality      |
| ★★★★☆ | SA8255P | Cockpit            | SA8295P以前のCockpit世代                   |
| ★★★★☆ | SA8650P | Snapdragon Ride    | ADAS、自動運転、AI推論                        |
| ★★★☆☆ | SA7255P | Entry/Mid Cockpit  | Cockpit製品のスケーラビリティ                    |
| ★★★★☆ | SA52xM  | TCU / Connectivity | 5G、GNSS、C-V2X、Security                |
| ★★★☆☆ | SA8155P | Cockpit            | Qualcomm車載Cockpitの世代変遷理解              |

---

# 3. Cockpit系の流れ

大まかな世代感としては、

```text
SA8155P
   ↓
SA8255P
   ↓
SA8295P
   ↓
Snapdragon Cockpit / Ride Flex / Elite
```

という流れで捉えると理解しやすい。

SA8295Pあたりから、

* Android Automotive
* QNX
* Hypervisor
* 複数Display
* GPU
* AI
* Camera

などを1 SoCへ集約する考え方がかなり明確になる。

---

# 4. Connectivity系：SA52xM

SA52xMは、SA8295PのようなCockpit SoCとは役割が異なる。

主に、

* 4G / 5G
* C-V2X
* GNSS
* V2V
* V2I
* Security
* Crypto
* TEE

などを担当する。

イメージとしては、

```text
              Cloud
                │
             4G / 5G
                │
        +----------------+
        |    SA52xM      |
        |   TCU / NAD    |
        |                |
        | 5G             |
        | GNSS           |
        | C-V2X          |
        | Security       |
        +----------------+
                │
       Automotive Ethernet
                │
             Cockpit
```

Cockpit SoCとSA52xMは競合するものではなく、車の中で別の役割を担当する。

---

# 5. SA8295Pを題材にSoCを理解する

SA8295Pのような車載SoCでは、CPUだけを見るのではなく、

```text
CPU
GPU
DSP / NPU
ISP
Display
Audio
Security
Ethernet
PCIe
USB
```

などのブロックを一体として理解することが重要。

概念的には以下のようになる。

```text
                 SA8295P
┌──────────────────────────────────┐
│                                  │
│   CPU       GPU       DSP / AI   │
│  Kryo      Adreno      Hexagon   │
│    │          │           │       │
│    └──────────┼───────────┘       │
│               │                  │
│          Memory / NoC            │
│               │                  │
│  ┌────────────┼──────────────┐   │
│  │            │              │   │
│ ISP        Display        Audio   │
│ Camera     Controller      DSP    │
│                                  │
│ Security / Crypto / Secure Boot  │
│                                  │
│ Ethernet / PCIe / USB / SPI ...  │
└──────────────────────────────────┘
```

---

# 6. CPU

CPUは一般的なソフトウェアを実行する。

例えば、

```text
Android Service
Native daemon
SOME/IP Service
QNX process
Linux process
Java / Kotlin
C / C++
```

など。

AAOSでは、

```text
AAOS
 └─ Android Service
      └─ Native Service
           └─ SOME/IP
                └─ ECU
```

のような処理がCPU上で動く。

ただしQualcomm SoCでは、

> CPUだけですべて処理する

のではなく、

> CPU / GPU / DSP / NPU / ISPに適切に処理を分散する

という **Heterogeneous Computing** が重要。

---

# 7. GPU

QualcommではAdreno GPUが使われる。

主な用途：

```text
AAOS UI
Navigation
3D Map
Instrument Cluster
Animation
Rear Seat Display
```

典型的には、

```text
Android
   ↓
SurfaceFlinger
   ↓
OpenGL ES / Vulkan
   ↓
Adreno GPU
   ↓
Display Controller
   ↓
LCD
```

となる。

車載Cockpitでは1つのSoCから、

```text
Center Display
Instrument Cluster
HUD
Passenger Display
Rear Display
```

など複数画面を駆動することがある。

---

# 8. Hexagon DSP / AI Engine

Qualcommを理解する上で重要なのがHexagon。

概念としては、

```text
              AI workload
                   │
          ┌────────┴────────┐
          │                 │
         CPU              GPU
          │                 │
          └───── Hexagon ───┘
                    │
                 DSP / NPU
```

主な用途：

* Voice Recognition
* Noise Cancellation
* Object Recognition
* Driver Monitoring
* Cabin Monitoring
* Natural Language Processing
* Camera Processing

考え方としては、

```text
CPU
→ 汎用処理

GPU
→ 並列グラフィックス / Compute

DSP / NPU
→ AI / Signal Processing
```

となる。

---

# 9. ISP

ISPは、

**Image Signal Processor**

の略。

Camera Sensorから入った画像を処理する。

```text
Camera Sensor
     │
     ↓
   MIPI CSI
     │
     ↓
 Spectra ISP
     │
     ├─ Exposure
     ├─ HDR
     ├─ Noise Reduction
     ├─ Color Correction
     │
     ↓
Camera Framework
     │
     ├── Android
     ├── Surround View
     └── AI Processing
```

Cockpitでも、

* Rear View Camera
* Surround View
* Driver Monitoring
* Cabin Monitoring

などで使用する。

ADASではさらに重要になる。

---

# 10. QNX Hypervisor

SA8295Pを理解する上で非常に重要。

車載では、

```text
Spotify
Netflix
Navigation
```

と、

```text
Speedometer
Warning
Vehicle Status
Safety-related Function
```

を同じ信頼レベルで扱うことはできない。

そこでHypervisorによってOSを分離する。

```text
                 Hardware
                    │
             QNX Hypervisor
          ┌─────────┴─────────┐
          │                   │
       VM #1                VM #2
        QNX                 Android
          │                   │
      Cluster               AAOS
      Vehicle                Apps
      Services
```

これにより、

* Memory Isolation
* Device Isolation
* Fault Isolation
* Security Isolation

などを実現する。

---

# 11. QNX Hypervisorと現在の学習の関係

QNX Hypervisor上で、

```text
QNX Host
  ↓
qvm
  ↓
Guest OS
```

を起動する実験は、そのまま実車のDomain Consolidationを理解する基礎になる。

特に、

* VM
* Guest
* Virtual Device
* Memory Mapping
* Interrupt
* Device Assignment
* VirtIO

は重要。

---

# 12. Device Ownership

Hypervisor環境では、

```text
GPU
Ethernet
Audio
Display
Camera
CAN
PCIe
```

を誰が所有するかが重要になる。

例えば、

```text
                    SA8295P
                       │
                  Hypervisor
           ┌───────────┴───────────┐
           │                       │
          QNX                    Android
           │                       │
        Ethernet                 VirtIO
        CAN                      Client
        Audio                      │
        Vehicle                    │
           │                       │
           └──────── Service ──────┘
```

のような構成が考えられる。

QNXがPhysical Deviceを持ち、

```text
Android
   ↓
Virtual Device
   ↓
Hypervisor
   ↓
QNX Backend
   ↓
Hardware
```

としてアクセスさせる場合もある。

ここで、

**VirtIO**

が非常に重要になる。

---

# 13. VirtIO

代表例：

```text
virtio-net
virtio-blk
virtio-console
```

例えばネットワークでは、

```text
Guest Android
     │
 virtio-net
     │
 Hypervisor
     │
 Host / Backend
     │
 Physical Ethernet
```

という形になる。

Hypervisor学習では、VirtIOは優先して理解しておきたい。

---

# 14. SOME/IPとの関係

SOME/IPはSoC内部というより、

**ECU間通信**

で重要になる。

```text
                      Vehicle
                         │
              CAN / Automotive Ethernet
                         │
                 ┌───────┴───────┐
                 │    SA8295P     │
                 │                │
                 │      QNX       │
                 │       │        │
                 │   SOME/IP      │
                 │       │        │
                 │ Vehicle Service│
                 │       │        │
                 │  IPC / VirtIO  │
                 │       │        │
                 │    Android     │
                 │       │        │
                 │ Android Service│
                 └───────────────┘
```

典型的には、

```text
Vehicle Network
      ↓
QNX / Linux Native
      ↓
SOME/IP
      ↓
Vehicle Service
      ↓
IPC
      ↓
Android Service
      ↓
App
```

のようなレイヤ構造になる。

---

# 15. SA8775P / Ride Flex

SA8295Pを理解した後は、

**SA8775P / Snapdragon Ride / Ride Flex**

を見ると理解しやすい。

SA8295Pでは主に、

```text
Cockpit
IVI
Cluster
```

を統合していた。

Ride Flexではさらに、

```text
Cockpit
ADAS
Autonomous Driving
Safety
```

まで統合する。

---

# 16. Domain Consolidationの流れ

昔は、

```text
IVI ECU        Cluster ECU       ADAS ECU
 Android          QNX             RTOS
    │              │                │
   SoC            SoC              SoC
```

という構成だった。

それが、

```text
SA8295P
┌──────────────────────────┐
│       Hypervisor         │
│                          │
│ Android       QNX        │
│   IVI        Cluster     │
└──────────────────────────┘
```

のように統合される。

さらに、

```text
Ride Flex
┌──────────────────────────────┐
│          Hypervisor          │
│                              │
│ Android   QNX/RTOS    ADAS   │
│ Cockpit   Vehicle    Safety  │
│                              │
│ CPU / GPU / NPU / ISP        │
│      Safety Island           │
└──────────────────────────────┘
```

へ進む。

これが、

**Domain Consolidation → Central Compute**

の流れ。

---

# 17. Safety Island

ADASや中央集約型SoCでは、

**Safety Island**

も重要になる。

安全関連処理を通常のApplication Processorとは分離する。

概念的には、

```text
             Main SoC
┌─────────────────────────────┐
│                             │
│ Android / Linux / QNX       │
│                             │
│ CPU / GPU / NPU             │
│                             │
│     ┌─────────────────┐     │
│     │  Safety Island  │     │
│     │                 │     │
│     │ Safety Monitor  │     │
│     │ Watchdog        │     │
│     │ Fail-safe       │     │
│     └─────────────────┘     │
└─────────────────────────────┘
```

となる。

---

# 18. SA52xMとSA8295Pの関係

車全体で見ると、

```text
                    Cloud
                      │
                    5G
                      │
                  SA52xM
                TCU / V2X
                      │
              Automotive Ethernet
                      │
        ┌────────── SA8295P ──────────┐
        │                              │
        │       QNX Hypervisor         │
        │                              │
        │   ┌───────┐    ┌────────┐   │
        │   │  QNX  │    │Android │   │
        │   │       │    │ AAOS   │   │
        │   └───┬───┘    └───┬────┘   │
        │       │   IPC       │        │
        │       └─────────────┘        │
        │                              │
        │ CPU / GPU / DSP / ISP        │
        └──────────────┬───────────────┘
                       │
                  SOME/IP
                       │
             ┌─────────┼─────────┐
             │         │         │
           Body       ADAS     Gateway
            ECU        ECU       ECU
```

というイメージになる。

---

# 19. Qualcomm車載SoCを学ぶ順番

以下の順番が理解しやすい。

## Step 1：SA8295P

まず、

```text
CPU
GPU
DSP
NPU
ISP
Memory
Peripheral
```

などSoCの基本構造を理解する。

---

## Step 2：QNX Hypervisor

次に、

```text
Host
Guest
VM
Memory Isolation
Interrupt
Device Assignment
```

を理解する。

---

## Step 3：VirtIO

```text
virtio-net
virtio-blk
virtio-console
```

などを理解する。

特に、

```text
Physical Device
     ↓
Host
     ↓
VirtIO Backend
     ↓
Guest
```

という考え方が重要。

---

## Step 4：Android Automotive

```text
Android App
     ↓
Android Service
     ↓
Native Service
     ↓
Vehicle Interface
```

を理解する。

---

## Step 5：SOME/IP / Automotive Ethernet

SoC内部だけでなく、

```text
SoC
 ↓
Ethernet
 ↓
Other ECU
```

というECU間通信を理解する。

---

## Step 6：SA52xM

TCU側として、

```text
5G
GNSS
C-V2X
Security
TEE
Crypto
```

を理解する。

---

## Step 7：SA8775P / Ride Flex

最後に、

```text
Cockpit
+
ADAS
+
Safety
```

を1 SoCへ統合する世界を見る。

---

# 20. 最終的に理解したいアーキテクチャ

最終的には、

```text
Cloud
  │
  │ 5G
  ↓
SA52xM
TCU
  │
  │ Ethernet
  ↓
Central Compute
SA8295P / SA8775P
  │
  ├── QNX
  │     │
  │     ├── Vehicle Service
  │     ├── SOME/IP
  │     └── Hardware Control
  │
  ├── Android Automotive
  │     │
  │     ├── Android Service
  │     └── Apps
  │
  ├── GPU
  ├── DSP / NPU
  ├── ISP
  └── Safety Island
        │
        ↓
Automotive Ethernet
        │
        ├── Body ECU
        ├── ADAS ECU
        ├── Gateway
        └── Other ECU
```

という構造を頭の中で描けるようになることが目標。

---

# 21. 特に重要なキーワード

Qualcomm車載SoCを学ぶ際は、以下の言葉をセットで理解するとよい。

```text
Snapdragon Automotive
Digital Cockpit
Snapdragon Ride
Ride Flex

QNX
QNX Hypervisor
VM
Guest
VirtIO

Android Automotive OS
AAOS

CPU
GPU
DSP
NPU
Hexagon
Adreno
ISP

Automotive Ethernet
SOME/IP

Domain Consolidation
Central Compute
Mixed Criticality

Functional Safety
ASIL
Safety Island

TCU
NAD
5G
GNSS
C-V2X

TEE
Secure Boot
Crypto
PKCS#11
```

---

# 22. 学習のポイント

Qualcomm車載SoCでは、SoCの型番やCPUクロックを暗記するより、

> 「この処理はどのProcessorで動くのか」

> 「Physical DeviceをどのOSが所有するのか」

> 「AndroidとQNXをどう分離するのか」

> 「Guest OSからHardwareへどうアクセスするのか」

> 「他ECUとはどう通信するのか」

を理解する方が重要。

つまり、

```text
Hardware
   ↓
Hypervisor
   ↓
OS
   ↓
Middleware
   ↓
Vehicle Network
   ↓
Other ECU / Cloud
```

という縦の構造を理解する。

SA8295Pは、この構造を勉強する題材として非常に分かりやすい。

---

# まとめ

Qualcomm車載SoCの学習では、まず以下を中心に押さえる。

```text
SA8295P
  ↓
QNX Hypervisor
  ↓
VirtIO
  ↓
Android Automotive
  ↓
SOME/IP
  ↓
SA52xM
  ↓
SA8775P / Ride Flex
```

これを理解すると、

* QNX
* AAOS
* SOME/IP
* Automotive Ethernet
* Hypervisor
* VirtIO
* TCU
* ADAS
* Functional Safety

が別々の技術ではなく、

**「Software Defined Vehicle / Central Computeを構成する一つのアーキテクチャ」**

としてつながって見えるようになる。
