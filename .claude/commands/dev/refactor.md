# リファクタリングスキル

コード品質を改善しながら動作を維持します。

## 使用方法
```
/dev:refactor <ファイル/関数> [--pattern=<パターン>]
```

---

## When to Use

- コードの可読性向上
- 重複コードの除去
- 複雑な処理の分割
- デザインパターンの適用
- 技術的負債の解消

## Scope

**制約**: 機能の変更なし、テストがパスし続けること

---

## リファクタリングパターン

### 1. 命名改善

```typescript
// Before
const d = new Date();
const u = users.filter(x => x.a > 18);
function proc(d) { /* ... */ }

// After
const currentDate = new Date();
const adultUsers = users.filter(user => user.age >= 18);
function processOrder(orderData) { /* ... */ }
```

### 2. 関数の抽出

```typescript
// Before
function processOrder(order: Order) {
  // 100行の処理...
  // バリデーション
  if (!order.items.length) throw new Error('No items');
  if (order.total < 0) throw new Error('Invalid total');

  // 在庫チェック
  for (const item of order.items) {
    const stock = await getStock(item.productId);
    if (stock < item.quantity) throw new Error('Out of stock');
  }

  // 決済処理
  const payment = await processPayment(order.paymentMethod, order.total);
  if (!payment.success) throw new Error('Payment failed');

  // 注文確定
  // ...
}

// After
function processOrder(order: Order) {
  validateOrder(order);
  await checkInventory(order.items);
  await processPayment(order);
  await confirmOrder(order);
}

function validateOrder(order: Order): void {
  if (!order.items.length) throw new ValidationError('No items');
  if (order.total < 0) throw new ValidationError('Invalid total');
}

async function checkInventory(items: OrderItem[]): Promise<void> {
  for (const item of items) {
    const stock = await getStock(item.productId);
    if (stock < item.quantity) {
      throw new InventoryError(`Out of stock: ${item.productId}`);
    }
  }
}
```

### 3. 条件分岐の簡略化

```typescript
// Before: ネストした条件
function getDiscount(user: User, order: Order): number {
  if (user) {
    if (user.isPremium) {
      if (order.total > 10000) {
        return 0.2;
      } else {
        return 0.1;
      }
    } else {
      if (order.total > 10000) {
        return 0.05;
      } else {
        return 0;
      }
    }
  }
  return 0;
}

// After: Early Return + テーブル駆動
const DISCOUNT_RATES = {
  premium: { high: 0.2, low: 0.1 },
  regular: { high: 0.05, low: 0 },
};

function getDiscount(user: User | null, order: Order): number {
  if (!user) return 0;

  const tier = user.isPremium ? 'premium' : 'regular';
  const amount = order.total > 10000 ? 'high' : 'low';

  return DISCOUNT_RATES[tier][amount];
}
```

### 4. 重複除去（DRY）

```typescript
// Before: 重複コード
async function createUser(data: CreateUserDto) {
  const user = new User();
  user.email = data.email;
  user.name = data.name;
  user.createdAt = new Date();
  user.updatedAt = new Date();
  await this.userRepo.save(user);
  await this.sendWelcomeEmail(user);
  await this.createAuditLog('user.created', user);
  return user;
}

async function createAdmin(data: CreateAdminDto) {
  const admin = new User();
  admin.email = data.email;
  admin.name = data.name;
  admin.role = 'admin';
  admin.createdAt = new Date();
  admin.updatedAt = new Date();
  await this.userRepo.save(admin);
  await this.sendWelcomeEmail(admin);
  await this.createAuditLog('admin.created', admin);
  return admin;
}

// After: 共通化
async function createUser(data: CreateUserDto, role: Role = 'user') {
  const user = this.buildUser(data, role);
  await this.userRepo.save(user);
  await this.postCreateActions(user, role);
  return user;
}

private buildUser(data: CreateUserDto, role: Role): User {
  return {
    ...data,
    role,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

private async postCreateActions(user: User, role: Role): Promise<void> {
  await this.sendWelcomeEmail(user);
  await this.createAuditLog(`${role}.created`, user);
}
```

### 5. クラス/モジュールの分割

```typescript
// Before: 巨大クラス（God Object）
class OrderService {
  // 注文処理
  createOrder() { /* ... */ }
  cancelOrder() { /* ... */ }

  // 決済処理
  processPayment() { /* ... */ }
  refundPayment() { /* ... */ }

  // 通知
  sendOrderConfirmation() { /* ... */ }
  sendShippingNotification() { /* ... */ }

  // レポート
  generateDailySalesReport() { /* ... */ }
  generateMonthlyReport() { /* ... */ }
}

// After: 責務分離
class OrderService {
  constructor(
    private paymentService: PaymentService,
    private notificationService: NotificationService,
  ) {}

  async createOrder(input: CreateOrderInput): Promise<Order> {
    const order = await this.orderRepo.save(Order.create(input));
    await this.paymentService.process(order);
    await this.notificationService.sendConfirmation(order);
    return order;
  }
}

class PaymentService {
  async process(order: Order): Promise<PaymentResult> { /* ... */ }
  async refund(order: Order): Promise<RefundResult> { /* ... */ }
}

class NotificationService {
  async sendConfirmation(order: Order): Promise<void> { /* ... */ }
  async sendShippingUpdate(order: Order): Promise<void> { /* ... */ }
}

class ReportService {
  async generateDailySales(): Promise<Report> { /* ... */ }
  async generateMonthly(): Promise<Report> { /* ... */ }
}
```

### 6. デザインパターン適用

#### Strategy パターン

```typescript
// Before: 条件分岐の塊
function calculateShipping(order: Order): number {
  if (order.shippingMethod === 'standard') {
    return order.weight * 100;
  } else if (order.shippingMethod === 'express') {
    return order.weight * 200 + 500;
  } else if (order.shippingMethod === 'overnight') {
    return order.weight * 300 + 1000;
  }
  throw new Error('Unknown shipping method');
}

// After: Strategy パターン
interface ShippingStrategy {
  calculate(order: Order): number;
}

class StandardShipping implements ShippingStrategy {
  calculate(order: Order): number {
    return order.weight * 100;
  }
}

class ExpressShipping implements ShippingStrategy {
  calculate(order: Order): number {
    return order.weight * 200 + 500;
  }
}

const strategies: Record<string, ShippingStrategy> = {
  standard: new StandardShipping(),
  express: new ExpressShipping(),
  overnight: new OvernightShipping(),
};

function calculateShipping(order: Order): number {
  const strategy = strategies[order.shippingMethod];
  if (!strategy) throw new Error('Unknown shipping method');
  return strategy.calculate(order);
}
```

---

## リファクタリング手順

```
┌─────────────────────────────────────────────────────────┐
│              リファクタリングフロー                      │
└─────────────────────────────────────────────────────────┘

1. テストの確認
   └─ 既存テストがパスすることを確認
   └─ カバレッジが不足していれば追加

2. 変更の特定
   └─ 改善対象のコードを特定
   └─ 影響範囲を把握

3. 小さなステップで変更
   └─ 一度に1つの変更のみ
   └─ 各ステップでテスト実行

4. テスト実行
   └─ 全テストがパスすることを確認
   └─ 動作が変わっていないことを確認

5. コミット
   └─ 意味のある単位でコミット
   └─ 変更内容を明確に記述
```

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  リファクタリング提案: OrderService
═══════════════════════════════════════════════════════════

【対象】
  ファイル: src/services/order.service.ts
  行数: 450行 → 120行（目標）

【検出された問題】

1. God Object
   - OrderServiceが複数の責務を持っている
   - 提案: PaymentService, NotificationServiceへ分割

2. 重複コード
   - createOrder, updateOrderで同様のバリデーション
   - 提案: validateOrderへ抽出

3. 複雑な条件分岐
   - calculateDiscount: 5段ネスト
   - 提案: Strategyパターン適用

【リファクタリング計画】

Step 1: バリデーション抽出
  - validateOrder()関数を作成
  - テスト: ✓ 既存テストパス確認

Step 2: PaymentService分離
  - PaymentServiceクラス作成
  - OrderServiceから決済ロジック移動
  - テスト: ✓ 既存テストパス確認

Step 3: 条件分岐簡略化
  - DiscountStrategyインターフェース作成
  - 各割引パターンをクラス化
  - テスト: ✓ 既存テストパス確認

【変更後のコード】
（改善後のコード例）
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--pattern` | 適用パターン | `--pattern=extract-function` |
| `--dry-run` | 変更のプレビュー | `--dry-run` |
| `--explain` | 詳細な説明付き | `--explain` |

---

## 引数

$ARGUMENTS
