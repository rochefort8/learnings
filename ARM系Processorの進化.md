# 最近のARM系Processorの進化

## 1. ARM Processorの最近の進化

最近のARM系Processorは、単なる「低消費電力CPU」から、PC、車載、サーバ、AIまでを狙う高性能なCompute Platformへ進化している。

主な進化の方向は以下のとおり。

- ARMv8からARMv9系への進化
- Out-of-Order実行の高度化
- シングルスレッド性能、IPCの向上
- big.LITTLEを発展させた異種CPU構成
- NEONからSVE / SVE2へのベクトル演算強化
- SME / SME2による行列演算・AI処理強化
- Cortex-Xによる高性能CPUコアの強化
- CPU、GPU、NPUを組み合わせたHeterogeneous Computing
- CPU IP単体からCompute Subsystemへの発展

従来、

```text
ARM = 低消費電力CPU
```

というイメージが強かったが、現在では、

```text
ARM = 高性能 + 低消費電力 + AI + Heterogeneous Computing
```

という方向へ変化している。

---

# 2. Out-of-Order CPUとしての進化

現在の高性能ARM CPUは、単純なPipeline型Processorではない。

概念的には、

```text
Fetch
  ↓
Branch Prediction
  ↓
Decode
  ↓
Register Rename
  ↓
Out-of-Order Scheduler
  ↓
┌─────────┬─────────┬────────────┐
│   ALU   │   ALU   │ Load/Store │
└─────────┴─────────┴────────────┘
  ↓
Retire
```

という、IntelやAMDの高性能CPUと同様の複雑な構造を持っている。

性能向上も単純なClock向上ではなく、

```text
Performance
    ≒
Clock
 × IPC
 × Memory Performance
 × Parallelism
```

として考える必要がある。

特に最近のARMでは、IPC（Instructions Per Cycle）の向上が重要になっている。

IPCを向上させることで、

```text
同じ処理量
   ↓
より短時間で終了
   ↓
CPUが早くIdleに戻る
   ↓
消費電力低減
```

というメリットも得られる。

---

# 3. big.LITTLE構成

## 3.1 big.LITTLEとは

big.LITTLEは、

**高性能なCPU Coreと省電力なCPU Coreを同じSoC内に搭載する構成**

である。

```text
┌────────────── SoC ──────────────┐
│                                 │
│   big Core       big Core       │
│   高性能          高性能         │
│                                 │
│   LITTLE Core    LITTLE Core    │
│   省電力          省電力         │
│                                 │
└─────────────────────────────────┘
```

重い処理ではbig Coreを使用し、

```text
Application起動
Game
Browser
Video処理
Compile
```

などを高速に処理する。

一方、

```text
Background処理
待ち受け
Telemetry
軽いDaemon
Audio再生
```

などはLITTLE Coreで処理する。

目的は、

> 必要なときだけ高性能Coreを使い、それ以外では消費電力を抑える

ことである。

Intelの、

```text
P-core = Performance Core
E-core = Efficiency Core
```

にも近い考え方である。

---

## 3.2 最近の構成

従来のbig.LITTLEは2種類のCPU Coreを組み合わせる考え方だった。

例えば、

```text
big       Cortex-A72
LITTLE    Cortex-A53
```

などである。

最近ではさらに進化して、

```text
Cortex-X       最大性能
Cortex-A7xx    中性能
Cortex-A5xx    省電力
```

という3段階構成も一般的になっている。

概念的には、

```text
1 × Cortex-X
3 × Cortex-A7xx
4 × Cortex-A5xx
```

のような構成になる。

アプリケーションが通常、

```text
この処理はbig Coreで実行する
```

と直接指定するわけではない。

Linux / AndroidのSchedulerが負荷を見ながら、

```text
重いTask
   ↓
Performance Core

軽いTask
   ↓
Efficiency Core
```

と配置を制御する。

---

# 4. NEON

## 4.1 NEONとは

NEONはARM CPUに搭載されているSIMD命令拡張である。

SIMDは、

**Single Instruction, Multiple Data**

の略。

1個の命令で複数のデータをまとめて処理する。

通常、

```text
a0 + b0
a1 + b1
a2 + b2
a3 + b3
```

という4回の演算が必要な場合でも、NEONでは概念的に、

```text
[a0 a1 a2 a3]
+
[b0 b1 b2 b3]
=
[c0 c1 c2 c3]
```

として並列に処理できる。

---

## 4.2 NEONの特徴

NEONのVector幅は基本的に128bitである。

例えば32bit整数なら、

```text
128bit ÷ 32bit = 4
```

なので4個の値を並列に処理できる。

用途としては、

- 画像処理
- Audio処理
- Video Codec
- DSP
- Signal Processing
- Machine Learning
- Sensor Processing
- Cryptography

などがある。

Intel系CPUでは、おおまかに、

```text
ARM NEON ≒ Intel SSE
```

という位置づけに近い。

---

# 5. SVE

## 5.1 SVEとは

SVEは、

**Scalable Vector Extension**

の略。

NEONを発展させたVector演算機構である。

NEONでは、

```text
128bit固定
```

だが、SVEでは、

```text
128bit
256bit
512bit
...
2048bit
```

までCPU実装によってVector長を選択できる。

重要なのは、Software側が特定のVector長を前提にしない設計を可能にしていることである。

同じプログラムを、

```text
CPU A : 128bit SVE
CPU B : 256bit SVE
CPU C : 512bit SVE
```

で動かすことができる。

SVEの狙いは、

> 大量の同じ種類のデータを効率よく並列処理すること

である。

用途は、

- HPC
- Scientific Computing
- AI
- Signal Processing
- Vector演算

など。

---

# 6. SVE2

SVE2はSVEをより一般用途向けに拡張したものである。

SVEが主にHPCなどを強く意識していたのに対して、SVE2では、

- DSP
- Multimedia
- Computer Vision
- Cryptography
- Machine Learning

などにも適用範囲が広がっている。

概念的には、

```text
NEON
  ↓
SVE
  ↓
SVE2
```

という発展として理解すると分かりやすい。

---

# 7. SME

## 7.1 SMEとは

SMEは、

**Scalable Matrix Extension**

の略。

行列計算を高速化するためのARMの拡張機能である。

特にAIでは、

```text
C = A × B
```

のようなMatrix演算が非常に多い。

Neural Networkでも、

```text
Y = W × X + B
```

のような計算が繰り返し行われる。

そのためCPU上でもMatrix演算を高速に処理できることが重要になっている。

---

## 7.2 ZA Array

SMEの特徴の一つが、ZAと呼ばれるMatrix Accumulatorである。

概念的には、

```text
          ZA

┌─────────────────┐
│                 │
│  Matrix         │
│  Accumulator    │
│                 │
└─────────────────┘
```

という2次元的なAccumulator領域を使う。

通常のVector演算では、

```text
Vector
  ↓
Vector
  ↓
Vector
```

という処理になる。

SMEでは、

```text
Vector A
    ×
Vector B
    ↓
┌──────────────┐
│      ZA      │
│    Matrix    │
│ Accumulator  │
└──────────────┘
```

としてMatrix演算の途中結果を効率よく蓄積できる。

---

# 8. NEON / SVE / SMEの関係

概念的には、

```text
NEON
  │
  └── SIMD / Vector
        ↓
       SVE
        ↓
       SVE2

SVE系
  +
Matrix演算機能
        ↓
       SME
        ↓
       SME2
```

となる。

単純にSMEがSVEを置き換えるわけではない。

役割の違いは、

```text
NEON
128bit SIMD

SVE
Scalable Vector Processing

SME
Matrix Processing
```

である。

例えば、

```c
for (int i = 0; i < N; i++) {
    c[i] = a[i] + b[i];
}
```

のような処理はVector演算なのでSVEが向いている。

一方、

```text
C = A × B
```

のようなMatrix演算はSMEが向いている。

---

# 9. Cortex-X

Cortex-XはARMのCPU Coreの中でも、

**最高性能を優先するCPU Core Family**

である。

従来のCortex-AシリーズではPerformance / Power Balanceを重視していたが、Cortex-Xでは、

> 消費電力を多少増やしてでもSingle Thread Performanceを高める

ことを重視している。

概念的には、

```text
Cortex-X
    ↓
最大性能

Cortex-A7xx
    ↓
中～高性能

Cortex-A5xx
    ↓
省電力
```

という役割分担になる。

Intelの構成にたとえるなら、

```text
Cortex-X     ≒ P-core

Cortex-A5xx  ≒ E-core
```

という感覚に近い。

---

## 9.1 Cortex-Xが高性能な理由

単純にClockが高いだけではない。

例えば、

- Fetch幅の拡大
- Decode性能向上
- Branch Predictor強化
- Out-of-Order Window拡大
- Execution Unit増加
- Cache大型化
- Memory Subsystem強化

などによってIPCを高めている。

---

# 10. Cortex-Xを使ったSoC構成

現在のSoCでは概念的に、

```text
             Cortex-X
          最大性能Core
               │
       ┌───────┴───────┐
       │               │
 Cortex-A7xx       Cortex-A7xx
   中性能            中性能

       Cortex-A5xx × N
          省電力
```

という構成が使われる。

特に、

- Application起動
- Browser
- JavaScript
- UI Rendering
- Navigation
- Game

など、Single Thread性能が重要な処理をCortex-Xが担当する。

---

# 11. Arm C1 Family

最近ARMではCPUのNaming / Platform戦略も変化している。

従来は、

```text
Cortex-X925
Cortex-A725
Cortex-A520
```

という名前が使われていた。

新しい世代では、

```text
C1-Ultra
C1-Premium
C1-Pro
C1-Nano
```

というC1 CPU Familyが登場している。

おおまかな役割としては、

```text
C1-Ultra
    ↓
最高性能

C1-Premium
    ↓
高性能

C1-Pro
    ↓
性能と効率のBalance

C1-Nano
    ↓
省電力
```

という位置づけになる。

注意点として、

```text
Cortex-C1
```

というCPU名ではない。

正しくは、

```text
Arm C1 CPU Family
```

あるいは、

```text
C1-Ultra
C1-Premium
C1-Pro
C1-Nano
```

と呼ぶ。

---

# 12. Heterogeneous Computing

最近のARM SoCはCPUだけを見ても全体像を理解しにくい。

現在は、

```text
                 SoC
                  │
       ┌──────────┼──────────┐
       │          │          │
      CPU        GPU        NPU
       │          │          │
 General       Graphics      AI
 Purpose       Compute     Inference
```

というHeterogeneous Computingが基本になっている。

CPUの中でも、

```text
Performance Core
Balanced Core
Efficiency Core
```

を使い分ける。

さらに、

```text
Scalar処理     → CPU
Vector処理     → NEON / SVE
Matrix処理     → SME
Graphics       → GPU
AI             → GPU / NPU / SME
```

のように処理を分担する。

---

# 13. 車載Processorとの関係

車載では、このHeterogeneous化が特に重要になる。

概念的には、

```text
                    Automotive SoC
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ↓                ↓                ↓
High Performance      Real-Time           AI
Application CPU       Processor          Accelerator
         │                │                │
       Linux            QNX / RTOS        NPU / GPU
       AAOS             Safety            ADAS
```

という構成が考えられる。

高性能Application Processorでは、

- AAOS
- Navigation
- Browser
- Media
- 3D UI
- Infotainment

などを処理する。

一方、

- Hard Real-Time
- Safety Critical Control
- Deterministic Processing

などについては、

- Cortex-R
- MCU
- Dedicated Safety Processor
- QNX
- RTOS

などと役割分担する。

したがって、

```text
Cortex-Xが速い
```

ということと、

```text
Cortex-XがReal-Time制御に最適
```

ということは別問題である。

---

# 14. ARM Processorの進化を一枚で整理

```text
                         ARM Processor

                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
        CPU性能             Vector / AI       System構成
          │                   │                   │
          ↓                   ↓                   ↓

     Cortex-A              NEON              big.LITTLE
          │                   │                   │
          ↓                   ↓                   ↓
     Cortex-X              SVE / SVE2      Heterogeneous
          │                   │              Computing
          ↓                   ↓                   │
      C1 Family          SME / SME2               ↓
          │                   │            CPU + GPU + NPU
          ↓                   ↓
   High Performance       AI / Matrix
```

---

# 15. まとめ

最近のARM Processorの進化を理解する上で重要なKeywordは、

```text
ARMv9
Out-of-Order
IPC
big.LITTLE
Cortex-X
C1
NEON
SVE
SVE2
SME
SME2
GPU
NPU
Heterogeneous Computing
```

である。

特に大きな変化は、

```text
昔

ARM
=
小型
省電力
Mobile向け
```

から、

```text
現在

ARM
=
High Performance CPU
+
Low Power CPU
+
Vector Processing
+
Matrix / AI Processing
+
GPU / NPU
+
Heterogeneous Computing
```

へ進化していることである。

車載Softwareの観点では、CPU Core単体だけを見るのではなく、

```text
ARMv9
+
Cortex-X / C1
+
SVE / SME
+
GPU / NPU
+
Virtualization
+
Real-Time
+
Functional Safety
```

まで含めてSoC全体を見ることが重要になっている。