# 車載システム・E/Eアーキテクチャ整理

## 1. クルマの主要な機能ドメイン

クルマの機能は、大きく以下のように分類できる。

| Domain | 主な役割 | 代表的な機能 |
|---|---|---|
| Powertrain | 走る | Engine、AT、Motor、Inverter、e-Axle |
| Chassis | 曲がる・止まる | Steering、Brake、ABS、ESC、Suspension |
| Body | 車体・快適装備 | Door、Window、Sunroof、Seat、Light、Wiper |
| ADAS | 認識・判断・運転支援 | Camera、Radar、AEB、ACC、LKA、自動駐車 |
| Cockpit / Infotainment | 人とクルマのインターフェース | Meter、Display、Navigation、Audio |
| Connectivity / Telematics | 車外との通信 | 4G/5G、Wi-Fi、OTA、V2X、LBS |

簡単に覚えると、

- **Powertrain** = 走る
- **Chassis** = 曲がる・止まる
- **Body** = ドア・窓・ライトなど
- **ADAS** = 見る・判断する・運転を支援する
- **Cockpit** = 人に見せる・聞かせる・操作させる
- **Connectivity** = 車外とつなぐ

---

# 2. Powertrain

## 2.1 Powertrainとは

Powertrain（パワートレイン）とは、

> **動力を作り、その動力を車輪まで伝えるシステム全体**

を指す。

ガソリン車では、

```text
Engine
   ↓
Transmission
   ↓
Drive Shaft
   ↓
Differential
   ↓
Wheels
```

となる。

---

## 2.2 PowertrainとDrivetrainの違い

### Powertrain

動力を作る部分と、動力を伝える部分の両方を含む。

### Drivetrain

主として、作られた動力を車輪まで伝える部分。

```text
Powertrain
│
├─ Engine
│
└─ Drivetrain
    ├─ Transmission
    ├─ Drive Shaft
    ├─ Differential
    └─ Axle
```

概念的には、

```text
Powertrain > Drivetrain
```

と考えると分かりやすい。

---

# 3. AT（Automatic Transmission）

ATはPowertrainの一部であり、Drivetrainの一部でもある。

典型的なAT車では、

```text
Engine
   ↓
Torque Converter
   ↓
Automatic Transmission
   ↓
Drive Shaft
   ↓
Differential
   ↓
Wheels
```

となる。

ATは、エンジンの回転を走行状況に合わせて変速する。

例えば、

- 発進時：低いギアで大きな駆動力を得る
- 加速時：順次シフトアップする
- 高速走行時：高いギアでエンジン回転数を下げる
- 後退時：Rギアを使用する

---

# 4. ATの電子制御

現在のATは、機械だけではなくコンピュータによって制御されている。

代表的なのが、

- TCU：Transmission Control Unit
- TCM：Transmission Control Module

である。

```text
車速 ──────────┐
アクセル開度 ────┤
エンジン回転数 ──┤
ブレーキ ───────┤
油温 ──────────┤
                ↓
              TCU
                ↓
       油圧・ソレノイド制御
                ↓
               AT
```

TCUは、

- いつ変速するか
- 何速にするか
- クラッチをどうつなぐか
- 油圧をどの程度にするか
- Torque ConverterをいつLock-upするか

などを判断する。

Engine ECUともCANなどを経由して連携する。

```text
Engine ECU
     ↕
 CAN / CAN FD
     ↕
    TCU
```

例えば変速時に、

> 「今から変速するのでエンジントルクを一瞬下げて」

とTCUがEngine ECUへ要求することで、変速ショックを低減できる。

---

# 5. EVとe-Axle

EVでは、一般的なガソリン車のような6速、8速、10速ATを必要としない構成が多い。

そこで重要になるのが **e-Axle** である。

```text
Battery
   ↓
┌──── e-Axle ────┐
│ Inverter       │
│      ↓         │
│    Motor       │
│      ↓         │
│ Reduction Gear │
│      ↓         │
│ Differential   │
└────────────────┘
        ↓
      Wheels
```

e-Axleは主に、

- Motor
- Inverter
- Reduction Gear
- Differential

などを統合したEV用駆動ユニットである。

単純化すると、

```text
ガソリン車

Engine → AT → Wheels
```

に対して、

```text
EV

Battery → e-Axle → Wheels
```

となる。

---

# 6. Chassis

Chassisは、

> **曲がる、止まる、安定して走る**

ための機能を担当する。

代表例：

- Steering
- EPS（Electric Power Steering）
- Brake
- ABS
- ESC
- Suspension

したがって、

```text
Powertrain = 走る
Chassis    = 曲がる・止まる
```

と整理できる。

---

# 7. Body

Body Domainには、車体・快適装備に関連する機能が含まれる。

代表例：

- パワースライドドア
- パワーバックドア
- パワーウィンドウ
- サンルーフ
- パワーシート
- ドアロック
- 電動ミラー
- ヘッドライト
- ウインカー
- ワイパー

例えばパワーウィンドウでは、

```text
Window Switch
     ↓
Door ECU
     ↓
Motor Driver
     ↓
Window Motor
     ↓
Window
```

となる。

単純なON/OFFだけでなく、

- 挟み込み防止
- 全開・全閉位置検出
- Motor電流監視
- 車速との連携

なども電子制御される。

---

# 8. ADAS

ADASは、

**Advanced Driver Assistance Systems**

の略で、日本語では「先進運転支援システム」。

代表的な機能：

| 略称 | 正式名称 | 機能 |
|---|---|---|
| ACC | Adaptive Cruise Control | 前車追従 |
| AEB | Autonomous Emergency Braking | 自動緊急ブレーキ |
| FCW | Forward Collision Warning | 前方衝突警告 |
| LKA | Lane Keeping Assist | 車線維持支援 |
| LDW | Lane Departure Warning | 車線逸脱警告 |
| BSM/BSD | Blind Spot Monitoring / Detection | 死角車両検知 |
| RCTA | Rear Cross Traffic Alert | 後退時の横方向車両検知 |
| TSR | Traffic Sign Recognition | 標識認識 |
| APA | Automated Parking Assist | 自動駐車・駐車支援 |
| DMS | Driver Monitoring System | ドライバー監視 |

---

## 8.1 ADASの基本構造

ADASは、

> **見る → 判断する → 操作する**

と考えると分かりやすい。

```text
Camera
Radar
LiDAR
Ultrasonic
    ↓
  認識
    ↓
ADAS ECU
    ↓
  判断
    ↓
 ┌───┼─────────┐
 ↓   ↓         ↓
Brake Steering Powertrain
 ↓   ↓         ↓
止まる 曲がる    走る
```

ADAS自身がタイヤなどを直接動かすのではなく、

- Powertrain
- Brake
- Steering

などの別Domainと協調して車両を動かす。

---

# 9. 自動駐車

自動駐車は、複数Domainの協調制御の代表例である。

```text
Camera
Ultrasonic
    ↓
周辺認識
    ↓
ADAS / Parking ECU
    ↓
経路計算
    ↓
┌────────┬────────┬───────────┐
↓        ↓        ↓
Steering Brake   Powertrain
↓        ↓        ↓
曲がる    止まる    前進・後退
```

自動駐車はEV専用ではない。

ガソリン車でも、

- EPS
- 電子制御Brake
- 電子スロットル
- 電子制御AT

などをECUから操作できれば実現可能である。

---

# 10. Cockpit / Infotainment

Cockpit / Infotainmentは、人とクルマのインターフェースを担当する。

代表例：

- Instrument Cluster
- Meter
- Center Display
- Navigation
- Audio
- Smartphone Integration
- Apple CarPlay
- Android Auto

ADASが「運転を支援する領域」なのに対して、

> Cockpitは人に情報を提供し、人から操作を受け付ける領域

と整理できる。

---

# 11. LBS

LBSは、

**Location-Based Service(s)**

つまり「位置情報サービス」。

代表例：

- Navigation
- 周辺検索
- 駐車場検索
- EV充電ステーション検索
- ガソリンスタンド検索
- Traffic Information
- Geo-fencing
- 車両位置確認

```text
GPS / GNSS
     ↓
現在位置
     ↓
Navigation / LBS
     ↓
4G / 5G
     ↓
Cloud
     ↓
地図・交通・駐車場・充電情報
```

LBSは、

```text
Cockpit / Infotainment
        +
Connectivity / Telematics
```

の両方に関係する機能と考えられる。

---

# 12. ECUとは

ECUは、

**Electronic Control Unit**

であり、車両内の各機能を電子制御するコンピュータである。

従来は、

```text
Engine ECU
Transmission ECU
Brake ECU
Door ECU
Window ECU
Seat ECU
ADAS ECU
...
```

のように、多数のECUが搭載されてきた。

ただし、

> 「1機能 = 必ず1 ECU」

ではない。

複数機能を1つのECUが担当することもある。

---

# 13. ECU間通信

ECU同士は車載ネットワークを使って通信する。

代表的な通信方式：

| 通信 | 主な用途 |
|---|---|
| LIN | Door、Mirror、Seatなど |
| CAN / CAN FD | Powertrain、Body、Chassisなど |
| Automotive Ethernet | ADAS、Central Computer、大容量データ |
| SOME/IP | Ethernet上のサービス通信 |
| FlexRay | 一部の高信頼・時間制御用途 |

例えばCANでは、

```text
Engine ECU ─┐
TCU ────────┤
Brake ECU ──┼──── CAN Bus
EPS ECU ────┤
Body ECU ───┘
```

のように複数のECUがネットワークに接続される。

---

# 14. Automotive Ethernet

Automotive Ethernetは、まったく別のEthernetではない。

Ethernet技術をベースとしながら、

> **特にPHYや配線を車載環境向けにしたEthernet**

と考えると分かりやすい。

例えば、

```text
一般的なEthernet

1000BASE-T
複数のTwisted Pair
RJ45
```

に対して、

```text
Automotive Ethernet

1000BASE-T1
Single Twisted Pair
車載用Connector
```

などの違いがある。

車載では、

- 配線重量を減らす
- 配線量を減らす
- 電気的ノイズへの耐性
- 振動への耐性
- 高温・低温への耐性

などが重要となる。

一方、上位レイヤーでは、

```text
Application
    ↓
SOME/IP
    ↓
TCP / UDP
    ↓
IP
    ↓
Ethernet
    ↓
Automotive Ethernet PHY
```

のように、一般的なネットワーク技術との共通性が大きい。

---

# 15. Domain Controller

Domain Controllerは概念だけではなく、

> **実際に車両に搭載される高性能ECU**

である。

従来、

```text
Door ECU
Window ECU
Seat ECU
Lighting ECU
```

のように分散していた機能を、

```text
       Body Domain Controller
      ┌────────────────────┐
      │ CPU / SoC          │
      │ Memory             │
      │ CAN / CAN FD       │
      │ Ethernet           │
      │ OS / Software      │
      └─────────┬──────────┘
                │
       ┌────────┼────────┐
       ↓        ↓        ↓
      Door    Window    Light
```

のように統合できる。

代表的には、

- Powertrain Domain Controller
- Body Domain Controller
- Chassis Domain Controller
- ADAS Domain Controller
- Cockpit Domain Controller

などが考えられる。

---

# 16. E/E Architectureの進化

E/E（Electrical / Electronic）Architectureは、大きく見ると以下のように進化している。

## 16.1 Distributed ECU Architecture

```text
ECU   ECU   ECU   ECU   ECU
 ↓     ↓     ↓     ↓     ↓
Door Window Brake Engine Seat
```

機能ごとに多数のECUを持つ。

↓

## 16.2 Domain Architecture

```text
Powertrain Domain Controller
Body Domain Controller
Chassis Domain Controller
ADAS Domain Controller
Cockpit Domain Controller
```

機能単位でECUを統合する。

↓

## 16.3 Zonal + Central Compute Architecture

```text
             Central Computer
          ┌────────────────────┐
          │ Powertrain SW      │
          │ Body SW            │
          │ Chassis SW         │
          │ ADAS SW            │
          │ Cockpit SW         │
          └─────────┬──────────┘
                    │
           Automotive Ethernet
          ┌─────────┼─────────┐
          ↓         ↓         ↓
      Front Zone  Cabin     Rear Zone
         ECU      Zone ECU     ECU
          ↓         ↓         ↓
        Sensor    Door       Light
        Motor     Window     Sensor
```

Domainの機能ロジックをCentral Computer側へ集約し、物理I/OをZone ECU側へ配置する考え方である。

---

# 17. DomainとZoneの違い

非常に重要な違い。

| | Domain | Zone |
|---|---|---|
| 基準 | 機能 | 物理的位置 |
| 質問にすると | 「何をする？」 | 「どこにある？」 |
| 例 | Body、ADAS、Powertrain | Front、Rear、Left、Right |
| 主な役割 | 機能・Software | Sensor / ActuatorとのI/O |
| Central化 | Central Computerへ統合しやすい | 物理機器があるため残る |

一言でいうと、

```text
Domain = What
Zone   = Where
```

である。

Zonal Architectureになっても、

- Powertrain
- Body
- Chassis
- ADAS

という機能分類がなくなるわけではない。

---

# 18. Central Computer

Zonal Architectureでは、多くの高度な処理をCentral Computerへ集約できる。

```text
            Central Computer
       ┌─────────────────────┐
       │ Powertrain SW       │
       │ Body SW             │
       │ ADAS SW             │
       │ Cockpit SW          │
       └──────────┬──────────┘
                  │
         Automotive Ethernet
```

Central Computerでは、

- 車両機能
- 認識
- 判断
- Domainをまたぐ統合処理
- Application
- Middleware

などを実行できる。

QNXのようなOSが動作する場所の一つでもある。

---

# 19. Zone ECU

Zone ECUは、

> **物理的に近いSensor / Actuator / Switchなどを集約するECU**

である。

例えば右前のZone ECUなら、

```text
Window Motor ─┐
Door Lock    ─┤
Switch       ─┤
Sensor       ─┼→ Right Front Zone ECU
Light        ─┘          │
                         │
                Automotive Ethernet
                         │
                         ↓
                 Central Computer
```

のようになる。

機能が、

- Body
- Chassis
- Powertrain

のどれであるかより、

> **物理的に右前にある**

という理由で同じZone ECUへ接続できる。

---

# 20. なぜZone ECUは残るのか

SoftwareはCentral Computerへ集約できても、

- Camera
- Sensor
- Door
- Window Motor
- Light
- Brake
- Steering

などの物理デバイスは車体各部に存在する。

これをすべてCentral Computerまで直接配線すると、

```text
Window Motor ───────────────── Central
Door Lock    ───────────────── Central
Switch       ───────────────── Central
Sensor       ───────────────── Central
Light        ───────────────── Central
```

膨大なワイヤーハーネスが必要になる。

そこで、

```text
Local Devices
      ↓
   Zone ECU
      ↓
Automotive Ethernet
      ↓
Central Computer
```

とする。

これにより、

- 配線短縮
- ワイヤーハーネス削減
- 重量削減
- ECU統合
- ネットワーク構成の整理

などが可能になる。

---

# 21. Zonal化すると個々のDoor ECUなどはなくなるのか

Zonal Architectureの目的の一つは、

> **Door ECU、Window ECU、Lighting ECUなど多数の機能別ECUを減らし、Zone ECUへ集約すること**

である。

従来：

```text
Body Domain Controller
        │
      CAN
 ┌──────┼──────┐
 ↓      ↓      ↓
Door   Window  Light
ECU    ECU     ECU
 ↓      ↓       ↓
Motor  Motor   Lamp
```

Zonal：

```text
             Central Computer
                    │
          Automotive Ethernet
                    │
          Right Front Zone ECU
           ┌────────┼────────┐
           ↓        ↓        ↓
        Window     Lock    Mirror
         Motor     Motor    Motor
           ↑
         Switch
```

この場合、独立したDoor ECUをなくし、Zone ECUから直接I/Oを扱うことも可能になる。

---

# 22. ただし末端のECU / MCUが全部なくなるわけではない

Zonal Architectureになっても、

> **Central Computer + Zone ECUだけですべて処理するとは限らない**

点が重要。

例えばパワーウィンドウの挟み込み防止では、

```text
Window Motor
     ↓
異常な負荷を検出
     ↓
すぐにMotor停止
     ↓
Windowを逆方向へ
```

という高速なローカル制御が必要になる。

このような場合、

```text
Central Computer
       │
Automotive Ethernet
       │
    Zone ECU
       │
 LIN / CAN / Local Bus
       │
Small MCU / Smart Actuator
       │
 Window Motor
```

という構成も可能。

したがってZonal化の本質は、

> **ECUを全部なくすことではなく、機能ごとに乱立していたECUを統合し、必要な高速・安全・リアルタイム制御だけを末端に残すこと**

である。

---

# 23. 人間の身体にたとえる

Zonal E/E Architectureは、人間の神経系にたとえると理解しやすい。

| 人間 | クルマ |
|---|---|
| 脳 | Central Computer |
| 脊髄・神経幹 | Automotive Ethernet Backbone |
| 末梢神経の中継 | Zone ECU |
| 局所的な神経制御・反射 | Local ECU / MCU |
| 目・耳・皮膚 | Camera / Radar / Sensor |
| 筋肉 | Motor / Brake / SteeringなどのActuator |

全体として、

```text
              Central Computer
                    「脳」
                      │
             Automotive Ethernet
                  「神経幹」
                      │
                  Zone ECU
               「末梢の中継」
                      │
               Local ECU / MCU
                 「局所制御」
                      │
          ┌───────────┼───────────┐
          ↓           ↓           ↓
       Sensor       Motor       Brake
      「感覚器」     「筋肉」      「筋肉」
```

と考えることができる。

---

# 24. なぜ全部Central Computerで処理しないのか

すべての制御をCentral Computerで実行するとは限らない。

特に、

- Brake
- Steering
- Motor
- Windowの挟み込み防止

などでは、

- 高速応答
- Real-time性
- Functional Safety
- 障害時の独立性

などが重要になる。

そのため、

```text
          Central Computer
        高度な判断・統合処理
                │
       Automotive Ethernet
                │
             Zone ECU
        I/O・通信・局所処理
                │
          Local ECU / MCU
         高速・安全制御
                │
       Sensor / Actuator
```

という階層構造になる場合がある。

---

# 25. E/E Architecture全体像

```text
【Software / Function】

 Powertrain     Body      ADAS      Cockpit
      \           |         |          /
       \          |         |         /
        ┌──────────────────────────┐
        │     Central Computer     │
        │       CPU / SoC          │
        │       OS / QNX etc.      │
        │       Middleware         │
        │       Applications       │
        └────────────┬─────────────┘
                     │
           Automotive Ethernet
                     │
        ┌────────────┼────────────┐
        ↓            ↓            ↓
   Front Zone    Cabin Zone    Rear Zone
      ECU            ECU          ECU
        │             │            │
        └─────────────┼────────────┘
                      ↓
              Local ECU / MCU
                （必要な場合）
                      ↓

【Physical / I/O】

 Sensors / Cameras / Motors / Lights
 Switches / Brakes / Steering
 Doors / Windows / Seats
```

---

# 26. 最重要ポイント

今回の内容を短く整理すると、

```text
Powertrain = 走る
Chassis    = 曲がる・止まる
Body       = 車体機能
ADAS       = 見る・判断して運転を支援
Cockpit    = 人とクルマのInterface
Connectivity = 車外とつなぐ
```

E/E Architectureでは、

```text
Domain = What
         何の機能か

Zone   = Where
         物理的にどこにあるか
```

そしてZonal Architectureでは、

```text
Central Computer
       ↓
「頭脳」

Automotive Ethernet
       ↓
「神経幹」

Zone ECU
       ↓
「末梢の中継」

Local ECU / MCU
       ↓
「局所・リアルタイム制御」

Sensor / Actuator
       ↓
「感覚器・筋肉」
```

と捉えることができる。

---

# 27. SDVへのつながり

従来は、

```text
Hardware
   ↓
専用ECU
   ↓
専用Software
```

というように、機能とHardwareが強く結びついていた。

E/E Architectureの進化では、

```text
Distributed ECU
      ↓
Domain Controller
      ↓
Central Compute + Zonal Architecture
      ↓
Software Defined Vehicle
```

という方向へ進む。

重要なのは、

> **車両機能のSoftwareと、物理的なECU / Sensor / Actuatorの配置を徐々に分離していくこと**

である。

これによって、Central Computer上でさまざまなVehicle Softwareを実行し、Zone ECUを経由して実際の車両Hardwareを制御する構成が可能になる。

この領域が、QNX、Hypervisor、Vehicle Software Platform、Automotive Ethernet、SOME/IPなどの技術につながっていく。