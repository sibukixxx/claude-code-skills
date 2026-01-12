#!/bin/bash
#
# Claude Code Skills Installer
# 別プロジェクトにClaude Codeスキルをインストールするスクリプト
#

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# デフォルト値
SKILLS_REPO="https://github.com/sibukixxx/claude-code-skills.git"
TARGET_DIR=""
INSTALL_MODE="copy"  # copy, symlink, selective
SELECTED_CATEGORIES=""
FORCE=false
VERBOSE=false

# ヘルプメッセージ
show_help() {
    cat << EOF
Claude Code Skills Installer

Usage:
    ./install.sh [OPTIONS] [TARGET_DIRECTORY]

Options:
    -h, --help          このヘルプを表示
    -m, --mode MODE     インストールモード (copy|symlink|selective)
                        - copy: ファイルをコピー（デフォルト）
                        - symlink: シンボリックリンクを作成
                        - selective: 選択したカテゴリのみインストール
    -c, --categories    インストールするカテゴリ（カンマ区切り）
                        例: -c dev,doc,test
    -f, --force         既存ファイルを上書き
    -v, --verbose       詳細ログを出力
    --from-local PATH   ローカルのスキルディレクトリからインストール

Categories:
    dev      開発効率化 (tdd, review, refactor, debug)
    doc      ドキュメント生成 (api, changelog, readme, schema)
    data     データ処理 (csv-validate, csv-import, export, sql, transform)
    test     テスト・品質 (gen, security)
    content  コンテンツ作成 (research-writer)

Examples:
    # カレントディレクトリにインストール
    ./install.sh .

    # 特定のプロジェクトにインストール
    ./install.sh /path/to/my-project

    # devとtestカテゴリのみインストール
    ./install.sh -m selective -c dev,test /path/to/my-project

    # シンボリックリンクでインストール（スキル更新を自動反映）
    ./install.sh -m symlink /path/to/my-project

    # ローカルのスキルからインストール
    ./install.sh --from-local ~/claude-code-skills /path/to/my-project

EOF
}

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 引数解析
LOCAL_SOURCE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--mode)
            INSTALL_MODE="$2"
            shift 2
            ;;
        -c|--categories)
            SELECTED_CATEGORIES="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --from-local)
            LOCAL_SOURCE="$2"
            shift 2
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# ターゲットディレクトリの確認
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="."
fi

TARGET_DIR=$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")

if [ ! -d "$TARGET_DIR" ]; then
    log_error "ターゲットディレクトリが存在しません: $TARGET_DIR"
    exit 1
fi

log_info "インストール先: $TARGET_DIR"
log_info "インストールモード: $INSTALL_MODE"

# 一時ディレクトリの作成
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# スキルソースの準備
SKILLS_SOURCE=""
if [ -n "$LOCAL_SOURCE" ]; then
    if [ ! -d "$LOCAL_SOURCE/.claude/commands" ]; then
        log_error "ローカルソースにスキルが見つかりません: $LOCAL_SOURCE"
        exit 1
    fi
    SKILLS_SOURCE="$LOCAL_SOURCE"
    log_info "ローカルソースを使用: $SKILLS_SOURCE"
else
    # スクリプトの場所を確認
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$SCRIPT_DIR/.claude/commands" ]; then
        SKILLS_SOURCE="$SCRIPT_DIR"
        log_info "ローカルスキルを使用: $SKILLS_SOURCE"
    else
        log_info "GitHubからスキルをダウンロード中..."
        git clone --depth 1 "$SKILLS_REPO" "$TEMP_DIR/skills" 2>/dev/null || {
            log_error "リポジトリのクローンに失敗しました"
            exit 1
        }
        SKILLS_SOURCE="$TEMP_DIR/skills"
    fi
fi

# カテゴリ一覧の取得
get_categories() {
    ls -d "$SKILLS_SOURCE/.claude/commands"/*/ 2>/dev/null | xargs -n1 basename
}

# インストール対象のカテゴリを決定
CATEGORIES_TO_INSTALL=""
if [ "$INSTALL_MODE" = "selective" ] && [ -n "$SELECTED_CATEGORIES" ]; then
    CATEGORIES_TO_INSTALL=$(echo "$SELECTED_CATEGORIES" | tr ',' ' ')
else
    CATEGORIES_TO_INSTALL=$(get_categories)
fi

log_verbose "インストールするカテゴリ: $CATEGORIES_TO_INSTALL"

# .claude/commands ディレクトリの作成
TARGET_COMMANDS_DIR="$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_COMMANDS_DIR"

# インストール実行
install_category() {
    local category=$1
    local source_dir="$SKILLS_SOURCE/.claude/commands/$category"
    local target_dir="$TARGET_COMMANDS_DIR/$category"

    if [ ! -d "$source_dir" ]; then
        log_warn "カテゴリが見つかりません: $category"
        return
    fi

    log_verbose "カテゴリをインストール中: $category"

    case $INSTALL_MODE in
        copy|selective)
            if [ -d "$target_dir" ] && [ "$FORCE" != true ]; then
                log_warn "既存のディレクトリをスキップ: $target_dir (上書きするには -f を使用)"
                return
            fi
            mkdir -p "$target_dir"
            cp -r "$source_dir"/* "$target_dir/" 2>/dev/null || true
            log_success "$category をコピーしました"
            ;;
        symlink)
            if [ -e "$target_dir" ] && [ "$FORCE" != true ]; then
                log_warn "既存のパスをスキップ: $target_dir (上書きするには -f を使用)"
                return
            fi
            [ -e "$target_dir" ] && rm -rf "$target_dir"
            ln -s "$source_dir" "$target_dir"
            log_success "$category へのシンボリックリンクを作成しました"
            ;;
    esac
}

# 各カテゴリをインストール
for category in $CATEGORIES_TO_INSTALL; do
    install_category "$category"
done

# インストール結果のサマリー
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}インストール完了${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "インストール先: $TARGET_COMMANDS_DIR"
echo ""
echo "インストールされたスキル:"
for category in $CATEGORIES_TO_INSTALL; do
    if [ -d "$TARGET_COMMANDS_DIR/$category" ]; then
        echo "  /$category:*"
        ls "$TARGET_COMMANDS_DIR/$category"/*.md 2>/dev/null | while read file; do
            name=$(basename "$file" .md)
            echo "    - /$category:$name"
        done
    fi
done
echo ""
echo "使用方法:"
echo "  Claude Codeで以下のようにスキルを呼び出せます:"
echo "  /dev:tdd, /doc:readme, /test:gen など"
echo ""
