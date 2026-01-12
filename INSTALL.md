# Claude Code Skills インストールガイド

別のプロジェクトでClaude Code Skillsを使用するためのインストール手順です。

## 前提条件

- Claude Code CLI がインストールされていること
- bash シェルが利用可能なこと（macOS/Linux/WSL）

## インストール方法

### 方法1: ワンライナーインストール（推奨）

```bash
# カレントディレクトリにインストール
curl -fsSL https://raw.githubusercontent.com/sibukixxx/claude-code-skills/main/install.sh | bash -s -- .

# 特定のプロジェクトにインストール
curl -fsSL https://raw.githubusercontent.com/sibukixxx/claude-code-skills/main/install.sh | bash -s -- /path/to/your-project
```

### 方法2: リポジトリをクローンしてインストール

```bash
# 1. リポジトリをクローン
git clone https://github.com/sibukixxx/claude-code-skills.git
cd claude-code-skills

# 2. インストールスクリプトを実行
./install.sh /path/to/your-project
```

### 方法3: 手動コピー

```bash
# スキルディレクトリをコピー
cp -r /path/to/claude-code-skills/.claude /path/to/your-project/
```

## インストールオプション

### 全スキルをコピー（デフォルト）

```bash
./install.sh /path/to/your-project
```

### 特定のカテゴリのみインストール

```bash
# devとtestカテゴリのみ
./install.sh -m selective -c dev,test /path/to/your-project

# docとdataカテゴリのみ
./install.sh -m selective -c doc,data /path/to/your-project
```

### シンボリックリンクでインストール

スキルの更新を自動で反映したい場合に使用します。

```bash
./install.sh -m symlink /path/to/your-project
```

> **注意**: シンボリックリンクモードでは、元のスキルディレクトリを移動・削除するとリンクが切れます。

### 既存ファイルを上書き

```bash
./install.sh -f /path/to/your-project
```

## カテゴリ一覧

| カテゴリ | 説明 | スキル |
|---------|------|--------|
| `dev` | 開発効率化 | tdd, review, refactor, debug |
| `doc` | ドキュメント生成 | api, changelog, readme, schema |
| `data` | データ処理 | csv-validate, csv-import, export, sql, transform |
| `test` | テスト・品質 | gen, security |
| `content` | コンテンツ作成 | research-writer |

## ディレクトリ構造

インストール後、プロジェクトに以下の構造が作成されます：

```
your-project/
├── .claude/
│   └── commands/
│       ├── dev/
│       │   ├── tdd.md
│       │   ├── review.md
│       │   ├── refactor.md
│       │   └── debug.md
│       ├── doc/
│       │   ├── api.md
│       │   ├── changelog.md
│       │   ├── readme.md
│       │   └── schema.md
│       ├── data/
│       │   ├── csv-validate.md
│       │   ├── csv-import.md
│       │   ├── export.md
│       │   ├── sql.md
│       │   └── transform.md
│       ├── test/
│       │   ├── gen.md
│       │   └── security.md
│       └── content/
│           └── research-writer.md
└── ... (your project files)
```

## 使用方法

インストール後、Claude Codeでスキルを呼び出せます：

```bash
# TDD開発
/dev:tdd UserService.createUser

# コードレビュー
/dev:review src/services/

# README生成
/doc:readme

# テスト自動生成
/test:gen src/utils/validator.ts

# SQLクエリ生成
/data:sql "先月の売上TOP10を取得"

# コンテンツ作成
/content:research-writer "React Hooks入門" --type=tutorial
```

## アップデート

### コピーモードでインストールした場合

再度インストールスクリプトを実行します：

```bash
./install.sh -f /path/to/your-project
```

### シンボリックリンクモードでインストールした場合

元のリポジトリを更新するだけで自動的に反映されます：

```bash
cd /path/to/claude-code-skills
git pull
```

## アンインストール

```bash
# スキルディレクトリを削除
rm -rf /path/to/your-project/.claude/commands

# .claudeディレクトリ全体を削除（他の設定がない場合）
rm -rf /path/to/your-project/.claude
```

## カスタマイズ

### 独自スキルの追加

プロジェクト固有のスキルを追加できます：

```bash
# 新しいスキルファイルを作成
touch /path/to/your-project/.claude/commands/dev/my-custom-skill.md
```

スキルファイルの書き方は、既存のスキルファイルを参考にしてください。

### プロジェクト固有の設定

`CLAUDE.md` をプロジェクトルートに作成し、プロジェクト固有の指示を記述できます：

```markdown
# My Project

## 使用可能なスキル

- /dev:tdd - TDD開発
- /dev:review - コードレビュー
- /test:gen - テスト自動生成

## プロジェクト固有のルール

- テストはVitest使用
- スタイルはPrettier + ESLint
```

## トラブルシューティング

### スキルが認識されない

1. `.claude/commands/` ディレクトリが正しい場所にあるか確認
2. スキルファイルの拡張子が `.md` であることを確認
3. Claude Codeを再起動

### パーミッションエラー

```bash
chmod -R 755 /path/to/your-project/.claude
```

### シンボリックリンクが機能しない

WSL/Windows環境では、シンボリックリンクに管理者権限が必要な場合があります。コピーモードを使用してください：

```bash
./install.sh -m copy /path/to/your-project
```

## ライセンス

MIT License
