# =============================================================================
# 関数
# =============================================================================

# -----------------------------------------------------------------------------
# NOTE: ghq + fzf + eza Gitリポジトリ管理
# 共通: fzf でリポジトリ選択
# -----------------------------------------------------------------------------
function _ghq-fzf_select() {
  ghq list | fzf --preview "eza -l -g -a --icons $(ghq root)/{} | tail -n+4 | awk '{print \$6\"/\"\$8\" \"\$9 \" \" \$10}'"
}

# -----------------------------------------------------------------------------
# 参照→移動
# -----------------------------------------------------------------------------
function gitls() {
  local src=$(_ghq-fzf_select)
  if [ -n "$src" ]; then
    cd "$(ghq root)/$src"
  fi
}
compdef _nothing gitls

# -----------------------------------------------------------------------------
# 取得→移動
# -----------------------------------------------------------------------------
function gitget() {
  if [ -z "$1" ]; then
    echo "Usage: gitget <repository>"
    return 1
  fi
  ghq get "$@" && cd "$(ghq list -p | grep -E "$(basename ${@: -1} .git)$" | head -1)"
}
compdef _nothing gitget

# -----------------------------------------------------------------------------
# 参照→削除
# -----------------------------------------------------------------------------
function gitrm() {
  # 最初に ghq root を取得（後でカレントディレクトリが無効になる前に）
  local ghq_root="$(ghq root)"

  local src=$(_ghq-fzf_select)
  if [ -z "$src" ]; then
    return 1
  fi

  local repo_path="$ghq_root/$src"
  if [ ! -e "$repo_path" ]; then
    echo "Repository not found: $repo_path"
    return 1
  fi

  echo "Delete: $repo_path"

  # 未コミットの変更をチェック
  local uncommitted=$(git -C "$repo_path" -c status.color=always status --short)
  # プッシュされていないコミットをチェック
  local unpushed=$(git -C "$repo_path" log --branches --not --remotes --simplify-by-decoration --decorate --oneline --color=always 2>/dev/null)

  if [ -n "$uncommitted" ] || [ -n "$unpushed" ]; then
    echo "\n⚠️  Warning: Uncommitted changes or unpushed commits detected:"
    [ -n "$uncommitted" ] && echo "$uncommitted"
    [ -n "$unpushed" ] && echo "$unpushed"
    echo ""
    read -q "confirm?These changes will be deleted permanently. OK? [y/N]: "
  else
    read -q "confirm?Are you sure? [y/N]: "
  fi
  echo

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    return 1
  fi

  # 削除対象内にいる場合は先に移動（削除前に必ず実行）
  if [[ "${PWD:A}" == "${repo_path:A}"* ]]; then
    cd "$ghq_root" || cd "$HOME"
  fi

  rm -rf "$repo_path"

  # 空になった親ディレクトリを再帰的に削除（ghq root まで）
  local parent="$(dirname "$repo_path")"
  while [ "$parent" != "$ghq_root" ] && [ -d "$parent" ]; do
    if [ -z "$(ls -A "$parent")" ]; then
      rm -rf "$parent"
      parent="$(dirname "$parent")"
    else
      break
    fi
  done

  echo "Successfully deleted: $repo_path"
}
compdef _nothing gitrm
