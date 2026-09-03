# 車載OTA（Over-the-Air Update）の歴史

## 1. 概要

車載OTA（Over-the-Air Update）は、車両に搭載されたソフトウェアやファームウェアを、無線通信を通じて遠隔更新する仕組みである。

車載OTAは、以下のような段階を経て発展してきた。

1. ディーラーでの手動ソフトウェア更新
2. ナビゲーション地図・テレマティクス情報の更新
3. IVI（In-Vehicle Infotainment）のOTA更新
4. ECUソフトウェアのOTA更新
5. ADASや車両制御機能のOTA更新
6. 車両全体を継続的に進化させるWhole Vehicle OTA
7. SDV（Software Defined Vehicle）のソフトウェア配信基盤

現在ではOTAは単なる「更新機能」ではなく、SDVを成立させるための重要な基盤技術となっている。

---

## 2. 1990年代〜2000年代前半：OTA以前

当時の車載ソフトウェア更新は、基本的にディーラーで実施されていた。

代表的な更新方法は以下である。

- ECUを診断機経由で書き換える
- ナビゲーション地図をCD/DVDで更新する
- HDDナビのデータを書き換える
- 不具合修正時にはユーザーがディーラーへ車両を持ち込む

一方で、GMの **OnStar** などのテレマティクスサービスが登場し、車両がセルラー通信を利用して外部サーバーと接続する環境が整い始めた。

```text
Cloud
  |
Cellular Network
  |
Telematics ECU
```

この時代は、現在のOTAというよりも **Connected Carの基盤形成期** と考えることができる。

---

## 3. 2000年代後半〜2010年代前半：地図・IVI OTA

セルラー通信モジュールを搭載する車両が増えるにつれて、無線通信経由の更新が徐々に始まった。

最初にOTAの対象となったのは、比較的安全性への影響が小さい領域である。

主な対象は以下だった。

- Navigation Map
- Traffic Information
- POIデータ
- Infotainment
- Telematics関連ソフトウェア

典型的な構成は以下のようになる。

```text
Cloud
  |
Cellular
  |
TCU
  |
IVI / Navigation
```

Powertrain、Brake、SteeringなどのECUは、更新失敗時に走行安全へ直接影響するため、まだOTA対象にはしにくかった。

---

## 4. 2012年〜：Teslaによる大きな転換

車載OTAの歴史における大きな転換点が、**Tesla Model S（2012年）** である。

Teslaは車両をネットワーク接続されたコンピュータに近い思想で設計し、OTAによる継続的なソフトウェア更新を本格的に採用した。

OTA対象は単なるナビゲーションやIVIにとどまらず、以下へ拡大した。

- UI
- Navigation
- Battery Management
- Charging
- ADAS
- Autopilot
- Vehicle Controls
- Performance tuning

この考え方によって、

> 車は販売された時点で完成するのではなく、販売後もソフトウェアによって進化する

という新しい自動車の価値モデルが広く認識されるようになった。

---

## 5. 2018〜2020年：既存OEMも本格参入

Teslaの成功を受けて、従来型OEMもOTA機能を本格的に導入し始めた。

代表的なメーカーには以下がある。

- BMW
- Mercedes-Benz
- Volkswagen
- Ford
- Volvo
- GM

BMWでは **Operating System 7** 世代からRemote Software Upgradeを本格展開した。

OTA対象も次第に拡大した。

```text
Navigation
Android Auto
Voice Assistant
ADAS
eDrive
Vehicle Settings
```

この頃から、単なる

**IVI OTA**

ではなく、

**Vehicle OTA**

という考え方が広がっていった。

---

## 6. 2020〜2022年：Whole Vehicle OTA

次の段階では、車両内の多数のECUをOTA更新可能にする **Whole Vehicle OTA** が登場した。

Fordの **Power-Up** などが代表例である。

OTA対象は以下のように広がった。

- IVI
- ADAS
- Body ECU
- Gateway
- Powertrain関連ECU
- Battery関連ECU
- Connectivity ECU

典型的な車載OTA構成は以下のようになる。

```text
               Cloud
                 |
              Cellular
                 |
                TCU
                 |
           OTA Manager
                 |
        Central Gateway
        /      |       \
      IVI     ADAS     Body
                       /   \
                     ECU   ECU
```

OTA Managerは、車両内の複数ECUへソフトウェアを安全に配布・インストールする役割を持つ。

---

## 7. OTAとE/Eアーキテクチャの変化

OTAの普及は、車両のE/E（Electrical/Electronic）アーキテクチャにも大きな影響を与えた。

### 従来型：Distributed Architecture

従来車では、多数の独立ECUがCANなどのネットワークで接続されていた。

```text
ECU   ECU   ECU   ECU   ECU
 |     |     |     |     |
CAN   CAN   CAN   CAN   CAN
```

この構造では、

- ECUごとにSoCが異なる
- ECUごとにOSが異なる
- ECUごとにサプライヤーが異なる
- Flash方式が異なる
- Bootloaderが異なる
- Update方式が異なる

といった問題があり、車両全体をOTA更新することが難しかった。

---

### Centralized / Zonal Architecture

SDVでは、車両コンピューティングを中央集約する方向へ進んでいる。

```text
              Central Computer
              /      |       \
         Zone ECU  Zone ECU  Zone ECU
           |         |         |
        Sensors   Actuators   Sensors
```

Central Computerには以下のような高性能SoCが使用される。

- Qualcomm Snapdragon Ride / Cockpit
- NVIDIA DRIVE
- Renesas R-Car
- NXP S32
- Intel / Mobileye系SoC
- 各OEM独自SoC

この中央集約化によって、OTA対象をより効率的に管理できるようになる。

---

## 8. 2021年〜：UN-R156とSUMS

OTAの普及に伴い、ソフトウェア更新自体が法規制・型式認証の対象となった。

重要な規則が、

**UNECE UN Regulation No.156**

である。

UN-R156では、メーカーに対して

**SUMS（Software Update Management System）**

の構築が求められる。

主な要求項目には以下がある。

- ソフトウェアバージョン管理
- 更新データのIntegrity確認
- 更新元のAuthenticity確認
- 車両とのCompatibility確認
- 更新対象車両の管理
- 更新失敗時のRecovery
- Battery状態確認
- 更新中の安全確保
- ユーザーへの通知
- Type Approvalへの影響管理

これにより、OTAは単なる便利機能ではなく、

**Cybersecurity / Safety / Vehicle Regulation**

の一部となった。

---

## 9. OTA Updateの基本フロー

現在の典型的なOTA更新は、以下のような流れになる。

```text
Developer
   |
   v
CI/CD
   |
   v
OTA Backend
   |
   v
Internet
   |
   v
TCU
   |
   v
OTA Manager
   |
   v
Gateway
   |
   +----> IVI
   |
   +----> ADAS ECU
   |
   +----> Body ECU
   |
   +----> Powertrain ECU
```

実際には、単にソフトウェアをダウンロードするだけではなく、多数の安全機構が必要になる。

---

## 10. OTAで必要になる主要技術

### 10.1 Secure Download

通信経路ではTLSなどを使用する。

```text
OTA Server
    |
   TLS
    |
Vehicle
```

---

### 10.2 Digital Signature

更新ファイルに電子署名を付与する。

```text
Software Image
     |
     +-- Hash
     |
     +-- Digital Signature
```

車両側では署名を検証し、正当なソフトウェアであることを確認してからインストールする。

---

### 10.3 A/B Partition

OS更新では **A/B Partition方式** がよく使用される。

```text
Partition A   <- Running
Partition B   <- Update
```

更新後、

```text
Partition A
Partition B   <- Boot
```

に切り替える。

更新後の起動に失敗した場合は、

```text
Rollback
   |
Partition A
```

へ戻すことができる。

Android / Android Automotiveでも広く利用されている方式である。

---

### 10.4 Rollback

OTAでは更新失敗への対応が非常に重要である。

典型的な状態遷移は以下のようになる。

```text
Download
   |
Verify
   |
Install
   |
Reboot
   |
Health Check
   |
   +---- OK ----> Commit
   |
   +---- NG ----> Rollback
```

---

### 10.5 Uptane

自動車OTAのセキュリティフレームワークとして **Uptane** がある。

Uptaneは、ソフトウェアUpdate FrameworkであるTUF（The Update Framework）の考え方を車載向けに発展させたものである。

主な目的は以下。

- Update Server侵害対策
- Signing Key漏洩対策
- ECU間のUpdate整合性確保
- Replay Attack対策
- Rollback Attack対策
- Partial compromise対策

---

## 11. 2023年〜現在：OTAからSDVへ

現在では、OTAそのものが目的ではない。

OTAは、

**Software Defined Vehicle（SDV）のDeployment基盤**

として位置付けられている。

典型的なSDV開発環境は以下のようになる。

```text
Developer
    |
    v
Git
    |
    v
CI/CD
    |
    v
Cloud Backend
    |
    v
OTA Server
    |
    v
Internet
    |
    v
Vehicle
    |
    v
Central Computer
    |
+----------------------+
| Vehicle OS           |
| Middleware           |
| Applications         |
+----------------------+
```

これはIT業界の

```text
Code
  |
Build
  |
Test
  |
Deploy
```

というDevOps / CI/CDの仕組みを、自動車に持ち込んだものと考えることができる。

---

## 12. 現在OTAで配信されるもの

現在のOTAでは、配信対象が大幅に増えている。

```text
Firmware
OS
Middleware
Application
Container
Configuration
Certificates
Maps
ADAS Algorithm
AI Model
```

特にSDVでは、アプリケーションだけでなく、AI Modelや車両サービスまで継続的に更新することが想定される。

---

## 13. QNX / Linux / Android AutomotiveとOTA

現在のSDVでは複数OSが混在するケースが多い。

例えば以下のような構成が考えられる。

```text
                 Cloud
                   |
                OTA Server
                   |
                   v
                  TCU
                   |
              OTA Manager
                   |
          Central Computer
          /       |        \
        QNX      Linux      AAOS
         |         |         |
     Safety     Vehicle     IVI
     Domain     Services
```

### QNX

QNXは以下のような領域で利用される。

- Safety Critical ECU
- Digital Cockpit
- ADAS
- Gateway
- Central Compute

OTAでは、OS Image、Application、Firmwareなどの更新対象となる。

### Linux

Linuxは以下の用途で利用される。

- Vehicle Services
- Middleware
- Cloud Connectivity
- Containers
- AI

### Android Automotive OS

AAOSは主にIVI領域を担当する。

AndroidのA/B UpdateやUpdate Engineなど、スマートフォンで培われたOTA技術を車載にも活用できる。

---

## 14. OTAとSDVの関係

OTAとSDVの関係を簡単に整理すると、

```text
Connected Car
     |
     v
OTA
     |
     v
Vehicle Software Platform
     |
     v
Centralized E/E Architecture
     |
     v
Cloud + CI/CD
     |
     v
Software Defined Vehicle
```

となる。

つまり、

> **OTAはSDVを実現するための「車載版Deployment Infrastructure」**

と考えると理解しやすい。

---

## 15. 車載OTAの歴史まとめ

| 時代 | OTA対象 | 特徴 |
|---|---|---|
| ～2005年 | ほぼなし | Dealerで更新 |
| 2005〜2012年 | Map / Telematics | Connected Car |
| 2012年〜 | Tesla Whole Vehicle | Software-first |
| 2018年〜 | IVI / ADAS / ECU | 既存OEM本格参入 |
| 2020年〜 | 多数ECU | Whole Vehicle OTA |
| 2021年〜 | 法規対応 | UN-R156 / SUMS |
| 2023年〜 | OS / Apps / AI | SDV |
| 現在 | Vehicle Platform全体 | Cloud Native Vehicle |

---

## 16. OTA進化の本質

車載OTAの進化を一言で表すと、

```text
Dealer Update
      ↓
Map OTA
      ↓
IVI OTA
      ↓
ECU OTA
      ↓
Whole Vehicle OTA
      ↓
SDV Continuous Deployment
```

である。

従来の自動車では、

> Hardwareが車を定義する

という考え方が中心だった。

SDVでは、

> Softwareが車の機能・価値を継続的に定義する

という方向へ変わっている。

そのSoftwareを安全に車両へ届けるための中心技術が **OTA** である。

---

## 参考資料

- Tesla Owner's Manual / Software Updates  
  https://www.tesla.com/ownersmanual/

- BMW Remote Software Upgrade  
  https://www.press.bmwgroup.com/

- Ford Power-Up Software Updates  
  https://media.ford.com/

- UNECE UN Regulation No.156 - Software Update and Software Update Management System  
  https://unece.org/transport/documents/2021/03/standards/un-regulation-no-156-software-update-and-software-update

- Uptane  
  https://uptane.org/

- The Update Framework (TUF)  
  https://theupdateframework.io/
