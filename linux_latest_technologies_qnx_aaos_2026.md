# Linux最新技術10選 ― QNX / Android Automotiveとの関係から理解する

**更新日:** 2026-08-28  
**対象:** Linux / 組込みLinux / Android Automotive OS (AAOS) / QNX に関心のあるエンジニア  
**前提知識:** Linuxのプロセス、スレッド、システムコール、デバイスドライバ、基本的なリアルタイムOSの知識

---

## 0. はじめに

Linuxは、以前の「汎用OS・サーバーOS」という位置づけから大きく広がっている。

現在は、

- Cloud / Data Center
- Edge Computing
- Android
- Automotive
- Robotics
- Industrial
- AI
- High Performance Computing

まで、非常に広い領域で使われている。

特に近年のLinuxでは、単純な性能向上だけでなく、

- **カーネルを安全に拡張する**
- **リアルタイム性を高める**
- **カーネルを書き換えずに動作を変更する**
- **実行中のシステムを詳細に観測する**
- **ワークロードを強く分離する**
- **メモリ安全性を高める**

という方向への進化が目立つ。

2026年8月28日時点で、kernel.orgでは **Linux 7.2.1** がstableとして公開されている。

本書では、これからLinuxを深く理解するうえで特に重要な10技術を、QNXおよびAndroid Automotiveとの関係も含めて解説する。

---

# 1. eBPF ― 「動いているカーネル」を安全に拡張する

## 概要

eBPF（extended Berkeley Packet Filter）は、Linuxカーネル内部で小さなプログラムを実行する仕組みである。

従来、

```text
機能を追加
   ↓
Kernel source変更
   ↓
Kernel build
   ↓
再起動
```

が必要だった処理の一部を、

```text
User Space
    |
    | load BPF program
    v
+--------------------+
|   Linux Kernel     |
|                    |
|   eBPF VM/JIT      |
|      |             |
|      +--> trace    |
|      +--> network  |
|      +--> security |
+--------------------+
```

のように動的に追加できる。

## 主な用途

- Performance tracing
- Network packet processing
- Security monitoring
- System call monitoring
- Scheduler拡張
- Observability
- Container networking

代表的な周辺技術は以下。

```text
eBPF
 ├─ BPF Maps
 ├─ BTF
 ├─ CO-RE
 ├─ libbpf
 ├─ kprobe
 ├─ tracepoint
 ├─ XDP
 └─ sched_ext
```

## 従来Linuxとの違い

従来は、

```text
printk()
strace
perf
ftrace
kernel module
```

などを目的に応じて使っていた。

eBPFでは、実行中のカーネルに対して非常に細かい観測・制御を行える。

例えば、

```text
Application
    |
 syscall
    |
    v
VFS
    |
Block Layer
    |
Driver
    |
Hardware
```

のどこで遅延しているかを、カーネルを書き換えずに追跡できる。

## QNXとの関係

QNXでは、OS構造そのものがマイクロカーネルであり、多くのサービスがUser Spaceに存在する。

```text
QNX
 Application
     |
 Message Passing
     |
 Resource Manager
     |
 Microkernel
```

Linuxでは多くの機能がKernel Spaceにあるため、内部状態を安全に観測する仕組みとしてeBPFの価値が非常に大きい。

## Android Automotiveとの関係

AAOSでは、

```text
Android App
Framework
System Service
HAL / AIDL
Native Service
Linux Kernel
Driver
ECU / Hardware
```

という深いスタックになる。

例えば車両サービスの応答が遅い場合、

```text
Binder?
HAL?
Socket?
SOME/IP?
Kernel scheduler?
Network driver?
```

のどこが原因かを調べる必要がある。

ここでeBPFは強力な解析手段になる。

## 学習優先度

**★★★★★**

Linuxを今から深く学ぶなら、最優先候補。

---

# 2. Rust for Linux ― カーネルにMemory Safetyを導入する

## 概要

Linuxカーネルは歴史的にほぼCで実装されてきた。

しかしCでは、

- Use After Free
- Buffer Overflow
- NULL Pointer
- Double Free
- Data Race

などが発生しやすい。

RustはOwnershipと型システムによって、この種の問題の多くをコンパイル時に防止できる。

```text
Traditional

C Driver
   |
unsafe memory access
   |
Linux Kernel


Rust for Linux

Rust Driver
   |
Ownership / Lifetime
   |
Safe Abstraction
   |
Linux Kernel
```

## 何が重要なのか

Rust for Linuxの目的は、

> Linux全部をRustに書き換えること

ではない。

現実的には、

> 新しいドライバやサブシステムで、安全な実装手段を増やす

という方向である。

Rust向けのカーネル抽象化は徐々に広がっており、PCI、IRQ、Device Tree、IOMMU、各種ドライバ基盤などが重要な領域になる。

## QNXとの関係

QNXの大きな強みは、

- Microkernel
- Process isolation
- Fault containment

である。

Linux + Rustでは、

```text
Linux
 ├─ Monolithic kernel
 └─ Rustによるmemory safety向上
```

という別の方向から安全性を高める。

つまり、

```text
QNX
 → architectureで障害を隔離

Linux + Rust
 → implementationでメモリエラーを減らす
```

という違いがある。

## Android Automotiveとの関係

Android自体もRust採用を進めており、Linux kernel側のRust対応とは非常に相性がよい。

将来的な車載スタックでは、

```text
Android Framework
      |
Rust Native Component
      |
Rust Driver / Safe abstraction
      |
Linux Kernel
```

という構成が増える可能性がある。

## 学習優先度

**★★★★★**

C/C++を知っているLinuxエンジニアほど学習効果が高い。

---

# 3. io_uring ― 高性能Asynchronous I/O

## 概要

従来Linuxでは、

```c
read()
write()
poll()
select()
epoll()
```

などを組み合わせてI/O処理を行ってきた。

io_uringではUser SpaceとKernel Spaceにリングバッファを共有する。

```text
User Space

 Submission Queue
       |
       v
+------------------+
|                  |
|   Linux Kernel   |
|                  |
+------------------+
       |
       v
 Completion Queue
```

これにより、

- syscall回数削減
- context switch削減
- asynchronous処理
- batch処理

などが可能になる。

## 車載での意味

車載では巨大Webサーバーのような処理だけでなく、

- Logging
- Telemetry
- Sensor data
- Storage
- Network gateway
- OTA
- Data recorder

などで非同期I/Oの性能が重要になる。

## QNXとの関係

QNXはMessage Passingを中心としたOS設計である。

一方io_uringは、

> Linuxの従来I/Oモデルを高効率化する技術

であり、OSアーキテクチャそのものを変えるものではない。

## Android Automotiveとの関係

AAOSのNative Serviceや車両データ処理では、

```text
Vehicle data
   ↓
Native Service
   ↓
Network / Storage
```

のような大量I/Oを扱うケースがある。

io_uringは、そのようなLinux Native部分で有効になる可能性がある。

## 学習優先度

**★★★★☆**

---

# 4. PREEMPT_RT ― LinuxをReal-Time OSへ近づける

## 概要

Linuxは本来General Purpose OSである。

通常Linuxでは、

```text
High priority task
      |
      | wakeup
      v
 scheduler
      |
      +---- latency ----+
```

の遅延時間にばらつきがある。

PREEMPT_RTでは、カーネル内のプリエンプト可能範囲を増やし、割込み処理などもスケジューリング可能な形へ近づける。

## 代表的なReal-Time Linux構成

```text
PREEMPT_RT
+
CPU isolation
+
IRQ affinity
+
Real-time scheduling
+
Memory locking
+
CPU frequency control
```

例えば、

```text
isolcpus=
nohz_full=
rcu_nocbs=
```

などを利用して特定CPUをリアルタイム処理専用にする構成もある。

## QNXとの違い

ここは非常に重要。

### QNX

```text
Microkernel
    |
Priority scheduling
    |
Deterministic IPC
    |
Small kernel
```

OS設計そのものがリアルタイム向け。

### Linux + PREEMPT_RT

```text
Large Linux Kernel
      |
PREEMPT_RT
      |
Latency reduction
```

Linuxをリアルタイム用途へ適応させるアプローチ。

したがって、

```text
Hard RT / Safety critical
      → QNXが有利な場合が多い

Soft RT / Mixed workload
      → Linux + PREEMPT_RTが非常に有力
```

となる。

## Android Automotiveとの関係

典型的な車載アーキテクチャでは、

```text
           Vehicle
              |
     +--------+--------+
     |                 |
   QNX/RTOS           Linux
 Safety / Control    AAOS
                     IVI
```

のように役割を分離することが多い。

しかしLinuxのリアルタイム性能が向上することで、その境界は徐々に変化している。

## 学習優先度

**★★★★★**

特にQNXを理解する人には必須。

---

# 5. sched_ext ― SchedulerをBPFで差し替える

## 概要

Linux schedulerはOSの中心機能である。

従来、

```text
CFS / EEVDF
Real-Time Scheduler
Deadline Scheduler
```

などはカーネル側で実装されていた。

sched_extでは、

```text
Linux Kernel
    |
sched_ext
    |
BPF Scheduler
    |
Custom Policy
```

という構成を作れる。

## 何が画期的なのか

従来Schedulerを研究するには、

```text
Kernel source変更
↓
build
↓
boot
↓
test
```

が必要だった。

sched_extなら、BPF schedulerを動的に有効化・無効化できる。

異常が発生した場合は通常のschedulerへ戻る仕組みも用意されている。

## Automotiveでの可能性

例えばSoC上に、

```text
CPU0-1 : Android
CPU2-3 : Vehicle Service
CPU4-5 : AI
CPU6   : Audio
CPU7   : Background
```

のような異なるワークロードが存在するとする。

sched_extを利用すると、ワークロードに合わせたCPU scheduling研究が容易になる。

ただしSafety Critical制御で使用するには、決定性、検証性、認証など別の問題がある。

## QNXとの関係

QNXでは優先度ベースのリアルタイムスケジューリングがOSの重要な設計要素。

sched_extはLinux側で、

> schedulerを「固定されたOS内部機能」から「拡張可能なpolicy」へ変える

という点で非常に興味深い。

## 学習優先度

**★★★★☆**

将来性が非常に高い。

---

# 6. XDP ― Linux Network Stackより前でPacket処理

## 概要

XDP（eXpress Data Path）はeBPFを使い、Linux networking stackのかなり早い段階でpacketを処理する。

通常、

```text
NIC
 |
Driver
 |
Linux Network Stack
 |
Socket
 |
Application
```

XDPでは、

```text
NIC
 |
Driver
 |
XDP/eBPF
 | \
 |  DROP
 |  REDIRECT
 |  TX
 |
Linux Network Stack
```

という処理が可能。

## 用途

- High-performance networking
- Packet filtering
- DDoS protection
- Load balancing
- Network gateway
- Observability

## Automotiveとの関係

Software Defined VehicleではEthernet利用が拡大している。

```text
Camera
ADAS ECU
IVI
Gateway
Telematics
Cloud
```

がEthernet networkで接続される。

LinuxベースGatewayではXDP/eBPFを利用した高速packet処理や監視が有力になる。

SOME/IPトラフィックの観測やGateway処理を考える際にも、Linux networking内部を理解するうえで重要。

## QNXとの関係

QNX Networking StackとLinux Networking Stackは設計が異なるが、LinuxではXDP/eBPFによって非常に柔軟なnetwork処理を追加できるのが特徴。

## 学習優先度

**★★★★☆**

---

# 7. cgroup v2 + PSI ― Resource ManagementとPressure監視

## 概要

Linuxでは複数のworkloadが同じSoC上で動作するケースが増えている。

cgroup v2は、

- CPU
- Memory
- I/O
- Process

などのresource管理を統一的に行う。

```text
Linux
 |
 +-- cgroup A : Android
 |
 +-- cgroup B : Vehicle service
 |
 +-- cgroup C : AI workload
 |
 +-- cgroup D : Background
```

PSI（Pressure Stall Information）は、

- CPU
- Memory
- I/O

のresource不足によってtaskがどの程度待たされているかを可視化する。

## Androidとの関係

Androidでは既にcgroupを広く利用している。

Android Automotiveでも、

```text
Foreground App
System Server
Vehicle Service
Media
Background App
```

などのresource allocationは重要。

単純なCPU使用率だけではなく、

> 「CPUやmemoryが足りないため、どれだけ処理が止まったか」

を見るPSIは性能解析に有用。

## QNXとの違い

QNXは比較的predictableなresource managementを重視する。

Linuxでは多数のworkloadを同時実行するため、

```text
cgroup
PSI
scheduler
OOM
memory reclaim
```

を組み合わせて制御する。

## 学習優先度

**★★★★☆**

AAOSを扱うなら特に重要。

---

# 8. Landlock / LSM ― Linux Sandboxの進化

## 概要

Linuxには、

```text
SELinux
AppArmor
Smack
Landlock
```

などのsecurity mechanismがある。

LandlockはLSM（Linux Security Module）を利用したsandbox機構で、unprivileged process自身がアクセス権をさらに狭めることができる。

重要なのは、

```text
System Policy
     +
Application Sandbox
```

という多層防御を作れること。

## Android Automotiveとの関係

AndroidではSELinuxが非常に重要。

例えば、

```text
App
 ↓
SELinux domain
 ↓
Binder / HAL
 ↓
Native Service
```

のアクセスがpolicyで管理される。

Automotiveではさらに、

- Vehicle data
- Location
- User information
- Cloud credentials
- ECU control

などを扱うため、Linux security isolationは重要性が高い。

## QNXとの違い

QNXではProcess Separationがarchitecture上の大きな特徴。

Linuxでは、

```text
Process isolation
+
Namespace
+
cgroup
+
SELinux
+
Seccomp
+
Landlock
```

のように複数の仕組みを積み重ねる。

## 学習優先度

**★★★★☆**

---

# 9. KVM / Virtio / pKVM ― 車載SoCのVirtualization

## 概要

車載SoCでは、1台の高性能SoCで複数OSを動かす構成が増えている。

```text
             Hypervisor
        /        |        \
      QNX      Linux     Android
     Safety    Service     AAOS
```

LinuxではKVMとVirtioが仮想化の中心技術。

AndroidではpKVM（protected KVM）のような、より強い隔離を目指す仕組みも重要になっている。

## Virtio

Virtioはvirtual device interface。

```text
Guest OS
   |
virtio-net
virtio-blk
virtio-gpu
   |
Hypervisor
   |
Hardware
```

という構成で、GuestとHost間のデバイス共有を効率化する。

## Automotiveでの意味

Cockpit domain controllerなどでは、

```text
AAOS
Instrument Cluster
Safety OS
Linux Service
```

を1 SoC上に統合するケースがある。

ここで、

- CPU isolation
- Memory isolation
- Device assignment
- GPU sharing
- Networking

が重要になる。

## QNXとの関係

QNX HypervisorとLinux KVM系は競合・共存の両方があり得る。

QNXをSafety/Realtime側、AAOSをIVI側で動かすarchitectureは、車載virtualizationを理解するうえで代表的な構成。

## 学習優先度

**★★★★★**

Automotiveでは特に重要。

---

# 10. Confidential Computing / Hardware-backed Isolation

## 概要

従来のsecurity modelでは、

```text
OS / Hypervisorは信頼する
```

ことが前提だった。

Confidential Computingでは、

```text
Guest
 |
Encrypted / Protected Memory
 |
Untrusted Hypervisor
 |
Hardware
```

というモデルを目指す。

x86では代表的に、

- AMD SEV-SNP
- Intel TDX

などがある。

Arm系でも、Realmなどhardware-backed isolationの方向が進んでいる。

## Automotiveとの関係

将来のSoftware Defined Vehicleでは、

```text
Vehicle
  |
  +-- OEM software
  +-- Supplier software
  +-- Third-party App
  +-- AI model
  +-- Cloud credentials
```

が同一SoCに存在する可能性がある。

単なるprocess isolationだけではなく、

> hardwareレベルで異なるtrust domainを分離する

考え方が重要になる。

## QNXとの関係

QNXのMicrokernelによるprocess isolationと、hardware virtualizationによるisolationは別レイヤ。

将来的には、

```text
Hardware isolation
       |
Hypervisor
       |
+------+------+
|             |
QNX          AAOS
|             |
Safety        IVI
```

のような多層構造が一般的になると考えられる。

## 学習優先度

**★★★☆☆**

現在よりも今後さらに重要になる分野。

---

# 11. 10技術を一覧で比較

| 技術 | 主目的 | QNXとの関係 | AAOS/車載との関係 | 優先度 |
|---|---|---|---|---|
| eBPF | Kernel拡張・観測 | Linux特有の強力な観測手段 | 性能解析、障害解析 | ★★★★★ |
| Rust for Linux | Memory Safety | Microkernelとは別方向の安全化 | Driver / Native component | ★★★★★ |
| io_uring | 高速Async I/O | Linux I/O高速化 | Logging / Storage / Network | ★★★★☆ |
| PREEMPT_RT | Real-Time | QNXと直接比較可能 | Vehicle/Edge処理 | ★★★★★ |
| sched_ext | Scheduler拡張 | QNX schedulerとの比較が面白い | SoC workload最適化 | ★★★★☆ |
| XDP | 高速Network | Linux独自のnetwork拡張 | Ethernet Gateway | ★★★★☆ |
| cgroup v2 / PSI | Resource管理 | Linux multi-workload管理 | Android resource管理 | ★★★★☆ |
| Landlock / LSM | Security | Process isolationとの比較 | Android security | ★★★★☆ |
| KVM / Virtio / pKVM | Virtualization | QNX Hypervisorとの関係 | Cockpit / Domain Controller | ★★★★★ |
| Confidential Computing | Hardware isolation | QNXより下位レイヤの分離 | 将来のSDV | ★★★☆☆ |

---

# 12. QNXとModern Linuxを俯瞰する

非常に単純化すると、両者の方向性は次のように整理できる。

## QNX

```text
Small Microkernel
      |
Message Passing
      |
Process Isolation
      |
Deterministic Scheduling
      |
Safety / Real-Time
```

強み：

- Determinism
- Fault isolation
- Safety
- Real-Time
- Small TCB

---

## Modern Linux

```text
Linux Kernel
 |
 +-- PREEMPT_RT
 +-- eBPF
 +-- Rust
 +-- cgroup
 +-- namespace
 +-- LSM
 +-- KVM
 +-- io_uring
 +-- sched_ext
```

強み：

- Huge ecosystem
- Hardware support
- Androidとの親和性
- Cloud connectivity
- AI/GPU ecosystem
- 高い拡張性

Linuxは、

> 「巨大なMonolithic Kernelである」という弱点を、Isolation、Security、Observability、Memory Safety、Virtualizationによって補強する

方向に進化していると見ることができる。

---

# 13. Android Automotiveから見るとどうなるか

AAOSシステムをModern Linuxの観点で描くと、

```text
+-------------------------------------------+
|              Android Apps                 |
+-------------------------------------------+
|          Android Framework                |
|        Car Service / System Server        |
+-------------------------------------------+
|     Vehicle / Native Services             |
+-------------------------------------------+
|      AIDL / Binder / Socket / SOME-IP     |
+-------------------------------------------+
|              Linux Kernel                 |
|                                           |
| eBPF        PREEMPT_RT       cgroup/PSI   |
| XDP         SELinux/LSM      io_uring     |
| Rust        KVM/Virtio       sched_ext    |
+-------------------------------------------+
|      Ethernet / GPU / Storage / CAN       |
+-------------------------------------------+
|                Hardware                   |
+-------------------------------------------+
```

AAOSエンジニアにとってLinux Kernelの知識は、

> Androidより下の層で何が起きているか

を理解するために非常に重要になる。

特に、

```text
Binder latency
CPU scheduling
Network latency
Memory pressure
Driver issue
ECU communication delay
```

の解析ではLinuxの理解が大きな差になる。

---

# 14. QNXエンジニアがLinuxを学ぶ場合の重要ポイント

QNX経験者なら、Linuxを単なる別OSとして学ぶより、

```text
QNX concept
     ↓
Linux equivalent
```

で比較すると理解しやすい。

| QNX | Linux |
|---|---|
| Microkernel | Monolithic / Modular Kernel |
| Message Passing | IPC / Binder / Socket / D-Bus |
| Resource Manager | Driver / User-space daemon / FUSE等 |
| Priority Scheduling | SCHED_FIFO / SCHED_RR / DEADLINE |
| Real-Time | PREEMPT_RT |
| Process Isolation | namespace / LSM / seccomp |
| Hypervisor | KVM / other hypervisors |
| Tracing | ftrace / perf / eBPF |
| Network Stack | Linux Networking / XDP |
| Safety architecture | RT + isolation + hypervisor + certification strategy |

---

# 15. おすすめ学習順序

組込み・Android Automotive・QNXとの比較を目的とするなら、以下を推奨する。

```text
STEP 1
Linux Scheduling
   |
   v
STEP 2
PREEMPT_RT
   |
   v
STEP 3
ftrace / perf
   |
   v
STEP 4
eBPF
   |
   v
STEP 5
XDP
   |
   v
STEP 6
cgroup / PSI
   |
   v
STEP 7
KVM / Virtio
   |
   v
STEP 8
Rust for Linux
   |
   v
STEP 9
sched_ext
   |
   v
STEP 10
Confidential Computing
```

特に最初の重要なラインは、

```text
Linux Scheduler
      ↓
PREEMPT_RT
      ↓
ftrace
      ↓
eBPF
```

である。

この4つを理解すると、Modern Linuxのかなり重要な部分が見える。

---

# 16. 実際に手を動かすなら

学習用Linux PCまたはUbuntu環境で、

## Phase 1: 基本Observability

```bash
strace
perf
ftrace
trace-cmd
```

## Phase 2: eBPF

```bash
bpftrace
bpftool
libbpf
```

## Phase 3: Real-Time

```bash
chrt
taskset
cyclictest
```

以下を確認する。

```text
Scheduling policy
CPU affinity
IRQ affinity
Scheduling latency
```

## Phase 4: Resource Control

```bash
systemd-cgls
systemd-cgtop
cat /proc/pressure/cpu
cat /proc/pressure/memory
cat /proc/pressure/io
```

## Phase 5: Virtualization

```text
KVM
QEMU
Virtio
```

を使ってLinux Guestを起動し、Host / Guest間のresource sharingを理解する。

---

# 17. 結論

2026年のLinuxを理解するキーワードは、

```text
        Modern Linux

             |
  +----------+----------+
  |          |          |
Safety    Performance  Flexibility
  |          |          |
Rust      io_uring     eBPF
LSM       XDP          sched_ext
  |          |          |
  +----------+----------+
             |
         PREEMPT_RT
             |
        Virtualization
             |
       KVM / Virtio
```

と整理できる。

QNXが、

> **小さなMicrokernel + Message Passing + Isolation + Determinism**

を中心に発展してきたのに対し、Linuxは、

> **巨大なecosystemを維持しながら、Real-Time、Security、Isolation、Observability、Memory Safetyを後から非常に強力に進化させている**

点が特徴である。

Android Automotiveを扱う場合、この両者を理解すると、

```text
Safety / Control
       |
QNX / RTOS
       |
Hypervisor
       |
Linux / AAOS
       |
IVI / Connectivity / Cloud / AI
```

というSoftware Defined Vehicle全体のarchitectureを理解しやすくなる。

---

# 18. 参考資料

- Linux Kernel Archives  
  https://www.kernel.org/

- Linux Kernel Documentation  
  https://docs.kernel.org/

- BPF Documentation  
  https://docs.kernel.org/bpf/

- sched_ext Documentation  
  https://docs.kernel.org/scheduler/sched-ext.html

- Landlock Documentation  
  https://docs.kernel.org/security/landlock.html

- Rust for Linux Documentation  
  https://rust.docs.kernel.org/

- Android Open Source Project  
  https://source.android.com/

---

## Appendix: まず3つだけ学ぶなら

時間が限られている場合は、

1. **eBPF**
2. **PREEMPT_RT**
3. **Rust for Linux**

を推奨する。

QNXとの比較まで考えるなら、

1. **PREEMPT_RT**
2. **Linux Scheduler / sched_ext**
3. **KVM / Virtio**

の順でもよい。

Android Automotiveのトラブルシューティング能力を伸ばすなら、

1. **ftrace / perf / eBPF**
2. **cgroup / PSI**
3. **Linux Networking / XDP**
4. **Scheduler / CPU affinity**
5. **KVM / Virtio**

の順が実務的である。
