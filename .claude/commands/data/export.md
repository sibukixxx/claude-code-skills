# データエクスポート機能スキル

データを様々な形式にエクスポートする機能を設計・実装します。

## 使用方法
```
/data-export <データソース> <出力形式> [オプション]
```

---

## フォーマット比較

| 項目 | CSV | Excel (.xlsx) |
|------|-----|---------------|
| ファイルサイズ | 非常に軽量 | 比較的重い（書式情報含む） |
| データ件数制限 | なし（アプリ依存） | **最大 1,048,576行/シート** |
| 互換性 | ほぼ全システムで利用可 | 主に人間が閲覧・編集用 |
| 装飾 | 不可（テキストのみ） | セル色、結合、フォント可 |
| 実装負荷 | 低い（標準ライブラリ） | 高い（専用ライブラリ必要） |
| 型情報 | なし（全て文字列） | あり（日付、数値、文字列） |

---

## フォーマット固有の注意点

### CSV

#### 1. 型情報の欠落
```
問題: 全てが文字列として扱われる
- 先頭の「0」が消える（0埋めID: 00123 → 123）
- 長い数字が指数表記になる（Excel表示時）

対策:
- 文字列として扱いたいカラムは先頭に「'」を付与
- ="00123" 形式で出力（Excel向け）
```

#### 2. カンマ・改行のエスケープ
```
問題: データ内のカンマや改行でカラムがズレる

対策: RFC 4180 準拠
- カンマ、改行、ダブルクォートを含む場合 → ダブルクォートで囲む
- ダブルクォート自体 → "" でエスケープ

例:
入力: Hello, "World"
出力: "Hello, ""World"""
```

#### 3. BOM（Byte Order Mark）
```
問題: UTF-8（BOMなし）だとExcelで日本語が文字化け

対策:
- Excel向け → UTF-8 BOMあり（\xEF\xBB\xBF）
- システム連携向け → UTF-8 BOMなし
- レガシー連携 → Shift_JIS
```

### Excel (.xlsx)

#### 1. セルの型指定
```
問題: 型を指定しないと予期しない変換が発生
- 長い数字 → 指数表記（1234567890123 → 1.23E+12）
- 日付文字列 → 日付シリアル値
- 先頭ゼロ → 削除

対策:
- 文字列型を明示的に指定
- 数値型でも書式を設定（桁区切り、小数点など）
- 日付は日付型 + 表示形式を設定
```

#### 2. シート名の制限
```
制限事項:
- 最大31文字
- 使用不可文字: : \ / ? * [ ]
- 先頭・末尾の空白不可
- 空文字不可

対策: サニタイズ関数で自動修正
```

#### 3. データ件数制限
```
制限: 1シートあたり 1,048,576行

対策:
- 100万行超 → 複数シートに分割
- または複数ファイルに分割
- ユーザーへの事前警告
```

---

## 実装・設計チェック項目

### 1. メモリ管理（ストリーミング出力）

```
❌ アンチパターン:
const allData = await db.query("SELECT * FROM users"); // 100万件をメモリに
const csv = generateCSV(allData); // さらにメモリ消費
return csv;

✅ 推奨パターン:
const cursor = db.queryCursor("SELECT * FROM users");
const stream = createWriteStream("export.csv");
for await (const row of cursor) {
  stream.write(formatRow(row));
}
```

#### ストリーミング実装ガイド

```typescript
// Node.js/TypeScript
import { Transform } from 'stream';
import { pipeline } from 'stream/promises';

class CSVTransform extends Transform {
  private headerWritten = false;

  _transform(row: Record<string, any>, encoding: string, callback: Function) {
    if (!this.headerWritten) {
      this.push(Object.keys(row).join(',') + '\n');
      this.headerWritten = true;
    }
    this.push(Object.values(row).map(escapeCSV).join(',') + '\n');
    callback();
  }
}

// 使用例
await pipeline(
  dbCursor,
  new CSVTransform(),
  createWriteStream('export.csv')
);
```

```python
# Python
def stream_export(query_result, output_path):
    with open(output_path, 'w', newline='', encoding='utf-8-sig') as f:
        writer = None
        for chunk in query_result.yield_per(1000):  # 1000件ずつ
            if writer is None:
                writer = csv.DictWriter(f, fieldnames=chunk[0].keys())
                writer.writeheader()
            writer.writerows([row._asdict() for row in chunk])
```

### 2. タイムアウト対策

#### 推奨: 非同期処理アーキテクチャ

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│ Client  │────▶│   API   │────▶│  Queue  │────▶│ Worker  │
└─────────┘     └─────────┘     └─────────┘     └─────────┘
     │               │                               │
     │  1. リクエスト │                               │
     │◀──────────────│                               │
     │  2. ジョブID   │                               │
     │               │                               │
     │               │         3. 非同期処理          │
     │               │                               ▼
     │               │                         ┌─────────┐
     │               │                         │ Storage │
     │               │                         │  (S3等)  │
     │               │                         └─────────┘
     │                                               │
     │◀──────────────────────────────────────────────│
     │  4. 完了通知（メール/Webhook/ポーリング）      │
     │                                               │
     │  5. ダウンロード                              │
     │──────────────────────────────────────────────▶│
```

#### 実装例

```typescript
// API エンドポイント
async function requestExport(req: Request): Promise<Response> {
  const jobId = await exportQueue.add({
    userId: req.user.id,
    format: req.body.format,
    filters: req.body.filters,
  });

  return {
    jobId,
    status: 'accepted',
    message: '処理を開始しました。完了後にメールで通知します。'
  };
}

// Worker
async function processExportJob(job: ExportJob) {
  const { userId, format, filters } = job.data;

  // 権限チェック（実行直前に再確認）
  await validatePermissions(userId, filters);

  const filePath = await generateExport(format, filters);
  const downloadUrl = await uploadToStorage(filePath);

  await notifyUser(userId, downloadUrl);
}
```

### 3. セキュリティ

#### CSVインジェクション対策

```
危険な入力例:
=HYPERLINK("http://evil.com","Click")
=cmd|'/C calc'!A0
@SUM(1+1)*cmd|' /C calc'!A0
+cmd|'/C calc'!A0
-cmd|'/C calc'!A0

攻撃: Excelで開くと数式として実行される
```

```typescript
// 対策: 危険な先頭文字をエスケープ
function sanitizeForCSV(value: string): string {
  if (typeof value !== 'string') return value;

  const dangerousChars = ['=', '+', '-', '@', '\t', '\r'];

  if (dangerousChars.some(char => value.startsWith(char))) {
    return `'${value}`;  // 先頭にシングルクォート
  }

  return value;
}

// または、数式を完全に無効化
function escapeFormula(value: string): string {
  return value.replace(/^([=+\-@\t\r])/, "'$1");
}
```

#### 権限チェック

```typescript
async function exportData(userId: string, options: ExportOptions) {
  // 1. ユーザー認証確認
  const user = await getAuthenticatedUser(userId);
  if (!user) throw new UnauthorizedError();

  // 2. エクスポート対象データへのアクセス権確認
  const hasAccess = await checkDataAccess(user, options.dataSource);
  if (!hasAccess) throw new ForbiddenError();

  // 3. エクスポート機能の利用権限確認
  const canExport = await checkFeatureAccess(user, 'export');
  if (!canExport) throw new ForbiddenError('エクスポート権限がありません');

  // 4. レート制限チェック
  await checkRateLimit(userId, 'export');

  // 5. 実行
  return await performExport(options);
}
```

---

## エクスポート機能インターフェース

```typescript
interface ExportOptions {
  // 出力形式
  format: 'csv' | 'xlsx' | 'json' | 'jsonl';

  // ファイル設定
  fileName?: string;
  encoding?: 'utf-8' | 'utf-8-bom' | 'shift-jis';

  // CSV固有
  delimiter?: ',' | '\t' | ';';
  includeHeader?: boolean;
  lineEnding?: 'LF' | 'CRLF';

  // Excel固有
  sheetName?: string;
  autoColumnWidth?: boolean;
  freezeHeader?: boolean;
  maxRowsPerSheet?: number;  // デフォルト: 1000000

  // データ処理
  columns?: string[];           // 出力カラム指定
  columnMapping?: Record<string, string>;  // カラム名変換
  dateFormat?: string;          // 日付フォーマット
  nullValue?: string;           // NULL値の表現

  // 大量データ対応
  chunkSize?: number;           // チャンクサイズ
  compression?: 'none' | 'gzip' | 'zip';

  // セキュリティ
  sanitizeFormulas?: boolean;   // CSVインジェクション対策
}
```

---

## 実装チェックリスト

### 共通
- [ ] ストリーミング出力でメモリ効率化
- [ ] 非同期処理（大量データ対応）
- [ ] 進捗表示/ステータス確認API
- [ ] キャンセル機能
- [ ] エラーハンドリング（部分失敗時のリカバリ）
- [ ] ログ出力（監査用）

### セキュリティ
- [ ] 実行直前の権限再チェック
- [ ] CSVインジェクション対策
- [ ] レート制限
- [ ] ファイルアクセス制御（署名付きURL等）
- [ ] 一定期間後の自動削除

### CSV
- [ ] RFC 4180 準拠のエスケープ
- [ ] BOM設定（Excel向け）
- [ ] エンコーディング選択
- [ ] 改行コード統一

### Excel
- [ ] セル型の明示的指定
- [ ] シート名サニタイズ
- [ ] 100万行超の分割処理
- [ ] 長い数字の文字列化
- [ ] 日付フォーマット設定

---

## コード生成テンプレート

### Node.js/TypeScript

```typescript
// src/services/exporter.ts
import { Readable, Transform } from 'stream';
import { createGzip } from 'zlib';
import * as XLSX from 'xlsx';

export class DataExporter {
  async exportCSV(
    dataSource: AsyncIterable<Record<string, any>>,
    options: ExportOptions
  ): Promise<Readable> {
    const { encoding = 'utf-8-bom', sanitizeFormulas = true } = options;

    // BOM付与
    const bom = encoding === 'utf-8-bom' ? '\uFEFF' : '';

    // Transform Stream
    const transform = new Transform({
      objectMode: true,
      transform(row, encoding, callback) {
        // CSVインジェクション対策 + エスケープ
        const values = Object.values(row).map(v =>
          escapeCSV(sanitizeFormulas ? sanitizeForCSV(v) : v)
        );
        callback(null, values.join(',') + '\n');
      }
    });

    // ヘッダー出力
    transform.push(bom);

    // ストリーミング処理
    return pipeline(dataSource, transform);
  }

  async exportExcel(
    dataSource: AsyncIterable<Record<string, any>>,
    options: ExportOptions
  ): Promise<Buffer> {
    const workbook = XLSX.utils.book_new();
    let currentSheet: any[] = [];
    let sheetIndex = 1;
    let rowCount = 0;
    const maxRows = options.maxRowsPerSheet || 1000000;

    for await (const row of dataSource) {
      if (rowCount >= maxRows) {
        // シート追加
        addSheetToWorkbook(workbook, currentSheet, sheetIndex++);
        currentSheet = [];
        rowCount = 0;
      }
      currentSheet.push(formatRowForExcel(row, options));
      rowCount++;
    }

    // 最後のシート
    if (currentSheet.length > 0) {
      addSheetToWorkbook(workbook, currentSheet, sheetIndex);
    }

    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  }
}
```

### Python

```python
# services/exporter.py
import csv
import io
from typing import Iterator, Any
from openpyxl import Workbook
from openpyxl.utils import get_column_letter

class DataExporter:
    def export_csv(
        self,
        data_source: Iterator[dict[str, Any]],
        options: dict
    ) -> Iterator[bytes]:
        """ストリーミングCSV出力"""
        encoding = options.get('encoding', 'utf-8-sig')
        sanitize = options.get('sanitize_formulas', True)

        # BOM
        if encoding == 'utf-8-sig':
            yield b'\xef\xbb\xbf'

        buffer = io.StringIO()
        writer = None

        for row in data_source:
            if writer is None:
                writer = csv.DictWriter(buffer, fieldnames=row.keys())
                writer.writeheader()
                yield buffer.getvalue().encode(encoding.replace('-sig', ''))
                buffer.seek(0)
                buffer.truncate()

            if sanitize:
                row = {k: self._sanitize_formula(v) for k, v in row.items()}

            writer.writerow(row)
            yield buffer.getvalue().encode(encoding.replace('-sig', ''))
            buffer.seek(0)
            buffer.truncate()

    def _sanitize_formula(self, value: Any) -> Any:
        """CSVインジェクション対策"""
        if isinstance(value, str) and value and value[0] in '=+-@\t\r':
            return f"'{value}"
        return value
```

---

## 引数

$ARGUMENTS
