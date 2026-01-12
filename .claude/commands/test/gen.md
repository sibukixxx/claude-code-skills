# テスト自動生成スキル

既存コードからテストケースを自動生成します。

## 使用方法
```
/test:gen <ファイル/ディレクトリ> [--type=<テスト種類>] [--framework=<フレームワーク>]
```

---

## When to Use

- 既存コードへのテスト追加
- カバレッジ向上
- リファクタリング前のテスト整備
- レガシーコードの保護

## Scope

| 言語 | フレームワーク | テストファイル命名 |
|------|---------------|-------------------|
| TypeScript | Jest | `*.test.ts` / `*.spec.ts` |
| TypeScript | Vitest | `*.test.ts` / `*.spec.ts` |
| Python | pytest | `test_*.py` / `*_test.py` |
| Go | testing | `*_test.go` |

---

## テスト種類

| 種類 | 説明 | 対象 |
|------|------|------|
| **unit** | ユニットテスト | 関数、クラスメソッド |
| **integration** | 統合テスト | API、DB連携 |
| **e2e** | E2Eテスト | ユーザーフロー全体 |

---

## ワークフロー

### Step 1: コード解析

対象コードから以下を抽出:
- 関数/メソッドのシグネチャ
- 入力パラメータの型
- 戻り値の型
- 依存関係（外部呼び出し）
- エッジケースの候補

### Step 2: テストケース設計

```markdown
## 対象: calculateDiscount(price, discountRate)

### 正常系
1. 通常の割引計算（price=1000, rate=0.1 → 900）
2. 割引なし（rate=0 → 1000）
3. 100%割引（rate=1 → 0）

### 境界値
4. price=0
5. rate=0（下限）
6. rate=1（上限）
7. 小数点の丸め

### 異常系
8. 負の価格
9. 負の割引率
10. 割引率が1を超える
11. null/undefined入力
```

### Step 3: テストコード生成

---

## 生成テンプレート

### TypeScript (Jest/Vitest)

```typescript
// src/utils/calculator.test.ts
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { calculateDiscount } from './calculator';

describe('calculateDiscount', () => {
  // ===== 正常系 =====
  describe('正常系', () => {
    it('should apply 10% discount correctly', () => {
      const result = calculateDiscount(1000, 0.1);
      expect(result).toBe(900);
    });

    it('should return original price when discount is 0', () => {
      const result = calculateDiscount(1000, 0);
      expect(result).toBe(1000);
    });

    it('should return 0 when discount is 100%', () => {
      const result = calculateDiscount(1000, 1);
      expect(result).toBe(0);
    });

    it('should handle decimal prices', () => {
      const result = calculateDiscount(99.99, 0.1);
      expect(result).toBeCloseTo(89.99, 2);
    });
  });

  // ===== 境界値 =====
  describe('境界値', () => {
    it('should handle zero price', () => {
      const result = calculateDiscount(0, 0.1);
      expect(result).toBe(0);
    });

    it('should handle minimum discount rate', () => {
      const result = calculateDiscount(1000, 0);
      expect(result).toBe(1000);
    });

    it('should handle maximum discount rate', () => {
      const result = calculateDiscount(1000, 1);
      expect(result).toBe(0);
    });

    it('should handle very small discount', () => {
      const result = calculateDiscount(1000, 0.001);
      expect(result).toBeCloseTo(999, 0);
    });
  });

  // ===== 異常系 =====
  describe('異常系', () => {
    it('should throw error for negative price', () => {
      expect(() => calculateDiscount(-100, 0.1))
        .toThrow('Price must be non-negative');
    });

    it('should throw error for negative discount rate', () => {
      expect(() => calculateDiscount(1000, -0.1))
        .toThrow('Discount rate must be between 0 and 1');
    });

    it('should throw error for discount rate over 1', () => {
      expect(() => calculateDiscount(1000, 1.5))
        .toThrow('Discount rate must be between 0 and 1');
    });

    it('should throw error for null price', () => {
      expect(() => calculateDiscount(null as any, 0.1))
        .toThrow();
    });
  });
});
```

### Python (pytest)

```python
# tests/test_calculator.py
import pytest
from decimal import Decimal
from utils.calculator import calculate_discount

class TestCalculateDiscount:
    """calculate_discount関数のテスト"""

    # ===== 正常系 =====
    class TestNormalCases:
        def test_apply_10_percent_discount(self):
            result = calculate_discount(1000, 0.1)
            assert result == 900

        def test_return_original_price_when_no_discount(self):
            result = calculate_discount(1000, 0)
            assert result == 1000

        def test_return_zero_when_100_percent_discount(self):
            result = calculate_discount(1000, 1)
            assert result == 0

        def test_handle_decimal_prices(self):
            result = calculate_discount(Decimal("99.99"), Decimal("0.1"))
            assert result == pytest.approx(Decimal("89.99"), rel=0.01)

    # ===== 境界値 =====
    class TestBoundaryValues:
        def test_zero_price(self):
            result = calculate_discount(0, 0.1)
            assert result == 0

        @pytest.mark.parametrize("price,rate,expected", [
            (1000, 0, 1000),      # 最小割引率
            (1000, 1, 0),         # 最大割引率
            (1000, 0.001, 999),   # 極小割引
        ])
        def test_discount_rate_boundaries(self, price, rate, expected):
            result = calculate_discount(price, rate)
            assert result == pytest.approx(expected, rel=0.01)

    # ===== 異常系 =====
    class TestErrorCases:
        def test_negative_price_raises_error(self):
            with pytest.raises(ValueError, match="Price must be non-negative"):
                calculate_discount(-100, 0.1)

        def test_negative_discount_rate_raises_error(self):
            with pytest.raises(ValueError, match="Discount rate must be between 0 and 1"):
                calculate_discount(1000, -0.1)

        def test_discount_rate_over_1_raises_error(self):
            with pytest.raises(ValueError, match="Discount rate must be between 0 and 1"):
                calculate_discount(1000, 1.5)

        def test_none_price_raises_error(self):
            with pytest.raises(TypeError):
                calculate_discount(None, 0.1)
```

### Go (testing)

```go
// calculator_test.go
package utils

import (
    "math"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestCalculateDiscount(t *testing.T) {
    // ===== 正常系 =====
    t.Run("正常系", func(t *testing.T) {
        t.Run("should apply 10% discount correctly", func(t *testing.T) {
            result, err := CalculateDiscount(1000, 0.1)
            require.NoError(t, err)
            assert.Equal(t, 900.0, result)
        })

        t.Run("should return original price when no discount", func(t *testing.T) {
            result, err := CalculateDiscount(1000, 0)
            require.NoError(t, err)
            assert.Equal(t, 1000.0, result)
        })

        t.Run("should return 0 when 100% discount", func(t *testing.T) {
            result, err := CalculateDiscount(1000, 1)
            require.NoError(t, err)
            assert.Equal(t, 0.0, result)
        })
    })

    // ===== 境界値 =====
    t.Run("境界値", func(t *testing.T) {
        testCases := []struct {
            name     string
            price    float64
            rate     float64
            expected float64
        }{
            {"zero price", 0, 0.1, 0},
            {"minimum rate", 1000, 0, 1000},
            {"maximum rate", 1000, 1, 0},
        }

        for _, tc := range testCases {
            t.Run(tc.name, func(t *testing.T) {
                result, err := CalculateDiscount(tc.price, tc.rate)
                require.NoError(t, err)
                assert.InDelta(t, tc.expected, result, 0.01)
            })
        }
    })

    // ===== 異常系 =====
    t.Run("異常系", func(t *testing.T) {
        t.Run("should return error for negative price", func(t *testing.T) {
            _, err := CalculateDiscount(-100, 0.1)
            assert.Error(t, err)
            assert.Contains(t, err.Error(), "price must be non-negative")
        })

        t.Run("should return error for invalid discount rate", func(t *testing.T) {
            _, err := CalculateDiscount(1000, -0.1)
            assert.Error(t, err)

            _, err = CalculateDiscount(1000, 1.5)
            assert.Error(t, err)
        })
    })
}

// ベンチマークテスト
func BenchmarkCalculateDiscount(b *testing.B) {
    for i := 0; i < b.N; i++ {
        CalculateDiscount(1000, 0.1)
    }
}
```

---

## モック生成

### 依存関係のモック

```typescript
// 元のコード
export class OrderService {
  constructor(
    private readonly orderRepo: OrderRepository,
    private readonly paymentGateway: PaymentGateway,
    private readonly emailService: EmailService,
  ) {}

  async createOrder(input: CreateOrderInput): Promise<Order> {
    const order = await this.orderRepo.save(Order.create(input));
    await this.paymentGateway.charge(order.totalAmount);
    await this.emailService.sendConfirmation(order);
    return order;
  }
}
```

```typescript
// 生成されるテスト
describe('OrderService', () => {
  let orderService: OrderService;
  let mockOrderRepo: MockProxy<OrderRepository>;
  let mockPaymentGateway: MockProxy<PaymentGateway>;
  let mockEmailService: MockProxy<EmailService>;

  beforeEach(() => {
    mockOrderRepo = mock<OrderRepository>();
    mockPaymentGateway = mock<PaymentGateway>();
    mockEmailService = mock<EmailService>();

    orderService = new OrderService(
      mockOrderRepo,
      mockPaymentGateway,
      mockEmailService,
    );
  });

  describe('createOrder', () => {
    const mockOrder = {
      id: 'order-123',
      totalAmount: 1000,
      // ...
    };

    beforeEach(() => {
      mockOrderRepo.save.mockResolvedValue(mockOrder);
      mockPaymentGateway.charge.mockResolvedValue({ success: true });
      mockEmailService.sendConfirmation.mockResolvedValue(undefined);
    });

    it('should create order and process payment', async () => {
      const input = { /* ... */ };

      const result = await orderService.createOrder(input);

      expect(mockOrderRepo.save).toHaveBeenCalledTimes(1);
      expect(mockPaymentGateway.charge).toHaveBeenCalledWith(1000);
      expect(mockEmailService.sendConfirmation).toHaveBeenCalledWith(mockOrder);
      expect(result).toEqual(mockOrder);
    });

    it('should rollback when payment fails', async () => {
      mockPaymentGateway.charge.mockRejectedValue(new PaymentError());

      await expect(orderService.createOrder(input))
        .rejects.toThrow(PaymentError);

      expect(mockOrderRepo.delete).toHaveBeenCalled();
      expect(mockEmailService.sendConfirmation).not.toHaveBeenCalled();
    });
  });
});
```

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  テスト生成レポート: src/services/order.service.ts
═══════════════════════════════════════════════════════════

【対象】
  ファイル: src/services/order.service.ts
  クラス: OrderService
  メソッド: createOrder, cancelOrder, getOrderById

【生成ファイル】
  src/services/order.service.test.ts

【生成テストケース】
  createOrder:
    - ✅ 正常系: 注文作成成功
    - ✅ 正常系: 複数商品の注文
    - ✅ 異常系: 在庫不足
    - ✅ 異常系: 決済失敗
    - ✅ 異常系: 無効な入力

  cancelOrder:
    - ✅ 正常系: キャンセル成功
    - ✅ 異常系: キャンセル不可ステータス
    - ✅ 異常系: 注文が見つからない

  getOrderById:
    - ✅ 正常系: 注文取得成功
    - ✅ 異常系: 注文が見つからない

【統計】
  総テストケース: 10
  正常系: 4
  異常系: 6

【モック】
  - OrderRepository
  - PaymentGateway
  - EmailService

【次のステップ】
  1. npm test でテスト実行
  2. カバレッジ確認: npm test -- --coverage
  3. 必要に応じてテストケース追加
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--type` | テスト種類 | `--type=unit` |
| `--framework` | フレームワーク指定 | `--framework=vitest` |
| `--coverage` | カバレッジ目標 | `--coverage=80` |
| `--mock` | モック生成方法 | `--mock=jest-mock-extended` |

---

## 引数

$ARGUMENTS
