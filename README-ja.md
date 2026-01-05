# mkwork

日付つきの作業ディレクトリを素早く作成して移動するための、シェル関数ベースのユーティリティです。

- `~/work/YYYYMMDD_name` を自動作成
- 作成後そのディレクトリへ `cd`
- インストール直後から現在のシェルで利用可能
- 自己更新 / アンインストールも `mkwork` 単体で完結

## 依存コマンド

更新チェック・更新・リリース取得には以下が必要です。

- `curl`
- `jq`
- `sha256sum` または `shasum`

## インストール

```sh
. <(curl -fsSL https://github.com/book000/mkwork/releases/latest/download/mkwork.sh)
mkwork --install
```

インストール後、以下のいずれかに mkwork の rc ブロックが追加されます。

- bash: `~/.bashrc`
- zsh: `~/.zshrc`
- それ以外: `~/.profile`

## 使い方

```sh
mkwork example
```

`~/work/20260106_example` のようなディレクトリが作成され、その場に移動します。

## 管理コマンド

```sh
mkwork --install
mkwork --update
mkwork --uninstall
mkwork --doctor
mkwork --version
```

## 設定ファイル

設定はファイルのみで管理します（環境変数は使いません）。

読み込み順（後勝ち）:

1. `~/.config/mkwork/config`
2. `/etc/mkwork/config`

フォーマット:

- POSIX shell 互換
- `KEY=VALUE`
- 不明キーは無視

設定項目:

- `repo=OWNER/REPO`（更新取得元）
- `work_root=~/work`
- `update_check=0|1`（デフォルト 1）
- `notify_update=0|1`（デフォルト 1）
- `auto_update=0|1`（デフォルト 0）
- `update_check_interval_days=1`

### install 時の repo 上書き

インストール時だけ一時的に repo を上書きできます。

```sh
mkwork --install --repo OWNER/REPO
```

保存しない場合:

```sh
mkwork --install --repo OWNER/REPO --write-config=none
```

## 更新チェック

`mkwork` 実行時に 1 日 1 回、更新チェックを行います。

- `update_check=1` のときのみ
- `update_check_interval_days` を経過していればチェック
- 更新がある場合のみ通知（`notify_update=1`）
- 自動更新は `auto_update=1` の時のみ
- 更新失敗や通信失敗でも mkwork 本来の機能は継続

状態は以下に保存されます:

- 非 root: `~/.local/state/mkwork/state.json`
- root: `/var/lib/mkwork/state.json`

## アンインストール

```sh
mkwork --uninstall
```

rc ブロック、インストール本体、設定、状態ファイルを削除します。

## 仕組み（概要）

mkwork は「シェル関数」として動作します。
外部コマンドでは親シェルの `cwd` を変更できないため、
`mkdir + cd` を一体化する目的で関数にしています。
