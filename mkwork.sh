#!/usr/bin/env sh
# mkwork: create dated work directories and manage updates

MKWORK_VERSION="v1.0.0"  # replaced by release workflow
MKWORK_DEFAULT_REPO="book000/mkwork"
MKWORK_DEFAULT_WORK_ROOT="$HOME/work"
MKWORK_DEFAULT_UPDATE_CHECK=1
MKWORK_DEFAULT_NOTIFY_UPDATE=1
MKWORK_DEFAULT_AUTO_UPDATE=0
MKWORK_DEFAULT_UPDATE_CHECK_INTERVAL_DAYS=1

# mkwork__is_root: return 0 when running as root.
mkwork__is_root() {
  [ "$(id -u 2>/dev/null)" = "0" ]
}

# mkwork__path_home_expand: expand a leading ~ to $HOME.
mkwork__path_home_expand() {
  case "$1" in
    ~|~/*) printf '%s\n' "$HOME${1#~}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# mkwork__config_paths: list config files in load order.
mkwork__config_paths() {
  printf '%s\n' "$HOME/.config/mkwork/config" "/etc/mkwork/config"
}

# mkwork__install_paths: set install/config/state paths by privilege.
mkwork__install_paths() {
  if mkwork__is_root; then
    MKWORK_INSTALL_PATH="/usr/local/share/mkwork/mkwork.sh"
    MKWORK_CONFIG_PATH="/etc/mkwork/config"
    MKWORK_STATE_DIR="/var/lib/mkwork"
  else
    MKWORK_INSTALL_PATH="$HOME/.local/share/mkwork/mkwork.sh"
    MKWORK_CONFIG_PATH="$HOME/.config/mkwork/config"
    MKWORK_STATE_DIR="$HOME/.local/state/mkwork"
  fi
}

# mkwork__ensure_dirs: create install/config/state directories.
mkwork__ensure_dirs() {
  mkwork__install_paths
  if ! mkwork__is_root; then
    mkdir -p "$HOME/.local/share/mkwork" "$HOME/.config/mkwork" "$HOME/.local/state/mkwork"
  else
    mkdir -p "/usr/local/share/mkwork" "/etc/mkwork" "/var/lib/mkwork"
  fi
}

# mkwork__load_config: load config files (later wins) with defaults.
mkwork__load_config() {
  # Load config files (later wins), with defaults when missing.
  MKWORK_REPO="$MKWORK_DEFAULT_REPO"
  MKWORK_WORK_ROOT="$MKWORK_DEFAULT_WORK_ROOT"
  MKWORK_UPDATE_CHECK="$MKWORK_DEFAULT_UPDATE_CHECK"
  MKWORK_NOTIFY_UPDATE="$MKWORK_DEFAULT_NOTIFY_UPDATE"
  MKWORK_AUTO_UPDATE="$MKWORK_DEFAULT_AUTO_UPDATE"
  MKWORK_UPDATE_CHECK_INTERVAL_DAYS="$MKWORK_DEFAULT_UPDATE_CHECK_INTERVAL_DAYS"

  for cfg in $(mkwork__config_paths); do
    [ -f "$cfg" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        ''|\#*) continue ;;
      esac
      key=${line%%=*}
      val=${line#*=}
      case "$key" in
        repo) MKWORK_REPO="$val" ;;
        work_root) MKWORK_WORK_ROOT="$val" ;;
        update_check) MKWORK_UPDATE_CHECK="$val" ;;
        notify_update) MKWORK_NOTIFY_UPDATE="$val" ;;
        auto_update) MKWORK_AUTO_UPDATE="$val" ;;
        update_check_interval_days) MKWORK_UPDATE_CHECK_INTERVAL_DAYS="$val" ;;
        *) : ;;
      esac
    done < "$cfg"
  done

  MKWORK_WORK_ROOT="$(mkwork__path_home_expand "$MKWORK_WORK_ROOT")"
}

# mkwork__now_utc_iso: current UTC timestamp in ISO8601.
mkwork__now_utc_iso() {
  date -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null
}

# mkwork__epoch_from_iso: convert ISO8601 UTC to epoch seconds.
mkwork__epoch_from_iso() {
  iso="$1"
  if date -u -d "$iso" +%s >/dev/null 2>&1; then
    date -u -d "$iso" +%s
    return 0
  fi
  if command -v gdate >/dev/null 2>&1; then
    gdate -u -d "$iso" +%s && return 0
  fi
  if date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s >/dev/null 2>&1; then
    date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s
    return 0
  fi
  return 1
}

# mkwork__state_path: path to update-check state file.
mkwork__state_path() {
  # State file used for update checks.
  mkwork__install_paths
  printf '%s\n' "$MKWORK_STATE_DIR/state.json"
}

# mkwork__read_state_value: read a JSON field from state file.
mkwork__read_state_value() {
  key="$1"
  state="$(mkwork__state_path)"
  [ -f "$state" ] || return 1
  sed -n "s/.*\"$key\"[ ]*:[ ]*\"\([^\"]*\)\".*/\1/p" "$state" | head -n 1
}

# mkwork__write_state: write update-check state JSON.
mkwork__write_state() {
  mkwork__install_paths
  mkdir -p "$MKWORK_STATE_DIR"
  state="$(mkwork__state_path)"
  # Write a minimal JSON state file (no JSON parser dependency).
  cat <<EOF > "$state"
{
  "last_checked": "$1",
  "last_seen_latest": "$2",
  "last_auto_update_attempt": "$3",
  "last_result": "$4"
}
EOF
}

# mkwork__curl: curl wrapper with safe flags.
mkwork__curl() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$@"
  else
    return 1
  fi
}

# mkwork__get_release_tag_stable: fetch latest release tag.
mkwork__get_release_tag_stable() {
  repo="$1"
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  mkwork__curl "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name // ""'
}

# mkwork__get_latest_tag: get the latest release tag.
mkwork__get_latest_tag() {
  repo="$1"
  mkwork__get_release_tag_stable "$repo"
}

# mkwork__sha256_check: verify checksum using sha256sum/shasum.
mkwork__sha256_check() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "$1"
    return $?
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c "$1"
    return $?
  fi
  return 1
}

# mkwork__require_deps: ensure required external commands exist.
mkwork__require_deps() {
  # Hard deps for network update paths.
  if ! command -v curl >/dev/null 2>&1; then
    printf 'mkwork: curl is required\n' >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'mkwork: jq is required\n' >&2
    return 1
  fi
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    printf 'mkwork: sha256sum or shasum is required\n' >&2
    return 1
  fi
  return 0
}

# mkwork__download_release: download release assets and verify checksum.
mkwork__download_release() {
  repo="$1"
  tag="$2"
  out_dir="$3"
  mkwork__curl "https://github.com/$repo/releases/download/$tag/mkwork.sh" > "$out_dir/mkwork.sh" || return 1
  mkwork__curl "https://github.com/$repo/releases/download/$tag/mkwork.sh.sha256" > "$out_dir/mkwork.sh.sha256" || return 1
  (cd "$out_dir" && mkwork__sha256_check "mkwork.sh.sha256")
}

# mkwork__maybe_check_update: check and optionally auto-update.
mkwork__maybe_check_update() {
  mkwork__load_config
  [ "$MKWORK_UPDATE_CHECK" = "1" ] || return 0
  # Skip silently if deps or interval conditions are not met.
  mkwork__require_deps >/dev/null 2>&1 || return 0

  last_checked=$(mkwork__read_state_value "last_checked")
  if [ -n "$last_checked" ]; then
    last_epoch=$(mkwork__epoch_from_iso "$last_checked" 2>/dev/null || true)
    now_epoch=$(date -u +%s 2>/dev/null || true)
    if [ -n "$last_epoch" ] && [ -n "$now_epoch" ]; then
      interval_sec=$((MKWORK_UPDATE_CHECK_INTERVAL_DAYS * 86400))
      if [ "$((now_epoch - last_epoch))" -lt "$interval_sec" ]; then
        return 0
      fi
    fi
  fi

  latest_tag=$(mkwork__get_latest_tag "$MKWORK_REPO")
  now_iso=$(mkwork__now_utc_iso)

  if [ -z "$latest_tag" ]; then
    mkwork__write_state "$now_iso" "" "" "error"
    return 0
  fi

  if [ "$latest_tag" != "$MKWORK_VERSION" ]; then
    if [ "$MKWORK_NOTIFY_UPDATE" = "1" ]; then
      printf 'mkwork: update available (%s -> %s). Run: mkwork update\n' "$MKWORK_VERSION" "$latest_tag" >&2
    fi
    if [ "$MKWORK_AUTO_UPDATE" = "1" ]; then
      mkwork update >/dev/null 2>&1
    fi
  fi

  mkwork__write_state "$now_iso" "$latest_tag" "" "ok"
}

# mkwork__rc_block_start: start marker for rc block.
mkwork__rc_block_start() {
  printf '%s\n' '# >>> mkwork >>>'
}

# mkwork__rc_block_end: end marker for rc block.
mkwork__rc_block_end() {
  printf '%s\n' '# <<< mkwork <<<'
}

# mkwork__rc_file_default: choose default rc file by shell.
mkwork__rc_file_default() {
  case "$SHELL" in
    */bash) printf '%s\n' "$HOME/.bashrc" ;;
    */zsh) printf '%s\n' "$HOME/.zshrc" ;;
    *) printf '%s\n' "$HOME/.profile" ;;
  esac
}

# mkwork__rc_block_content: content for rc inclusion block.
mkwork__rc_block_content() {
  mkwork__install_paths
  # Dedicated rc block so uninstall can remove cleanly.
  mkwork__rc_block_start
  printf 'if [ -f "%s" ]; then\n  . "%s"\nfi\n' "$MKWORK_INSTALL_PATH" "$MKWORK_INSTALL_PATH"
  mkwork__rc_block_end
}

# mkwork__ensure_rc_block: append rc block if missing.
mkwork__ensure_rc_block() {
  rc_file="$1"
  [ -f "$rc_file" ] || : > "$rc_file"
  if ! grep -q "mkwork >>>" "$rc_file" 2>/dev/null; then
    mkwork__rc_block_content >> "$rc_file"
  fi
}

# mkwork__remove_rc_block: remove rc block from file.
mkwork__remove_rc_block() {
  rc_file="$1"
  [ -f "$rc_file" ] || return 0
  tmp="$rc_file.tmp.$$"
  awk '
    /# >>> mkwork >>>/ {skip=1; next}
    /# <<< mkwork <<</ {skip=0; next}
    skip==0 {print}
  ' "$rc_file" > "$tmp" && mv "$tmp" "$rc_file"
}

# mkwork__usage: print command usage.
mkwork__usage() {
  cat <<'EOF'
Usage:
  mkwork <name>
  mkwork --install [--repo OWNER/REPO] [--write-config=none]
  mkwork --update
  mkwork --uninstall
  mkwork --doctor
  mkwork --version
EOF
}

# mkwork__cmd_install: install mkwork script and rc block.
mkwork__cmd_install() {
  repo_override=""
  write_config=1
  # Install from local source when available; otherwise fetch from release.
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) repo_override="$2"; shift 2 ;;
      --write-config=none) write_config=0; shift 1 ;;
      *) break ;;
    esac
  done

  mkwork__ensure_dirs
  mkwork__install_paths

  if [ -n "$MKWORK_SOURCE_PATH" ] && [ -f "$MKWORK_SOURCE_PATH" ]; then
    cp "$MKWORK_SOURCE_PATH" "$MKWORK_INSTALL_PATH" || return 1
  else
    mkwork__load_config
    mkwork__require_deps || return 1
    latest_tag=$(mkwork__get_latest_tag "$MKWORK_REPO")
    if [ -z "$latest_tag" ]; then
      printf 'mkwork: failed to fetch latest release info\\n' >&2
      return 1
    fi
    tmpdir=$(mkwork__path_home_expand "${TMPDIR:-/tmp}")
    workdir="$tmpdir/mkwork.$$"
    mkdir -p "$workdir" || return 1
    if ! mkwork__download_release "$MKWORK_REPO" "$latest_tag" "$workdir"; then
      printf 'mkwork: download or sha256 verification failed\\n' >&2
      rm -rf "$workdir"
      return 1
    fi
    mv "$workdir/mkwork.sh" "$MKWORK_INSTALL_PATH" || return 1
    rm -rf "$workdir"
  fi

  if [ "$write_config" = "1" ] && [ -n "$repo_override" ]; then
    printf 'repo=%s\n' "$repo_override" > "$MKWORK_CONFIG_PATH"
  fi

  rc_file=$(mkwork__rc_file_default)
  mkwork__ensure_rc_block "$rc_file"

  printf 'mkwork installed: %s\n' "$MKWORK_INSTALL_PATH"
}

# mkwork__cmd_update: update installed mkwork from releases.
mkwork__cmd_update() {
  mkwork__load_config
  mkwork__require_deps || return 1
  mkwork__ensure_dirs
  mkwork__install_paths

  latest_tag=$(mkwork__get_latest_tag "$MKWORK_REPO")
  if [ -z "$latest_tag" ]; then
    printf 'mkwork: failed to fetch latest release info\n' >&2
    return 1
  fi

  tmpdir=$(mkwork__path_home_expand "${TMPDIR:-/tmp}")
  workdir="$tmpdir/mkwork.$$"
  mkdir -p "$workdir" || return 1

  if ! mkwork__download_release "$MKWORK_REPO" "$latest_tag" "$workdir"; then
    printf 'mkwork: download or sha256 verification failed\n' >&2
    rm -rf "$workdir"
    return 1
  fi

  mv "$workdir/mkwork.sh" "$MKWORK_INSTALL_PATH" || return 1
  rm -rf "$workdir"

  now_iso=$(mkwork__now_utc_iso)
  mkwork__write_state "$now_iso" "$latest_tag" "$now_iso" "ok"

  if [ -f "$MKWORK_INSTALL_PATH" ]; then
    # shellcheck source=/dev/null
    . "$MKWORK_INSTALL_PATH"
  fi

  printf 'mkwork updated to %s\n' "$latest_tag"
}

# mkwork__cmd_uninstall: remove installed files and rc block.
mkwork__cmd_uninstall() {
  mkwork__install_paths
  rc_file=$(mkwork__rc_file_default)
  mkwork__remove_rc_block "$rc_file"
  rm -f "$MKWORK_INSTALL_PATH" "$MKWORK_CONFIG_PATH"
  rm -rf "$MKWORK_STATE_DIR"
  printf 'mkwork uninstalled\n'
}

# mkwork__cmd_doctor: print diagnostics.
mkwork__cmd_doctor() {
  mkwork__load_config
  mkwork__install_paths

  printf 'mkwork doctor\n'
  printf '  version: %s\n' "$MKWORK_VERSION"
  printf '  repo: %s\n' "$MKWORK_REPO"
  printf '  work_root: %s\n' "$MKWORK_WORK_ROOT"
  printf '  install_path: %s\n' "$MKWORK_INSTALL_PATH"
  printf '  config_path: %s\n' "$MKWORK_CONFIG_PATH"
  printf '  state_dir: %s\n' "$MKWORK_STATE_DIR"

  if command -v curl >/dev/null 2>&1; then
    printf '  curl: ok\n'
  else
    printf '  curl: missing\n'
  fi

  if command -v jq >/dev/null 2>&1; then
    printf '  jq: ok\n'
  else
    printf '  jq: missing\n'
  fi

  if command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; then
    printf '  sha256: ok\n'
  else
    printf '  sha256: missing\n'
  fi

  if [ -f "$MKWORK_INSTALL_PATH" ]; then
    printf '  installed: yes\n'
  else
    printf '  installed: no\n'
  fi

  if [ -w "$MKWORK_STATE_DIR" ] || [ ! -e "$MKWORK_STATE_DIR" ]; then
    printf '  state_dir_writable: yes\n'
  else
    printf '  state_dir_writable: no\n'
  fi
}

# mkwork__list_dirs: 作成したディレクトリの一覧を取得する
# 引数: なし
# 出力: ディレクトリのフルパス (日付降順、改行区切り)
# 終了コード: 0 = 成功、1 = エラー
mkwork__list_dirs() {
  # $MKWORK_WORK_ROOT が未設定または不存在の場合はエラー
  if [ -z "$MKWORK_WORK_ROOT" ] || [ ! -d "$MKWORK_WORK_ROOT" ]; then
    printf 'mkwork: work_root is not set or does not exist\n' >&2
    return 1
  fi

  # グロブでディレクトリを列挙 (POSIX 互換)
  # nullglob 相当の処理 (候補がない場合を検出)
  set -- "$MKWORK_WORK_ROOT"/????????_*
  if [ ! -d "$1" ]; then
    # グロブがマッチしなかった場合
    printf 'mkwork: no directories found\n' >&2
    return 1
  fi

  # 日付降順でソート (basename のみを使用して判定)
  for dir in "$@"; do
    printf '%s\n' "$dir"
  done | sort -r
}

# mkwork__select_with_fzf: fzf を使ってディレクトリを選択する
# 引数: なし
# 出力: 選択されたディレクトリのフルパス (標準出力)
# 終了コード: 0 = 選択成功、1 = キャンセルまたはエラー
mkwork__select_with_fzf() {
  mkwork__list_dirs | fzf --prompt="Select directory: " --height=40% --reverse
  # fzf の終了コードをそのまま返す (0 = 選択、130 = キャンセル)
}

# mkwork__select_with_number: 番号入力でディレクトリを選択する (POSIX 互換)
# 引数: なし
# 出力: 選択されたディレクトリのフルパス (標準出力)
# 終了コード: 0 = 選択成功、1 = キャンセルまたはエラー
mkwork__select_with_number() {
  # ディレクトリ一覧を取得
  dirs=$(mkwork__list_dirs) || return 1

  # 一覧を表示 (改行区切り)
  i=1
  printf '%s\n' "$dirs" | while IFS= read -r dir; do
    basename=$(basename "$dir")
    printf '%2d) %s\n' "$i" "$basename" >&2
    i=$((i + 1))
  done

  # 番号を入力
  printf 'Select number (or press Ctrl-C to cancel): ' >&2
  read -r selection || return 1

  # 入力が空の場合はエラー
  if [ -z "$selection" ]; then
    printf 'mkwork: no selection\n' >&2
    return 1
  fi

  # 入力が数値かチェック
  case "$selection" in
    ''|*[!0-9]*)
      printf 'mkwork: invalid number\n' >&2
      return 1
      ;;
  esac

  # 選択された行を取得
  selected_dir=$(printf '%s\n' "$dirs" | sed -n "${selection}p")

  # 選択結果が空の場合はエラー
  if [ -z "$selected_dir" ]; then
    printf 'mkwork: invalid selection\n' >&2
    return 1
  fi

  printf '%s\n' "$selected_dir"
}

# mkwork__cmd_select: ディレクトリ選択モード
# 引数: なし
# 終了コード: 0 = 成功、1 = エラー
mkwork__cmd_select() {
  # 設定を読み込む
  mkwork__load_config

  # tty チェック (非対話モードでは実行しない)
  if [ ! -t 0 ]; then
    printf 'mkwork: select mode requires interactive terminal\n' >&2
    return 1
  fi

  # fzf の有無を確認
  if command -v fzf >/dev/null 2>&1; then
    selected_dir=$(mkwork__select_with_fzf)
  else
    selected_dir=$(mkwork__select_with_number)
  fi

  # 選択がキャンセルされた場合
  if [ $? -ne 0 ] || [ -z "$selected_dir" ]; then
    return 1
  fi

  # 選択されたディレクトリへ移動 (親シェルの cwd を変更)
  cd -- "$selected_dir" || return 1

  # 更新チェック (非ブロッキング)
  mkwork__maybe_check_update >/dev/null 2>&1 || true
}

# mkwork: main entry for create/update/install commands.
mkwork() {
  if [ -z "${MKWORK_SOURCE_PATH:-}" ] || [ ! -f "${MKWORK_SOURCE_PATH:-}" ]; then
    if [ -n "${BASH_SOURCE:-}" ] && [ -f "$BASH_SOURCE" ]; then
      MKWORK_SOURCE_PATH="$BASH_SOURCE"
    elif [ -f "$0" ]; then
      MKWORK_SOURCE_PATH="$0"
    fi
  fi
  case "$1" in
    --select|-s)
      mkwork__cmd_select
      return $?
      ;;
    --install)
      shift
      mkwork__cmd_install "$@"
      return $?
      ;;
    --update)
      shift
      mkwork__cmd_update "$@"
      return $?
      ;;
    --uninstall)
      shift
      mkwork__cmd_uninstall "$@"
      return $?
      ;;
    --doctor)
      shift
      mkwork__cmd_doctor "$@"
      return $?
      ;;
    --version|-v|version)
      printf 'mkwork %s\n' "$MKWORK_VERSION"
      return 0
      ;;
    -h|--help|help)
      mkwork__usage
      return 0
      ;;
    '')
      mkwork__usage
      return 1
      ;;
  esac

  name="$*"
  if [ -z "$name" ]; then
    mkwork__usage
    return 1
  fi

  mkwork__load_config
  date_part=$(date +%Y%m%d)
  dir_name="${date_part}_$name"
  target="$MKWORK_WORK_ROOT/$dir_name"

  mkdir -p "$target" || return 1
  cd "$target" || return 1

  mkwork__maybe_check_update >/dev/null 2>&1 || true
}
