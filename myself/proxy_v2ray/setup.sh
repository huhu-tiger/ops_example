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
# 设置 git 代理 (HTTP)
alias gitsetproxy='git config --global http.proxy http://39.155.179.4:20171 && git config --global https.proxy http://39.155.179.4:20171'

# 取消 git 代理
alias gitunsetproxy='git config --global --unset http.proxy && git config --global --unset https.proxy'

# 设置 git SSH 代理 (通过 SOCKS5)
gitsshsetproxy() {
  mkdir -p ~/.ssh
  if ! grep -q "# GIT-SSH-PROXY-START" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config << 'SSHEOF'

# GIT-SSH-PROXY-START
Host github.com
    HostName github.com
    User git
    ProxyCommand nc -X 5 -x 39.155.179.4:20170 %h %p

Host gitlab.com
    HostName gitlab.com
    User git
    ProxyCommand nc -X 5 -x 39.155.179.4:20170 %h %p
# GIT-SSH-PROXY-END
SSHEOF
    echo "已添加 SSH 代理配置到 ~/.ssh/config"
  else
    echo "SSH 代理配置已存在"
  fi
}

# 取消 git SSH 代理
gitsshunsetproxy() {
  if [ -f ~/.ssh/config ]; then
    sed -i '/# GIT-SSH-PROXY-START/,/# GIT-SSH-PROXY-END/d' ~/.ssh/config
    echo "已移除 SSH 代理配置"
  else
    echo "~/.ssh/config 不存在"
  fi
}
BLOCK_END

echo "已添加。执行 source $BASHRC 或重新登录后生效。"
