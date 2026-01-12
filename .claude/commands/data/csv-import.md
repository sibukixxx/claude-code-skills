# CSVインポート機能スキル

CSVファイルをシステムにインポートする機能を設計・実装します。

## 使用方法
```
/csv-import <インポート先> [オプション]
```

---

## インポート処理フロー

```
┌─────────────────────────────────────────────────────────────────┐
│                    CSVインポート処理フロー                        │
└─────────────────────────────────────────────────────────────────┘

  ┌──────────┐
  │ アップロード│
  └─────┬────┘
        ▼
  ┌──────────┐     NG    ┌──────────┐
  │ Phase 1  │─────────▶│ 即時拒否  │
  │ ファイル検証│          └──────────┘
  └─────┬────┘
        │ OK
        ▼
  ┌──────────┐
  │ 受付完了  │──▶ 「処理を開始しました」レスポンス
  │ (即時応答) │
  └─────┬────┘
        │
        ▼ (非同期)
  ┌──────────┐
  │ Phase 2  │
  │ 構造検証  │
  └─────┬────┘
        │
        ▼
  ┌──────────┐
  │ Phase 3  │
  │ データ検証│
  │ (全行)   │
  └─────┬────┘
        │
        ▼
  ┌──────────┐     エラーあり  ┌──────────┐
  │ 検証結果  │──────────────▶│ エラー通知 │
  │ 判定     │               │ (CSV出力) │
  └─────┬────┘               └──────────┘
        │ エラーなし
        ▼
  ┌──────────┐
  │ Phase 4  │
  │ DB書き込み│
  └─────┬────┘
        │
        ▼
  ┌──────────┐
  │ 完了通知  │
  └──────────┘
```

---

## Phase 1: ファイル受付時の事前チェック

データ解析前にファイル自体の安全性・処理可能性を検証。

### 1.1 ファイルサイズ制限

```typescript
const FILE_SIZE_LIMITS = {
  csv: 10 * 1024 * 1024,   // 10MB
  xlsx: 20 * 1024 * 1024,  // 20MB
};

function validateFileSize(file: File, type: 'csv' | 'xlsx'): ValidationResult {
  if (file.size > FILE_SIZE_LIMITS[type]) {
    return {
      valid: false,
      error: `ファイルサイズが上限を超えています（上限: ${FILE_SIZE_LIMITS[type] / 1024 / 1024}MB）`
    };
  }
  return { valid: true };
}
```

| 設定項目 | 推奨値 | 理由 |
|---------|--------|------|
| CSV上限 | 10MB | 約10-20万行相当 |
| Excel上限 | 20MB | 書式情報を含むため大きめに |
| 行数上限 | 100,000行 | メモリ・処理時間の制約 |

### 1.2 拡張子とMIMEタイプの検証

```typescript
const ALLOWED_TYPES = {
  csv: {
    extensions: ['.csv', '.txt'],
    mimeTypes: ['text/csv', 'text/plain', 'application/csv'],
  },
  xlsx: {
    extensions: ['.xlsx', '.xls'],
    mimeTypes: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-excel',
    ],
  },
};

function validateFileType(file: File): ValidationResult {
  const extension = path.extname(file.name).toLowerCase();
  const mimeType = file.type;

  // 拡張子チェック
  const allowedExtensions = Object.values(ALLOWED_TYPES)
    .flatMap(t => t.extensions);
  if (!allowedExtensions.includes(extension)) {
    return { valid: false, error: '許可されていないファイル形式です' };
  }

  // MIMEタイプチェック（偽装検知）
  const expectedMimes = ALLOWED_TYPES[extension === '.csv' ? 'csv' : 'xlsx'].mimeTypes;
  if (!expectedMimes.includes(mimeType)) {
    return { valid: false, error: 'ファイル形式が不正です（偽装の可能性）' };
  }

  // マジックバイト検証（より厳密な検証）
  return validateMagicBytes(file);
}
```

#### マジックバイト検証

```typescript
const MAGIC_BYTES = {
  csv: null,  // CSVはテキストなのでマジックバイトなし
  xlsx: [0x50, 0x4B, 0x03, 0x04],  // PKヘッダー（ZIP形式）
  xls: [0xD0, 0xCF, 0x11, 0xE0],   // OLE形式
};

async function validateMagicBytes(file: File): Promise<ValidationResult> {
  const buffer = await file.slice(0, 4).arrayBuffer();
  const bytes = new Uint8Array(buffer);
  // 検証ロジック...
}
```

### 1.3 エンコーディングの判定

```typescript
type Encoding = 'utf-8' | 'utf-8-bom' | 'shift-jis' | 'euc-jp';

interface EncodingDetectionResult {
  detected: Encoding;
  confidence: number;  // 0-1
  hasBOM: boolean;
}

async function detectEncoding(file: File): Promise<EncodingDetectionResult> {
  const buffer = await file.slice(0, 10000).arrayBuffer();
  const bytes = new Uint8Array(buffer);

  // BOM検出
  if (bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
    return { detected: 'utf-8-bom', confidence: 1.0, hasBOM: true };
  }

  // 文字コード判定ライブラリを使用
  // jschardet, encoding-japanese など
  const result = detectCharset(bytes);

  return {
    detected: result.encoding,
    confidence: result.confidence,
    hasBOM: false,
  };
}
```

| 戦略 | メリット | デメリット |
|------|----------|------------|
| 自動判定 | ユーザー負担が少ない | 誤判定リスクあり |
| 固定指定 | 確実 | ユーザーが正しく指定する必要 |
| 推奨: 自動判定 + 確認 | 精度と利便性のバランス | 実装コストがやや高い |

```
判定結果表示例:
「文字コードを UTF-8 と判定しました。正しくない場合は変更してください。」
[UTF-8] [Shift_JIS] [EUC-JP]
```

---

## Phase 2: インポート処理の挙動設計

### 処理方式の比較

| 方式 | 説明 | メリット | デメリット |
|------|------|----------|------------|
| **All or Nothing** | 1エラーで全件ロールバック | 整合性保証 | 1箇所のエラーで全件パー |
| **Partial Success** | 正常行のみ登録 | 正しいデータは即登録 | 整合性崩壊リスク |
| **Dry Run** | 事前プレビュー | 事前確認可能 | 実装コスト高 |
| **2フェーズ** | 全検証→全登録 | バランス良い | 処理時間が長い |

### 推奨: 2フェーズコミット方式

```
Phase A: バリデーション（全行）
    ↓
  エラー0件？ ─── No ──▶ エラーレポート出力、処理中断
    │
   Yes
    ↓
Phase B: DB書き込み（トランザクション）
    ↓
  完了通知
```

```typescript
interface ImportStrategy {
  mode: 'all_or_nothing' | 'partial_success' | 'dry_run' | 'two_phase';
  continueOnError: boolean;
  maxErrors: number;  // この数を超えたら処理中断
}

async function importWithTwoPhase(
  rows: ParsedRow[],
  strategy: ImportStrategy
): Promise<ImportResult> {
  // Phase A: 全行バリデーション
  const validationResults = await validateAllRows(rows);
  const errors = validationResults.filter(r => !r.valid);

  if (errors.length > 0) {
    return {
      success: false,
      phase: 'validation',
      errors,
      message: `${errors.length}件のエラーがあります。修正後に再アップロードしてください。`,
    };
  }

  // Phase B: DB書き込み（トランザクション）
  const transaction = await db.beginTransaction();
  try {
    for (const row of rows) {
      await insertOrUpdate(row, transaction);
    }
    await transaction.commit();

    return {
      success: true,
      importedCount: rows.length,
      message: `${rows.length}件のインポートが完了しました。`,
    };
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}
```

---

## Phase 3: データバリデーション

### 3.1 サニタイズ（クレンジング）

```typescript
interface SanitizeOptions {
  trimWhitespace: boolean;      // 前後空白除去
  trimFullWidth: boolean;       // 全角スペースも除去
  removeControlChars: boolean;  // 制御文字除去
  normalizeLineBreaks: boolean; // 改行コード統一
  normalizeUnicode: boolean;    // Unicode正規化（NFC）
}

function sanitizeValue(value: string, options: SanitizeOptions): string {
  let result = value;

  // 前後の空白除去（半角・全角）
  if (options.trimWhitespace) {
    result = result.trim();
  }
  if (options.trimFullWidth) {
    result = result.replace(/^[\s\u3000]+|[\s\u3000]+$/g, '');
  }

  // 制御文字除去（タブ、改行以外）
  if (options.removeControlChars) {
    result = result.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
  }

  // 改行コード統一
  if (options.normalizeLineBreaks) {
    result = result.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  }

  // Unicode正規化
  if (options.normalizeUnicode) {
    result = result.normalize('NFC');
  }

  return result;
}
```

### 3.2 外部キー（ID系項目）の存在確認

```typescript
interface ForeignKeyValidation {
  column: string;
  table: string;
  targetColumn: string;
  required: boolean;
}

const foreignKeyRules: ForeignKeyValidation[] = [
  { column: 'store_id', table: 'stores', targetColumn: 'id', required: true },
  { column: 'category_id', table: 'categories', targetColumn: 'id', required: false },
];

async function validateForeignKeys(
  rows: ParsedRow[],
  rules: ForeignKeyValidation[]
): Promise<ValidationError[]> {
  const errors: ValidationError[] = [];

  for (const rule of rules) {
    // 一括でIDを取得してキャッシュ
    const values = [...new Set(rows.map(r => r[rule.column]).filter(Boolean))];
    const existingIds = await db.query(
      `SELECT ${rule.targetColumn} FROM ${rule.table} WHERE ${rule.targetColumn} IN (?)`,
      [values]
    );
    const existingSet = new Set(existingIds.map(r => r[rule.targetColumn]));

    // 存在しないIDをエラーとして記録
    rows.forEach((row, index) => {
      const value = row[rule.column];
      if (value && !existingSet.has(value)) {
        errors.push({
          row: index + 2,  // ヘッダー行を考慮
          column: rule.column,
          value,
          message: `${rule.table}に存在しないID: ${value}`,
        });
      } else if (!value && rule.required) {
        errors.push({
          row: index + 2,
          column: rule.column,
          value: null,
          message: `${rule.column}は必須です`,
        });
      }
    });
  }

  return errors;
}
```

### 3.3 重複ハンドリング（INSERT / UPSERT）

```typescript
type DuplicateStrategy = 'error' | 'skip' | 'update' | 'upsert';

interface DuplicateConfig {
  strategy: DuplicateStrategy;
  uniqueColumns: string[];  // 重複判定に使用するカラム
  updateColumns?: string[]; // update時に更新するカラム
}

async function handleDuplicates(
  rows: ParsedRow[],
  config: DuplicateConfig
): Promise<{ toInsert: ParsedRow[]; toUpdate: ParsedRow[]; errors: ValidationError[] }> {
  const errors: ValidationError[] = [];
  const toInsert: ParsedRow[] = [];
  const toUpdate: ParsedRow[] = [];

  // 既存データを取得
  const existingRecords = await findExistingRecords(rows, config.uniqueColumns);
  const existingMap = new Map(
    existingRecords.map(r => [getUniqueKey(r, config.uniqueColumns), r])
  );

  // ファイル内重複チェック
  const seenInFile = new Map<string, number>();

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const key = getUniqueKey(row, config.uniqueColumns);

    // ファイル内重複
    if (seenInFile.has(key)) {
      errors.push({
        row: i + 2,
        column: config.uniqueColumns.join(', '),
        value: key,
        message: `ファイル内で重複しています（${seenInFile.get(key)}行目と同じ）`,
      });
      continue;
    }
    seenInFile.set(key, i + 2);

    // DB重複
    const existing = existingMap.get(key);
    if (existing) {
      switch (config.strategy) {
        case 'error':
          errors.push({
            row: i + 2,
            column: config.uniqueColumns.join(', '),
            value: key,
            message: '既にデータベースに存在します',
          });
          break;
        case 'skip':
          // 何もしない
          break;
        case 'update':
        case 'upsert':
          toUpdate.push({ ...row, _existingId: existing.id });
          break;
      }
    } else {
      toInsert.push(row);
    }
  }

  return { toInsert, toUpdate, errors };
}
```

| 戦略 | 動作 | ユースケース |
|------|------|-------------|
| `error` | 重複があればエラー | 新規登録のみ許可 |
| `skip` | 重複は無視（既存を維持） | 追加のみ、既存は変更しない |
| `update` | 重複は上書き | マスタデータ更新 |
| `upsert` | なければ挿入、あれば更新 | 同期処理 |

---

## Phase 4: ユーザーへのフィードバック

### エラー通知フォーマット

```typescript
interface ImportError {
  row: number;       // 行番号（1始まり、ヘッダー含む）
  column: string;    // カラム名
  value: any;        // 問題の値
  errorCode: string; // エラーコード
  message: string;   // エラーメッセージ
  suggestion?: string; // 修正提案
}

function formatErrorMessage(error: ImportError): string {
  return `${error.row}行目の「${error.column}」: ${error.message}`;
}

// 出力例:
// 5行目の「メールアドレス」: メールアドレスの形式が正しくありません（入力値: "invalid-email"）
// 12行目の「店舗ID」: storesテーブルに存在しないID: "S999"
```

### エラーCSVダウンロード

```typescript
async function generateErrorReport(
  originalRows: ParsedRow[],
  errors: ImportError[]
): Promise<string> {
  const errorsByRow = groupBy(errors, 'row');

  const reportRows = originalRows.map((row, index) => {
    const rowNumber = index + 2;  // ヘッダー考慮
    const rowErrors = errorsByRow[rowNumber] || [];

    return {
      __行番号: rowNumber,
      __エラー有無: rowErrors.length > 0 ? 'エラー' : 'OK',
      __エラー内容: rowErrors.map(e => `[${e.column}] ${e.message}`).join(' / '),
      ...row,
    };
  });

  return generateCSV(reportRows, {
    encoding: 'utf-8-bom',
    columns: ['__行番号', '__エラー有無', '__エラー内容', ...Object.keys(originalRows[0])],
  });
}
```

#### エラーレポートCSV例

```csv
行番号,エラー有無,エラー内容,id,email,store_id,start_date,end_date
2,OK,,1,user1@example.com,S001,2024-01-01,2024-12-31
3,OK,,2,user2@example.com,S002,2024-02-01,2024-11-30
4,エラー,[email] メールアドレスの形式が不正,3,invalid-email,S001,2024-03-01,2024-10-31
5,エラー,[store_id] 存在しないID / [end_date] 開始日より前,4,user4@example.com,S999,2024-04-01,2024-03-01
```

### 画面表示フォーマット

```
═══════════════════════════════════════════════════════════
  インポート結果: users_import.csv
═══════════════════════════════════════════════════════════

【処理結果】失敗

【サマリー】
  総行数:     1,234行
  成功:       0行（エラーがあるため処理を中断しました）
  エラー:     23行
  スキップ:   0行

═══════════════════════════════════════════════════════════
【エラー詳細】（最初の10件を表示）
═══════════════════════════════════════════════════════════

1. 5行目「email」
   エラー: メールアドレスの形式が正しくありません
   入力値: "invalid-email"
   修正例: "user@example.com" の形式で入力してください

2. 12行目「store_id」
   エラー: storesテーブルに存在しないIDです
   入力値: "S999"
   修正例: 有効な店舗IDを指定してください

3. 34行目「start_date」「end_date」
   エラー: 開始日が終了日より後になっています
   入力値: start_date=2024-05-01, end_date=2024-04-01
   修正例: 開始日を終了日より前に設定してください

... 他 20件

═══════════════════════════════════════════════════════════
【次のステップ】
═══════════════════════════════════════════════════════════

1. [エラーレポートをダウンロード] ボタンからCSVを取得
2. CSVの「エラー内容」列を確認して修正
3. 修正後、再度アップロードしてください

[エラーレポートをダウンロード]  [キャンセル]
```

---

## Phase 5: 非同期処理（バックグラウンド）

### アーキテクチャ

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│ Client  │────▶│   API   │────▶│  Queue  │────▶│ Worker  │
└─────────┘     └─────────┘     └─────────┘     └─────────┘
     │               │                               │
     │  1. ファイル   │                               │
     │    アップロード │                               │
     │◀──────────────│                               │
     │  2. ジョブID   │                               │
     │    受付完了    │                               │
     │               │                               │
     │               │         3. バックグラウンド処理   │
     │               │            ├─ 構造検証         │
     │               │            ├─ データ検証       │
     │               │            └─ DB書き込み       │
     │               │                               │
     │◀──────────────│◀──────────────────────────────│
     │  4. 進捗通知   │    (WebSocket/Polling)       │
     │               │                               │
     │◀──────────────│◀──────────────────────────────│
     │  5. 完了通知   │                               │
     │    ・成功/失敗 │                               │
     │    ・結果レポート                              │
     │    ・エラーCSV │                               │
```

### 実装例

```typescript
// API: ファイル受付
async function handleImportRequest(req: Request): Promise<Response> {
  const file = req.file;

  // Phase 1: 事前チェック（同期）
  const preCheck = await preValidateFile(file);
  if (!preCheck.valid) {
    return Response.json({
      success: false,
      error: preCheck.error,
    }, { status: 400 });
  }

  // ファイルを一時保存
  const tempPath = await saveTempFile(file);

  // ジョブをキューに追加
  const job = await importQueue.add({
    userId: req.user.id,
    filePath: tempPath,
    options: req.body.options,
  });

  return Response.json({
    success: true,
    jobId: job.id,
    message: '受付完了。処理が終わったら通知します。',
    statusUrl: `/api/import/status/${job.id}`,
  });
}

// Worker: バックグラウンド処理
async function processImportJob(job: ImportJob) {
  const { userId, filePath, options } = job.data;

  try {
    // 進捗更新: 開始
    await updateJobProgress(job.id, { status: 'processing', phase: 'parsing', progress: 0 });

    // CSVパース
    const rows = await parseCSV(filePath, options);
    await updateJobProgress(job.id, { phase: 'validating', progress: 20 });

    // Phase 2-3: バリデーション
    const validationResult = await validateAllRows(rows, options);
    await updateJobProgress(job.id, { phase: 'validated', progress: 60 });

    if (validationResult.errors.length > 0) {
      // エラーレポート生成
      const errorReportUrl = await generateAndUploadErrorReport(rows, validationResult.errors);

      await completeJob(job.id, {
        status: 'failed',
        errorCount: validationResult.errors.length,
        errorReportUrl,
        message: `${validationResult.errors.length}件のエラーがあります`,
      });

      await notifyUser(userId, {
        type: 'import_failed',
        jobId: job.id,
        errorReportUrl,
      });
      return;
    }

    // Phase 4: DB書き込み
    await updateJobProgress(job.id, { phase: 'importing', progress: 70 });
    const importResult = await importToDatabase(rows, options);
    await updateJobProgress(job.id, { progress: 100 });

    // 完了
    await completeJob(job.id, {
      status: 'completed',
      importedCount: importResult.count,
      message: `${importResult.count}件のインポートが完了しました`,
    });

    await notifyUser(userId, {
      type: 'import_completed',
      jobId: job.id,
      importedCount: importResult.count,
    });

  } catch (error) {
    await completeJob(job.id, {
      status: 'error',
      message: 'システムエラーが発生しました',
      error: error.message,
    });

    await notifyUser(userId, {
      type: 'import_error',
      jobId: job.id,
    });
  } finally {
    // 一時ファイル削除
    await deleteTempFile(filePath);
  }
}

// API: 進捗確認
async function getImportStatus(req: Request): Promise<Response> {
  const { jobId } = req.params;
  const job = await getJob(jobId);

  return Response.json({
    jobId,
    status: job.status,
    phase: job.phase,
    progress: job.progress,
    result: job.result,
  });
}
```

### 通知方法

| 方法 | メリット | デメリット |
|------|----------|------------|
| WebSocket | リアルタイム | 接続維持コスト |
| Polling | シンプル | サーバー負荷 |
| メール | 確実 | 遅延あり |
| アプリ内通知 | UX良好 | 実装コスト |

```typescript
// 推奨: WebSocket + フォールバック
async function notifyUser(userId: string, notification: ImportNotification) {
  // 1. WebSocket接続があれば即時通知
  const wsConnection = getWebSocketConnection(userId);
  if (wsConnection) {
    wsConnection.send(JSON.stringify(notification));
  }

  // 2. アプリ内通知（ベルマーク）
  await createInAppNotification(userId, notification);

  // 3. 大規模インポートの場合はメールも送信
  if (notification.importedCount > 1000 || notification.type === 'import_failed') {
    await sendEmail(userId, formatEmailNotification(notification));
  }
}
```

---

## 設定インターフェース

```typescript
interface ImportOptions {
  // ファイル設定
  encoding?: 'utf-8' | 'utf-8-bom' | 'shift-jis' | 'auto';
  delimiter?: ',' | '\t' | ';';
  hasHeader?: boolean;

  // 処理方式
  strategy: 'all_or_nothing' | 'partial_success' | 'dry_run' | 'two_phase';
  duplicateHandling: 'error' | 'skip' | 'update' | 'upsert';
  uniqueColumns: string[];

  // バリデーション
  maxErrors?: number;           // この数を超えたら処理中断
  validateForeignKeys?: boolean;
  schemaPath?: string;          // バリデーションスキーマ

  // サニタイズ
  sanitize?: {
    trimWhitespace?: boolean;
    trimFullWidth?: boolean;
    removeControlChars?: boolean;
    normalizeUnicode?: boolean;
  };

  // 通知
  notifyOnComplete?: boolean;
  notifyEmail?: string;
}
```

---

## 実装チェックリスト

### ファイル受付
- [ ] ファイルサイズ制限
- [ ] 拡張子チェック
- [ ] MIMEタイプ検証
- [ ] マジックバイト検証
- [ ] エンコーディング自動判定

### バリデーション
- [ ] スキーマベースの型チェック
- [ ] 必須項目チェック
- [ ] 外部キー存在確認
- [ ] 重複チェック（ファイル内 + DB）
- [ ] 相関チェック

### サニタイズ
- [ ] 前後空白トリミング
- [ ] 全角スペース対応
- [ ] 制御文字除去
- [ ] Unicode正規化

### エラーハンドリング
- [ ] 行番号・カラム名付きエラー
- [ ] エラーレポートCSV出力
- [ ] 修正提案の表示

### 非同期処理
- [ ] ジョブキュー実装
- [ ] 進捗表示
- [ ] 完了通知（WebSocket/メール）
- [ ] 一時ファイル自動削除

### セキュリティ
- [ ] 悪意のあるファイル検知
- [ ] 権限チェック
- [ ] レート制限

---

## 引数

$ARGUMENTS
