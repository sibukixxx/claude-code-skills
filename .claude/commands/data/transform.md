# データ変換スキル

データ変換パイプラインを設計・実装します。

## 使用方法
```
/data:transform <変換内容> [--input=<入力形式>] [--output=<出力形式>]
```

---

## When to Use

- データフォーマット変換
- ETL処理の実装
- データクレンジング
- 集計・レポート作成

## Scope

| 入力形式 | 出力形式 |
|---------|---------|
| CSV | JSON, CSV, DB |
| JSON / JSONL | CSV, JSON, DB |
| DB (SQL) | CSV, JSON, Excel |
| Excel | CSV, JSON, DB |

---

## 変換操作

### 1. マッピング（カラム変換）

```
入力: カラム名を日本語から英語に変換
```

#### TypeScript

```typescript
interface ColumnMapping {
  [source: string]: string | ((value: any) => any);
}

const mapping: ColumnMapping = {
  '顧客名': 'customerName',
  'メールアドレス': 'email',
  '電話番号': (v) => v.replace(/-/g, ''),  // ハイフン除去
  '登録日': (v) => new Date(v).toISOString(),
};

function mapColumns<T, R>(data: T[], mapping: ColumnMapping): R[] {
  return data.map(row => {
    const result: any = {};
    for (const [source, target] of Object.entries(mapping)) {
      const value = (row as any)[source];
      if (typeof target === 'function') {
        result[source] = target(value);
      } else {
        result[target] = value;
      }
    }
    return result as R;
  });
}
```

#### Python

```python
from typing import Callable, Dict, Any, List

ColumnMapping = Dict[str, str | Callable[[Any], Any]]

def map_columns(data: List[dict], mapping: ColumnMapping) -> List[dict]:
    result = []
    for row in data:
        new_row = {}
        for source, target in mapping.items():
            value = row.get(source)
            if callable(target):
                new_row[source] = target(value)
            else:
                new_row[target] = value
        result.append(new_row)
    return result

# 使用例
mapping = {
    '顧客名': 'customer_name',
    'メールアドレス': 'email',
    '電話番号': lambda v: v.replace('-', '') if v else None,
    '登録日': lambda v: datetime.fromisoformat(v).isoformat() if v else None,
}

transformed = map_columns(data, mapping)
```

### 2. フィルタリング

```
入力: アクティブユーザーのみ抽出
```

#### TypeScript

```typescript
interface FilterCondition<T> {
  field: keyof T;
  operator: '=' | '!=' | '>' | '<' | '>=' | '<=' | 'in' | 'contains';
  value: any;
}

function filterData<T>(data: T[], conditions: FilterCondition<T>[]): T[] {
  return data.filter(row => {
    return conditions.every(cond => {
      const fieldValue = row[cond.field];
      switch (cond.operator) {
        case '=': return fieldValue === cond.value;
        case '!=': return fieldValue !== cond.value;
        case '>': return fieldValue > cond.value;
        case '<': return fieldValue < cond.value;
        case '>=': return fieldValue >= cond.value;
        case '<=': return fieldValue <= cond.value;
        case 'in': return (cond.value as any[]).includes(fieldValue);
        case 'contains': return String(fieldValue).includes(cond.value);
        default: return true;
      }
    });
  });
}

// 使用例
const activeUsers = filterData(users, [
  { field: 'status', operator: '=', value: 'active' },
  { field: 'lastLoginAt', operator: '>=', value: lastMonth },
]);
```

#### Python

```python
from dataclasses import dataclass
from typing import Any, List
from operator import eq, ne, gt, lt, ge, le

@dataclass
class FilterCondition:
    field: str
    operator: str
    value: Any

OPERATORS = {
    '=': eq, '!=': ne, '>': gt, '<': lt, '>=': ge, '<=': le,
    'in': lambda a, b: a in b,
    'contains': lambda a, b: b in str(a),
}

def filter_data(data: List[dict], conditions: List[FilterCondition]) -> List[dict]:
    def matches(row: dict) -> bool:
        for cond in conditions:
            field_value = row.get(cond.field)
            op_func = OPERATORS.get(cond.operator)
            if op_func and not op_func(field_value, cond.value):
                return False
        return True

    return [row for row in data if matches(row)]
```

### 3. 集計（グループ化）

```
入力: カテゴリ別の売上集計
```

#### TypeScript

```typescript
interface AggregateConfig {
  groupBy: string[];
  aggregations: {
    [outputField: string]: {
      field: string;
      func: 'sum' | 'avg' | 'count' | 'min' | 'max';
    };
  };
}

function aggregate<T>(data: T[], config: AggregateConfig): any[] {
  const groups = new Map<string, T[]>();

  // グループ化
  for (const row of data) {
    const key = config.groupBy.map(f => (row as any)[f]).join('|');
    if (!groups.has(key)) {
      groups.set(key, []);
    }
    groups.get(key)!.push(row);
  }

  // 集計
  return Array.from(groups.entries()).map(([key, rows]) => {
    const result: any = {};

    // グループキーを結果に含める
    const keyParts = key.split('|');
    config.groupBy.forEach((field, i) => {
      result[field] = keyParts[i];
    });

    // 集計
    for (const [outputField, agg] of Object.entries(config.aggregations)) {
      const values = rows.map(r => (r as any)[agg.field]).filter(v => v != null);
      switch (agg.func) {
        case 'sum':
          result[outputField] = values.reduce((a, b) => a + b, 0);
          break;
        case 'avg':
          result[outputField] = values.reduce((a, b) => a + b, 0) / values.length;
          break;
        case 'count':
          result[outputField] = values.length;
          break;
        case 'min':
          result[outputField] = Math.min(...values);
          break;
        case 'max':
          result[outputField] = Math.max(...values);
          break;
      }
    }

    return result;
  });
}

// 使用例
const salesByCategory = aggregate(orders, {
  groupBy: ['categoryId'],
  aggregations: {
    totalSales: { field: 'amount', func: 'sum' },
    orderCount: { field: 'id', func: 'count' },
    avgOrderValue: { field: 'amount', func: 'avg' },
  },
});
```

#### Python (pandas)

```python
import pandas as pd

def aggregate_data(df: pd.DataFrame, config: dict) -> pd.DataFrame:
    """
    config = {
        'group_by': ['category_id'],
        'aggregations': {
            'total_sales': ('amount', 'sum'),
            'order_count': ('id', 'count'),
            'avg_order_value': ('amount', 'mean'),
        }
    }
    """
    agg_dict = {
        output_field: pd.NamedAgg(column=col, aggfunc=func)
        for output_field, (col, func) in config['aggregations'].items()
    }

    return df.groupby(config['group_by']).agg(**agg_dict).reset_index()

# 使用例
result = aggregate_data(df, {
    'group_by': ['category_id'],
    'aggregations': {
        'total_sales': ('amount', 'sum'),
        'order_count': ('id', 'count'),
    }
})
```

### 4. 結合（JOIN）

```
入力: ユーザーデータと注文データを結合
```

#### TypeScript

```typescript
type JoinType = 'inner' | 'left' | 'right' | 'outer';

function joinData<L, R>(
  left: L[],
  right: R[],
  leftKey: keyof L,
  rightKey: keyof R,
  type: JoinType = 'inner'
): (L & Partial<R>)[] {
  const rightMap = new Map<any, R[]>();
  for (const r of right) {
    const key = r[rightKey];
    if (!rightMap.has(key)) {
      rightMap.set(key, []);
    }
    rightMap.get(key)!.push(r);
  }

  const result: (L & Partial<R>)[] = [];

  for (const l of left) {
    const matches = rightMap.get(l[leftKey]) || [];

    if (matches.length > 0) {
      for (const r of matches) {
        result.push({ ...l, ...r });
      }
    } else if (type === 'left' || type === 'outer') {
      result.push({ ...l } as L & Partial<R>);
    }
  }

  // Right/Outer join: 左側にマッチしない右側のレコード
  if (type === 'right' || type === 'outer') {
    const leftKeys = new Set(left.map(l => l[leftKey]));
    for (const r of right) {
      if (!leftKeys.has(r[rightKey])) {
        result.push({ ...r } as any);
      }
    }
  }

  return result;
}

// 使用例
const usersWithOrders = joinData(users, orders, 'id', 'userId', 'left');
```

### 5. データクレンジング

```
入力: データの正規化・クリーニング
```

```typescript
interface CleansingConfig {
  trimStrings?: boolean;
  removeNulls?: boolean;
  normalizeWhitespace?: boolean;
  convertDates?: string[];  // 日付に変換するフィールド
  convertNumbers?: string[]; // 数値に変換するフィールド
  defaultValues?: Record<string, any>;
}

function cleanseData<T>(data: T[], config: CleansingConfig): T[] {
  return data.map(row => {
    const result: any = { ...row };

    for (const [key, value] of Object.entries(result)) {
      // 文字列のトリム
      if (config.trimStrings && typeof value === 'string') {
        result[key] = value.trim();
      }

      // 空白の正規化
      if (config.normalizeWhitespace && typeof value === 'string') {
        result[key] = result[key].replace(/\s+/g, ' ');
      }

      // 日付変換
      if (config.convertDates?.includes(key) && value) {
        result[key] = new Date(value);
      }

      // 数値変換
      if (config.convertNumbers?.includes(key) && value) {
        result[key] = Number(value);
      }

      // null除去
      if (config.removeNulls && (value === null || value === '')) {
        delete result[key];
      }
    }

    // デフォルト値の適用
    if (config.defaultValues) {
      for (const [key, defaultValue] of Object.entries(config.defaultValues)) {
        if (result[key] === undefined || result[key] === null) {
          result[key] = defaultValue;
        }
      }
    }

    return result as T;
  });
}
```

---

## パイプライン構築

```typescript
// パイプラインビルダー
class DataPipeline<T> {
  private data: T[];

  constructor(data: T[]) {
    this.data = data;
  }

  map<R>(mapping: ColumnMapping): DataPipeline<R> {
    this.data = mapColumns(this.data, mapping) as any;
    return this as any;
  }

  filter(conditions: FilterCondition<T>[]): DataPipeline<T> {
    this.data = filterData(this.data, conditions);
    return this;
  }

  aggregate(config: AggregateConfig): DataPipeline<any> {
    this.data = aggregate(this.data, config) as any;
    return this as any;
  }

  cleanse(config: CleansingConfig): DataPipeline<T> {
    this.data = cleanseData(this.data, config);
    return this;
  }

  sort(field: keyof T, order: 'asc' | 'desc' = 'asc'): DataPipeline<T> {
    this.data.sort((a, b) => {
      const aVal = a[field];
      const bVal = b[field];
      const cmp = aVal < bVal ? -1 : aVal > bVal ? 1 : 0;
      return order === 'asc' ? cmp : -cmp;
    });
    return this;
  }

  result(): T[] {
    return this.data;
  }
}

// 使用例
const result = new DataPipeline(rawData)
  .cleanse({ trimStrings: true, convertDates: ['createdAt'] })
  .map({ '顧客名': 'name', 'メール': 'email' })
  .filter([{ field: 'status', operator: '=', value: 'active' }])
  .aggregate({
    groupBy: ['region'],
    aggregations: { total: { field: 'amount', func: 'sum' } }
  })
  .sort('total', 'desc')
  .result();
```

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  データ変換: 売上データの月別集計
═══════════════════════════════════════════════════════════

【入力】
  形式: CSV
  レコード数: 10,000
  カラム: order_id, user_id, amount, status, created_at

【変換パイプライン】

1. クレンジング
   - 日付フォーマット統一
   - 空白トリム
   - ステータス正規化

2. フィルタリング
   - status = 'completed' のみ

3. 集計
   - グループ: 年月
   - 集計: 売上合計, 注文件数, 平均注文額

【出力】
  形式: JSON
  レコード数: 12
  カラム: year_month, total_sales, order_count, avg_order_value

【生成コード】
  src/transformations/monthly-sales.ts
```

---

## 引数

$ARGUMENTS
