# Shift Left 開発

## 1. Shift Leftとは

Shift Leftとは、**従来は開発後半で行われることが多かったテスト・分析・検証（Verification）を、より早い開発段階から実施する考え方**である。

開発工程を左から右に並べた場合の「左 = 上流工程」に活動を移すことから、Shift Leftと呼ばれる。

```text
要件 → Architecture → 設計 → 実装 → Integration → Test → Release
  ←────────────── Shift Left ──────────────
```

ポイントは単に「上流で考える」ことではなく、**実際の分析・検証・テストを早期から継続的に実施すること**にある。


## 2. Shift LeftはSecurityだけではない

「Shift Left Security」という言葉をよく聞くが、Shift Left自体はSecurityに限定された概念ではない。

Security、Safety、Performance、Reliabilityなど、特に**非機能要件全般**に適用できる。

| 領域 | Shift Leftの例 |
|---|---|
| Security | TARA、Threat Modeling、SAST、SCA、脆弱性Scan |
| Functional Safety | HARA、Safety Analysis、FMEA / FMEDA |
| Performance | CPU、Memory、Latency Budgetの早期設定・検証 |
| Real-time | WCET、Scheduling、Priority、Deadlineの早期検証 |
| Reliability | Failure Mode分析、Fault Injection |
| Maintainability | Logging、Diagnostics、Update方法の設計 |
| Testability | Unit Test、Test Hook、CI、自動テスト |
| Software Quality | Design Review、MISRA、Static Analysis |
| Communication | Interface設計、通信量、Latencyの早期検証 |


## 3. 「昔から普通のSW開発では？」という点

これは基本的にその通り。

従来のSoftware Engineeringでも、

- 非機能要件を要件段階で定義する
- Architecture段階でPerformanceやReliabilityを考慮する
- Design Reviewを行う
- 問題を早期に発見する
- 後工程ほど修正コストが大きくなるため、上流で問題を潰す

といった考え方は以前から存在していた。

そのため、

> **Shift Left = 非機能要件を上流工程から考える**

だけでは、「昔からやっていたこと」と大きな違いはない。


## 4. Shift Leftで特に強調されるポイント

Shift Leftでは、

> **早く「考える」だけでなく、早く「検証する」**

ことが特に重要になる。

例えば従来は、

```text
Requirement
    ↓
Architecture
    ↓
Design
    ↓
Coding
    ↓
Integration
    ↓
System Test
    ↓
ここで本格的に問題を検出
```

となりがちだった。

Shift Leftでは、

```text
Requirement
    ↓
Safety Analysis / TARA

Architecture
    ↓
Performance Analysis
Architecture Analysis

Coding
    ↓
Unit Test
Static Analysis
SAST

Build / CI
    ↓
SCA
Vulnerability Scan
Automated Test

Integration
    ↓
Continuous Verification

System Test
    ↓
最終V&V
```

のように、**Verificationそのものを前倒しする**。


## 5. CI/CD・自動化との関係

現代のShift Leftでは、CI/CDや自動化Toolとの組み合わせが重要になる。

例えばDeveloperがCodeをCommitした段階で、

```text
Developer
    ↓
  Commit
    ↓
    CI
    ↓
┌─────────────────┐
│ Unit Test       │
│ Static Analysis │
│ MISRA Check     │
│ SAST            │
│ SCA             │
│ Vuln Scan       │
│ SBOM生成        │
└─────────────────┘
    ↓
  Build
```

といった検証を自動実行できる。

つまり、完成したSoftwareを最後に一括して検証するのではなく、**Development CycleそのものにVerificationを組み込む**。


# 車載ソフト開発でのShift Left

## 6. Functional Safety

Functional Safetyは、元々かなりShift Left的な開発プロセスになっている。

```text
Item Definition
     ↓
HARA
     ↓
Safety Goals
     ↓
Functional Safety Concept
     ↓
Technical Safety Concept
     ↓
HW / SW Requirements
     ↓
Implementation
     ↓
Verification
```

ECUが完成してからSafetyを確認するのではなく、要件・Architecture段階からSafetyを設計に織り込む。

代表的な要素：

- ISO 26262
- HARA
- Safety Goal
- ASIL
- FMEA / FMEDA
- Safety Mechanism


## 7. Cybersecurity

完成したECUに対して最後にPenetration Testを行うだけでは、問題が見つかった場合の修正コストが大きい。

Shift Leftでは、

```text
Requirements
     ↓
TARA

Architecture
     ↓
Threat Modeling
Secure Architecture

Coding
     ↓
Secure Coding
SAST

Build / CI
     ↓
SCA
OSS Vulnerability Scan
SBOM

System
     ↓
Penetration Test
```

のように段階的にSecurityを検証する。

最終的なPenetration Testをなくすのではなく、**その前の段階で可能な限りSecurity Issueを検出・修正する**。


## 8. ADASでのPerformance / Latency

例えばADASに、

> Camera入力からBrake要求まで100 ms以内

という要求があるとする。

実機統合後に初めて測定して、

```text
Camera       30 ms
Perception   50 ms
Decision     30 ms
Control      20 ms
-------------------
Total       130 ms
```

となった場合、要求の100 msを満たさない。

この段階では、単なるOptimizationでは対応できず、Architectureから変更しなければならない可能性がある。

Shift LeftではArchitecture段階から、

```text
Total Latency Budget = 100 ms

Camera       20 ms
Perception   35 ms
Decision     20 ms
Control      15 ms
Margin       10 ms
```

のようにLatency Budgetを各Componentへ割り振る。

そして、

- Simulation
- SIL（Software-in-the-Loop）
- Virtual ECU
- Prototype HW
- HIL（Hardware-in-the-Loop）

などを利用して、実車完成前から継続的にLatencyを検証する。


## 9. QNX / Hypervisor / SoCでの例

例えばSoC上にHypervisorを使用して、

```text
           SoC
            │
      QNX Hypervisor
      ┌─────┴─────┐
      │           │
     QNX        Linux
      │           │
 Safety系       ADAS等
```

という構成を作る場合を考える。

実機統合後になって、

- CPU不足
- Memory不足
- Boot Time超過
- Interrupt Latency増大
- Guest間の干渉
- Device競合

などが発覚すると、Architecture変更の影響が大きい。

そのためArchitecture段階から、

- CPU Core Allocation
- Memory Partitioning
- Interrupt Assignment
- Device Assignment
- VirtIO / Device Passthrough
- Scheduling
- Boot-time Budget
- Worst-case Latency

などを設計する。

さらにSimulationやPrototype環境を使い、可能な項目を実機統合より前から検証する。

これも車載におけるShift Leftの具体例である。


## 10. SOME/IP・ECU間通信

例えば、

```text
ECU-A ─── SOME/IP ─── ECU-B
  │                      │
Service                Client
```

という構成がある場合、実ECUを接続して初めて通信確認を行うのでは遅い。

Shift Leftでは、

1. Service Interfaceを定義
2. Service ID / Method / Eventを設計
3. Stub / Simulationを作成
4. SILでService Discoveryや通信を確認
5. Network Load / Latencyを確認
6. ECU完成後にHIL
7. 最後に実車試験

というようにVerificationを段階的に行う。

```text
       実車
        ↑
       HIL
        ↑
       SIL
        ↑
   Virtual ECU
        ↑
Architecture /
Interface Design
```

つまり、

> **「実ECU・実車がなくても検証できる範囲」を広げる**

こともShift Leftの重要な実践方法である。


## 11. Shift Leftの本質

Shift Leftそのものは、完全に新しいSoftware Engineeringの考え方ではない。

従来から、

> 「問題はできるだけ早い段階で見つけた方がよい」

という考え方は存在していた。

現代のShift Leftで特に強調されているのは、

> **後工程に集中していた分析・テスト・Verificationを、Simulation、Virtualization、SIL / HIL、Static Analysis、CI/CDなどを活用して、より早い開発段階から実際に、かつ継続的に実施すること**

である。

重要なのは、System Testや実車試験をなくすことではない。

```text
従来：

「最後に検証する」


Shift Left：

「最初から継続的に検証する」
```

これにより、

- Integration段階で初めて重大問題が発覚するリスクを減らす
- 実車試験で初めて問題が発覚するリスクを減らす
- Architectureの大規模な手戻りを減らす
- 問題修正のコストを下げる
- Software Quality / Safety / Securityを継続的に確認する

ことができる。


## まとめ

**Shift Left = 単に上流から非機能要件を「考える」ことではなく、従来後工程で行っていた分析・Verification・Testを、より早い開発段階から実際に実施すること。**

特に車載ソフト開発では、

```text
Requirements
     ↓
Architecture
     ↓
Design
     ↓
Implementation
     ↓
Integration
     ↓
Vehicle
```

というDevelopment Lifecycleに対して、

```text
Safety Analysis
Security Analysis
Static Analysis
Unit Test
Simulation
Virtual ECU
SIL
HIL
CI/CD
```

などを組み合わせることで、**実ECU・実車に到達する前に可能な限り多くの問題を発見する**ことがShift Leftの実践となる。