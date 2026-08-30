# AUTOSAR CAPI 1.0 と QNX の関係
## ― Adaptive AUTOSAR共通実装がSDVアーキテクチャとベンダー構造に与える影響 ―

## 1. 概要

AUTOSAR CAPI 1.0 は、AUTOSAR Adaptive Platformのための共通実装である。

CAPIは、

**Common Adaptive Platform Implementation**

の略であり、単なる「C言語API」という意味ではない。

従来のAUTOSARは、主に仕様を標準化し、その仕様に基づく実装を各ベンダーが個別に開発するモデルだった。

```text
AUTOSAR
   ↓
Specification
   ↓
Vector / Elektrobit / ETAS / OEM / Tier1
   ↓
各社独自実装
```

CAPIでは、この構造を次のように変えることを目指している。

```text
AUTOSAR
   ↓
Specification
   +
Common Implementation
   ↓
CAPI
   ↓
OEM / Tier1
```

つまり、AUTOSAR自身が「共通の動作するソフトウェア実装」を持つ方向への大きな転換である。

CAPI 1.0は2026年8月に正式リリースされ、AUTOSAR Adaptive Platform R20-11をベースとした実装、Core Functional Cluster、コードジェネレータ、デモなどを含む。

---

# 2. CAPIの基本構造

CAPIは、Adaptive AUTOSARアプリケーションとOSの間に位置する。

```text
Application
     │
     │ ara::* API
     ▼
┌──────────────────────────────────┐
│ AUTOSAR CAPI                     │
│                                  │
│ ara::core                        │
│ ara::com                         │
│ ara::exec                        │
│ ara::log                         │
│ ara::diag                        │
│ ara::per                         │
│ ara::crypto                      │
│ ara::phm                         │
│ ...                              │
├──────────────────────────────────┤
│ Platform / OS abstraction        │
├──────────────────────────────────┤
│ POSIX API                        │
│ socket / mmap / pthread / IPC    │
├───────────────┬──────────────────┤
│ Linux         │ QNX              │
└───────────────┴──────────────────┘
```

アプリケーションから見ると、

```cpp
#include <ara/com/...>
#include <ara/core/...>
```

のようなAUTOSAR標準APIを利用する。

その下で、CAPIが通信、プロセス管理、ログ、診断、永続化などを実装する。

---

# 3. `ara::com`

SDVで特に重要なのが `ara::com` である。

`ara::com` はAdaptive AUTOSARの通信APIであり、アプリケーションを通信プロトコルから分離する役割を持つ。

```text
Application
     │
     ▼
ara::com
     │
     ▼
Communication Management
     │
     ├── SOME/IP
     ├── DDS
     ├── Shared Memory
     └── IPC
```

アプリケーションは、概念的には次のようなコードを書く。

```cpp
auto handles =
    RadarServiceProxy::FindService();

RadarServiceProxy proxy(handles[0]);

proxy.VehicleSpeed.Subscribe(
    [](auto sample) {
        std::cout << sample->speed;
    }
);
```

アプリケーション側では、

- SOME/IP
- DDS
- Shared Memory
- ローカルIPC

などの具体的な通信方式を強く意識しない。

---

# 4. SOME/IPとの関係

ECU間通信ではSOME/IPが重要な役割を持つ。

```text
ECU A
      ara::com
         │
         ▼
      SOME/IP
         │
      Ethernet
         │
         ▼
      SOME/IP
         │
      ara::com
ECU B
```

内部では概念的に、

```text
ara::com
   ↓
Service Discovery
   ↓
Serialization
   ↓
SOME/IP Header
   ↓
socket()
sendmsg()
recvmsg()
poll()
```

のように処理が下位層へ降りていく。

ここから下ではOS依存性が大きくなる。

---

# 5. QNXとの関係

AUTOSAR Adaptive PlatformはPOSIX系OSを前提としている。

そのため基本的には、

```text
             CAPI
               │
            POSIX API
          /           \
       Linux          QNX
```

という構造が成立する。

QNX上では、

```text
CAPI
 │
 ├── pthread
 ├── mmap
 ├── socket
 ├── poll/select
 ├── File I/O
 │
 ▼
QNX Neutrino
```

となる。

Linuxでは、

```text
CAPI
 │
 ▼
glibc / libc++
 │
 ▼
Linux Kernel
```

となる。

---

# 6. POSIXだけでは完全な移植性は得られない

LinuxとQNXには共通POSIX APIが多い。

例えば、

```cpp
pthread_create()
socket()
mmap()
clock_gettime()
```

などは双方で利用できる。

しかし、OS固有機能に近づくと差が大きくなる。

## Linux

```text
epoll
eventfd
timerfd
systemd
cgroups
namespace
/proc
/sys
```

## QNX

```text
Pulse
Channel
Connection
MsgSend
MsgReceive
Resource Manager
slog2
procnto
```

したがって、CAPIをQNXへ移植する際にはOS abstraction layerが非常に重要になる。

---

# 7. OS Adaptation Layer

理想的には次のような構造になる。

```text
               CAPI
                 │
      ┌──────────┴──────────┐
      │ Platform Abstraction│
      └──────────┬──────────┘
                 │
        ┌────────┴────────┐
        │                 │
      Linux              QNX
        │                 │
      epoll           MsgReceive
      systemd         Pulse
      DLT             slog2
```

AUTOSAR上位APIは同じでも、OS固有処理はこの層で吸収する。

これにより、アプリケーションや多くのCAPI実装をLinux/QNX間で共通化できる。

---

# 8. `ara::exec`

Adaptive AUTOSARではExecution Managementがプロセスライフサイクルを管理する。

```text
Vehicle Startup
     │
     ▼
Execution Manager
     │
     ├── Start RadarApp
     ├── Start CameraApp
     ├── Start BodyApp
     └── Monitor Processes
```

アプリケーションはExecution Managerへ状態を通知する。

```cpp
ara::exec::ExecutionClient client;

client.ReportExecutionState(
    ara::exec::ExecutionState::kRunning
);
```

Linuxでは内部実装として、

```text
fork()
exec()
signals
cgroups
systemd
```

などが利用できる。

QNXでは、

```text
spawn()
procmgr
procnto
Pulse
IPC
```

などに対応付けられる。

ここはQNXの強みが特に活きる領域である。

---

# 9. QNX Microkernelとの親和性

QNX NeutrinoではメッセージパッシングIPCがOS設計の中心となっている。

```text
Process A
   │
 MsgSend()
   │
   ▼
QNX Kernel
   │
 MsgReceive()
   │
   ▼
Process B
```

そのためAUTOSAR Adaptiveの、

- Execution Management
- Communication Management
- Process Isolation
- Health Monitoring

などとの親和性が高い。

Linuxの設計をそのまま移植するより、QNXネイティブのIPCを活かした最適化も考えられる。

---

# 10. `ara::log`

Adaptive AUTOSARでは標準Logging APIが存在する。

```cpp
auto logger =
    ara::log::CreateLogger(
        "RADAR",
        "Radar Service"
    );

logger.LogInfo()
    << "Radar initialized";
```

Linuxでは、

```text
ara::log
   ↓
DLT
   ↓
dlt-daemon
```

という構成が一般的である。

QNXの場合、

```text
ara::log
   ↓
Adapter
   ↓
slog2
```

という統合も可能である。

---

# 11. `ara::core`

`ara::core` はAdaptive AUTOSAR全体で利用される基本データ型やユーティリティを提供する。

代表例：

```text
ara::core::Result
ara::core::ErrorCode
ara::core::Vector
ara::core::String
ara::core::Future
ara::core::Promise
```

例えば、

```cpp
ara::core::Result<int> getValue()
{
    if (ok) {
        return 42;
    }

    return ara::core::ErrorCode(...);
}
```

のように利用される。

これはアプリケーションとOSの間で利用される非常に基礎的な共通レイヤとなる。

---

# 12. Code Generator

AUTOSAR AdaptiveではARXMLを入力としてコードを生成する開発モデルが使われる。

```text
ARXML
  │
  ▼
Code Generator
  │
  ├── Proxy
  ├── Skeleton
  ├── Manifest
  └── Configuration
```

例えば、

```text
VehicleSpeedService.arxml
```

から、

```text
VehicleSpeedProxy.hpp
VehicleSpeedSkeleton.hpp
```

などを生成する。

SOME/IPで必要となる、

```text
Service ID
Method ID
Event ID
Instance ID
```

などの情報もARXMLから管理できる。

CAPI 1.0では、このコードジェネレータ自体も重要な構成要素となっている。

---

# 13. Proxy / Skeleton Model

Adaptive AUTOSARのRPC通信はProxy/Skeletonモデルを採用する。

```text
Client
  │
Proxy
  │
════════ Network ════════
  │
Skeleton
  │
Server
```

Server側では概念的に、

```cpp
class ClimateService
    : public ClimateSkeleton
{
public:

    ara::core::Future<SetTempOutput>
    SetTemp(SetTempInput input)
    {
        ...
    }
};
```

のように実装する。

その通信経路は、

```text
Proxy
 ↓
ara::com
 ↓
SOME/IP
 ↓
Ethernet
 ↓
SOME/IP
 ↓
ara::com
 ↓
Skeleton
```

となる。

---

# 14. CAPI 1.0 の Functional Cluster

CAPI 1.0は、AUTOSAR Adaptive Platform R20-11をベースに、Core Functional Clusterを共通実装として提供する。

代表的なFunctional Clusterは以下の通りである。

| Functional Cluster | 主な役割 | 代表API / 概念 |
|---|---|---|
| Adaptive Platform Core | 基本型・ユーティリティ | `ara::core` |
| Communication Management | Service Oriented Communication | `ara::com` |
| Cryptography | 暗号処理、鍵管理 | `ara::crypto` |
| Diagnostics | 車両診断 | `ara::diag` |
| Execution Management | Process起動・停止・状態管理 | `ara::exec` |
| Log and Trace | ロギング、トレース | `ara::log` |
| Network Management | ネットワーク状態管理 | `ara::nm` |
| Operating System Interface | POSIX OSとのインターフェース | POSIX API |
| Persistency | 永続データ管理 | `ara::per` |
| Platform Health Management | Watchdog / Health Monitoring | `ara::phm` |
| State Management | 車両・ECU状態管理 | `ara::sm` |
| Time Synchronization | 時刻同期 | `ara::tsync` |
| Update and Configuration Management | ECUソフトウェア更新 | `ara::ucm` |
| Security関連 | アクセス制御・Security | Security APIs |
| Platform Supporting Functions | Adaptive基盤サービス | Platform APIs |

Functional Clusterをレイヤで見ると、

```text
┌─────────────────────────────────┐
│ Vehicle Applications            │
├─────────────────────────────────┤
│ Application-facing APIs         │
│ ara::com                        │
│ ara::diag                       │
│ ara::crypto                     │
│ ara::per                        │
├─────────────────────────────────┤
│ Platform Management             │
│ ara::exec                       │
│ ara::sm                         │
│ ara::phm                        │
│ ara::ucm                        │
├─────────────────────────────────┤
│ Platform Infrastructure         │
│ ara::log                        │
│ ara::tsync                      │
│ ara::nm                         │
│ ara::core                       │
├─────────────────────────────────┤
│ OS Interface                    │
├─────────────────────────────────┤
│ Linux / QNX / POSIX OS          │
└─────────────────────────────────┘
```

ここで重要なのは、

```text
Functional Cluster
≠
単なるライブラリ
```

という点である。

Execution ManagementやDiagnosticsなどは、daemonや独立プロセスとして実装される場合もある。

---

# 15. CAPI + QNXの全体アーキテクチャ

実際の車載システムでは次のような構成が考えられる。

```text
┌─────────────────────────────────────┐
│ Vehicle Applications                │
│                                     │
│ ADAS / Body / Gateway / Cockpit     │
├─────────────────────────────────────┤
│ AUTOSAR APIs                        │
│                                     │
│ ara::com                            │
│ ara::exec                           │
│ ara::log                            │
│ ara::diag                           │
├─────────────────────────────────────┤
│ AUTOSAR CAPI                        │
├─────────────────────────────────────┤
│ OS Adaptation Layer                 │
├─────────────────────────────────────┤
│ QNX SDP                             │
│                                     │
│ POSIX                               │
│ IPC                                 │
│ Networking                          │
│ Resource Manager                    │
├─────────────────────────────────────┤
│ QNX Neutrino Microkernel            │
├─────────────────────────────────────┤
│ Qualcomm / Renesas / NXP / NVIDIA   │
└─────────────────────────────────────┘
```

役割を分けると、

```text
CAPI
    = Vehicle Middleware
      AUTOSAR Programming Model

QNX
    = OS
      Safety
      Isolation
      Scheduling
      IPC
```

という関係になる。

---

# 16. Android Automotiveとの共存

SDVのCockpitシステムではAndroid AutomotiveとAUTOSAR Adaptiveの共存も重要になる。

```text
┌───────────────────────────────┐
│ Android Automotive            │
│ App / Framework               │
├───────────────────────────────┤
│ Vehicle Service               │
├───────────────────────────────┤
│ SOME/IP / DDS / IPC           │
└──────────────┬────────────────┘
               │
        Vehicle Ethernet
               │
┌──────────────▼────────────────┐
│ AUTOSAR CAPI                  │
│ ara::com                      │
├───────────────────────────────┤
│ QNX                           │
└───────────────────────────────┘
```

AndroidはHMIやIVIを担当し、QNX + AUTOSAR Adaptive側が車両制御に近い処理を担当する構成が考えられる。

---

# 17. Hypervisor構成

高性能SoCではHypervisor上にAndroidとQNXを共存させることも可能である。

```text
                 SoC
                  │
        ┌─────────┴─────────┐
        │ QNX Hypervisor    │
        └──────┬──────┬─────┘
               │      │
              QNX   Android
               │
              CAPI
               │
        Vehicle Applications
```

この構成では、

- Android：IVI / UX
- QNX：リアルタイム / Safety
- CAPI：AUTOSAR Adaptive middleware

という役割分担が可能になる。

---

# 18. CAPIと既存Adaptive AUTOSAR製品の比較

CAPI登場以前から、主要AUTOSARベンダーはAdaptive AUTOSAR製品を提供してきた。

代表的なのが、

```text
Vector
    MICROSAR Adaptive

Elektrobit
    EB corbos AdaptiveCore

ETAS
    RTA-VRTE
```

である。

比較すると次のようになる。

| 項目 | AUTOSAR CAPI | Vector MICROSAR Adaptive | EB corbos AdaptiveCore | ETAS RTA-VRTE |
|---|---|---|---|---|
| 提供主体 | AUTOSAR | Vector | Elektrobit | ETAS |
| 基本目的 | 共通実装 | 商用Adaptive Platform | 商用Adaptive Platform | Vehicle Runtime Platform |
| AUTOSAR Adaptive対応 | Yes | Yes | Yes | Yes |
| Code Generator | あり | DaVinci系 | EB corbos Studio | ISOLAR-VRTE |
| Linux | 対象 | 対応 | 対応 | 対応 |
| QNX | 移植対象になり得る | 対応可能 | 公式QNX版あり | QNX環境あり |
| SOME/IP | 対応領域 | 対応 | 対応 | 対応 |
| Safety | 今後強化 | 商用Safety対応 | Safety対応 | ASIL対応用途 |
| Tooling | 発展途上 | 非常に強い | 強い | 強い |
| Support | AUTOSAR Ecosystem | Vendor Support | Vendor Support | Vendor Support |
| Vendor Lock-in | 低減を狙う | 比較的高い | 比較的高い | 比較的高い |

---

# 19. Vector MICROSAR Adaptive

VectorのMICROSAR Adaptiveは成熟した商用Adaptive AUTOSAR Platformである。

構成としては、

```text
MICROSAR Adaptive
+
DaVinci Developer Adaptive
+
DaVinci Configurator
+
Vector Network Tools
```

という強力なツールチェーンを持つ。

つまり単なるmiddlewareではなく、

```text
Modeling
↓
Configuration
↓
Code Generation
↓
Build
↓
Integration
↓
Network Analysis
```

までカバーしている。

Vectorの最大の強みは、このTool Ecosystemにある。

---

# 20. Elektrobit EB corbos AdaptiveCore

Elektrobitは、

```text
EB corbos AdaptiveCore
```

をAdaptive AUTOSAR middlewareとして提供している。

特徴的なのは、

```text
EB corbos AdaptiveCore for Linux

EB corbos AdaptiveCore for QNX
```

という両OS向け製品が存在することである。

構造としては、

```text
EB corbos AdaptiveCore
       ↓
 Linux / QNX
```

となる。

これは、

```text
AUTOSAR CAPI
       ↓
 OS Adaptation
       ↓
 Linux / QNX
```

というCAPIが目指し得る構造と非常に近い。

---

# 21. ETAS RTA-VRTE

ETASのRTA-VRTEはAdaptive AUTOSAR middlewareという位置付けを超えて、

```text
Vehicle Runtime Environment
```

として設計されている。

その構造には、

```text
ara::com
ara::exec
ara::diag
ara::crypto
ara::phm
ara::ucm
ara::log
ara::tsync
ara::per
```

などのAdaptive AUTOSAR機能に加えて、

```text
Hypervisor
OS
Communication Stack
Vehicle Lifecycle Management
Vehicle Diagnosis
Vehicle Update Management
```

なども含む。

したがって、

```text
CAPI
    = Adaptive AUTOSAR Common Implementation

RTA-VRTE
    = Vehicle Computer Runtime Platform
```

という違いがある。

---

# 22. CAPIはQNXの競合か

CAPIとQNXは基本的には競合ではなく、レイヤが異なる。

CAPIが影響を与える可能性が高いのは、

```text
Vector Adaptive AUTOSAR
EB corbos Adaptive
ETAS Adaptive Stack
OEM独自Adaptive Platform
Tier1独自Adaptive Platform
```

などのmiddleware層である。

一方、

```text
QNX Neutrino
QNX Safety OS
QNX Hypervisor
QNX SDP
```

はOS / Hypervisor層である。

したがって、

```text
CAPI
──────
QNX
```

という組み合わせは自然である。

---

# 23. QNXにとってのチャンス

CAPIによってmiddlewareが共通化されると、OS側の差別化がより重要になる可能性がある。

QNXが持つ、

```text
ISO 26262
Functional Safety
Process Isolation
Deterministic Scheduling
Microkernel Architecture
Hypervisor
Security
```

は、そのまま強い差別化要素になる。

理想的には、

```text
AUTOSAR CAPI
+
QNX Safety OS
+
QNX Hypervisor
+
QNX Toolchain
```

をAdaptive AUTOSAR向けReference Platformとして位置付けることができる。

---

# 24. CAPIはSDVベンダー構造をどう変えるか

CAPIの最も大きな意味は、技術そのものよりも、

**自動車ソフトウェア産業のレイヤ構造を変える可能性**

にある。

---

# 25. 従来のSDVソフトウェア構造

従来は、

```text
                 OEM
                  │
                  ▼
             Tier1 / SI
                  │
                  ▼
      AUTOSAR Middleware Vendor
                  │
       ┌──────────┼──────────┐
       │          │          │
     Vector       EB        ETAS
       │          │          │
       ▼          ▼          ▼
       OS / Hypervisor Vendor
                  │
             Linux / QNX
                  │
                  ▼
                 SoC
```

という構造になっていた。

OEMはAUTOSAR準拠であっても、

```text
Vector版
EB版
ETAS版
```

のどれかを選ぶ必要があった。

---

# 26. API標準化だけではVendor Lock-inはなくならない

AUTOSARはAPIを標準化している。

例えば、

```cpp
ara::com
ara::exec
ara::log
```

は共通である。

それでも実際には、

```text
Configuration
Code Generator
Build System
Manifest
Deployment
Diagnostics
Vendor Extensions
Tool Chain
```

がベンダーごとに異なる。

そのため、

```text
API Standardization
≠
Implementation Portability
```

であった。

---

# 27. CAPI登場後の構造

CAPIが成熟すると、

```text
                 OEM
                  │
                  ▼
          Vehicle Software
                  │
                  ▼
          AUTOSAR CAPI
                  │
        ┌─────────┼─────────┐
        │         │         │
       QNX      Linux     Other
        │         │
        └────┬────┘
             │
           SoC
```

という構造が可能になる。

ここでは、AUTOSAR Adaptive implementationそのものが共通化される。

---

# 28. Middleware Vendorの役割変化

これはVector、Elektrobit、ETASが不要になるという意味ではない。

むしろ競争領域が変わる可能性が高い。

従来：

```text
AUTOSAR Specification
        ↓
Vendor implements stack
        ↓
OEM buys implementation
```

CAPI以降：

```text
AUTOSAR
   ↓
CAPI common implementation
   ↓
Vendor adds value
```

となる。

Vendorの競争領域は、

```text
Adaptive AUTOSAR APIを実装すること
```

から、

```text
Integration
Tooling
Safety
Performance
Diagnostics
Cloud
OTA
Security
Developer Experience
```

へ移る可能性がある。

---

# 29. Linuxとの類似性

これはLinuxの歴史とよく似ている。

かつてUNIXベンダーは、

```text
Sun Solaris
IBM AIX
HP-UX
SGI IRIX
```

のようにOSそのものを差別化していた。

Linuxが共通基盤になると、

```text
Linux Kernel
      ↓
Common OS Foundation
      ↓
Red Hat
Canonical
SUSE
Cloud Vendors
```

という構造へ変化した。

AUTOSARでも同様に、

```text
AUTOSAR Specification
        ↓
CAPI
        ↓
Common Automotive Middleware
```

となる可能性がある。

---

# 30. 「AUTOSAR版Linux Kernel」になる可能性

極端に表現すると、CAPIは、

```text
Automotive Middleware版 Linux
```

のような位置付けを目指しているとも考えられる。

```text
Linux Kernel
     ↓
OS Ecosystem
```

に対して、

```text
AUTOSAR CAPI
     ↓
Vehicle Software Ecosystem
```

という関係である。

CAPIによって、同じAdaptive AUTOSAR機能を各社が何度も実装する必要を減らせる可能性がある。

---

# 31. OEMのソフトウェア内製化との関係

CAPIはOEMの内製化とも相性が良い。

従来：

```text
OEM
 ↓
Tier1
 ↓
Middleware Vendor
 ↓
OS Vendor
```

CAPI利用：

```text
OEM Software Team
       │
       ▼
Vehicle Software Platform
       │
       ▼
AUTOSAR CAPI
       │
       ▼
Linux / QNX
```

となる。

これによりOEMがVehicle Software Platformを直接開発しやすくなる。

---

# 32. Tier1への影響

Tier1も、

```text
AUTOSAR Stackを提供する会社
```

から、

```text
Vehicle Functionを提供する会社
```

へ軸足を移す必要が出てくる可能性がある。

より重要になるのは、

```text
ADAS
Energy Management
Body Control
Charging
Thermal Management
Cockpit
```

などのVehicle Functionそのものになる。

---

# 33. 競争レイヤの変化

SDV Software Stack全体を整理すると、

```text
┌──────────────────────────────────┐
│ Vehicle Applications             │
│ OEM差別化領域                    │
├──────────────────────────────────┤
│ Vehicle Services                 │
│ OEM / Tier1差別化領域            │
├──────────────────────────────────┤
│ AUTOSAR CAPI                     │
│ 共通化・Commodity化の可能性      │
├──────────────────────────────────┤
│ OS / Hypervisor                  │
│ QNX / Linux                      │
├──────────────────────────────────┤
│ SoC                              │
│ Qualcomm / NVIDIA / Renesas etc. │
└──────────────────────────────────┘
```

SDVで価値の高い領域は、

```text
Middleware
```

から、

```text
Vehicle Function
Developer Platform
Cloud
AI
OTA
Data
UX
```

へ上がっていく可能性がある。

---

# 34. `ara::com` からQNXまでの通信経路

CAPIとQNXの関係を理解する上で、特に重要なのが1回のRPCがどのように流れるかである。

送信側：

```text
Vehicle Application
        │
        ▼
Generated Proxy
        │
        ▼
ara::com
        │
        ▼
CAPI Communication Management
        │
        ▼
Serialization
        │
        ▼
SOME/IP
        │
        ▼
socket()
        │
        ▼
QNX TCP/IP Stack
        │
        ▼
Ethernet
```

受信側：

```text
Ethernet
   │
   ▼
QNX TCP/IP Stack
   │
   ▼
socket()
   │
   ▼
SOME/IP
   │
   ▼
Deserialization
   │
   ▼
ara::com
   │
   ▼
Generated Skeleton
   │
   ▼
Vehicle Application
```

この部分が、

**AUTOSAR CAPIとQNXが実際に接続される重要な境界**

になる。

---

# 35. 将来的なSDV Stack

将来的には次のような構造が有力になる。

```text
┌──────────────────────────────────────┐
│ Cloud / AI / DevOps                  │
├──────────────────────────────────────┤
│ Vehicle Applications                 │
│ ADAS / Cockpit / Body / Energy       │
├──────────────────────────────────────┤
│ Vehicle Service Platform             │
├──────────────────────────────────────┤
│ AUTOSAR Adaptive API                 │
├──────────────────────────────────────┤
│ AUTOSAR CAPI                         │
├──────────────────────────────────────┤
│ QNX / Linux                          │
├──────────────────────────────────────┤
│ Hypervisor                           │
├──────────────────────────────────────┤
│ Qualcomm / NVIDIA / Renesas / NXP    │
└──────────────────────────────────────┘
```

この構造では、

```text
AUTOSAR
```

はVehicle Softwareの共通言語となり、

```text
CAPI
```

はその共通Runtime Implementationになる。

---

# 36. まとめ

AUTOSAR CAPIはAdaptive AUTOSARの大きな転換点である。

従来の、

```text
Specification Only
```

から、

```text
Specification
+
Common Executable Implementation
```

への移行を意味している。

CAPIはOSそのものではなく、

```text
Vehicle Application
        ↓
AUTOSAR APIs
        ↓
CAPI
        ↓
Operating System
```

というmiddleware層に位置する。

そのためQNXとの関係は競合ではなく、

```text
AUTOSAR CAPI
      +
QNX Neutrino / Safety OS / Hypervisor
```

という補完関係になる可能性が高い。

CAPIが普及した場合、Adaptive AUTOSAR middlewareの共通化によって、

- ベンダーロックイン低減
- Linux/QNX間の移植性向上
- OEMのソフトウェア内製化
- Middleware Vendorの価値のTooling / Safety / Integrationへの移動
- Vehicle Function / Cloud / AI / OTAへの競争軸移動

が進む可能性がある。

最終的には、

```text
Applications
     │
     │ OEM differentiation
     ▼
Vehicle Services
     │
     ▼
AUTOSAR CAPI
     │
     │ Common middleware
     ▼
QNX / Linux
     │
     │ OS / Safety / Isolation
     ▼
Hypervisor
     │
     ▼
SoC
```

という構造がSDVの重要なアーキテクチャ候補になる。

特に今後注目すべきなのは、

1. `ara::com` のSOME/IP / DDS / IPC実装
2. QNX向けOS Adaptation Layer
3. `ara::exec` とQNX Process / IPCの統合
4. Functional Safety対応
5. CAPIとQNX Safety OSの認証戦略
6. Android Automotiveとの共存
7. Central Compute / Zonal Architectureへの展開
8. Vector / EB / ETASがCAPIをどう取り込むか

である。

CAPIの登場によってSDVの競争軸は、

```text
「AUTOSARを実装できるか」
```

から、

```text
「AUTOSARの上で何を作れるか」
```

へ移っていく可能性が高い。