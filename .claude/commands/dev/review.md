# コードレビュースキル

コードやPRの品質をレビューし、改善提案を行います。

## 使用方法
```
/dev:review <ファイル/ディレクトリ/PR番号> [--focus=<観点>]
```

---

## When to Use

- プルリクエストのレビュー
- 実装完了後のセルフレビュー
- コード品質の定期チェック
- 新規メンバーのコード確認

## Scope

| 言語 | 対応フレームワーク |
|------|-------------------|
| TypeScript | Express, NestJS, Next.js, React |
| Python | Django, FastAPI, Flask |
| Go | gin, echo, net/http |

---

## レビュー観点

### 1. 可読性・命名

```typescript
// ❌ Bad
const d = new Date();
const u = users.filter(x => x.a > 18);
function proc(d) { /* ... */ }

// ✅ Good
const currentDate = new Date();
const adultUsers = users.filter(user => user.age > 18);
function processOrder(orderData) { /* ... */ }
```

**チェック項目**:
- [ ] 変数名が意図を表現しているか
- [ ] 関数名が動作を表現しているか
- [ ] 略語は一般的なもののみ使用しているか
- [ ] 一貫した命名規則（camelCase/snake_case）

### 2. ロジックの正確性

```typescript
// ❌ Bug: off-by-one error
for (let i = 0; i <= items.length; i++) {
  process(items[i]); // items[length] は undefined
}

// ✅ Correct
for (let i = 0; i < items.length; i++) {
  process(items[i]);
}
```

**チェック項目**:
- [ ] 境界条件の処理は正しいか
- [ ] null/undefinedの考慮
- [ ] 型の不一致がないか
- [ ] ビジネスロジックが仕様通りか

### 3. エラーハンドリング

```typescript
// ❌ Bad: エラーを握りつぶす
try {
  await saveUser(user);
} catch (e) {
  console.log(e);
}

// ✅ Good: 適切にハンドリング
try {
  await saveUser(user);
} catch (error) {
  if (error instanceof ValidationError) {
    throw new BadRequestError(error.message);
  }
  if (error instanceof DuplicateKeyError) {
    throw new ConflictError('User already exists');
  }
  // 予期しないエラーは上位に伝播
  throw error;
}
```

**チェック項目**:
- [ ] try-catchの範囲は適切か
- [ ] エラーの種類に応じた処理があるか
- [ ] エラーメッセージは有用か
- [ ] リソースのクリーンアップは確実か

### 4. セキュリティ（OWASP Top 10）

#### A01: アクセス制御の不備
```typescript
// ❌ Bad: 認可チェックなし
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id);
  res.json(user);
});

// ✅ Good: 認可チェックあり
app.get('/users/:id', authenticate, async (req, res) => {
  const user = await User.findById(req.params.id);
  if (user.id !== req.user.id && !req.user.isAdmin) {
    throw new ForbiddenError();
  }
  res.json(user);
});
```

#### A03: インジェクション
```typescript
// ❌ Bad: SQLインジェクション
const query = `SELECT * FROM users WHERE email = '${email}'`;

// ✅ Good: パラメータ化クエリ
const query = 'SELECT * FROM users WHERE email = $1';
const result = await db.query(query, [email]);
```

#### A07: XSS
```typescript
// ❌ Bad: 未サニタイズの出力
res.send(`<div>${userInput}</div>`);

// ✅ Good: エスケープ処理
res.send(`<div>${escapeHtml(userInput)}</div>`);
```

**チェック項目**:
- [ ] 認証・認可のチェック
- [ ] 入力のバリデーション・サニタイズ
- [ ] SQLインジェクション対策
- [ ] XSS対策
- [ ] CSRF対策
- [ ] 機密情報のハードコード
- [ ] 依存関係の脆弱性

### 5. パフォーマンス

```typescript
// ❌ Bad: N+1問題
const users = await User.findAll();
for (const user of users) {
  const orders = await Order.findByUserId(user.id); // N回クエリ
}

// ✅ Good: 一括取得
const users = await User.findAll({
  include: [{ model: Order }],
});
```

**チェック項目**:
- [ ] N+1問題
- [ ] 不要なループ・計算
- [ ] 大量データの一括処理
- [ ] キャッシュの活用
- [ ] 適切なインデックス

### 6. テストカバレッジ

```typescript
// ❌ Bad: エッジケースのテストなし
it('should create user', () => {
  const user = createUser({ name: 'Test' });
  expect(user).toBeDefined();
});

// ✅ Good: 境界値・異常系も網羅
describe('createUser', () => {
  it('should create user with valid input', () => { /* ... */ });
  it('should throw error for empty name', () => { /* ... */ });
  it('should throw error for name exceeding 100 chars', () => { /* ... */ });
  it('should trim whitespace from name', () => { /* ... */ });
});
```

**チェック項目**:
- [ ] 正常系のテスト
- [ ] 異常系・エッジケースのテスト
- [ ] 境界値のテスト
- [ ] モックの適切な使用

---

## レビューレベル

| レベル | 説明 | 対象 |
|--------|------|------|
| **CRITICAL** | 必ず修正が必要 | セキュリティ脆弱性、データ破損リスク |
| **MAJOR** | 修正を強く推奨 | バグ、パフォーマンス問題 |
| **MINOR** | 改善推奨 | 可読性、ベストプラクティス |
| **SUGGESTION** | 提案 | より良い書き方、代替案 |

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  コードレビュー: src/services/user.service.ts
═══════════════════════════════════════════════════════════

【サマリー】
  CRITICAL: 1件
  MAJOR:    2件
  MINOR:    3件
  SUGGESTION: 2件

═══════════════════════════════════════════════════════════
【CRITICAL】
═══════════════════════════════════════════════════════════

[C001] SQLインジェクションの脆弱性
  場所: user.service.ts:45
  現在のコード:
    const query = `SELECT * FROM users WHERE email = '${email}'`;

  問題:
    ユーザー入力が直接SQLに埋め込まれており、
    SQLインジェクション攻撃が可能です。

  修正案:
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await db.query(query, [email]);

═══════════════════════════════════════════════════════════
【MAJOR】
═══════════════════════════════════════════════════════════

[M001] N+1クエリ問題
  場所: user.service.ts:60-65
  現在のコード:
    for (const user of users) {
      const orders = await this.orderRepo.findByUserId(user.id);
    }

  問題:
    ユーザー数分のクエリが発行されます。
    100ユーザーなら101クエリ（1 + 100）。

  修正案:
    const userIds = users.map(u => u.id);
    const ordersMap = await this.orderRepo.findByUserIds(userIds);
    // または Eager Loading を使用

[M002] エラーハンドリングの不足
  場所: user.service.ts:80
  現在のコード:
    const result = await externalApi.call();
    return result.data;

  問題:
    外部API呼び出しの失敗ケースが未処理です。

  修正案:
    try {
      const result = await externalApi.call();
      return result.data;
    } catch (error) {
      if (error instanceof TimeoutError) {
        throw new ServiceUnavailableError('External service timeout');
      }
      throw new InternalError('Failed to fetch external data');
    }

═══════════════════════════════════════════════════════════
【MINOR】
═══════════════════════════════════════════════════════════

[m001] 命名の改善
  場所: user.service.ts:20
  現在: const d = new Date();
  推奨: const createdAt = new Date();

[m002] マジックナンバー
  場所: user.service.ts:35
  現在: if (password.length < 8)
  推奨: const MIN_PASSWORD_LENGTH = 8;
        if (password.length < MIN_PASSWORD_LENGTH)

[m003] 不要なコメント
  場所: user.service.ts:50
  現在: // ユーザーを取得する
        const user = await this.userRepo.findById(id);
  推奨: コードが自明な場合、コメントは不要です

═══════════════════════════════════════════════════════════
【SUGGESTION】
═══════════════════════════════════════════════════════════

[S001] Early Return パターン
  場所: user.service.ts:70-85
  現在:
    if (user) {
      if (user.isActive) {
        // 20行の処理
      }
    }

  提案:
    if (!user) return null;
    if (!user.isActive) return null;
    // 処理

[S002] Object Destructuring
  場所: user.service.ts:90
  現在: const name = input.name;
        const email = input.email;
  提案: const { name, email } = input;

═══════════════════════════════════════════════════════════
【全体的なフィードバック】
═══════════════════════════════════════════════════════════

良い点:
- 関数の責務が明確に分離されている
- 型定義が適切に行われている
- テストが書かれている

改善点:
- セキュリティ関連の修正は必須
- エラーハンドリングの強化
- パフォーマンスの考慮

推奨アクション:
1. [C001] SQLインジェクション修正 → 即座に対応
2. [M001] N+1問題の解消 → 今回のPRで対応
3. [M002] エラーハンドリング追加 → 今回のPRで対応
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--focus` | 特定の観点に絞る | `--focus=security` |
| `--level` | 最小レベル指定 | `--level=major` |
| `--format` | 出力形式 | `--format=markdown` |

### フォーカスオプション

```bash
/dev:review src/ --focus=security    # セキュリティのみ
/dev:review src/ --focus=performance # パフォーマンスのみ
/dev:review src/ --focus=naming      # 命名のみ
```

---

## 引数

$ARGUMENTS
