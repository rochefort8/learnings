# 自動運転・運転支援技術の主要企業と日本企業の位置づけ

作成日：2026年9月17日  
対象：ここまでの対話で確認した公開情報の要約

## 1. 概要

自動運転分野の「先進企業」は、何を評価するかによって異なる。

- **無人タクシーの商用運行実績**では、Waymoが最有力候補。BaiduのApollo Goも有力。
- **自動車メーカーに供給する運転支援・自動運転システム／ソフト**では、Mobileye、Momenta、Wayveなどが注目される。
- **車載AI半導体とソフトウェア基盤**では、NVIDIA、Qualcomm、Horizon Roboticsが重要。
- **日本企業**では、デンソーだけでなく、Astemo、TIER IV、ウーブン・バイ・トヨタも見る必要がある。

これは統一指標による世界ランキングではない。量産採用、無人運行、技術開発、将来の採用計画を区別した整理である。

## 2. 比較する際の区分

| 区分 | 主な内容 | 比較するときの注意点 |
|---|---|---|
| 運転支援（ADAS） | 車線維持、追従走行、車線変更支援など | 手放し運転ができても、運転者の監視が必要な場合がある |
| 条件付き自動運転 | 限定された条件下でシステムが運転を担う | 作動条件や、運転者への引き継ぎ要件がある |
| 無人運転サービス | 指定された地域・条件で運転者なしに走行 | 対応地域や道路、天候などの範囲を確認する必要がある |
| 開発・計算基盤 | 半導体、開発ツール、学習・シミュレーション環境 | 基盤の採用が、その企業の運転ソフト全体の採用を意味するわけではない |

## 3. 無人運転の実用化で目立つ企業

| 企業 | 注目点 | 位置づけ |
|---|---|---|
| **Waymo** | 週50万回以上の無人乗車サービスを提供。2026年9月1日時点で14都市に利用者向けサービスを展開 | 公開されている商用運行実績から、最有力候補と評価できる |
| **Baidu／Apollo Go** | 2026年の第2四半期決算発表で、無人自動運転の累計走行距離が2.4億km超。ドバイでも無人商用運行を展開 | 中国発の有力企業で、海外展開も進める |
| **Pony.ai** | トヨタと共同開発したbZ4Xロボタクシーの量産などを推進 | 自動車メーカーとの連携と車両量産が特徴 |
| **Zoox** | 自動運転専用車両を開発し、ラスベガスやサンフランシスコで利用者向けサービスを展開 | 車両設計と自動運転システムを一体で開発 |

運行地域数には、一般開放、利用者限定、試験などの違いがあるため、各社の数字をそのまま比較することはできない。

出典：[Waymoの運行規模](https://www.waymo.com/sustainability/)、[Waymoの都市展開](https://blog.waymo.com/blog/2026/09/ride-in-denver-san-diego-tampa/)、[Baidu決算発表](https://ir.baidu.com/news-releases/news-release-details/baidu-announces-second-quarter-2026-results)、[Pony.aiとトヨタ](https://www.prnewswire.com/news-releases/ponyai-and-toyota-advance-robotaxi-commercialization-with-mass-produced-bz4x-robotaxis-302682255.html)、[Zoox](https://zoox.com/community/)

## 4. メーカー向け「自動運転システム・ソフト」の主要企業

ここでいうソフトは、主に周囲の認識、進路・行動の判断、運転制御を担うものを指す。

| 企業 | 主なシステム・技術 | 実績・計画と評価 |
|---|---|---|
| **Mobileye** | EyeQと認識ソフト、高度運転支援のSuperVision、無人運転向けのMobileye Driveなど | 量産車への技術供給実績が大きい。SuperVisionはZEEKRで採用実績がある。EyeQ全体の普及台数と高度自動運転の普及台数は別 |
| **Momenta** | 市街地・高速道路の運転支援AI、データを活用した学習・改善 | 中国市場のメーカー向けソフト供給で注目。メルセデス・ベンツや中国のトヨタ合弁などと協業 |
| **Wayve** | エンドツーエンドAIを用いたWayve AI Driver | 日産の次世代プロパイロットに採用予定。日本の市販車への搭載は2027年度予定で、量産実績とは区別する |
| **NVIDIA** | DRIVE AVの認識・経路計画ソフト、車載計算基盤、学習・検証環境 | メルセデス・ベンツなどと開発。半導体だけでなく運転ソフトも提供するが、採用範囲はメーカーごとに異なる |
| **Qualcomm** | Snapdragon Ride Pilot、認識・運転判断ソフト | BMWと共同開発し、新型iX3に展開。半導体とソフトの両方を供給 |
| **Helm.ai** | AIによる認識・運転行動学習 | ホンダと次世代ADASを開発。将来の量産展開を目指す企業として注目 |

まず比較するなら、**量産供給実績のMobileye、中国で採用を広げるMomenta、次世代AIと日産への採用計画を持つWayve**が分かりやすい。ただし、これは技術性能の確定順位ではない。

出典：[Mobileye SuperVision](https://www.mobileye.com/news/mobileye-supervision-pilot-functions-added-to-110000-zeekr-vehicles/)、[Momenta](https://www.momenta.ai/en/about.html)、[日産の次世代プロパイロット](https://www.nissan-global.com/JP/INNOVATION/TECHNOLOGY/ARCHIVE/NEXT_GEN_PROPILOT/)、[NVIDIA DRIVE AV](https://blogs.nvidia.com/blog/mercedes-benz-l4-s-class-drive-av-platform/)、[QualcommとBMW](https://www.qualcomm.com/news/releases/2025/09/qualcomm-and-bmw-group-unveil-groundbreaking-automated-driving-s)、[ホンダとHelm.ai](https://global.honda/jp/news/2025/c251015a.html)

## 5. 日本車にはどこの技術が入っているか

日本車では、自動車メーカーがシステムを開発・統合し、外部企業の認識ソフト、AI、センサー、半導体などを組み合わせる。自社ブランドのシステム名であっても、全要素が自社製とは限らない。

| メーカー | システム例 | 外部企業・グループ企業との関係 |
|---|---|---|
| **トヨタ／レクサス** | Toyota Safety Sense、Teammate | LS・MIRAIのAdvanced Drive向けにデンソー製品の採用実績。ZFとMobileyeのADAS技術の採用も発表。ウーブンのAreneを使ったソフト開発も進める |
| **日産** | プロパイロット | プロパイロット2.0にMobileye技術の採用実績。次世代版ではWayve AI Driverの搭載を予定 |
| **ホンダ** | Honda SENSING、SENSING Elite | レジェンドに旧・日立Astemoの自動運転用制御ユニットなどを採用。次世代ADASはHelm.aiと開発 |
| **スバル** | アイサイト、アイサイトX | 自社のステレオカメラ・認識技術が中心。次世代向けにはAMDの半導体を採用する計画 |

**車種・年式・販売地域によって構成は異なる。** 中国向け車両の採用事例を、日本国内向けの全車種に当てはめることはできない。

トヨタとWaymoは協業の枠組みを発表しているが、それだけで「現在のトヨタ市販車にはWaymoのシステムが入っている」とは言えない。[トヨタ公式発表](https://global.toyota/jp/newsroom/corporate/42703314.html)

出典：[デンソーの採用例](https://www.denso.com/global/en/news/newsroom/2021/20210409-g01/)、[トヨタによるZF・Mobileye採用](https://press.zf.com/press/en/releases/release_26752.html)、[Mobileyeのプロパイロット2.0関連資料](https://d1io3yog0oux5.cloudfront.net/_c76321f1f4db2603fa6259cf9d8961f3/intel/db/861/7795/pdf/Mobileye-CES-2020-presentation.pdf)、[レジェンドへの採用例](https://www.hitachi.com/ja-jp/press/articles/2021/04/0426/)、[スバルの安全技術](https://www.subaru.co.jp/outline/about/zeroaccident/)

## 6. 日本企業の位置づけ

| 企業 | 主な役割 | 見るべきポイント |
|---|---|---|
| **デンソー** | 量産車向けのセンサー、制御装置、関連ソフト・システム | 自動車メーカーへの量産供給と車両への組み込み |
| **Astemo（旧・日立Astemo）** | 認識・判断・車両制御を統合した自動運転・ADAS | デンソーとともに確認すべき国内のシステム供給企業 |
| **TIER IV（ティアフォー）** | Autowareの開発を主導し、それを使った自動運転システムを展開 | 日本の自動運転ソフト企業として重要。スズキとも資本業務提携 |
| **ウーブン・バイ・トヨタ** | トヨタグループの自動運転・先進運転支援技術、ソフト開発基盤 | グループ内の中核開発。複数メーカーへの外販企業とは立ち位置が異なる |

TIER IVが開発を主導する**Autowareはオープンソースの自動運転ソフトウェア**である。一方、ウーブンの**Areneはソフトウェア開発基盤**であり、運転を担うソフトそのものと同一視しない。新型RAV4では、Arene SDKを使ってToyota Safety Senseなどが開発されている。

日本企業が存在しないのではなく、量産部品・システム供給、メーカーグループ内開発、オープンソースを使った自動運転などに役割が分かれている。Mobileyeのような世界規模の外販実績と比較する際は、採用台数だけでなく供給範囲も合わせて確認する必要がある。

出典：[AstemoのAD・ADAS](https://www.astemo.com/jp/products/ad-adas/)、[TIER IVとAutoware](https://tier4.jp/en/autoware/)、[TIER IVとスズキ](https://tier4.jp/cn/media/detail/?category=NEWS&sys_id=1kVrZ82xGo0jfHlEX214OM)、[AreneのRAV4開発への採用](https://woven.toyota/jp/news/20250521)

## 7. 周辺企業と評価上の注意

BoschやZFは、センサー、制御装置、運転支援ソフトを車両に統合する総合サプライヤーとして重要である。Horizon Roboticsは中国市場を中心に車載AI半導体と運転支援ソフトを展開している。これらの企業は競合すると同時に、他社技術を組み込んで協業することもある。[Bosch](https://www.bosch-mobility.com/en/solutions/automated-driving/)・[ZF](https://www.zf.com/products/en/cars/products_64065.html)・[Horizon Robotics](https://www.horizon.auto/en/solutions/horizon-journey?tp=2)

Teslaは市販車の運転支援ソフトで注目されるが、今回の「他の自動車メーカーへの供給」という比較とは切り口が異なる。一般向けFSD（Supervised）は運転者の監視を必要とする。[Tesla公式説明](https://www.tesla.com/en_ie/support/autopilot)

企業を比較する際は、次の点を確認する。

1. **実証・採用決定・量産・商用運行のどの段階か。**
2. **運転者の監視が必要か、どの条件で無人運転できるか。**
3. **半導体、認識ソフト、運転判断、車両制御のどこまでを供給するか。**
4. **搭載車種・販売地域・年式と、供給規模は何か。**

本レポートは会話で扱った主要企業の概観であり、網羅的な市場調査ではない。各社の発表は実績と計画を分けて記載し、将来の採用予定を実現済みの性能として評価していない。
