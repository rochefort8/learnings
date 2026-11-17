# QNX OS 学習まとめ

## 1. QNX OSとは

QNXは、**リアルタイム性と障害分離を重視したMicrokernel型RTOS**として理解すると全体像を捉えやすい。

```text
Application
     │
     │ POSIX API / IPC
     ▼
+----------------------------+
| Process Manager            |
| Filesystem                 |
| Network                    |
| Device Driver / Services   |
+----------------------------+
          ↕ IPC
+----------------------------+
|      QNX Microkernel       |
| Thread / Scheduling        |
| IPC / Interrupt etc.       |
+----------------------------+
          │
       Hardware
```

重要なのは、

> OSの機能をすべてKernelに入れるのではなく、小さなMicrokernelと独立した各種ServiceをIPCで結合する。

という設計思想。

---

## 2. Microkernel

QNXではKernelを小さく保ち、リアルタイムOSの中核となる処理を担当させる。

主な要素：

- Thread
- Scheduling
- Priority
- Preemption
- Interrupt
- IPC

Filesystem、Network、各種Service、Driverなど、多くの機能をKernelから分離できる。

### Microkernelのメリット

例えばDevice Driverで障害が発生した場合：

```text
Driver
  ↓
異常終了
  ↓
Processとして分離
  ↓
障害を局所化しやすい
```

Microkernel Architectureは、Realtimeだけではなく、**Fault IsolationやHigh Availabilityにも関係する**。

---

# 3. ProcessとThread

基本的な考え方はLinuxと似ている。

## Process

基本的に独立したVirtual Address Spaceを持つ実行環境。

## Thread

Process内部で、実際にCPU上で実行される単位。

```text
Process A
│
├─ Virtual Address Space
├─ Global variables ──┐
├─ Heap             ──┤ Shared
│                      │
├─ Thread A            │
│   └─ Stack A         │
│                      │
└─ Thread B            │
    └─ Stack B
```

同じProcess内のThreadはメモリ空間などを共有する。

一方、

- Stack
- Register state

などはThreadごとに持つ。

QNXのRealtime Schedulingを考える場合、重要な単位は**Thread**。

---

# 4. User ModeとKernel Mode

ThreadがSystem Callを呼び出すと、

```text
Thread B
User Mode
   │
   │ System Call
   ▼
Thread B
Kernel Mode
   │
   │ Kernel処理
   ▼
Thread B
User Mode
```

となる。

重要なのは、

> Kernel Modeに入ったから、別の「Kernel Thread」に変わるわけではない。

という点。

Thread BがCPUの特権レベルを変更してKernel Codeを実行している。

したがって概念的には、

```text
Thread B Priority = 20

User Mode   : Priority 20
Kernel Mode : Priority 20
```

と考えられる。

**Kernel ModeだからThread Priorityが高くなるわけではない。**

---

# 5. PriorityとPreemption

PriorityとPreemptionは別の概念。

例えば、

```text
Thread B Priority 10
         │
         ▼
      Kernel処理
         │
         │
Thread A Priority 50
         READY
```

となった場合、本来Schedulerは高PriorityのThread Aを実行させたい。

しかしKernelがその瞬間、

```text
Non-preemptible
```

な状態なら、即座にはThread Aへ切り替えられない場合がある。

つまり、

> **Priority = 次にどのThreadを実行したいか**

と、

> **Preemptibility = 今この瞬間にThreadを切り替えられるか**

は別の問題。

---

# 6. Non-preemptible区間

Non-preemptibleになる可能性がある代表例：

- Kernel内部のCritical Section
- Lock保持中
- 共有Kernel Dataの更新
- 一部のLow-level処理
- Interruptを一時的にMaskする処理

概念的には、

```text
Thread B
    │
    ▼
Critical Section
    │
    │ ← Thread A（High Priority）がREADY
    │
    │   まだ切替できない
    ▼
Critical Section終了
    │
    ▼
Scheduler
    │
    ▼
Thread A
```

Realtime OSにとって重要なのは、

**「高Priority Threadが最大でどの程度待たされる可能性があるか」**

というWorst-case latency。

---

# 7. Real-timeとは「速い」ことではない

重要なのは、

```text
Performance ≠ Real-time
```

という点。

Realtimeで重要なのは、

> **Deadlineまでに処理を完了できること**

例えば：

| OS | 通常Latency | Worst Case |
|---|---:|---:|
| OS A | 5 µs | 10 ms |
| OS B | 20 µs | 50 µs |

平均的にはOS Aの方が高速。

しかしDeadlineが100 µsなら、OS Bの方がRealtime用途に適している可能性がある。

---

# 8. Deterministic

Realtimeを考える上で重要なのが**Determinism（決定性）**。

QNX / RTOSの文脈では、

> 処理時間、応答時間のWorst Caseを予測・制御できること

と考えると分かりやすい。

```text
高速
 │
 └─ 平均処理時間が短い

Deterministic
 │
 └─ Worst-case latencyを予測・制御しやすい

Real-time
 │
 └─ Deadlineを満たす
```

この3つは同じ意味ではない。

---

# 9. QNXのScheduling

QNXではPriority-based preemptive schedulingが基本的な考え方になる。

```text
Priority 50  Thread A
Priority 30  Thread B
Priority 10  Thread C
```

Thread AがReadyになれば、低Priority ThreadよりAを優先して実行する。

同じPriorityのThread間ではScheduling Policyが関係する。

代表例：

- FIFO
- Round Robin
- Sporadic

## EDFとの違い

Earliest Deadline First（EDF）は、

```text
Deadlineが最も近いTask
        ↓
      最優先
```

というScheduling方式。

したがって、

- Priority-based Scheduling
- Earliest Deadline First

は別のScheduling戦略。

---

# 10. Adaptive Partitioning

Priorityとは別の軸として、Adaptive Partitioningがある。

例えば：

```text
CPU
│
├─ Safety   50%
├─ IVI      30%
└─ Other    20%
```

のように、アプリケーション群ごとのCPU Budgetを管理する。

重要な違い：

> **Priority = Thread間の実行優先順位**

> **Adaptive Partitioning = グループごとのCPU時間管理**

負荷が低いときには余っているCPUを利用でき、CPU競合が発生すると設定されたBudgetが意味を持つ。

---

# 11. Cortex-A / Application ProcessorとRealtime

高性能Application Processorでは、MCUなどと比較してTimingが複雑になる。

```text
CPU Core
   ↓
L1 Cache
   ↓
L2/L3 Cache
   ↓
Interconnect
   ↓
Memory Controller
   ↓
DDR
```

さらに、

- Cache miss
- TLB miss
- DDR latency
- 他Coreとのメモリ競合
- Cache coherency
- Multicore

などがWorst-case execution timeに影響する。

したがって、

> **CPUは高速になったが、Worst-case timingの予測は複雑になる**

という問題がある。

これはARM Cortex-Aだけの問題ではなく、Intel x86などの高性能Processorにも共通する。

---

# 12. LinuxとのRealtime性の違い

単純に、

```text
QNX   = Microkernel
Linux = Monolithic Kernel
```

だからQNXの方がRealtime、というだけでは不十分。

重要なのは、

```text
High Priority Thread becomes READY
              ↓
その瞬間にCPUを渡せるか？
              ↓
Kernel / Interrupt / Lockなどで
待たされる可能性
              ↓
Worst-case latency
```

という点。

Linuxは歴史的にGeneral Purpose OSとして、

- Throughput
- Fairness
- Hardware Support
- General Purpose Computing

なども重視してきた。

一方QNXはRTOSとして、**Latencyの予測可能性を重要な設計目標**としている。

なお、LinuxにもPREEMPT_RTがあり、

> Linux = Realtimeには使えない

という理解も正確ではない。

---

# 13. IPCとMessage Passing

Microkernel Architectureを成立させる上で重要なのがIPC。

QNXの基本的なMessage Passingのイメージ：

```text
Client Thread
      │
      │ MsgSend()
      ▼
Server Thread
      │
      │ Processing
      ▼
   MsgReply()
      │
      ▼
Client Thread
```

QNXでは単に、

> 「Process間通信APIがある」

だけではない。

**独立したOS ServiceをMessage Passingによって結合する**

というOS ArchitectureそのものにIPCが深く関係している。

---

# 14. Real-timeとHigh Availability

Real-time（RT）とHigh Availability（HA）は、**別の非機能要件**。

| 観点 | Real-time | High Availability |
|---|---|---|
| 問題 | Deadline内に処理できるか | 障害が起きてもサービスを継続できるか |
| 注目対象 | Time / Deadline | Failure / Recovery |
| 代表的概念 | Priority、Preemption、Latency | Monitoring、Fault Detection、Recovery |
| 目標 | Deterministic Execution | Service Availability |

したがって、

```text
Real-time性能が高い
        ≠
High Availabilityが高い
```

となる。

---

# 15. HAM（High Availability Manager）

QNXにはHigh Availabilityを実現するためのHAMがある。

HAMはProcessやServiceを監視し、

- Process Failure
- Service Failure
- 無応答
- 許容できないService状態

などに対してRecoveryを実行する「Smart Watchdog」と考えることができる。

基本的な流れ：

```text
Process / Service
       │
       ▼
    Monitor
       │
       ▼
   Fault / Event
       │
       ▼
      HAM
       │
       ▼
Recovery Action
```

HA FrameworkではPublish / Subscribeの仕組みを使ってSystem Eventを扱える。

HAM自身だけでなく、外部Detectorから異常Eventを通知することも可能。

```text
External Detector
       │
       │ Event
       ▼
      HAM
       │
       ▼
     Action
       │
       ▼
    Recovery
```

## Multistage Recovery

HAMでは、段階的なRecoveryを考えることができる。

例えば概念的には、

```text
異常検出
   ↓
Service Restart
   ↓
復旧しない
   ↓
次のRecovery Action
   ↓
さらに上位のRecovery
```

An HA system must also consider Single Point of Failure（SPOF）。

HAM自体が重要な監視・Recoveryコンポーネントなので、

> **HAM自身がSPOFにならないようにする**

ことも重要。

---

# 16. QNX HAMとLinux systemd

QNX HAMとLinux systemdは類似する部分があるが、同じものではない。

| 観点 | QNX HAM | Linux systemd |
|---|---|---|
| 主目的 | High Availability | Service / System Management |
| Process監視 | ○ | ○ |
| 自動再起動 | ○ | ○ |
| ハング監視 | ○ | ○ Watchdog |
| Event → Action | HA Frameworkとして設計 | Unitなどで構築 |
| Multistage Recovery | 明確に想定 | 複数機能を組み合わせる |
| 外部Detector | ○ | 可能だが仕組みは異なる |
| HA専用Framework | Yes | No |

したがって、

```text
HAM ≠ systemd
```

と考えるべき。

一方でLinuxでは、

```text
systemd
   +
Service Watchdog
   +
Linux / Hardware Watchdog
   +
必要ならHA Cluster機構
```

などを組み合わせることで、HAMと重なる機能を実現できる。

---

# 17. QNX OS全体の関係

ここまでを一本につなげると以下のようになる。

```text
                 QNX OS
                    │
          Microkernel Architecture
                    │
          ┌─────────┴─────────┐
          │                   │
       Thread                IPC
          │                   │
       Priority        Process Isolation
          │                   │
     Preemption               │
          │                   │
     Worst-case             Fault
       Latency             Isolation
          │                   │
     Determinism              │
          │                   │
      Real-time              HAM
          │                   │
          │                Recovery
          │                   │
          ▼                   ▼
         RT                  HA
```

Microkernelという共通のArchitecture上に、

- **Real-time**
- **Fault Isolation**
- **High Availability**

という異なる要求・特性が乗っている、と整理すると理解しやすい。

---

# まとめ

QNX OSを一文でまとめると：

> **QNX OSは、小さなMicrokernelを中心として、ThreadベースのPriority Schedulingと予測可能なPreemptionによってリアルタイム性を追求し、OS ServiceやDriverをProcessとして分離してMessage Passingで連携させることで障害分離性を高め、さらにHAMなどの仕組みによる障害検出・RecoveryによってHigh Availabilityを実現できるRTOSである。**

## キーワードの関係

```text
QNX
│
├─ Architecture
│   ├─ Microkernel
│   ├─ Process
│   ├─ Thread
│   └─ Message Passing / IPC
│
├─ Real-time
│   ├─ Priority
│   ├─ Scheduling
│   ├─ Preemption
│   ├─ Interrupt
│   ├─ Latency
│   └─ Determinism
│
├─ Resource Management
│   └─ Adaptive Partitioning
│
└─ High Availability
    ├─ Fault Detection
    ├─ HAM
    ├─ Event
    ├─ Recovery
    └─ Fault Isolation
```