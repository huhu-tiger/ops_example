#!/usr/bin/env bash

# proxy_env.sh — 用于快速 set/unset HTTP(S) 代理及 npm 代理
usage() {
  cat <<EOF
Usage:
  $0 unset
    取消 http_proxy, https_proxy, HTTP_PROXY, HTTPS_PROXY 及 npm proxy/https-proxy

  $0 set <proxy_url>
    设置 http_proxy, https_proxy, HTTP_PROXY, HTTPS_PROXY 及 npm proxy 为 <proxy_url>
EOF
  exit 1
}

# 没有参数则打印用法
if [ $# -lt 1 ]; then
  usage
fi

case "$1" in
  unset)
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    if command -v npm >/dev/null 2>&1; then
      npm config delete proxy 2>/dev/null || true
      npm config delete https-proxy 2>/dev/null || true
      echo "已取消代理（含 npm）。"
    else
      echo "已取消代理。"
    fi
    ;;
  set)
    if [ -z "$2" ]; then
      echo "Error: missing proxy URL."
      usage
    fi
    proxy="$2"
    export http_proxy="$proxy"
    export https_proxy="$proxy"
    export HTTP_PROXY="$proxy"
    export HTTPS_PROXY="$proxy"
    if command -v npm >/dev/null 2>&1; then
      npm config set proxy "$proxy"
      npm config set https-proxy "$proxy"
      echo "已设置代理为 $proxy（含 npm）。"
    else
      echo "已设置代理为 $proxy"
    fi
    ;;
  *)
    usage
    ;;
esac