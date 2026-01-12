# Claude Code Skills Collection

コーディング効率化のためのスキル集

## Installation

別プロジェクトへのインストール：

```bash
# ワンライナー
curl -fsSL https://raw.githubusercontent.com/sibukixxx/claude-code-skills/main/install.sh | bash -s -- /path/to/your-project

# または、クローンしてインストール
git clone https://github.com/sibukixxx/claude-code-skills.git
./claude-code-skills/install.sh /path/to/your-project
```

詳細は [INSTALL.md](INSTALL.md) を参照

## Languages

- TypeScript/Node.js (primary)
- Python
- Go

## Commands Namespace

| 名前空間 | 用途 | コマンド例 |
|---------|------|-----------|
| `/dev:*` | 開発効率化 | tdd, review, refactor, debug |
| `/doc:*` | ドキュメント生成 | api, changelog, readme, schema |
| `/data:*` | データ処理 | csv-validate, csv-import, export, sql, transform |
| `/test:*` | テスト・品質 | gen, coverage, security |
| `/content:*` | コンテンツ作成 | research-writer |
| `/pm:*` | プロジェクト管理 | estimate |

## Usage

```bash
# TDDでの実装
/dev:tdd UserService.createUser

# コードレビュー
/dev:review src/services/

# チェンジログ生成
/doc:changelog v1.0.0..v1.1.0

# CSVバリデーション
/data:csv-validate data.csv schema.yaml

# SQLクエリ生成
/data:sql "先月の売上TOP10商品を取得"

# テスト自動生成
/test:gen src/utils/validator.ts

# コンテンツリサーチ＆ライティング
/content:research-writer "React Server Components入門" --type=tutorial --audience=intermediate
```

## Conventions

- スキルは名前空間で整理（`/カテゴリ:コマンド`）
- 各スキルは独立して動作
- 出力は具体的・実行可能なコード
- 3言語（TypeScript, Python, Go）に対応

## Directory Structure

```
.claude/commands/
├── dev/          # 開発効率化
├── doc/          # ドキュメント
├── data/         # データ処理
├── test/         # テスト・品質
├── content/      # コンテンツ
└── pm/           # プロジェクト管理
```
