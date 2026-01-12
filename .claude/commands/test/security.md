# セキュリティチェックスキル

コードの脆弱性をスキャンし、修正提案を行います。

## 使用方法
```
/test:security <ファイル/ディレクトリ> [--level=<レベル>]
```

---

## When to Use

- リリース前のセキュリティレビュー
- PRのセキュリティチェック
- 定期的な脆弱性スキャン
- 新規コードのレビュー

---

## チェック項目（OWASP Top 10）

### A01: アクセス制御の不備

```typescript
// ❌ 脆弱: 認可チェックなし
app.get('/users/:id', async (req, res) => {
  const user = await User.findById(req.params.id);
  res.json(user);
});

// ✅ 安全: 認可チェックあり
app.get('/users/:id', authenticate, async (req, res) => {
  const user = await User.findById(req.params.id);

  // 自分自身または管理者のみアクセス可
  if (user.id !== req.user.id && !req.user.isAdmin) {
    throw new ForbiddenError();
  }

  res.json(user);
});
```

### A02: 暗号化の失敗

```typescript
// ❌ 脆弱: 平文パスワード保存
const user = {
  email: input.email,
  password: input.password,  // 平文！
};

// ✅ 安全: ハッシュ化
import bcrypt from 'bcrypt';

const user = {
  email: input.email,
  passwordHash: await bcrypt.hash(input.password, 12),
};

// パスワード検証
const isValid = await bcrypt.compare(inputPassword, user.passwordHash);
```

### A03: インジェクション

#### SQLインジェクション

```typescript
// ❌ 脆弱: 文字列連結
const query = `SELECT * FROM users WHERE email = '${email}'`;

// ✅ 安全: パラメータ化クエリ
const query = 'SELECT * FROM users WHERE email = $1';
const result = await db.query(query, [email]);

// または ORM
const user = await User.findOne({ where: { email } });
```

#### NoSQLインジェクション

```typescript
// ❌ 脆弱: ユーザー入力をそのまま使用
const user = await User.findOne({
  email: req.body.email,
  password: req.body.password,  // { $gt: "" } で全件マッチ
});

// ✅ 安全: 型チェック + サニタイズ
if (typeof req.body.email !== 'string') {
  throw new ValidationError('Invalid email');
}

const user = await User.findOne({
  email: req.body.email,
});
if (user && await bcrypt.compare(req.body.password, user.passwordHash)) {
  // 認証成功
}
```

#### コマンドインジェクション

```typescript
// ❌ 脆弱: ユーザー入力を直接実行
const { exec } = require('child_process');
exec(`ping ${userInput}`);  // userInput = "; rm -rf /"

// ✅ 安全: 引数を配列で渡す
const { execFile } = require('child_process');
execFile('ping', ['-c', '4', userInput]);
```

### A04: 安全でない設計

```typescript
// ❌ 脆弱: レート制限なし
app.post('/login', async (req, res) => {
  // ブルートフォース攻撃可能
});

// ✅ 安全: レート制限
import rateLimit from 'express-rate-limit';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 5, // 5回まで
  message: 'Too many login attempts',
});

app.post('/login', loginLimiter, async (req, res) => {
  // ...
});
```

### A05: セキュリティの設定ミス

```typescript
// ❌ 脆弱: エラー詳細を露出
app.use((err, req, res, next) => {
  res.status(500).json({
    error: err.message,
    stack: err.stack,  // スタックトレース露出
  });
});

// ✅ 安全: 本番環境では詳細を隠す
app.use((err, req, res, next) => {
  console.error(err);  // ログには記録

  res.status(500).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
});
```

### A06: 脆弱で古いコンポーネント

```bash
# 脆弱性チェック
npm audit
pip-audit
go list -m -u all

# 自動修正
npm audit fix
```

### A07: 認証の不備

```typescript
// ❌ 脆弱: 弱いセッション管理
app.use(session({
  secret: 'secret',  // 弱いシークレット
  cookie: {
    // secure, httpOnly, sameSite なし
  },
}));

// ✅ 安全: 強固なセッション管理
app.use(session({
  secret: process.env.SESSION_SECRET,  // 環境変数から
  cookie: {
    secure: true,       // HTTPS必須
    httpOnly: true,     // JavaScript からアクセス不可
    sameSite: 'strict', // CSRF対策
    maxAge: 3600000,    // 1時間
  },
  resave: false,
  saveUninitialized: false,
}));
```

### A08: ソフトウェアとデータの整合性の不備

```typescript
// ❌ 脆弱: 署名検証なし
const payload = JSON.parse(req.body.payload);

// ✅ 安全: 署名検証
import crypto from 'crypto';

const signature = req.headers['x-signature'];
const expectedSignature = crypto
  .createHmac('sha256', process.env.WEBHOOK_SECRET)
  .update(req.body)
  .digest('hex');

if (!crypto.timingSafeEqual(
  Buffer.from(signature),
  Buffer.from(expectedSignature)
)) {
  throw new UnauthorizedError('Invalid signature');
}
```

### A09: セキュリティログとモニタリングの不備

```typescript
// ❌ 脆弱: ログなし
async function login(email: string, password: string) {
  const user = await authenticate(email, password);
  return user;
}

// ✅ 安全: 監査ログ
async function login(email: string, password: string, req: Request) {
  try {
    const user = await authenticate(email, password);

    await auditLog.info('login.success', {
      userId: user.id,
      email,
      ip: req.ip,
      userAgent: req.headers['user-agent'],
    });

    return user;
  } catch (error) {
    await auditLog.warn('login.failed', {
      email,
      ip: req.ip,
      reason: error.message,
    });
    throw error;
  }
}
```

### A10: Server-Side Request Forgery (SSRF)

```typescript
// ❌ 脆弱: ユーザー入力URLをそのまま使用
const response = await fetch(req.body.url);

// ✅ 安全: URL検証
const ALLOWED_HOSTS = ['api.example.com', 'cdn.example.com'];

function validateUrl(url: string): URL {
  const parsed = new URL(url);

  if (!ALLOWED_HOSTS.includes(parsed.host)) {
    throw new ValidationError('URL host not allowed');
  }

  if (parsed.protocol !== 'https:') {
    throw new ValidationError('Only HTTPS allowed');
  }

  // プライベートIPの除外
  if (isPrivateIP(parsed.hostname)) {
    throw new ValidationError('Private IP not allowed');
  }

  return parsed;
}
```

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  セキュリティスキャン: src/
═══════════════════════════════════════════════════════════

【サマリー】
  CRITICAL: 2
  HIGH:     3
  MEDIUM:   5
  LOW:      8
  INFO:     12

═══════════════════════════════════════════════════════════
【CRITICAL】
═══════════════════════════════════════════════════════════

[SEC-001] SQLインジェクション
  ファイル: src/repositories/user.repo.ts:45
  カテゴリ: A03 Injection

  脆弱なコード:
    const query = `SELECT * FROM users WHERE id = '${id}'`;

  修正案:
    const query = 'SELECT * FROM users WHERE id = $1';
    const result = await db.query(query, [id]);

[SEC-002] ハードコードされた認証情報
  ファイル: src/config/database.ts:10
  カテゴリ: A02 Cryptographic Failures

  脆弱なコード:
    const password = 'admin123';

  修正案:
    const password = process.env.DB_PASSWORD;

═══════════════════════════════════════════════════════════
【HIGH】
═══════════════════════════════════════════════════════════

[SEC-003] 認可チェックの欠如
  ファイル: src/controllers/user.controller.ts:30
  カテゴリ: A01 Broken Access Control

  脆弱なコード:
    app.delete('/users/:id', async (req, res) => {
      await User.destroy(req.params.id);
    });

  修正案:
    app.delete('/users/:id', authenticate, authorize(['admin']), ...)

═══════════════════════════════════════════════════════════
【依存関係の脆弱性】
═══════════════════════════════════════════════════════════

| パッケージ | バージョン | 脆弱性 | 修正バージョン |
|-----------|-----------|--------|---------------|
| lodash | 4.17.19 | Prototype Pollution | 4.17.21 |
| axios | 0.21.0 | SSRF | 0.21.1 |

修正コマンド:
  npm audit fix

═══════════════════════════════════════════════════════════
【推奨アクション】
═══════════════════════════════════════════════════════════

優先度順:
1. [SEC-001] SQLインジェクション修正 - 即座に対応
2. [SEC-002] 認証情報を環境変数へ移動
3. [SEC-003] 認可チェックを追加
4. 依存関係をアップデート
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--level` | 最小レベル | `--level=high` |
| `--output` | レポート出力 | `--output=security-report.md` |
| `--fix` | 自動修正（可能な場合） | `--fix` |

---

## 引数

$ARGUMENTS
