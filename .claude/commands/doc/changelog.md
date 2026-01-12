# チェンジログ生成スキル

Git履歴からユーザー向けチェンジログを自動生成します。

## 使用方法
```
/doc:changelog [バージョン範囲] [--format=<形式>]
```

---

## When to Use

- リリース前のチェンジログ作成
- バージョンアップ時のリリースノート
- 定期的な変更履歴の更新

## Scope

- Conventional Commits形式のコミットメッセージを推奨
- Git履歴からの自動解析
- マージコミット、PRタイトルの活用

---

## Conventional Commits 形式

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Type一覧

| Type | 説明 | CHANGELOG カテゴリ |
|------|------|-------------------|
| `feat` | 新機能 | Added |
| `fix` | バグ修正 | Fixed |
| `docs` | ドキュメント | Documentation |
| `style` | フォーマット（動作に影響なし） | - |
| `refactor` | リファクタリング | Changed |
| `perf` | パフォーマンス改善 | Changed |
| `test` | テスト追加・修正 | - |
| `chore` | ビルド・CI等 | - |
| `BREAKING CHANGE` | 破壊的変更 | Breaking Changes |
| `security` | セキュリティ修正 | Security |
| `deprecated` | 非推奨化 | Deprecated |
| `removed` | 機能削除 | Removed |

---

## ワークフロー

### Step 1: Git履歴の取得

```bash
# バージョン間のコミット取得
git log v1.0.0..v1.1.0 --oneline --no-merges

# または最新タグから
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```

### Step 2: コミット解析

```
コミット例:
feat(auth): ソーシャルログイン機能を追加
fix(api): ユーザー取得時のN+1問題を修正
docs(readme): インストール手順を更新
BREAKING CHANGE: 認証APIのレスポンス形式を変更
```

### Step 3: カテゴリ分類

```markdown
## Added
- ソーシャルログイン機能を追加 (#123)

## Fixed
- ユーザー取得時のN+1問題を修正 (#124)

## Breaking Changes
- 認証APIのレスポンス形式を変更
```

---

## 出力形式

### Keep a Changelog 形式（推奨）

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-01-15

### Added
- ソーシャルログイン機能（Google, GitHub対応）(#123)
- ダークモードのサポート (#125)
- CSVエクスポート機能 (#127)

### Changed
- ダッシュボードのUIを刷新 (#126)
- APIレスポンス時間を30%改善 (#128)

### Fixed
- ユーザー取得時のN+1問題を修正 (#124)
- パスワードリセットメールが送信されない問題を修正 (#129)

### Security
- 依存パッケージの脆弱性を修正 (#130)

### Breaking Changes
- 認証APIのレスポンス形式を変更
  - `user` → `data.user` に移動
  - 移行ガイド: docs/migration-v1.1.md

## [1.0.0] - 2024-12-01

### Added
- 初回リリース
- ユーザー認証機能
- 基本的なCRUD操作

[Unreleased]: https://github.com/user/repo/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/user/repo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

### リリースノート形式

```markdown
# Release Notes - v1.1.0

**Release Date:** 2025-01-15

## Highlights

### ソーシャルログイン対応
Google、GitHubアカウントでのログインが可能になりました。
設定画面から連携できます。

### パフォーマンス改善
APIレスポンス時間を平均30%改善しました。

## What's Changed

### New Features
* feat(auth): Add social login support by @developer1 in #123
* feat(ui): Add dark mode toggle by @developer2 in #125
* feat(export): Add CSV export functionality by @developer1 in #127

### Bug Fixes
* fix(api): Resolve N+1 query issue by @developer3 in #124
* fix(email): Fix password reset email not sending by @developer2 in #129

### Security
* security: Update dependencies to fix vulnerabilities by @dependabot in #130

## Breaking Changes

### Authentication API Response Format
The authentication API response structure has changed:

**Before:**
```json
{
  "user": { "id": 1, "name": "..." }
}
```

**After:**
```json
{
  "data": {
    "user": { "id": 1, "name": "..." }
  }
}
```

See [Migration Guide](docs/migration-v1.1.md) for details.

## Upgrade Instructions

```bash
npm install your-package@1.1.0
```

## Contributors
@developer1, @developer2, @developer3
```

---

## 技術的なコミット → ユーザー向け変換

| 技術的なコミット | ユーザー向け表現 |
|-----------------|-----------------|
| `fix: resolve race condition in auth middleware` | ログイン時に稀に発生するエラーを修正 |
| `perf: add Redis caching for user queries` | ページ読み込み速度を改善 |
| `feat: implement WebSocket for real-time updates` | リアルタイム通知機能を追加 |
| `refactor: migrate from REST to GraphQL` | API応答速度を改善 |

---

## 自動化スクリプト

### package.json スクリプト

```json
{
  "scripts": {
    "changelog": "conventional-changelog -p angular -i CHANGELOG.md -s",
    "changelog:all": "conventional-changelog -p angular -i CHANGELOG.md -s -r 0",
    "release": "standard-version",
    "release:minor": "standard-version --release-as minor",
    "release:major": "standard-version --release-as major"
  }
}
```

### GitHub Actions

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate Changelog
        id: changelog
        uses: conventional-changelog/standard-version@v5

      - name: Create Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
          body: ${{ steps.changelog.outputs.changelog }}
```

---

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--format` | 出力形式 | `--format=keepachangelog` |
| `--from` | 開始バージョン | `--from=v1.0.0` |
| `--to` | 終了バージョン | `--to=v1.1.0` |
| `--output` | 出力ファイル | `--output=CHANGELOG.md` |

### 使用例

```bash
# 最新タグから現在まで
/doc:changelog

# バージョン指定
/doc:changelog v1.0.0..v1.1.0

# リリースノート形式
/doc:changelog --format=release-notes

# ファイル出力
/doc:changelog --output=CHANGELOG.md
```

---

## 引数

$ARGUMENTS
