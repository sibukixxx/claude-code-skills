# SQL生成スキル

自然言語からSQLクエリを生成します。

## 使用方法
```
/data:sql "<クエリ内容>" [--db=<データベース>] [--explain]
```

---

## When to Use

- 複雑なクエリの作成
- レポート用SQL作成
- データ分析クエリ
- パフォーマンス改善（インデックス提案）

## Scope

| データベース | 方言 | 特徴 |
|-------------|------|------|
| PostgreSQL | PostgreSQL | Window関数、CTE、JSONB |
| MySQL | MySQL 8.0+ | JSON関数、CTE |
| SQLite | SQLite | 軽量、組み込み |

---

## 入力形式

### 自然言語での指定

```
/data:sql "先月の売上TOP10商品を取得"
/data:sql "アクティブユーザーの月別推移"
/data:sql "注文がないユーザー一覧"
```

### スキーマ情報の提供

```sql
-- テーブル定義を提供
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  total_amount DECIMAL(10,2),
  status VARCHAR(20),
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## クエリパターン

### 基本的なSELECT

```
入力: "全ユーザーの名前とメールを取得"
```

```sql
SELECT name, email
FROM users
ORDER BY created_at DESC;
```

### フィルタリング

```
入力: "先月登録したアクティブユーザー"
```

```sql
SELECT *
FROM users
WHERE status = 'active'
  AND created_at >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
  AND created_at < DATE_TRUNC('month', CURRENT_DATE);
```

### 集計

```
入力: "商品カテゴリ別の売上合計と件数"
```

```sql
SELECT
  c.name AS category_name,
  COUNT(o.id) AS order_count,
  SUM(oi.quantity * oi.unit_price) AS total_sales
FROM categories c
JOIN products p ON p.category_id = c.id
JOIN order_items oi ON oi.product_id = p.id
JOIN orders o ON o.id = oi.order_id
WHERE o.status = 'completed'
GROUP BY c.id, c.name
ORDER BY total_sales DESC;
```

### JOIN

```
入力: "ユーザーごとの注文数と合計金額"
```

```sql
SELECT
  u.id,
  u.name,
  u.email,
  COUNT(o.id) AS order_count,
  COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id, u.name, u.email
ORDER BY total_spent DESC;
```

### サブクエリ

```
入力: "平均注文金額以上の注文をしたユーザー"
```

```sql
SELECT DISTINCT u.*
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE o.total_amount >= (
  SELECT AVG(total_amount)
  FROM orders
  WHERE status = 'completed'
);
```

### CTE（共通テーブル式）

```
入力: "3ヶ月連続で注文があるユーザー"
```

```sql
WITH monthly_orders AS (
  SELECT
    user_id,
    DATE_TRUNC('month', created_at) AS order_month
  FROM orders
  WHERE status = 'completed'
  GROUP BY user_id, DATE_TRUNC('month', created_at)
),
consecutive_months AS (
  SELECT
    user_id,
    order_month,
    order_month - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_month) * INTERVAL '1 month') AS grp
  FROM monthly_orders
),
streak_counts AS (
  SELECT
    user_id,
    COUNT(*) AS streak_length
  FROM consecutive_months
  GROUP BY user_id, grp
  HAVING COUNT(*) >= 3
)
SELECT DISTINCT u.*
FROM users u
JOIN streak_counts sc ON sc.user_id = u.id;
```

### Window関数

```
入力: "各ユーザーの注文履歴と累計金額"
```

```sql
SELECT
  u.name,
  o.id AS order_id,
  o.total_amount,
  o.created_at,
  SUM(o.total_amount) OVER (
    PARTITION BY u.id
    ORDER BY o.created_at
  ) AS running_total,
  ROW_NUMBER() OVER (
    PARTITION BY u.id
    ORDER BY o.created_at DESC
  ) AS order_rank
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE o.status = 'completed'
ORDER BY u.id, o.created_at DESC;
```

### ランキング

```
入力: "売上TOP10商品（同率順位あり）"
```

```sql
SELECT
  p.name,
  SUM(oi.quantity * oi.unit_price) AS total_sales,
  RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS sales_rank
FROM products p
JOIN order_items oi ON oi.product_id = p.id
JOIN orders o ON o.id = oi.order_id
WHERE o.status = 'completed'
GROUP BY p.id, p.name
ORDER BY sales_rank
LIMIT 10;
```

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  SQL生成: 先月の売上TOP10商品
═══════════════════════════════════════════════════════════

【生成クエリ】

```sql
SELECT
  p.id,
  p.name,
  SUM(oi.quantity) AS total_quantity,
  SUM(oi.quantity * oi.unit_price) AS total_sales
FROM products p
JOIN order_items oi ON oi.product_id = p.id
JOIN orders o ON o.id = oi.order_id
WHERE o.status = 'completed'
  AND o.created_at >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
  AND o.created_at < DATE_TRUNC('month', CURRENT_DATE)
GROUP BY p.id, p.name
ORDER BY total_sales DESC
LIMIT 10;
```

【クエリ解説】

1. `products` と `order_items` を結合して商品ごとの注文を取得
2. `orders` と結合してステータスと日付でフィルタ
3. 先月（前月1日〜末日）の完了注文のみ対象
4. 商品ごとに数量と売上金額を集計
5. 売上金額の降順でソートしてTOP10を取得

【使用テーブル】
- products: 商品マスタ
- order_items: 注文明細
- orders: 注文ヘッダ

【パフォーマンス考慮】
推奨インデックス:
```sql
CREATE INDEX idx_orders_status_created ON orders(status, created_at);
CREATE INDEX idx_order_items_product ON order_items(product_id);
```

【実行計画（概算）】
- orders: 日付範囲でフィルタ
- order_items: product_idでJOIN
- 集計: HashAggregate
```

---

## インデックス提案

```
入力: "このクエリに最適なインデックスを提案"
```

```sql
-- 元のクエリ
SELECT *
FROM orders
WHERE user_id = 123
  AND status = 'completed'
  AND created_at >= '2025-01-01';
```

```
【インデックス提案】

1. 複合インデックス（推奨）
   CREATE INDEX idx_orders_user_status_created
   ON orders(user_id, status, created_at);

   理由: WHERE句の全条件をカバー

2. 部分インデックス（代替案）
   CREATE INDEX idx_orders_completed_user
   ON orders(user_id, created_at)
   WHERE status = 'completed';

   理由: 'completed'ステータスのみ頻繁に検索する場合

【EXPLAIN ANALYZE結果の予測】
Before: Seq Scan on orders (cost=0.00..1000.00)
After:  Index Scan using idx_orders_user_status_created (cost=0.00..10.00)
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--db` | データベース種類 | `--db=postgresql` |
| `--explain` | 実行計画を含める | `--explain` |
| `--index` | インデックス提案 | `--index` |
| `--format` | 出力形式 | `--format=pretty` |

---

## 引数

$ARGUMENTS
