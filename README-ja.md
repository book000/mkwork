# mkwork

日付つきの作業ディレクトリを素早く作成して移動するための、シェル関数ベースのユーティリティです。

- `~/work/YYYYMMDD_name` を自動作成
- 作成後そのディレクトリへ `cd`
- インストール直後から現在のシェルで利用可能
- 自己更新 / アンインストールも `mkwork` 単体で完結（standalone インストール時のみ。「mise 経由でのインストール」参照）

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

## mise 経由でのインストール

mkwork は [mise](https://mise.jdx.dev/) 経由でもインストール・利用できます。standalone インストーラと同じ Release asset を使います。`mise.toml` に以下を追加してください。

```toml
[tools]
"github:book000/mkwork" = { version = "<version>", asset_pattern = "mkwork.sh", bin = "mkwork.sh" }

[shell_alias]
mkwork = '''
unalias mkwork
export MKWORK_INSTALL_METHOD=mise
. "$(mise where github:book000/mkwork)/mkwork.sh"
unset MKWORK_INSTALL_METHOD
mkwork
'''
```

`unalias mkwork` は必須です。これを省略すると、`mkwork.sh` 内部の `mkwork() { ... }` 定義を読み込む際に Bash が `mkwork` alias を展開してしまい、構文エラーになります。

この方法でインストールすると、mkwork は自身が mise 管理下にあることを検知し、`--install`・`--update`・`--uninstall` と定期更新チェックを無効化します。更新・削除は mise 側で行ってください（`mise upgrade` / `mise uninstall github:book000/mkwork`）。`mkwork <name>`・`mkwork --select`・`mkwork --doctor`・`mkwork --version` は通常どおり利用できます。`mkwork --doctor` の `managed_by: mise|standalone` 行で現在の管理主体を確認できます。

## 使い方

```sh
mkwork example
```

`~/work/20260106_example` のようなディレクトリが作成され、その場に移動します。

## エラーハンドリング

- mkwork が認識しない未知のオプション（`-` で始まる引数）を指定するとエラーになり、終了ステータス 1 で stderr にエラーを出力します。
- `-` で始まる作業名は使用できません（未知オプションとして扱われます）。
- `--` によるオプション終端はサポートしません。他の未知の `-` 始まり引数と同様、未知オプションとして扱われます。
- `mkwork --install --repo` は値が必須です。値を省略するとエラーになります。
- `version`・`help` は予約されたディスパッチ用の単語であり、作業名として使用できません。

## ディレクトリ選択

```sh
mkwork --select
```

`work_root` 配下の既存の作業ディレクトリを一覧表示し、選択したディレクトリへ移動します。
`fzf` がインストールされている場合はファジーファインダーを使用し、そうでない場合は番号入力で選択します。

## 管理コマンド

```sh
mkwork --install
mkwork --update
mkwork --uninstall
mkwork --doctor
mkwork --version
```

## 設定ファイル

設定は基本的にファイルで管理します。唯一の例外が `MKWORK_INSTALL_METHOD` で、mise の `[shell_alias]` ブートストラップ（前述の「mise 経由でのインストール」参照）が一時的に使う環境変数であり、mkwork は読み取り後にこれを unset します。

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
mise 管理下では利用できません。その場合の削除方法は「mise 経由でのインストール」を参照してください。

## 仕組み（概要）

mkwork は「シェル関数」として動作します。
外部コマンドでは親シェルの `cwd` を変更できないため、
`mkdir + cd` を一体化する目的で関数にしています。
