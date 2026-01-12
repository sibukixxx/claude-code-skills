# README生成スキル

プロジェクトのREADME.mdを自動生成します。

## 使用方法
```
/doc:readme [--template=<テンプレート>] [--sections=<セクション>]
```

---

## When to Use

- 新規プロジェクトのREADME作成
- 既存READMEの更新・充実
- OSS公開前のドキュメント整備

## Scope

- package.json / pyproject.toml / go.mod からプロジェクト情報を抽出
- ソースコードからAPI/CLIの使用方法を抽出
- 既存のドキュメントがあれば参照

---

## 標準セクション構成

```markdown
1. プロジェクト名・バッジ
2. 概要（Description）
3. 特徴（Features）
4. 必要条件（Prerequisites）
5. インストール（Installation）
6. 使用方法（Usage）
7. 設定（Configuration）
8. API リファレンス（API Reference）
9. 開発（Development）
10. テスト（Testing）
11. デプロイ（Deployment）
12. 貢献（Contributing）
13. ライセンス（License）
14. 謝辞（Acknowledgements）
```

---

## 生成テンプレート

### 標準テンプレート

```markdown
# プロジェクト名

[![npm version](https://badge.fury.io/js/package-name.svg)](https://badge.fury.io/js/package-name)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/user/repo/workflows/CI/badge.svg)](https://github.com/user/repo/actions)
[![codecov](https://codecov.io/gh/user/repo/branch/main/graph/badge.svg)](https://codecov.io/gh/user/repo)

簡潔な説明（1-2文）

## Features

- 機能1
- 機能2
- 機能3

## Prerequisites

- Node.js >= 18
- npm >= 9

## Installation

```bash
npm install package-name
```

## Quick Start

```typescript
import { Something } from 'package-name';

const result = Something.do();
console.log(result);
```

## Usage

### 基本的な使い方

```typescript
// 詳細な使用例
```

### 高度な使い方

```typescript
// 高度な使用例
```

## Configuration

| 環境変数 | 説明 | デフォルト |
|---------|------|-----------|
| `API_URL` | APIエンドポイント | `http://localhost:3000` |
| `LOG_LEVEL` | ログレベル | `info` |

## API Reference

### `functionName(param1, param2)`

説明

**Parameters:**
- `param1` (string): 説明
- `param2` (number, optional): 説明

**Returns:**
- `Promise<Result>`: 説明

**Example:**
```typescript
const result = await functionName('value', 42);
```

## Development

```bash
# リポジトリをクローン
git clone https://github.com/user/repo.git
cd repo

# 依存関係をインストール
npm install

# 開発サーバーを起動
npm run dev
```

## Testing

```bash
# ユニットテスト
npm test

# カバレッジ付き
npm run test:coverage

# E2Eテスト
npm run test:e2e
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [Library1](https://example.com) - 説明
- [Library2](https://example.com) - 説明
```

### CLIプロジェクト用テンプレート

```markdown
# CLI名

コマンドラインツールの説明

## Installation

```bash
# npm
npm install -g cli-name

# Homebrew
brew install cli-name

# Binary
curl -sSL https://install.cli-name.dev | sh
```

## Quick Start

```bash
# 初期化
cli-name init

# 実行
cli-name run

# ヘルプ
cli-name --help
```

## Commands

### `cli-name init`

プロジェクトを初期化します。

```bash
cli-name init [options]

Options:
  -t, --template <name>  テンプレートを指定 (default: "default")
  -d, --directory <dir>  出力ディレクトリ (default: ".")
  -f, --force            既存ファイルを上書き
```

### `cli-name run`

メインコマンドを実行します。

```bash
cli-name run <file> [options]

Arguments:
  file                   入力ファイル

Options:
  -o, --output <file>    出力ファイル
  -v, --verbose          詳細ログを出力
  -c, --config <file>    設定ファイルを指定
```

## Configuration

設定ファイル: `.cli-name.yaml`

```yaml
# .cli-name.yaml
output:
  directory: ./dist
  format: json

logging:
  level: info
  file: ./logs/cli.log
```

## Examples

### 基本的な使用例

```bash
# ファイルを処理
cli-name run input.txt -o output.json

# 設定ファイルを使用
cli-name run input.txt -c config.yaml
```

### 高度な使用例

```bash
# パイプで使用
cat input.txt | cli-name run - | jq '.result'

# 複数ファイル
cli-name run *.txt -o results/
```
```

### Webアプリケーション用テンプレート

```markdown
# アプリケーション名

Webアプリケーションの説明

## Demo

[Live Demo](https://demo.example.com) | [Documentation](https://docs.example.com)

![Screenshot](docs/images/screenshot.png)

## Tech Stack

- **Frontend:** React, TypeScript, Tailwind CSS
- **Backend:** Node.js, Express, TypeScript
- **Database:** PostgreSQL
- **Cache:** Redis
- **Infrastructure:** Docker, AWS

## Getting Started

### Prerequisites

- Node.js 18+
- Docker & Docker Compose
- PostgreSQL 15+

### Installation

```bash
# Clone the repository
git clone https://github.com/user/repo.git
cd repo

# Install dependencies
npm install

# Setup environment
cp .env.example .env

# Start database
docker-compose up -d db

# Run migrations
npm run db:migrate

# Start development server
npm run dev
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_URL` | Redis connection string | Yes |
| `JWT_SECRET` | JWT signing secret | Yes |
| `AWS_ACCESS_KEY_ID` | AWS access key | No |

## Architecture

```
src/
├── app/              # Next.js App Router
├── components/       # React components
├── lib/              # Shared utilities
├── server/           # API routes
│   ├── routers/      # tRPC routers
│   └── services/     # Business logic
└── db/               # Database schema
```

## Deployment

### Docker

```bash
docker build -t app-name .
docker run -p 3000:3000 app-name
```

### Vercel

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/user/repo)

### AWS

See [deployment guide](docs/deployment/aws.md) for AWS deployment instructions.
```

---

## バッジ一覧

### ビルド・CI

```markdown
[![CI](https://github.com/user/repo/workflows/CI/badge.svg)](https://github.com/user/repo/actions)
[![Build Status](https://travis-ci.org/user/repo.svg?branch=main)](https://travis-ci.org/user/repo)
```

### パッケージバージョン

```markdown
[![npm version](https://badge.fury.io/js/package.svg)](https://www.npmjs.com/package/package)
[![PyPI version](https://badge.fury.io/py/package.svg)](https://pypi.org/project/package/)
[![Go Reference](https://pkg.go.dev/badge/github.com/user/repo.svg)](https://pkg.go.dev/github.com/user/repo)
```

### コード品質

```markdown
[![codecov](https://codecov.io/gh/user/repo/branch/main/graph/badge.svg)](https://codecov.io/gh/user/repo)
[![Code Climate](https://codeclimate.com/github/user/repo/badges/gpa.svg)](https://codeclimate.com/github/user/repo)
[![Maintainability](https://api.codeclimate.com/v1/badges/xxx/maintainability)](https://codeclimate.com/github/user/repo/maintainability)
```

### ライセンス

```markdown
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
```

### その他

```markdown
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Downloads](https://img.shields.io/npm/dm/package.svg)](https://www.npmjs.com/package/package)
[![GitHub stars](https://img.shields.io/github/stars/user/repo.svg)](https://github.com/user/repo/stargazers)
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--template` | テンプレート種類 | `--template=cli` |
| `--sections` | 含めるセクション | `--sections=install,usage,api` |
| `--output` | 出力ファイル | `--output=README.md` |
| `--language` | 言語 | `--language=ja` |

---

## 引数

$ARGUMENTS
