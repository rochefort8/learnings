# 要約

APIやサービス間通信のデータフォーマットの話。

### Reference
* https://medium.com/@maahisoft20/forget-json-these-4-data-formats-made-my-apis-5x-faster-a43a7b3935d6

外部APIならJSON、それ以外の内部Machine-to-Machine通信ではバイナリフォーマットが有効。

JSONは可読性が高く、デバッグもしやすい良いフォーマットだが、データサイズが大きくなりやすく、Encode / Decodeにも比較的時間がかかる。

Protocol Buffers、MessagePack、Avro、FlatBuffersなどのバイナリ形式を使うことで、通信量やSerialize / Deserializeの処理時間を大きく削減できる。

記事中の例では、ケースによってJSONより数倍高速で、約5倍の性能差が出ている。

要するに、

- 人が触る外部境界 → JSON
- マシン同士の大量通信 → バイナリ形式

という使い分けが重要。

# 備考

## Key-Valueベース

JSONやMessagePackのように、

```text
key = value
```

の組み合わせでデータを表現する方式。

例えばJSONでは、

```json
{
  "id": 1,
  "name": "Arjun",
  "email": "a@dev.io"
}
```

のように、`id`、`name`、`email`というキーをデータ自身が持っている。

MessagePackも考え方はほぼ同じだが、文字列ではなくバイナリで表現するため、JSONより小さく高速になりやすい。

特徴：

- スキーマ定義が不要
- JSONから移行しやすい
- データ構造を柔軟に変更しやすい
- キー名もデータとして送るため、その分のサイズは必要

## スキーマベース

ProtobufやAvroのように、データ構造をあらかじめ別途定義しておく方式。

例えばProtobufでは、

```proto
message User {
  int32 id = 1;
  string name = 2;
  string email = 3;
}
```

のように定義する。

送信側と受信側がこのスキーマを共有しているため、通信時に毎回 `"id"`、`"name"`、`"email"` といったフィールド名を送る必要がない。

概念的には、

```text
JSON:
"name": "Arjun"

Protobuf:
2: "Arjun"
```

のような違いになる。

特徴：

- データサイズを小さくしやすい
- 型が明確
- Serialize / Deserializeを高速化しやすい
- 送受信側でスキーマ管理が必要
- フィールド追加や変更では互換性を考慮する必要がある

## 大まかな分類

| 形式 | 方式 | 特徴 |
|---|---|---|
| JSON | Key-Value / テキスト | 可読性が高い |
| MessagePack | Key-Value / バイナリ | JSONに近く、移行しやすい |
| Protobuf | スキーマベース / バイナリ | 小型・高速、サービス間通信向け |
| Avro | スキーマベース / バイナリ | スキーマ変更に強く、Kafkaなど向け |
| FlatBuffers | スキーマベース / バイナリ | バッファを直接読むため低レイテンシ |

※「バイナリ形式＝すべてKey-Value」というわけではない。  
MessagePackはJSONに近いKey-Value型だが、Protobuf、Avro、FlatBuffersは事前にデータ構造を定義するスキーマベース。