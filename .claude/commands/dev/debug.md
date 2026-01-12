# デバッグ支援スキル

エラーの解析と根本原因の特定を支援します。

## 使用方法
```
/dev:debug <エラーメッセージ/ファイル> [--trace]
```

---

## When to Use

- ランタイムエラーの調査
- 予期しない動作の原因特定
- スタックトレースの解析
- パフォーマンス問題の調査

---

## デバッグワークフロー

```
┌─────────────────────────────────────────────────────────┐
│                  デバッグフロー                          │
└─────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │ 1. 問題の再現 │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ 2. 情報収集   │ ← ログ、スタックトレース、入力値
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ 3. 仮説立案   │ ← 考えられる原因のリストアップ
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ 4. 仮説検証   │ ← ログ追加、ブレークポイント
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ 5. 原因特定   │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ 6. 修正実装   │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ 7. 再発防止   │ ← テスト追加
    └──────────────┘
```

---

## エラー解析パターン

### 1. TypeError / NullPointerException

```
エラー: Cannot read property 'name' of undefined
```

**解析手順**:

```typescript
// 1. エラー発生箇所を特定
// stack trace: src/services/user.service.ts:45
const userName = user.name;  // user が undefined

// 2. データの流れを追跡
async function getUser(id: string) {
  const user = await this.userRepo.findById(id);
  // findById が undefined を返している
  return user;
}

// 3. 原因の特定
// - DBにレコードが存在しない
// - IDが不正
// - クエリが間違っている

// 4. 修正案
async function getUser(id: string) {
  const user = await this.userRepo.findById(id);
  if (!user) {
    throw new NotFoundError(`User not found: ${id}`);
  }
  return user;
}

// または Optional Chaining + Nullish Coalescing
const userName = user?.name ?? 'Unknown';
```

### 2. 非同期エラー

```
エラー: UnhandledPromiseRejection
```

```typescript
// Before: エラーハンドリングなし
async function processAll(items: Item[]) {
  for (const item of items) {
    await processItem(item);  // エラーが発生すると止まる
  }
}

// After: 適切なエラーハンドリング
async function processAll(items: Item[]) {
  const results = await Promise.allSettled(
    items.map(item => processItem(item))
  );

  const failures = results.filter(r => r.status === 'rejected');
  if (failures.length > 0) {
    console.error('Some items failed:', failures);
    // エラーレポートを生成
  }

  return results.filter(r => r.status === 'fulfilled');
}
```

### 3. レースコンディション

```typescript
// 問題: データの不整合
let counter = 0;

async function increment() {
  const current = counter;
  await someAsyncOperation();
  counter = current + 1;  // 古い値に基づいて更新
}

// 同時に呼ばれると...
await Promise.all([increment(), increment()]);
// counter は 1 になる（期待値は 2）

// 修正: ミューテックス/ロック
import { Mutex } from 'async-mutex';

const mutex = new Mutex();

async function incrementSafe() {
  const release = await mutex.acquire();
  try {
    counter++;
  } finally {
    release();
  }
}
```

### 4. メモリリーク

```typescript
// 問題: イベントリスナーの解除忘れ
class Component {
  constructor() {
    window.addEventListener('resize', this.handleResize);
  }

  handleResize = () => { /* ... */ };

  // cleanup メソッドがない = リーク
}

// 修正: クリーンアップを実装
class Component {
  private abortController = new AbortController();

  constructor() {
    window.addEventListener('resize', this.handleResize, {
      signal: this.abortController.signal,
    });
  }

  handleResize = () => { /* ... */ };

  destroy() {
    this.abortController.abort();
  }
}
```

### 5. N+1問題

```typescript
// 問題: 大量のクエリ
async function getUsersWithOrders() {
  const users = await User.findAll();  // 1クエリ

  for (const user of users) {
    user.orders = await Order.findByUserId(user.id);  // N クエリ
  }

  return users;
}

// 修正: Eager Loading
async function getUsersWithOrders() {
  return User.findAll({
    include: [{ model: Order }],
  });  // 1-2クエリ
}

// または DataLoader パターン
const orderLoader = new DataLoader(async (userIds) => {
  const orders = await Order.findByUserIds(userIds);
  return userIds.map(id => orders.filter(o => o.userId === id));
});
```

---

## デバッグツール

### Console/Logger

```typescript
// 構造化ログ
console.log('Processing order', {
  orderId: order.id,
  userId: order.userId,
  items: order.items.length,
  timestamp: new Date().toISOString(),
});

// タイミング計測
console.time('processOrder');
await processOrder(order);
console.timeEnd('processOrder');

// スタックトレース
console.trace('Called from here');
```

### Debugger

```typescript
// ブレークポイント
function processOrder(order: Order) {
  debugger;  // ここで停止
  // ...
}
```

### 環境変数でのデバッグ有効化

```typescript
const DEBUG = process.env.DEBUG === 'true';

function debugLog(...args: any[]) {
  if (DEBUG) {
    console.log('[DEBUG]', ...args);
  }
}
```

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  デバッグ分析: TypeError
═══════════════════════════════════════════════════════════

【エラー】
  TypeError: Cannot read property 'email' of undefined
  at UserService.sendWelcomeEmail (user.service.ts:45)
  at UserService.createUser (user.service.ts:30)

【スタックトレース分析】

1. createUser (user.service.ts:30)
   → userRepo.save() の戻り値を確認

2. sendWelcomeEmail (user.service.ts:45)
   → user パラメータが undefined

【仮説】

1. [高] userRepo.save() が undefined を返している
   - DBエラー
   - トランザクションの問題

2. [中] 非同期処理の問題
   - await の欠落

3. [低] 引数の渡し方が間違っている

【検証コード】

```typescript
async createUser(input: CreateUserInput) {
  console.log('Input:', input);

  const user = await this.userRepo.save(input);
  console.log('Saved user:', user);  // ← ここで undefined?

  if (!user) {
    throw new Error('Failed to save user');
  }

  await this.sendWelcomeEmail(user);
}
```

【原因特定】

userRepo.save() に await が欠落していました。

```typescript
// Before (問題)
const user = this.userRepo.save(input);  // Promise を返す

// After (修正)
const user = await this.userRepo.save(input);
```

【修正案】

1. await を追加
2. TypeScript strict モードを有効化（Promise の未処理を検出）
3. テストケースを追加

【再発防止】

```typescript
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true
  }
}

// ESLint rule
{
  "rules": {
    "@typescript-eslint/no-floating-promises": "error"
  }
}
```
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--trace` | 詳細なトレース | `--trace` |
| `--memory` | メモリ分析 | `--memory` |
| `--performance` | パフォーマンス分析 | `--performance` |

---

## 引数

$ARGUMENTS
