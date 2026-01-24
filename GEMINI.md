# GEMINI.md

## 目的
- Gemini CLI 向けのコンテキストと作業方針を定義する。

## 出力スタイル
- 言語: 日本語
- トーン: 簡潔で事実ベース
- 形式: Markdown

## 共通ルール
- 会話は日本語で行う。
- PR とコミットは Conventional Commits に従う。
- PR タイトルとコミット本文の言語: PR タイトルは Conventional Commits 形式（英語推奨）。PR 本文は日本語。コミットは Conventional Commits 形式（description は日本語）。
- 日本語と英数字の間には半角スペースを入れる。

## プロジェクト概要
Shell utility that creates dated work directories with format YYYYMMDD_name and provides self-update capabilities.

### 技術スタック
- **言語**: POSIX Shell Script
- **パッケージマネージャー**: none
- **主要な依存関係**:
  - curl
  - jq
  - sha256sum/shasum

## コーディング規約
- フォーマット: 既存設定（ESLint / Prettier / formatter）に従う。
- 命名規則: 既存のコード規約に従う。
- コメント言語: 日本語
- エラーメッセージ: 英語

### 開発コマンド
```bash
# install
mkwork --install

# dev
Manual shell testing

# build
None

# test
None

# lint
None

```

## 注意事項
- 認証情報やトークンはコミットしない。
- ログに機密情報を出力しない。
- 既存のプロジェクトルールがある場合はそれを優先する。

## リポジトリ固有
- **type**: Shell function utility
- **shell_compatibility**: POSIX shell (bash, zsh, sh)
**installation_targets:**
  - ~/.bashrc
  - ~/.zshrc
  - ~/.profile
- **configuration**: File-based at ~/.config/mkwork/config or /etc/mkwork/config
- **state_tracking**: JSON at ~/.local/state/mkwork/state.json or /var/lib/mkwork/state.json
**features:**
  - Automatic work directory creation
  - Self-update mechanism
  - Update checking (daily interval configurable)