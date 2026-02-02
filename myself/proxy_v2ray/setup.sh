#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROXY_ENV="$SCRIPT_DIR/proxy_env.sh"
BASHRC="${BASHRC:-/root/.bashrc}"
BLOCK_MARKER='alias setproxy='

if grep -qF "$BLOCK_MARKER" "$BASHRC" 2>/dev/null; then
  echo "代理别名已存在于 $BASHRC，跳过添加"
  exit 0
fi

echo "正在将代理别名追加到 $BASHRC"
cat >> "$BASHRC" << BLOCK_END

# 设置代理
alias setproxy='source $PROXY_ENV set http://39.155.179.4:20171'
# 取消代理
alias unsetproxy='source $PROXY_ENV unset'
BLOCK_END

echo "已添加。执行 source $BASHRC 或重新登录后生效。"
