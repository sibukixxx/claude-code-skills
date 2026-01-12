# CSVバリデーションスキル

指定されたCSVファイルを検証し、問題点をレポートします。

## 使用方法
```
/csv-validate <ファイルパス> [スキーマ定義ファイル]
```

---

## エラーレベル定義

| レベル | 説明 | 処理継続 |
|--------|------|----------|
| **FATAL** | 処理続行不可能な致命的エラー | 即座に中断 |
| **ERROR** | データ不整合、修正必須 | 継続するが失敗扱い |
| **WARNING** | 警告、確認推奨 | 継続、成功扱い |
| **INFO** | 情報提供 | 継続 |

---

## 検証フロー

### Phase 1: ファイルレベル検証

最初に実行。FATALエラーがあれば以降の検証をスキップ。

| チェック項目 | レベル | 説明 |
|--------------|--------|------|
| ファイル存在 | FATAL | 指定パスにファイルが存在するか |
| 拡張子 | WARNING | `.csv` 拡張子であるか |
| ファイルサイズ | WARNING/ERROR | 空ファイル(ERROR)、上限超過(WARNING) |
| エンコーディング | FATAL/WARNING | 指定の文字コードであるか |
| 読み取り可否 | FATAL | ファイルを開けるか |

#### エンコーディング検証詳細
```
対応エンコーディング:
- UTF-8 (BOMなし) ← 推奨
- UTF-8 (BOMあり)
- Shift_JIS (CP932)
- EUC-JP

検証内容:
- 指定エンコードでデコード可能か
- 文字化けの検出
- BOMの有無を報告
```

### Phase 2: 構造検証

#### 2.1 改行コード統一チェック

| 状態 | レベル | 説明 |
|------|--------|------|
| LFのみ | INFO | Unix形式、推奨 |
| CRLFのみ | INFO | Windows形式、許容 |
| **混在** | **ERROR** | CRLF/LFが混在している |

```
出力例:
改行コード: 混在検出 (ERROR)
- LF: 行 1-50, 100-200
- CRLF: 行 51-99
```

#### 2.2 ヘッダー検証

| チェック項目 | レベル | 説明 |
|--------------|--------|------|
| ヘッダー行なし | **FATAL** | 1行目がヘッダーとして認識できない |
| 必須ヘッダー欠落 | **FATAL** | スキーマ定義の必須カラムがない |
| 未定義ヘッダー | WARNING | スキーマにないカラムが存在 |
| ヘッダー重複 | ERROR | 同名のカラムが複数存在 |
| ヘッダー空白 | ERROR | 空のヘッダー名 |

```yaml
# スキーマ定義例 (schema.yaml)
headers:
  required:  # 必須（なければFATAL）
    - id
    - email
    - created_at
  optional:  # 任意
    - name
    - phone
```

#### 2.3 カラム数（列数）不一致チェック

| 状態 | レベル |
|------|--------|
| 列数がヘッダーより少ない | **ERROR** |
| 列数がヘッダーより多い | **ERROR** |

```
出力例:
カラム数不一致: 5件 (ERROR)
| 行番号 | 期待 | 実際 | 差分 |
|--------|------|------|------|
| 45 | 8 | 7 | -1 (末尾欠落の可能性) |
| 102 | 8 | 9 | +1 (エスケープ漏れの可能性) |
```

### Phase 3: データ検証

#### 3.1 重複チェック (Uniqueness)

スキーマで `unique: true` が指定されたカラムを検証。

```yaml
# スキーマ定義例
columns:
  email:
    type: string
    unique: true  # ファイル内で重複不可

  employee_id:
    type: string
    unique: true
```

| 状態 | レベル |
|------|--------|
| 重複値あり | **ERROR** |

```
出力例:
重複チェック: email - 3件の重複 (ERROR)
| 値 | 出現行 |
|----|--------|
| test@example.com | 行 12, 45, 203 |
| user@domain.com | 行 88, 156 |
```

#### 3.2 相関チェック (Cross-field Validation)

複数カラム間の整合性を検証。

```yaml
# スキーマ定義例
correlations:
  - rule: "start_date < end_date"
    fields: [start_date, end_date]
    message: "開始日は終了日より前である必要があります"
    level: ERROR

  - rule: "min_value <= max_value"
    fields: [min_value, max_value]
    message: "最小値は最大値以下である必要があります"
    level: ERROR

  - rule: "country == 'JP' implies postal_code matches /^\d{3}-\d{4}$/"
    fields: [country, postal_code]
    message: "日本の場合、郵便番号はXXX-XXXX形式"
    level: WARNING
```

```
出力例:
相関チェック: start_date < end_date - 2件のエラー
| 行 | start_date | end_date | 問題 |
|----|------------|----------|------|
| 34 | 2024-03-15 | 2024-03-10 | 開始日が終了日より後 |
| 89 | 2024-12-01 | 2024-11-30 | 開始日が終了日より後 |
```

#### 3.3 データ型・フォーマット検証

```yaml
# スキーマ定義例
columns:
  id:
    type: integer
    required: true

  email:
    type: string
    format: email
    required: true

  created_at:
    type: date
    format: "YYYY-MM-DD"
    required: true

  price:
    type: decimal
    min: 0
    max: 999999.99

  status:
    type: enum
    values: [active, inactive, pending]
```

---

## 実行手順

1. **引数解析**: ファイルパスとスキーマ定義を取得
2. **Phase 1 実行**: ファイルレベル検証 → FATALなら中断
3. **Phase 2 実行**: 構造検証 → FATALなら中断
4. **Phase 3 実行**: データ検証
5. **レポート生成**: 全結果を集約して出力

---

## 出力フォーマット

```
═══════════════════════════════════════════════════════════
  CSV検証レポート: example.csv
═══════════════════════════════════════════════════════════

【ファイル情報】
  パス: /path/to/example.csv
  サイズ: 1.2 MB
  エンコード: UTF-8 (BOMなし)
  改行コード: LF
  総行数: 1,234 (ヘッダー除く)
  カラム数: 8

【検証結果サマリー】
  ┌─────────┬─────┐
  │ FATAL   │  0  │
  │ ERROR   │  5  │
  │ WARNING │ 12  │
  │ INFO    │  3  │
  └─────────┴─────┘

  結果: NG (ERRORが存在するため)

═══════════════════════════════════════════════════════════
【FATAL】なし
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
【ERROR】5件
═══════════════════════════════════════════════════════════

[E001] カラム数不一致
  行 45: 期待 8列, 実際 7列
  行 102: 期待 8列, 実際 9列

[E002] 重複値 (email)
  値 "test@example.com" が重複: 行 12, 45

[E003] 相関エラー (start_date < end_date)
  行 34: start_date=2024-03-15, end_date=2024-03-10

═══════════════════════════════════════════════════════════
【WARNING】12件
═══════════════════════════════════════════════════════════

[W001] 未定義ヘッダー
  "extra_column" はスキーマに定義されていません

[W002] 空白文字
  行 12, カラム "name": 前後に空白あり "  John Doe  "
  ...

═══════════════════════════════════════════════════════════
【修正提案】
═══════════════════════════════════════════════════════════

1. 行 45: 末尾にカンマを追加してカラム数を合わせてください
2. 行 12, 45: 重複メールアドレスを確認し、一方を削除または修正
3. 行 34: 開始日と終了日を確認し、正しい日付に修正

═══════════════════════════════════════════════════════════
```

---

## スキーマ定義ファイル (YAML形式)

```yaml
# csv-schema.yaml
version: "1.0"

file:
  encoding: UTF-8        # UTF-8, UTF-8-BOM, Shift_JIS, EUC-JP
  delimiter: ","         # カンマ区切り
  quote_char: '"'        # 引用符
  max_size_mb: 100       # 最大ファイルサイズ
  line_ending: LF        # LF, CRLF, any

headers:
  required:
    - id
    - email
    - start_date
    - end_date
  optional:
    - name
    - phone
    - notes

columns:
  id:
    type: integer
    required: true
    unique: true
    min: 1

  email:
    type: string
    required: true
    unique: true
    format: email
    max_length: 255

  start_date:
    type: date
    required: true
    format: "YYYY-MM-DD"

  end_date:
    type: date
    required: true
    format: "YYYY-MM-DD"

  name:
    type: string
    max_length: 100
    pattern: "^[a-zA-Z\\s]+$"

  phone:
    type: string
    pattern: "^\\d{2,4}-\\d{2,4}-\\d{4}$"

correlations:
  - rule: "start_date < end_date"
    fields: [start_date, end_date]
    message: "開始日は終了日より前である必要があります"
    level: ERROR

  - rule: "start_date >= 2020-01-01"
    fields: [start_date]
    message: "開始日は2020年以降である必要があります"
    level: WARNING
```

---

## 引数

$ARGUMENTS
