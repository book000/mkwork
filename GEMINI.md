# Gemini CLI 作業方針

## 目的

このドキュメントは、Gemini CLI がこのプロジェクトで作業する際のコンテキストと作業方針を定義します。

## 出力スタイル

- **言語**: 日本語
- **トーン**: 技術的で簡潔
- **形式**: Markdown

## 共通ルール

- **会話言語**: 日本語
- **コミット規約**: Conventional Commits に従い、`<description>` は日本語で記載
  - 例: `feat: 自動更新機能を追加`
- **ブランチ命名**: Conventional Branch に従う
  - 例: `feat/add-auto-update`
- **日本語と英数字の間**: 半角スペースを挿入

## プロジェクト概要

- **目的**: 日付つきの作業ディレクトリを素早く作成して移動するためのシェル関数ユーティリティ
- **主な機能**:
  - `~/work/YYYYMMDD_name` を自動作成
  - 作成後そのディレクトリへ `cd`
  - 自動更新チェック・更新機能
  - インストール/アンインストール
- **技術スタック**: Bash / POSIX Shell
- **依存コマンド**: curl, jq, sha256sum/shasum（更新機能のみ）

## コーディング規約

- **記法**: POSIX Shell 互換を優先
- **関数命名**: `mkwork__` プレフィックスを使用
- **コメント言語**: 日本語
- **エラーメッセージ言語**: 英語
- **静的解析**: ShellCheck の警告に従う

## 開発コマンド

```bash
# シンタックスチェック
sh -n mkwork.sh

# ShellCheck による静的解析
shellcheck mkwork.sh

# スモークテスト（基本動作確認）
tmp_dir="$(mktemp -d)"
export HOME="$tmp_dir/home"
mkdir -p "$HOME"
. ./mkwork.sh
mkwork --version
mkwork --doctor
mkwork testdir
test -d "$HOME/work/$(date +%Y%m%d)_testdir"
```

## 注意事項

### セキュリティ

- API キーや認証情報を Git にコミットしない
- ログに個人情報や認証情報を出力しない
- ダウンロードしたファイルは SHA256 チェックサムで検証する

### 既存ルールの優先

- プロジェクトの既存のコーディングスタイルに従う
- ShellCheck の警告に従う
- POSIX Shell 互換性を維持する

### 既知の制約

- シェル関数として動作するため、親シェルの環境に依存する
- 更新機能は `curl`, `jq`, `sha256sum`/`shasum` に依存する
- 本体機能（ディレクトリ作成と移動）は外部コマンドに依存しない

## リポジトリ固有

- このプロジェクトは単一の `mkwork.sh` ファイルで構成される
- リリース時に GitHub Actions が自動的に `MKWORK_VERSION` を注入する
- 更新チェック・更新機能は `curl`, `jq`, `sha256sum`/`shasum` に依存するが、本体機能（ディレクトリ作成と移動）は外部コマンドに依存しない
- シェル関数として動作するため、親シェルの `cwd` を変更できる
- インストール先は非 root の場合 `~/.local/share/mkwork/mkwork.sh`、root の場合 `/usr/local/share/mkwork/mkwork.sh`
- 設定ファイルは `~/.config/mkwork/config` または `/etc/mkwork/config`
- 状態ファイルは `~/.local/state/mkwork/state.json` または `/var/lib/mkwork/state.json`
