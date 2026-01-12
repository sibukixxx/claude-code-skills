# Claude Code Skills Collection

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Claude Code用のスキル（カスタムコマンド）コレクション。開発効率を向上させる再利用可能なプロンプトテンプレート集です。

## Features

- **開発効率化** - TDD、コードレビュー、リファクタリング、デバッグ支援
- **ドキュメント生成** - API仕様書、チェンジログ、README、スキーマ
- **データ処理** - CSV検証/インポート、SQL生成、データ変換/エクスポート
- **テスト・品質** - テスト自動生成、セキュリティチェック
- **コンテンツ作成** - リサーチ＆ライティング支援

## Quick Start

### インストール

```bash
# 方法1: ワンライナー
curl -fsSL https://raw.githubusercontent.com/sibukixxx/claude-code-skills/main/install.sh | bash -s -- .

# 方法2: クローン & インストール
git clone https://github.com/sibukixxx/claude-code-skills.git
./claude-code-skills/install.sh /path/to/your-project

# 方法3: 手動コピー
git clone https://github.com/sibukixxx/claude-code-skills.git
cp -r claude-code-skills/.claude /path/to/your-project/
```

### 使用例

```bash
# TDD開発
/dev:tdd UserService.createUser

# コードレビュー
/dev:review src/services/

# テスト自動生成
/test:gen src/utils/validator.ts

# README生成
/doc:readme

# SQLクエリ生成
/data:sql "先月の売上TOP10商品を取得"

# 技術ブログ執筆
/content:research-writer "React Server Components入門" --type=tutorial
```

## Available Skills

### `/dev:*` - 開発効率化

| スキル | 説明 | 使用例 |
|-------|------|--------|
| `tdd` | テスト駆動開発 | `/dev:tdd UserService.createUser` |
| `review` | コードレビュー | `/dev:review src/services/` |
| `refactor` | リファクタリング支援 | `/dev:refactor src/utils/legacy.ts` |
| `debug` | デバッグ支援 | `/dev:debug "APIが500エラーを返す"` |

### `/doc:*` - ドキュメント生成

| スキル | 説明 | 使用例 |
|-------|------|--------|
| `api` | API仕様書生成 | `/doc:api src/routes/` |
| `changelog` | チェンジログ生成 | `/doc:changelog v1.0.0..v1.1.0` |
| `readme` | README生成 | `/doc:readme` |
| `schema` | スキーマドキュメント | `/doc:schema src/models/` |

### `/data:*` - データ処理

| スキル | 説明 | 使用例 |
|-------|------|--------|
| `csv-validate` | CSVバリデーション | `/data:csv-validate data.csv schema.yaml` |
| `csv-import` | CSVインポート機能 | `/data:csv-import users.csv` |
| `export` | データエクスポート | `/data:export users --format=csv` |
| `sql` | SQLクエリ生成 | `/data:sql "アクティブユーザー数"` |
| `transform` | データ変換 | `/data:transform input.json --to=csv` |

### `/test:*` - テスト・品質

| スキル | 説明 | 使用例 |
|-------|------|--------|
| `gen` | テスト自動生成 | `/test:gen src/utils/validator.ts` |
| `security` | セキュリティチェック | `/test:security src/` |

### `/content:*` - コンテンツ作成

| スキル | 説明 | 使用例 |
|-------|------|--------|
| `research-writer` | リサーチ＆ライティング | `/content:research-writer "GraphQL入門" --type=blog` |

## Supported Languages

- TypeScript / JavaScript (Node.js)
- Python
- Go

## Directory Structure

```
.claude/commands/
├── dev/                    # 開発効率化
│   ├── tdd.md
│   ├── review.md
│   ├── refactor.md
│   └── debug.md
├── doc/                    # ドキュメント生成
│   ├── api.md
│   ├── changelog.md
│   ├── readme.md
│   └── schema.md
├── data/                   # データ処理
│   ├── csv-validate.md
│   ├── csv-import.md
│   ├── export.md
│   ├── sql.md
│   └── transform.md
├── test/                   # テスト・品質
│   ├── gen.md
│   └── security.md
└── content/                # コンテンツ作成
    └── research-writer.md
```

## Installation Options

### 全スキルをインストール

```bash
./install.sh /path/to/project
```

### 特定カテゴリのみ

```bash
# dev と test のみ
./install.sh -m selective -c dev,test /path/to/project
```

### シンボリックリンク（更新自動反映）

```bash
./install.sh -m symlink /path/to/project
```

詳細は [INSTALL.md](INSTALL.md) を参照してください。

## Creating Custom Skills

独自のスキルを作成できます：

```bash
# 新しいスキルファイルを作成
touch .claude/commands/dev/my-skill.md
```

### スキルファイルの構造

```markdown
# スキル名

スキルの説明

## 使用方法
\`\`\`
/カテゴリ:スキル名 <引数> [オプション]
\`\`\`

## When to Use

- ユースケース1
- ユースケース2

## ワークフロー

[詳細な手順]

## 出力形式

[期待される出力]

## 引数

$ARGUMENTS
```

## Contributing

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/new-skill`)
3. Add your skill to `.claude/commands/<category>/`
4. Commit your changes (`git commit -m 'Add new skill'`)
5. Push to the branch (`git push origin feature/new-skill`)
6. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related

- [Claude Code](https://claude.ai/claude-code) - Anthropic's official CLI for Claude
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
