# QNX RTOSのリアルタイム性能とその内部メカニズム
## 割り込み処理、スケジューリング、Context Switch、最悪応答時間（WCRT）の仕組み

対象：QNX OS 8.0 / ARM64 / マルチコアシステム

---

# 第1章 リアルタイム性能とは何か

## 1.1 リアルタイム性能の基本概念

リアルタイム性能を実現するうえで最も重要なのは、**処理を速くすることではなく、決められた時間内に処理が完了することを保証できるようにすること**です。

例えば、自動車の制御システムで「センサー入力から1ms以内に制御処理を完了する」という要件がある場合、通常は100µsで完了していても、まれに3msかかるのであれば、その要件を満たしていません。

リアルタイムシステムで重要なのは、平均実行時間よりも最悪実行時間です。

ここでいうリアルタイム性には、以下の概念があります。

- **Hard Real-Time**：デッドライン違反が許容されないシステム
- **Soft Real-Time**：多少のデッドライン違反があってもサービスを継続できるシステム
- **Determinism（決定性）**：処理時間や応答時間について、予測・解析可能な性質
- **Deadline（デッドライン）**：処理を完了しなければならない期限
- **Worst-Case Response Time（WCRT）**：最悪条件下で要求から完了までに必要な時間

QNXはHard Real-Timeシステムを構築するためのRTOSですが、QNXを採用するだけでアプリケーションの期限遵守が自動的に保証されるわけではありません。

## 1.2 リアルタイム性能を決定する6つの要素

| 技術 | 実現すること |
|---|---|
| プリエンプティブスケジューリング | 高優先度タスクを優先して実行する |
| 割り込み処理 | 外部イベントに素早く反応する |
| 優先度制御 | 重要な処理を先に実行する |
| メモリ管理 | ページフォルトなどによる遅延を抑える |
| CPUリソース管理 | 他の処理からの干渉を減らす |
| WCET解析 | 最悪実行時間を把握・評価する |

これらを組み合わせて、実行時間の予測可能性を高めます。

---

# 第2章 QNXがリアルタイム性能を実現する仕組み

## 2.1 優先度ベースのプリエンプティブスケジューリング

QNXは、基本的に実行可能なスレッドのうち、優先度が最も高いものを実行します。

例えば、以下の3つのタスクがあるとします。

| タスク | 優先度 | 処理内容 |
|---|---:|---|
| A | 50 | ブレーキ制御 |
| B | 30 | センサー処理 |
| C | 10 | ログ記録 |

Bが動作中にAがREADY状態になれば、カーネルはBをプリエンプトし、AにCPUを割り当てます。

ここで重要なのは、Aが自分の実行順番を待つのではなく、優先度によって即座に実行候補として選択される点です。

QNX 8.0では、主に次のスケジューリングポリシーをサポートしています。

- `SCHED_FIFO`：同じ優先度のスレッド間では、原則としてブロック、yield、プリエンプションなどが発生するまで実行を継続する
- `SCHED_RR`：同じ優先度のスレッド間でタイムスライスを使用する
- `SCHED_SPORADIC`：実行時間の予算を管理するスケジューリング方式

いずれも、高優先度のスレッドがREADYになれば、基本的には低優先度のスレッドより優先して実行されます。

公式資料：
[Scheduling policies — QNX 8.0](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_SchedulingAlgorithms.html)

## 2.2 マイクロカーネルアーキテクチャ

QNXでは、OSの中核機能を比較的小さなマイクロカーネルに集約し、さまざまなサービスやドライバーを独立したプロセスとして動作させます。

これにより、ドライバーなどの実行制御や優先度管理を明確にしやすくなります。

QNXのマイクロカーネルは、スレッドスケジューリング、同期、IPC、割り込み処理など、リアルタイムシステムに必要な基本機能を提供します。

ただし、マイクロカーネルを採用しただけで処理時間が保証されるわけではありません。

IPC、ドライバー、割り込み処理まで含めた設計が必要です。

## 2.3 優先度逆転への対応

高優先度スレッドAが、低優先度スレッドCの保持しているMutexを待つ場合、優先度逆転（Priority Inversion）が起こります。

例えば、次の状態を考えます。

- スレッドA：優先度80。Mutexを必要としている
- スレッドB：優先度50。通常の計算処理
- スレッドC：優先度20。Mutexを保持している

AはCのMutex解放を待ちますが、BがREADYになると、Cより優先度が高いBが実行されます。

その結果、Aは間接的にBの実行によって待たされます。

QNXでは、Mutexやメッセージ通信の優先度継承を利用することで、この問題を軽減できます。

例えば、CがAの優先度を一時的に継承すれば、Bによる不要な干渉を防ぎやすくなります。

ただし、優先度継承によってブロッキング時間がゼロになるわけではありません。CがMutexを保持する時間の上限も必要です。

公式資料：
[Priority inheritance and messages](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/ipc_Priority_inheritance_messages.html)

---

# 第3章 QNX 8.0における割り込み処理の内部動作

## 3.1 QNX 8.0のIST方式

QNX 8.0では、従来のISR（Interrupt Service Routine）方式から、IST（Interrupt Service Thread）を中心とした割り込み処理方式に変更されました。

QNX 7.x以前で使われていたユーザー定義ISR向けの`InterruptAttach()`は削除され、QNX 8.0では`InterruptAttachThread()`によってスレッドを割り込みに関連付けることができます。

割り込みの発生に応じて、通常のスレッドスケジューリング機構を利用してISTを実行します。

QNX 8.0には`InterruptAttachEvent()`も残っていますが、直接ISTを関連付ける`InterruptAttachThread()`が推奨されています。

公式資料：
[Migrating to QNX OS 8.0 — Kernel and process manager](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxsdp.migration/topic/kernel.html)

## 3.2 割り込みからアプリケーション実行まで

全体の流れを整理すると、以下のようになります。

```text
  Hardware Device
  (Ethernet / CAN / Sensor)
          |
          | IRQ
          v
  Interrupt Controller
  (GIC / APIC)
          |
          v
  CPU Exception
          |
          v
  QNX Microkernel
  Interrupt Exception Handler
          |
          | ISTをREADYに変更
          v
  QNX Scheduler
          |
          | Priority / CPU affinity
          v
  Context Switch
          |
          v
  IST (Interrupt Service Thread)
          |
          | デバイス処理
          | IPC / Pulseなど
          v
  Application Thread
          |
          v
  Control Processing
```

IST自身が制御処理を担当する場合には、別のアプリケーションスレッドへ通知する工程を省くこともできます。

## 3.3 STEP 1 — ハードウェアがIRQを発生する

例えば、Ethernetコントローラがデータを受信すると、ハードウェアが割り込みを発行します。

ARM64ではGIC、x86ではAPICなどの割り込みコントローラが、対象CPUコアへ通知します。

割り込みの発生には、デバイス、割り込みコントローラ、CPUという複数のハードウェア要素が関係します。

これらの遅延は、OSだけで完全に制御できるものではありません。

## 3.4 STEP 2 — CPUがException Handlerに入る

CPUは現在の実行状態に関する例外復帰情報を保持し、割り込み例外処理へ移行します。

QNXカーネルは、概念的には次の処理を行います。

1. 割り込み番号を特定する
2. 対応するISTを見つける
3. ISTをREADY状態にする
4. 対象割り込みをマスクする
5. 割り込みコントローラへEOI（End of Interrupt）を通知する

実際のマスクやEOIのタイミングは、ハードウェアや割り込み処理経路に依存します。

QNXは、このカーネル内処理を短く保つ設計になっています。

公式資料：
[Interrupt handling — QNX System Architecture](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_INTERRUPTHANDLING.html)

## 3.5 STEP 3 — スケジューラが実行スレッドを決定する

例えば、単一CPU上で以下の状態だとします。

| スレッド | 優先度 | 状態 |
|---|---:|---|
| IST | 80 | READY |
| Application A | 50 | RUNNING |
| Logger | 10 | READY |

ISTがREADYになると、スケジューラは優先度80のISTを選択し、Application Aをプリエンプトします。

ここで行われるのがContext Switchです。

- Application AのCPU実行コンテキストを保存する
- ISTのCPU実行コンテキストを復元する
- ISTの実行を再開する

QNXでは、カーネル呼び出し、例外、割り込みなどによってスケジューリング判断が行われます。

## 3.6 STEP 4 — ISTがデバイスを処理する

ISTは、割り込みを待つスレッドとして動作します。

例えば、次のような処理を実行します。

```c
for (;;) {
    if (InterruptWait(
            _NTO_INTR_WAIT_FLAGS_UNMASK,
            NULL) == -1) {
        // エラー処理
        break;
    }

    // デバイスの割り込み要因を確認
    // デバイスレジスタを処理
    // 必要ならアプリケーションへ通知
}
```

ISTはデバイスの割り込み要因を適切に処理してから、次の割り込み待ちに戻ります。

`_NTO_INTR_WAIT_FLAGS_UNMASK`を指定すると、割り込みのUnmaskと待機を組み合わせられます。

## 3.7 STEP 5 — アプリケーションスレッドを起床する

ISTが別のアプリケーションスレッドに処理を依頼する場合、Pulse、メッセージ通信、Semaphoreなどの仕組みを利用できます。

例えば、ISTがPulseを送信し、アプリケーション側の`MsgReceive()`が復帰して制御処理を開始する構成です。

ただし、ISTからアプリケーションに通知しただけでは、アプリケーションが即座に動くとは限りません。

アプリケーションの優先度、CPU affinity、他のREADYスレッドの状態に応じてスケジューラが判断します。

---

# 第4章 READY Queueの内部動作

## 4.1 READY Queueとは何か

QNXのリアルタイム性を理解する鍵は、次の3つです。

1. READY Queue：次に実行できるスレッドを優先度別に管理する
2. Context Switch：現在のスレッドから別のスレッドにCPUを切り替える
3. Interrupt Preemption：割り込みによって高優先度スレッドを実行可能にする

単一CPUで次の状態を考えます。

```text
CPU 0

RUNNING:
    Application A (Priority 50)

READY Queue:
    Priority 80 : IST
    Priority 60 : Thread B
    Priority 30 : Thread C
    Priority 10 : Logger
```

IRQが発生すると、ISTの状態がBLOCKEDからREADYへ変わります。

ISTの優先度80が現在のApplication Aの優先度50より高いため、カーネルはISTを実行対象として選択します。

## 4.2 READY Queueの順序

QNXでは、同じ優先度のスレッドの扱いも決まっています。

| イベント | READY Queueの扱い |
|---|---|
| 高優先度スレッドによるプリエンプション | 中断されたスレッドは同優先度Queueの先頭へ |
| BLOCKEDからREADYへの復帰 | 通常は同優先度Queueの末尾へ |
| `sched_yield()` | 同優先度Queueの末尾へ |
| `SCHED_RR`のタイムスライス満了 | 同優先度の次のスレッドへ切り替え |

高優先度スレッドの実行を妨げないことと、同一優先度間の実行順序の両方が重要です。

公式資料：
[Thread scheduling — QNX 8.0](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_SCHEDULING.html)

[Scheduling priority — QNX 8.0](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_Scheduling_priority.html)

---

# 第5章 Context SwitchでCPU内部に何が起きるか

## 5.1 ARM64を例にしたContext Switch

ここからは、AWS Gravitonなどでも利用されるARM64（AArch64）を例に説明します。

CPUが実行しているスレッドをApplication AからISTへ切り替えるとき、カーネルはApplication Aの実行状態を保存し、ISTの状態を復元します。

```text
          CPU 0
            |
     Application A
        RUNNING
            |
            | IRQ
            v
     Exception Handler
            |
            v
   Application Aの
   Contextを保存
            |
            v
       Scheduler
       ISTを選択
            |
            v
   ISTのContextを復元
            |
            v
        IST実行
```

## 5.2 CPUコンテキストの代表的な情報

| ARM64レジスタ | 役割 |
|---|---|
| `X0–X30` | 汎用レジスタ |
| `SP` | スタックポインタ |
| `PC` | 次の実行命令のアドレス |
| `PSTATE` | CPUの状態情報 |
| `ELR_EL1` | EL1例外復帰アドレス |
| `SPSR_EL1` | EL1例外復帰時の状態 |

また、処理内容によってはFP/SIMDレジスタなどの状態も管理する必要があります。

例外進入時に保存される情報と、スレッドのContext Switchで保存する情報は厳密には異なります。

例えば、割り込みでEL1に入る場合、ARMアーキテクチャは復帰先などの例外情報を専用レジスタへ保持します。

その後、OSが必要なレジスタ状態を管理します。

正確にどのレジスタをいつ保存するか、FP/SIMDをどう扱うかは、QNX 8.0のカーネル実装に依存します。

## 5.3 実行の流れ

1. CPU 0でApplication Aが動作中
2. IRQ発生
3. CPUがカーネルの例外処理へ移行
4. カーネルがISTをREADYへ変更
5. スケジューラがISTを選択
6. Application Aの再開に必要なコンテキストを保存
7. ISTのコンテキストを復元
8. 例外復帰経路を経てISTの実行を再開

この一連の処理がScheduling Latencyに関係します。

QNX公式資料では、例外ハンドラの最後の命令からドライバースレッドの最初の命令までをScheduling Latencyとして説明しています。

公式資料：
[Interrupt latency — QNX 8.0](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_Interrupt_latency.html)

---

# 第6章 マルチコアでのスケジューリングとIPI

## 6.1 マルチコアでは何が違うのか

AWS Graviton3のようなマルチコア環境では、単一CPUより複雑になります。

例えば、次の構成を考えます。

```text
CPU 0                        CPU 1
------------------           ------------------
Thread A                     Thread B
Priority 50                  Priority 20
RUNNING                      RUNNING

IRQ受信
    |
    v
Kernel
    |
    | ISTがREADY
    | Priority 80
    |
    | 必要ならIPI
    +-----------------------> CPU 1
                                   |
                                   v
                              Scheduler
                                   |
                                   v
                              IST実行
```

IPI（Inter-Processor Interrupt）は、CPUコアが別のCPUコアへ割り込みを送る仕組みです。

QNXでは、カーネルのスケジューラが別CPUに再スケジューリングを促すため、IPIが使われる場合があります。

実際の割り込み送信処理はハードウェア依存です。

ここで重要なのは、高優先度ISTがREADYになったからといって、必ずIRQを受信したCPUで実行されるとは限らないという点です。

## 6.2 スケジューラが考慮する条件

- ISTの優先度
- ISTが実行可能なCPU（runmask）
- 各CPUで実行中のスレッド
- CPUクラスタ
- スケジューリング構成

QNXのマルチコアスケジューラは、これらの制約を考慮して実行するCPUを決定します。

## 6.3 CPU affinityがリアルタイム性能に影響する理由

例えば、Ethernet割り込みがCPU 0へ配送される場合を考えます。

**構成A：IRQ処理とISTをCPU 0に配置**

```text
IRQ / CPU 0
    |
    v
Kernel / CPU 0
    |
    v
IST / CPU 0
```

CPU間通信を必要としない経路にできる場合があります。

**構成B：IRQはCPU 0、ISTはCPU 1**

```text
IRQ / CPU 0
    |
    v
Kernel / CPU 0
    |
    | IPI等
    v
Scheduler / CPU 1
    |
    v
IST / CPU 1
```

別CPUの再スケジューリングが必要な場合、IPIなどの追加コストが発生し得ます。

ただし、CPU 0に他の高優先度スレッドが集中している場合、CPU 1でISTを実行する方が有利なこともあります。

つまり、単純に「IRQとISTを同じコアへ配置すれば最速」とは限りません。

QNX 8.0では、CPU affinityを設定するためにclusterやrunmaskを利用します。

公式資料：
[Processor affinity, clusters, runmasks, and inherit masks](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.prog/topic/multicore_processor_affinity.html)

---

# 第7章 リアルタイム処理の遅延時間

## 7.1 Interrupt Latency、Scheduling Latency、End-to-End Latency

まず、次の3つを区別する必要があります。

**Interrupt Latency**

ハードウェア割り込みが発生してから、待機していたISTがカーネルから戻って最初の命令を実行するまでの時間です。

**Scheduling Latency**

カーネルの割り込み例外ハンドラの最後の命令から、ドライバースレッドの最初の命令までの時間です。

**End-to-End Latency**

センサー入力などのイベントが発生してから、最終的な制御出力が完了するまでの総遅延です。

これらは同じ意味ではありません。

## 7.2 時間軸で見た処理

```text
Time ------------------------------------->

Hardware
  | IRQ
  v
  +------+
         |
Kernel   v
         +---------+
                   |
Scheduler          v
                   +-------+
                           |
IST                        v
                           +-------------+
                                         |
IPC / Wakeup                             v
                                         +------+
                                                |
Application                                     v
                                                +---------+
                                                          |
                                                          v
                                                       Complete
```

各区間にはハードウェア処理、カーネル処理、スケジューリング、アプリケーション実行などが含まれます。

## 7.3 総遅延時間の計算

概念的には、次のように分解できます。

\[
T_{\mathrm{total}}=
T_{\mathrm{hardware}}+
T_{\mathrm{kernel}}+
T_{\mathrm{schedule}}+
T_{\mathrm{IST}}+
T_{\mathrm{IPC}}+
T_{\mathrm{app}}
\]

それぞれの時間は次を意味します。

| 要素 | 意味 |
|---|---|
| Hardware | デバイスからCPUまでの遅延 |
| Kernel | 例外処理など |
| Schedule | スレッド切り替え |
| IST | デバイス処理 |
| IPC | 通知・起床 |
| Application | アプリケーション本体の処理 |

例えば、説明用の仮想的な測定値は次のようになります。

| 処理 | 時間 |
|---|---:|
| Device → Interrupt Controller → CPU | 2µs |
| Kernel Exception Handler | 3µs |
| Scheduling / Context Switch | 4µs |
| IST処理 | 12µs |
| IPC / Application起床 | 6µs |
| Application処理 | 40µs |
| **合計** | **67µs** |

仮に1msのデッドラインがあるシステムなら、この例の観測値には余裕があります。

ただし、他の高優先度スレッドによる干渉やキャッシュミスによって最大遅延が増えるため、この67µsだけで期限遵守を保証することはできません。

---

# 第8章 遅延時間の最大値は決定的なのか

## 8.1 Determinismの本当の意味

QNXはリアルタイム処理の遅延時間を予測可能にするよう設計されていますが、遅延の最大値が常に一定、あるいは自動的に保証されるわけではありません。

例えば、割り込みからIST実行開始までの遅延時間を考えます。

| 割り込み | 遅延時間 |
|---|---:|
| 1回目 | 5µs |
| 2回目 | 7µs |
| 3回目 | 6µs |
| 4回目 | 12µs |
| 5回目 | 5µs |

ここで実測最大値は12µsですが、次回の割り込みでも12µs以内に収まる保証はありません。

重要なのは以下の違いです。

- **Observed Maximum**：実測した最大遅延
- **Worst-Case Latency**：想定する条件下で発生し得る最大遅延
- **Proven Upper Bound**：解析などによって成立が示された遅延の上限

ハードリアルタイムシステムでは、最後の「上限が保証できること」が特に重要になります。

例えば、「どのような許容動作条件でもISTが50µs以内に起動する」と証明できれば、遅延時間自体は毎回異なっても、上限が決定的であると言えます。

## 8.2 QNXが最大遅延を制御できる理由

QNXの公式ドキュメントでは、割り込み遅延について、最小遅延にCPUの割り込み禁止時間が加わるという関係を説明しています。

基本モデルでは、

\[
T_{\mathrm{worst}} \approx
T_{\mathrm{minimum}}+
T_{\mathrm{max\ interrupt\ disabled}}
\]

という考え方になります。

これは割り込み遅延の基本的な説明であり、実際にはハードウェアの遅延、割り込みマスク、ISTの優先度、CPU affinity、スケジューリング干渉を考慮する必要があります。

QNXは、割り込み禁止区間を短くし、優先度ベースのプリエンプションを利用することで、遅延の上限を小さく抑える設計になっています。

公式資料：
[Interrupt latency](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_Interrupt_latency.html)

## 8.3 最大遅延が保証できなくなるケース

例えば、優先度80のISTが割り込みによってREADYになったとしても、優先度90のスレッドが実行し続ければ、ISTは実行できません。

このスレッドが無限ループしていて、一切ブロックしなければどうでしょうか。

ISTの待ち時間には有限の上限が存在しなくなります。

したがってQNXであっても、次の要素を適切に制約する必要があります。

- 高優先度タスクの実行時間
- 優先度逆転
- 割り込みの発生頻度
- 共有リソースへのアクセス
- 長時間の割り込み禁止
- CPU affinityによる競合

## 8.4 QNXはHard Real-Time OSなのか

QNXはHard Real-Timeシステムを構築するためのRTOSです。

ただし、次のように区別する必要があります。

| 項目 | QNXが提供するもの | システム設計者が行うこと |
|---|---|---|
| 割り込み応答 | 低遅延で予測可能な処理経路 | ハードウェアを含めた上限評価 |
| スケジューラ | 固定優先度プリエンプション | 優先度・CPU配置の設計 |
| 同期 | 優先度継承など | ブロッキング時間の制限 |
| アプリケーション | 実行環境 | WCET解析と期限遵守の検証 |

QNXのDeterminismとは、遅延時間が常に同じになることではなく、適切な前提条件のもとで最大遅延を有界にできることです。

---

# 第9章 最悪応答時間（WCRT）はどうやって決まるのか

## 9.1 WCRTの構成要素

QNXのようなリアルタイムOSでは、最悪応答時間は、CPU上で動作するすべての関連スレッドの優先度、実行時間、起動周期、リソース競合によって決まります。

重要なのは、QNXカーネルが最悪応答時間を一律に決めているわけではないという点です。

ある制御スレッドが起動要求を受けてから処理を完了するまでを考えます。

\[
R=C+B+I+O
\]

| 記号 | 意味 | 具体例 |
|---|---|---|
| C | 自分自身の実行時間 | 制御計算に200µs |
| B | ブロッキング時間 | Mutex待ちで40µs |
| I | 高優先度処理による干渉 | 他のスレッドにCPUを奪われる |
| O | OS・割り込み等のオーバーヘッド | Context Switchなど |

この式は概念的な分解です。

実際には、干渉時間Iが応答時間Rに依存するため、単純な足し算では決まらないことがあります。

## 9.2 具体例：1ms周期の制御処理

単一CPUで、以下の3つのスレッドが`SCHED_FIFO`で動作しているとします。

| スレッド | 優先度 | WCET | 周期 |
|---|---:|---:|---:|
| A：センサー処理 | 80 | 60µs | 300µs |
| B：通信処理 | 70 | 100µs | 500µs |
| C：制御処理 | 50 | 200µs | 1,000µs |

今回はスレッドCの最悪応答時間を求めます。

QNXの固定優先度スケジューリングでは、AとBがREADYになると、優先度の低いCより優先して実行されます。

Cの処理200µsに加えて、AとBによる干渉時間を考えなければなりません。

## 9.3 最悪のタイミングを考える

単純化した固定優先度モデルでは、対象スレッドCの起動と同時に、AとBも起動する状況が最悪応答時間の候補になります。

例えば次のようになります。

```text
Time (µs)

       0    60      160     300  360     460
       |-----|-------|-------|----|-------|

A      [====]                [====]
       0-60                  300-360

B           [========]
            60-160

C                   [=======]     [=====]
                    160-300       360-420
```

このブロッキングなしの例では、Cは420µsで完了します。

しかし、Cに最大40µsのブロッキングが発生する可能性も考慮すると、応答時間の上限はさらに増えます。

以下ではブロッキングを含む解析を行います。

## 9.4 Response Time Analysis（RTA）の式

固定優先度プリエンプティブスケジューリングでは、代表的なResponse Time Analysisの式があります。

\[
R_i=C_i+B_i+
\sum_{j\in hp(i)}
\left\lceil\frac{R_i}{T_j}\right\rceil C_j
\]

ここで、

| 記号 | 意味 |
|---|---|
| \(R_i\) | 対象タスクの最悪応答時間 |
| \(C_i\) | 対象タスクの最悪実行時間 |
| \(B_i\) | 最大ブロッキング時間 |
| \(hp(i)\) | 対象より高優先度のタスク集合 |
| \(T_j\) | 高優先度タスクの周期 |
| \(C_j\) | 高優先度タスクの最悪実行時間 |

これは単一CPU、固定優先度、周期タスク、適切に制約されたブロッキングなどを仮定した基本モデルです。

割り込みやスケジューラのオーバーヘッドも、実際の解析では適切に含める必要があります。

## 9.5 実際の計算

先ほどの例で、Cのブロッキング上限を40µsとし、OSオーバーヘッドをWCET等に含めて評価済みと仮定します。

すると、

\[
R_C=200+40+
\left\lceil\frac{R_C}{300}\right\rceil60+
\left\lceil\frac{R_C}{500}\right\rceil100
\]

となります。

応答時間\(R_C\)が右辺にもあるので、繰り返し計算して値を確定させます。

初期値：

\[
R_C^{(0)}=200+40=240
\]

1回目：

\[
R_C^{(1)}=240+60+100=400
\]

2回目：

\[
R_C^{(2)}=240+120+100=460
\]

3回目：

\[
R_C^{(3)}=240+120+100=460
\]

値が変わらなくなりました。

したがって、このモデルでの結果は、

\[
\boxed{R_C=460\ \mu s}
\]

となります。

| 要素 | 時間 |
|---|---:|
| C自身の実行 | 200µs |
| ブロッキング | 40µs |
| Aの干渉（2回） | 120µs |
| Bの干渉（1回） | 100µs |
| **最悪応答時間** | **460µs** |

デッドラインが1,000µsなら、

\[
1000-460=540\ \mu s
\]

となり、540µsの余裕があります。

つまり、この解析モデルの前提条件がすべて成立するなら、スレッドCは1ms以内に完了できると評価できます。

---

# 第10章 WCET（最悪実行時間）はどうやって決めるのか

## 10.1 WCETを決める難しさ

ここが実際のシステム開発で最も難しい部分です。

例えば、制御処理CのWCETを200µsとしましたが、この値を決めるには次の要素を評価します。

| 要素 | 遅延の原因 |
|---|---|
| CPU命令実行 | 命令数、パイプライン、分岐予測 |
| Cache | L1/L2キャッシュミス |
| メモリ | DRAMアクセス、メモリ競合 |
| IPC | QNXの`MsgSend()` / `MsgReceive()` |
| 同期 | Mutexによる待ち |
| 割り込み | ISTや別の高優先度処理 |
| OS | システムコール、スケジューリング |

WCETを決める方法には、大きく2種類あります。

## 10.2 測定ベースの方法

多数の条件で実行時間を測定し、最大値を求めます。

QNXのKernel Event Traceなどを活用できます。

例えば、

- 通常負荷で測定する
- CPU高負荷で測定する
- メモリ高負荷で測定する
- I/O負荷を増やして測定する
- 多数の割り込みを発生させる
- 長時間実行する

といった検証を行います。

ただし、実測最大値は真のWCETの保証にはなりません。

## 10.3 静的解析・形式的な方法

制御フロー、命令実行時間、メモリアクセスなどを解析し、実行時間の上限を導出します。

複雑なCPUでは、キャッシュ、分岐予測、アウトオブオーダー実行、メモリ干渉のため解析が非常に難しくなります。

実際の組込み開発では、測定、解析、負荷試験、余裕時間の確保を組み合わせます。

---

# 第11章 マルチコアにおける最悪応答時間

## 11.1 単一CPUの解析をそのまま使えない理由

前章のRTAの式は単一CPUの基本モデルです。

AWS Graviton3のようなマルチコア環境では、CPU affinityによって実行CPUを固定できたとしても、次のような共有リソースが残ります。

- 共有キャッシュ
- メモリバス
- DRAM
- 割り込みコントローラ
- DMA
- CPU周波数や電力制御

そのため、別CPUの処理が直接プリエンプトしなくても、メモリ干渉によってWCETが増える可能性があります。

## 11.2 CPU affinityだけでは不十分

例えば、制御タスクをCPU 1に固定したとします。

```text
CPU 0                  CPU 1

Ethernet Driver        Control Task
Logger                 Priority 80
File I/O
```

CPU 0の処理がCPU 1を直接プリエンプトすることはありません。

しかし、CPU 0が大量のメモリアクセスを行うと、CPU 1の制御タスクにも遅延が生じる可能性があります。

したがって、Hard Real-Timeの上限解析では、CPUの配置だけでなく、共有ハードウェアリソースの干渉も評価する必要があります。

## 11.3 IPIによる追加遅延

CPU 0で割り込みが発生し、CPU 1でISTを起動する場合、CPU間の再スケジューリングが必要になることがあります。

その際には、IPIなどの追加オーバーヘッドを考慮する必要があります。

ただし、IPIを利用するかどうか、どの程度の遅延が発生するかは、カーネル構成とハードウェアに依存します。

---

# 第12章 QNXアプリケーションでの実装

## 12.1 1ms周期のリアルタイムスレッド

例えば、1ms周期で動作するリアルタイムスレッドをC言語で実装します。

```c
#include <pthread.h>
#include <sched.h>
#include <time.h>
#include <stdio.h>

static void add_ns(struct timespec *t, long ns)
{
    t->tv_nsec += ns;

    if (t->tv_nsec >= 1000000000L) {
        t->tv_sec++;
        t->tv_nsec -= 1000000000L;
    }
}

void *realtime_thread(void *arg)
{
    struct sched_param param = {
        .sched_priority = 50
    };

    int ret = pthread_setschedparam(
        pthread_self(),
        SCHED_FIFO,
        &param
    );

    if (ret != 0) {
        fprintf(stderr,
                "Scheduling failed: %d\n", ret);
        return NULL;
    }

    struct timespec next;
    clock_gettime(CLOCK_MONOTONIC, &next);

    while (1) {
        // 制御処理
        // do_control();

        add_ns(&next, 1000000L); // 1ms

        clock_nanosleep(
            CLOCK_MONOTONIC,
            TIMER_ABSTIME,
            &next,
            NULL
        );
    }

    return NULL;
}
```

このコードのポイントは、次の3点です。

- `SCHED_FIFO`：高優先度のスレッドを優先して実行する
- `sched_priority = 50`：スレッド優先度を設定する
- `TIMER_ABSTIME`：絶対時刻で周期を管理し、相対Sleepによるドリフトを防ぐ

ただし、これは周期動作の基本例です。

1ms以内の完了を保証するものではなく、優先度50を設定するための権限、処理時間超過の検出、割り込み遅延なども考慮する必要があります。

実運用では、時刻取得とスリープのエラー処理、期限超過時のポリシーも追加する必要があります。

## 12.2 ISTの実装例

QNX 8.0では、次のような構成で割り込み処理を実装できます。

```c
#include <sys/neutrino.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>

#define DEVICE_IRQ 76  // 例。実機のIRQを指定

void *ist_thread(void *arg)
{
    struct sched_param param = {
        .sched_priority = 80
    };

    int err = pthread_setschedparam(
        pthread_self(),
        SCHED_FIFO,
        &param
    );

    if (err != 0) {
        fprintf(stderr,
                "sched error: %d\n", err);
        return NULL;
    }

    int id = InterruptAttachThread(
        DEVICE_IRQ,
        _NTO_INTR_FLAGS_NO_UNMASK
    );

    if (id == -1) {
        perror("InterruptAttachThread");
        return NULL;
    }

    for (;;) {
        if (InterruptWait(
            _NTO_INTR_WAIT_FLAGS_UNMASK,
            NULL
        ) == -1) {
            perror("InterruptWait");
            break;
        }

        // デバイスの状態確認
        // 割り込み要因の処理
        // アプリケーションへの通知
    }

    InterruptDetach(id);
    return NULL;
}
```

これはISTの基本構造を示したコードです。

実際の動作には、IRQ番号、割り込み権限、デバイスレジスタ処理、CPU affinityなどの設定が必要です。

特に、デバイスの割り込み要因を適切に解除しないままUnmaskすると、割り込みが連続発生する可能性があります。

公式資料：
[Handling interrupts — QNX 8.0](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.getting_started/topic/s1_inter_Handling.html)

---

# 第13章 リアルタイム性能を高める方法

QNXでリアルタイム性能を高める場合、OSだけでなく、アプリケーションとハードウェアを含めた設計が必要です。

| 対策 | 具体的な方法 |
|---|---|
| CPU競合の抑制 | CPU affinity、CPUリソース分離 |
| メモリ遅延の抑制 | メモリの事前確保、ロック |
| 同期遅延の抑制 | Mutex保持時間の短縮、優先度継承 |
| 割り込み遅延の抑制 | ISTを短くし、割り込み禁止時間を抑える |
| I/O遅延の抑制 | リアルタイム経路での同期ディスクI/Oを避ける |
| キャッシュ干渉の抑制 | CPU配置、共有データ、メモリアクセスの最適化 |

特にマルチコアCPUでは、スレッドの優先度だけでなく、どのCPUコアで実行するかも重要です。

## 13.1 ISTの優先度

優先度が低いと、READYになってもCPUを取得できない可能性があります。

ただし、ISTを最高優先度にすればよいわけではありません。

ISTの仕事を短くし、他の重要なスレッドを阻害しないことが重要です。

## 13.2 CPU affinity

IRQが配送されるCPUとISTのaffinityの関係が重要です。

CPU間通信を避けることが有利なケースもありますが、同一CPU上で競合が増える場合には別CPUで実行する方がよいこともあります。

## 13.3 割り込みマスク時間

CPUの割り込み禁止区間やデバイス割り込みのマスク時間が長いと、応答遅延が増加します。

ISTが処理後に適切にUnmaskしない場合、次の割り込みを受けられなくなる可能性があります。

## 13.4 IPCとContext Switch

ISTから別スレッドへ仕事を渡す場合には、通知処理とスケジューリングのコストが追加されます。

非常に短い制御処理であればIST内で完結させる設計も検討対象になります。

ただし、ISTを長時間占有すると、そのデバイスの後続割り込み処理に影響します。

---

# 第14章 QNXでリアルタイム性能を測定する

## 14.1 Kernel Event TraceとSystem Profiler

QNX 8.0では、Kernel Event TraceとSystem Profilerを利用して、スケジューリングや割り込みの挙動を解析できます。

具体的には、次のイベントを観測します。

- IRQの発生
- スレッドのREADYへの遷移
- RUNNINGへの切り替わり
- Context Switch
- IPC・シグナルの発生
- スレッドのブロック
- CPU使用状況

## 14.2 ターゲットでの確認

まず、ターゲット上で次を確認します。

```sh
pidin ar
pidin threads
```

Kernel Event Traceを取得できる構成であれば、次のように実行します。

```sh
tracelogger -s 10
```

この例は、10秒間のトレースを取得することを意図しています。

ターゲットではトレース対応カーネルと必要な権限・保存領域が必要です。

取得した`.kev`ファイルをQNX System Profilerで開きます。

これにより、ISTがREADYになった時刻と、実際にRUNNINGになった時刻との差を観測できます。

公式資料：
[System Profiler](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.ide.userguide/topic/sysprofiler_tool.html)

[tracelogger](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/t/tracelogger.html)

## 14.3 測定だけでは保証にならない

大量の試験を行って、最大遅延が20µsだったとします。

それでも、次回の割り込みで30µsになる可能性は残ります。

したがって、実測最大値と解析による最悪値は明確に区別する必要があります。

リアルタイム保証では、許容するすべての条件で期限内に完了することが重要です。

---

# 第15章 QNXとLinux PREEMPT_RTの違い

| 観点 | 一般的なLinux | QNX RTOS |
|---|---|---|
| 主な目的 | スループット・公平性など | 決定性・リアルタイム制御 |
| 優先度制御 | `SCHED_FIFO`などが利用可能 | 固定優先度制御が基本 |
| プリエンプション | カーネル構成に依存 | リアルタイム向けに設計 |
| 割り込み処理 | カーネル・ドライバー構成に依存 | ISTなどを利用 |
| リアルタイム解析 | ftrace、rtlaなど | Kernel Trace、System Profiler |

LinuxもPREEMPT_RTを使うことで、高いリアルタイム性能を実現できます。

したがって、QNXだから自動的に速い、Linuxではリアルタイム制御ができない、という違いではありません。

QNXの優位性を評価する場合には、対象ハードウェア、負荷条件、必要な認証、ドライバー構成、応答時間の上限などを比較する必要があります。

---

# 第16章 QNX Containersでのリアルタイム性能

QNX 8.0のContainer環境でも、重要なのはコンテナそのものではなく、内部で動作するスレッドがどのようにスケジューリングされ、どのリソースにアクセスするかです。

コンテナ内のプロセスについても、スケジューリング権限、CPU・メモリ・IPC構成、コンテナ管理の制約を確認する必要があります。

実際には、以下の順番で検証するのがよいでしょう。

1. QNXネイティブ環境で1ms周期タスクを実装する
2. 最大遅延とジッターを測定する
3. 同じアプリケーションをQNX Container内で動作させる
4. 高負荷時の遅延を比較する
5. 必要に応じてCPU affinityや優先度を調整する

Containerの利用によって追加される管理処理やIPC経路の影響も、実際の構成で測定する必要があります。

---

# 第17章 実際のQNX開発での進め方

現実的には、以下の順番で進めます。

**STEP 1 — Deadlineを定義する**

例えば、センサー入力から制御出力まで1msとします。

**STEP 2 — タスク構成を決定する**

IST、通信処理、制御処理などの構成を決めます。

**STEP 3 — 各タスクのWCETを見積もる**

測定や解析によって実行時間の上限を評価します。

**STEP 4 — 優先度・周期・ブロッキング時間を決める**

スレッドの優先度、起動周期、Mutexの保持時間などを決定します。

**STEP 5 — WCRT解析を実施する**

すべてのタスクがデッドライン以内に完了可能か評価します。

**STEP 6 — 実機で負荷試験する**

最大遅延、ジッター、IPC、割り込みを測定します。

**STEP 7 — 解析モデルと測定結果を比較する**

必要に応じてWCET、ブロッキング上限、CPU配置、割り込み構成を見直します。

---

# 第18章 QNXカーネル自体のWCETは誰が保証するのか

ここまでの説明から、一つ重要な疑問が出てきます。

**「QNXカーネル自体のWCETは誰が保証するのか？」**

アプリケーション側で応答時間を計算できても、その計算に含まれるカーネル内部の処理時間が有界でなければ、システム全体の保証は成立しません。

例えば、

- 割り込み禁止時間の最大値
- Context Switchの最悪時間
- スケジューラ内部処理の最大時間
- IPCの最大処理時間
- メモリ管理の最悪処理時間

などについて、対象ハードウェアとソフトウェア構成で上限が成立する必要があります。

QNXの公式ドキュメントでは、割り込み遅延をハードウェア経路、割り込み禁止時間、スケジューリング遅延などに分解して説明しています。

しかし、その説明だけで、あらゆるCPU・周辺デバイス・負荷条件における単一の数値上限が保証されるわけではありません。

QNXがリアルタイムOSであることと、特定のハードウェア上で任意のアプリケーションのWCRTを保証できることは、明確に区別する必要があります。

---

# 第19章 まとめ

QNXのリアルタイム性能を実現する仕組みをまとめると、次のようになります。

```text
Hardware IRQ
     |
     v
Kernel Exception Handler
     |
     v
IST → READY
     |
     v
Priority Scheduler
     |
     v
Context Switch
     |
     v
IST → RUNNING
     |
     v
Application Processing
     |
     v
Deadline以内に完了
```

QNXの強みは、ハードウェアイベントを短いカーネル処理でスレッドの実行可能状態へ変換し、優先度スケジューラで迅速に実行へ移すことです。

しかし、リアルタイム性を保証するには、OSだけでなく、アプリケーション、ドライバー、ハードウェアを含めたシステム全体の解析が必要です。

重要なポイントは次のとおりです。

- リアルタイム性能とは、単なる処理速度ではなく、期限内に完了できること
- QNXでは固定優先度プリエンプティブスケジューリングを基本とする
- QNX 8.0ではISTを利用した割り込み処理が中心となる
- READY QueueとContext Switchが応答時間に関係する
- マルチコアではCPU affinityやIPIによる干渉も考慮する
- 最大遅延は実測値だけでは保証できない
- WCRTはWCET、ブロッキング、高優先度処理による干渉、OSオーバーヘッドから評価する
- Hard Real-Timeの保証には、システム全体の最悪条件を解析する必要がある

**QNXのDeterminismとは、毎回まったく同じ時間で動作することではなく、適切な条件のもとで応答時間の上限を解析・保証できるようにすることです。**

---

# 参考資料 — QNX OS 8.0公式ドキュメント

1. [QNX System Architecture — Interrupt handling](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_INTERRUPTHANDLING.html)
2. [QNX System Architecture — Interrupt latency](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_Interrupt_latency.html)
3. [QNX System Architecture — Thread scheduling](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_SCHEDULING.html)
4. [QNX System Architecture — Scheduling priority](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_Scheduling_priority.html)
5. [QNX System Architecture — Scheduling policies](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/kernel_SchedulingAlgorithms.html)
6. [QNX Programmer's Guide — Handling Hardware Interrupts](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.prog/topic/inthandler.html)
7. [QNX Getting Started — Handling interrupts](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.getting_started/topic/s1_inter_Handling.html)
8. [QNX Programmer's Guide — Processor affinity, clusters, runmasks, and inherit masks](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.prog/topic/multicore_processor_affinity.html)
9. [QNX System Architecture — Priority inheritance and messages](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/ipc_Priority_inheritance_messages.html)
10. [QNX Tool Suite — System Profiler](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.ide.userguide/topic/sysprofiler_tool.html)
11. [QNX Utilities Reference — tracelogger](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/t/tracelogger.html)
12. [Migrating to QNX OS 8.0 — Kernel and process manager](https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxsdp.migration/topic/kernel.html)

以上。