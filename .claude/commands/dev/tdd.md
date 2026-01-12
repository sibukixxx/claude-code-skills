# テスト駆動開発（TDD）スキル

機能実装やバグ修正をテスト駆動で行います。

## 使用方法
```
/dev:tdd <対象機能またはファイル> [テストフレームワーク]
```

---

## When to Use

- 新機能の実装前
- バグ修正前（再発防止テスト）
- リファクタリング前（既存動作の保証）
- 入出力が明確な処理の実装

## Scope

| 言語 | テストフレームワーク | 実行コマンド |
|------|---------------------|--------------|
| TypeScript | Jest | `npm test` / `npx jest` |
| TypeScript | Vitest | `npm test` / `npx vitest` |
| Python | pytest | `pytest` / `python -m pytest` |
| Go | testing | `go test ./...` |
| Go | testify | `go test ./...` |

---

## TDDサイクル

```
┌─────────────────────────────────────────────────────────┐
│                    TDD Cycle                            │
└─────────────────────────────────────────────────────────┘

    ┌─────────┐
    │  RED    │ ◀── 失敗するテストを書く
    │ (失敗)  │
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │  GREEN  │ ◀── 最小限のコードでテストを通す
    │ (成功)  │
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │REFACTOR │ ◀── コードを改善（テストは常にパス）
    │ (改善)  │
    └────┬────┘
         │
         └──────▶ 次のテストへ
```

---

## ワークフロー

### Step 1: 要件確認・テストケース設計

まず、実装する機能の仕様を明確にします。

```markdown
## 機能: ユーザー登録

### 入力
- email: string（必須、メールアドレス形式）
- password: string（必須、8文字以上）
- name: string（必須）

### 出力
- 成功: { id, email, name, createdAt }
- 失敗: ValidationError / DuplicateError

### テストケース
1. 正常系: 有効な入力でユーザー作成成功
2. 異常系: 不正なメールアドレス形式
3. 異常系: パスワードが8文字未満
4. 異常系: 必須項目が欠落
5. 異常系: メールアドレス重複
```

### Step 2: RED - 失敗するテストを書く

**重要**: この段階では実装コードを書かない

#### TypeScript (Jest/Vitest)
```typescript
// src/services/user.service.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { UserService } from './user.service';
import { ValidationError, DuplicateError } from '../errors';

describe('UserService', () => {
  let userService: UserService;

  beforeEach(() => {
    userService = new UserService();
  });

  describe('createUser', () => {
    it('should create a user with valid input', async () => {
      const input = {
        email: 'test@example.com',
        password: 'password123',
        name: 'Test User',
      };

      const result = await userService.createUser(input);

      expect(result).toMatchObject({
        email: 'test@example.com',
        name: 'Test User',
      });
      expect(result.id).toBeDefined();
      expect(result.createdAt).toBeInstanceOf(Date);
    });

    it('should throw ValidationError for invalid email', async () => {
      const input = {
        email: 'invalid-email',
        password: 'password123',
        name: 'Test User',
      };

      await expect(userService.createUser(input))
        .rejects.toThrow(ValidationError);
    });

    it('should throw ValidationError for short password', async () => {
      const input = {
        email: 'test@example.com',
        password: 'short',
        name: 'Test User',
      };

      await expect(userService.createUser(input))
        .rejects.toThrow(ValidationError);
    });
  });
});
```

#### Python (pytest)
```python
# tests/test_user_service.py
import pytest
from services.user_service import UserService
from errors import ValidationError, DuplicateError

class TestUserService:
    @pytest.fixture
    def user_service(self):
        return UserService()

    def test_create_user_with_valid_input(self, user_service):
        input_data = {
            "email": "test@example.com",
            "password": "password123",
            "name": "Test User",
        }

        result = user_service.create_user(input_data)

        assert result["email"] == "test@example.com"
        assert result["name"] == "Test User"
        assert "id" in result
        assert "created_at" in result

    def test_create_user_with_invalid_email(self, user_service):
        input_data = {
            "email": "invalid-email",
            "password": "password123",
            "name": "Test User",
        }

        with pytest.raises(ValidationError):
            user_service.create_user(input_data)

    def test_create_user_with_short_password(self, user_service):
        input_data = {
            "email": "test@example.com",
            "password": "short",
            "name": "Test User",
        }

        with pytest.raises(ValidationError):
            user_service.create_user(input_data)
```

#### Go (testing)
```go
// user_service_test.go
package service

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestUserService_CreateUser(t *testing.T) {
    t.Run("should create user with valid input", func(t *testing.T) {
        svc := NewUserService()
        input := CreateUserInput{
            Email:    "test@example.com",
            Password: "password123",
            Name:     "Test User",
        }

        result, err := svc.CreateUser(input)

        require.NoError(t, err)
        assert.Equal(t, "test@example.com", result.Email)
        assert.Equal(t, "Test User", result.Name)
        assert.NotEmpty(t, result.ID)
    })

    t.Run("should return error for invalid email", func(t *testing.T) {
        svc := NewUserService()
        input := CreateUserInput{
            Email:    "invalid-email",
            Password: "password123",
            Name:     "Test User",
        }

        _, err := svc.CreateUser(input)

        assert.Error(t, err)
        assert.IsType(t, &ValidationError{}, err)
    })
}
```

**テスト実行**: この時点でテストは失敗する（RED）
```bash
# TypeScript
npm test -- --watch

# Python
pytest -v

# Go
go test -v ./...
```

### Step 3: GREEN - 最小限の実装

テストをパスする最小限のコードを書く。

**原則**:
- テストを通すことだけに集中
- 過度な最適化・汎用化はしない
- ハードコードでもOK（後でリファクタリング）

```typescript
// src/services/user.service.ts
export class UserService {
  async createUser(input: CreateUserInput): Promise<User> {
    // バリデーション
    if (!this.isValidEmail(input.email)) {
      throw new ValidationError('Invalid email format');
    }
    if (input.password.length < 8) {
      throw new ValidationError('Password must be at least 8 characters');
    }

    // ユーザー作成（最小限の実装）
    return {
      id: crypto.randomUUID(),
      email: input.email,
      name: input.name,
      createdAt: new Date(),
    };
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
}
```

**テスト実行**: すべてのテストがパスする（GREEN）

### Step 4: REFACTOR - コード改善

テストがパスした状態を維持しながら、コードを改善する。

**リファクタリングの観点**:
- 重複の除去
- 命名の改善
- 関数の分割
- デザインパターンの適用

```typescript
// リファクタリング後
export class UserService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly validator: UserValidator,
  ) {}

  async createUser(input: CreateUserInput): Promise<User> {
    // バリデーション（責務分離）
    this.validator.validate(input);

    // 重複チェック
    const existing = await this.userRepository.findByEmail(input.email);
    if (existing) {
      throw new DuplicateError('Email already exists');
    }

    // ユーザー作成
    const user = User.create(input);
    return this.userRepository.save(user);
  }
}
```

**テスト実行**: リファクタリング後もテストはパスする

### Step 5: 次のテストへ

残りのテストケースについて、Step 2-4を繰り返す。

---

## 制約事項

```
┌─────────────────────────────────────────────────────────┐
│                    TDD の鉄則                           │
└─────────────────────────────────────────────────────────┘

1. 失敗するテストなしに実装コードを書かない
   → テストが仕様書となる

2. テストを通す最小限のコードのみ書く
   → YAGNI（You Aren't Gonna Need It）

3. リファクタリングは GREEN の状態でのみ行う
   → テストが動作保証となる

4. 1つのテストで1つの振る舞いを検証
   → 失敗原因が明確になる
```

---

## テストの書き方ガイド

### AAA パターン

```typescript
it('should do something', () => {
  // Arrange（準備）
  const input = createTestInput();

  // Act（実行）
  const result = target.method(input);

  // Assert（検証）
  expect(result).toBe(expected);
});
```

### Given-When-Then パターン

```typescript
it('given valid input, when creating user, then returns user with id', () => {
  // Given
  const input = { email: 'test@example.com', ... };

  // When
  const result = userService.createUser(input);

  // Then
  expect(result.id).toBeDefined();
});
```

### テスト名の命名規則

```
should_<期待される結果>_when_<条件>

例:
- should_create_user_when_input_is_valid
- should_throw_validation_error_when_email_is_invalid
- should_return_null_when_user_not_found
```

---

## 出力形式

```
═══════════════════════════════════════════════════════════
  TDD実行レポート: UserService.createUser
═══════════════════════════════════════════════════════════

【対象機能】
  ユーザー登録機能

【テストケース】
  1. ✅ 正常系: 有効な入力でユーザー作成成功
  2. ✅ 異常系: 不正なメールアドレス形式
  3. ✅ 異常系: パスワードが8文字未満
  4. ✅ 異常系: 必須項目が欠落
  5. ✅ 異常系: メールアドレス重複

【作成ファイル】
  - src/services/user.service.ts（実装）
  - src/services/user.service.test.ts（テスト）
  - src/errors/validation.error.ts（エラークラス）

【カバレッジ】
  Statements: 95%
  Branches: 90%
  Functions: 100%
  Lines: 95%

═══════════════════════════════════════════════════════════
```

---

## 引数

$ARGUMENTS
