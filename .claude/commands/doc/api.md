# API仕様書生成スキル

コードからOpenAPI/Swagger仕様書を自動生成します。

## 使用方法
```
/doc:api <ルートディレクトリ> [--format=<形式>] [--output=<出力先>]
```

---

## When to Use

- API実装後の仕様書作成
- APIドキュメントの自動更新
- Swagger UI用の定義ファイル生成
- クライアントSDK生成の準備

## Scope

| フレームワーク | 解析対象 | 出力形式 |
|--------------|---------|---------|
| Express | ルート定義、ミドルウェア | OpenAPI 3.0 |
| NestJS | デコレータ、DTO | OpenAPI 3.0 |
| FastAPI | 型ヒント、Pydantic | OpenAPI 3.0（自動） |
| Go (gin/echo) | ハンドラ、構造体 | OpenAPI 3.0 |

---

## OpenAPI 3.0 構造

```yaml
openapi: 3.0.3
info:
  title: API名
  version: 1.0.0
  description: API説明

servers:
  - url: https://api.example.com/v1

paths:
  /users:
    get: ...
    post: ...

components:
  schemas: ...
  securitySchemes: ...
```

---

## フレームワーク別生成

### Express

```typescript
// 元のコード: routes/users.ts
import { Router } from 'express';
import { body, param, query } from 'express-validator';

const router = Router();

/**
 * @route GET /users
 * @description ユーザー一覧を取得
 * @query {number} page - ページ番号
 * @query {number} limit - 取得件数
 * @returns {User[]} ユーザー一覧
 */
router.get('/',
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  userController.list
);

/**
 * @route POST /users
 * @description 新規ユーザーを作成
 * @body {CreateUserDto} - ユーザー情報
 * @returns {User} 作成されたユーザー
 */
router.post('/',
  body('email').isEmail(),
  body('password').isLength({ min: 8 }),
  body('name').notEmpty(),
  userController.create
);
```

```yaml
# 生成されるOpenAPI
paths:
  /users:
    get:
      summary: ユーザー一覧を取得
      tags:
        - Users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
          description: ページ番号
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
          description: 取得件数
      responses:
        '200':
          description: 成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
                  pagination:
                    $ref: '#/components/schemas/Pagination'

    post:
      summary: 新規ユーザーを作成
      tags:
        - Users
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserDto'
      responses:
        '201':
          description: 作成成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '400':
          description: バリデーションエラー
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ValidationError'
        '409':
          description: メールアドレス重複
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ConflictError'
```

### NestJS

```typescript
// 元のコード: users.controller.ts
@ApiTags('Users')
@Controller('users')
export class UsersController {
  @Get()
  @ApiOperation({ summary: 'ユーザー一覧を取得' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, type: [UserDto] })
  async list(@Query() query: ListUsersQuery): Promise<UserDto[]> {
    return this.usersService.findAll(query);
  }

  @Post()
  @ApiOperation({ summary: '新規ユーザーを作成' })
  @ApiBody({ type: CreateUserDto })
  @ApiResponse({ status: 201, type: UserDto })
  @ApiResponse({ status: 400, description: 'バリデーションエラー' })
  async create(@Body() dto: CreateUserDto): Promise<UserDto> {
    return this.usersService.create(dto);
  }
}

// dto/create-user.dto.ts
export class CreateUserDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ minLength: 8 })
  @MinLength(8)
  password: string;

  @ApiProperty({ example: 'John Doe' })
  @IsNotEmpty()
  name: string;
}
```

### FastAPI (Python)

```python
# 元のコード: routers/users.py
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, EmailStr

router = APIRouter(prefix="/users", tags=["Users"])

class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str  # min_length=8
    name: str

    class Config:
        json_schema_extra = {
            "example": {
                "email": "user@example.com",
                "password": "password123",
                "name": "John Doe"
            }
        }

class UserResponse(BaseModel):
    id: int
    email: EmailStr
    name: str
    created_at: datetime

@router.get("/", response_model=list[UserResponse])
async def list_users(
    page: int = Query(1, ge=1, description="ページ番号"),
    limit: int = Query(20, ge=1, le=100, description="取得件数"),
):
    """ユーザー一覧を取得"""
    return await user_service.find_all(page, limit)

@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(request: CreateUserRequest):
    """新規ユーザーを作成"""
    return await user_service.create(request)
```

### Go (gin)

```go
// 元のコード: handlers/users.go

// @Summary ユーザー一覧を取得
// @Tags Users
// @Param page query int false "ページ番号" default(1)
// @Param limit query int false "取得件数" default(20)
// @Success 200 {object} ListUsersResponse
// @Router /users [get]
func (h *UserHandler) List(c *gin.Context) {
    // ...
}

// @Summary 新規ユーザーを作成
// @Tags Users
// @Accept json
// @Produce json
// @Param request body CreateUserRequest true "ユーザー情報"
// @Success 201 {object} UserResponse
// @Failure 400 {object} ErrorResponse
// @Router /users [post]
func (h *UserHandler) Create(c *gin.Context) {
    // ...
}

// CreateUserRequest represents the request body for creating a user
type CreateUserRequest struct {
    Email    string `json:"email" binding:"required,email" example:"user@example.com"`
    Password string `json:"password" binding:"required,min=8" example:"password123"`
    Name     string `json:"name" binding:"required" example:"John Doe"`
}
```

---

## 生成されるOpenAPI完全版

```yaml
openapi: 3.0.3
info:
  title: User Management API
  description: |
    ユーザー管理システムのREST API

    ## 認証
    すべてのエンドポイントはBearer認証が必要です。

    ## レート制限
    - 認証済み: 1000 requests/hour
    - 未認証: 100 requests/hour
  version: 1.0.0
  contact:
    name: API Support
    email: support@example.com
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.example.com/v1
    description: Production
  - url: https://staging-api.example.com/v1
    description: Staging
  - url: http://localhost:3000/v1
    description: Development

tags:
  - name: Users
    description: ユーザー管理
  - name: Auth
    description: 認証

paths:
  /users:
    get:
      summary: ユーザー一覧を取得
      description: ページネーション付きでユーザー一覧を取得します
      operationId: listUsers
      tags:
        - Users
      security:
        - BearerAuth: []
      parameters:
        - name: page
          in: query
          description: ページ番号
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          description: 1ページあたりの取得件数
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
        - name: sort
          in: query
          description: ソート順
          schema:
            type: string
            enum: [created_at, name, email]
            default: created_at
        - name: order
          in: query
          description: 昇順/降順
          schema:
            type: string
            enum: [asc, desc]
            default: desc
      responses:
        '200':
          description: 成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
                  meta:
                    $ref: '#/components/schemas/PaginationMeta'
              example:
                data:
                  - id: 1
                    email: user@example.com
                    name: John Doe
                    createdAt: '2025-01-01T00:00:00Z'
                meta:
                  currentPage: 1
                  totalPages: 10
                  totalItems: 100
                  itemsPerPage: 20
        '401':
          $ref: '#/components/responses/Unauthorized'

    post:
      summary: 新規ユーザーを作成
      operationId: createUser
      tags:
        - Users
      security:
        - BearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserRequest'
            example:
              email: newuser@example.com
              password: securePassword123
              name: New User
      responses:
        '201':
          description: 作成成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '400':
          $ref: '#/components/responses/ValidationError'
        '409':
          $ref: '#/components/responses/Conflict'

  /users/{id}:
    get:
      summary: ユーザー詳細を取得
      operationId: getUser
      tags:
        - Users
      security:
        - BearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          description: ユーザーID
          schema:
            type: integer
      responses:
        '200':
          description: 成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '404':
          $ref: '#/components/responses/NotFound'

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: integer
          description: ユーザーID
        email:
          type: string
          format: email
          description: メールアドレス
        name:
          type: string
          description: 名前
        createdAt:
          type: string
          format: date-time
          description: 作成日時
        updatedAt:
          type: string
          format: date-time
          description: 更新日時
      required:
        - id
        - email
        - name
        - createdAt

    CreateUserRequest:
      type: object
      properties:
        email:
          type: string
          format: email
          description: メールアドレス
        password:
          type: string
          minLength: 8
          description: パスワード（8文字以上）
        name:
          type: string
          description: 名前
      required:
        - email
        - password
        - name

    PaginationMeta:
      type: object
      properties:
        currentPage:
          type: integer
        totalPages:
          type: integer
        totalItems:
          type: integer
        itemsPerPage:
          type: integer

    Error:
      type: object
      properties:
        code:
          type: string
        message:
          type: string
        details:
          type: array
          items:
            type: object
            properties:
              field:
                type: string
              message:
                type: string

  responses:
    Unauthorized:
      description: 認証エラー
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            code: UNAUTHORIZED
            message: Authentication required

    ValidationError:
      description: バリデーションエラー
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            code: VALIDATION_ERROR
            message: Validation failed
            details:
              - field: email
                message: Invalid email format

    NotFound:
      description: リソースが見つからない
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            code: NOT_FOUND
            message: User not found

    Conflict:
      description: リソースの競合
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            code: CONFLICT
            message: Email already exists

  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--format` | 出力形式 | `--format=yaml` / `--format=json` |
| `--output` | 出力ファイル | `--output=openapi.yaml` |
| `--title` | API タイトル | `--title="My API"` |
| `--version` | API バージョン | `--version=1.0.0` |

---

## 引数

$ARGUMENTS
