#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
DOMAIN=${DOMAIN:-taojunting.com}
# 多个域名用空格分隔，如: DOMAINS="taojunting.com junting.net"
DOMAINS=${DOMAINS:-$DOMAIN}
EMAIL=${EMAIL:-ws00310976@gmail.com}
WEBROOT=${WEBROOT:-./html}
CERT_DIR=${CERT_DIR:-./certs}
COMPOSE_FILE=${COMPOSE_FILE:-"$BASE_DIR/docker-compose.yml"}
ACME=${ACME:-"$HOME/.acme.sh/acme.sh"}
STAGING=${STAGING:-0}

usage() {
  cat <<EOF
Usage: $(basename "$0") [issue|renew|force-renew|install|reload|help]

Env vars:
  DOMAIN       FQDN，单域名时使用 (default: $DOMAIN)
  DOMAINS      多域名，空格分隔，如 "taojunting.com junting.net" (default: \$DOMAIN)
  EMAIL        Contact email (default: $EMAIL)
  WEBROOT      Webroot for HTTP-01 (default: $WEBROOT)
  CERT_DIR     Output certs dir (default: $CERT_DIR)
  COMPOSE_FILE docker-compose file (default: $COMPOSE_FILE)
  ACME         acme.sh path (default: $ACME)
  STAGING      Use LE staging (0/1) (default: $STAGING)

示例 - 为 taojunting.com 与 junting.net 申请证书:
  DOMAINS="taojunting.com junting.net" $0 issue

通配符 (*.junting.net): 本脚本仅支持 HTTP-01，通配符需 DNS-01。先手动用 acme.sh
  --dns 签发，再执行 DOMAINS=junting.net $0 install 安装到 CERT_DIR。
EOF
}

action=${1:-issue}
case "$action" in
  help|-h|--help)
    usage
    exit 0
    ;;
  issue|renew|force-renew|install|reload)
    ;;
  *)
    echo "Unknown action: $action" >&2
    usage
    exit 1
    ;;
esac

echo "Using DOMAINS=$DOMAINS, EMAIL=$EMAIL, WEBROOT=$WEBROOT, CERT_DIR=$CERT_DIR, STAGING=$STAGING"

ensure_acme() {
  if ! command -v "$ACME" >/dev/null 2>&1; then
    echo "Installing acme.sh for $EMAIL"
    curl https://get.acme.sh | sh -s email="$EMAIL"
  fi
  "$ACME" --set-default-ca --server letsencrypt
  "$ACME" --install-cronjob >/dev/null 2>&1 || true
}

ensure_webroot() {
  mkdir -p "$WEBROOT/.well-known/acme-challenge"
}

ensure_nginx() {
  if ! docker compose -f "$COMPOSE_FILE" ps nginx >/dev/null 2>&1; then
    echo "docker compose not ready; file: $COMPOSE_FILE" >&2
    return 1
  fi
  # Start nginx if not running
  if ! docker compose -f "$COMPOSE_FILE" ps --status running | grep -q "nginx"; then
    docker compose -f "$COMPOSE_FILE" up -d nginx
  fi
}

install_cert() {
  local d="${1:-$DOMAIN}"
  mkdir -p "$CERT_DIR"
  "$ACME" --install-cert -d "$d" \
    --key-file "$CERT_DIR/$d.key" \
    --fullchain-file "$CERT_DIR/$d.fullchain.cer" \
    --reloadcmd "docker compose -f $COMPOSE_FILE exec nginx nginx -s reload"
  echo "Installed cert to $CERT_DIR for $d"
}

case "$action" in
  issue)
    ensure_acme
    ensure_webroot
    ensure_nginx
    for d in $DOMAINS; do
      echo "--- Issuing cert for $d ---"
      if [ "$STAGING" = "1" ]; then
        "$ACME" --issue -d "$d" -w "$WEBROOT" --test || true
      else
        "$ACME" --issue -d "$d" -w "$WEBROOT" || true
      fi
      install_cert "$d"
    done
    ;;
  renew)
    ensure_acme
    for d in $DOMAINS; do
      echo "--- Renewing cert for $d ---"
      if [ "$STAGING" = "1" ]; then
        "$ACME" --renew -d "$d" --test || true
      else
        "$ACME" --renew -d "$d" || true
      fi
      install_cert "$d"
    done
    ;;
  force-renew)
    ensure_acme
    for d in $DOMAINS; do
      echo "--- Force-renewing cert for $d ---"
      if [ "$STAGING" = "1" ]; then
        "$ACME" --renew -d "$d" --force --test || true
      else
        "$ACME" --renew -d "$d" --force || true
      fi
      install_cert "$d"
    done
    ;;
  install)
    ensure_acme
    for d in $DOMAINS; do
      echo "--- Installing cert for $d ---"
      install_cert "$d"
    done
    ;;
  reload)
    docker compose -f "$COMPOSE_FILE" exec nginx nginx -s reload
    ;;
esac

echo "Done: $action for $DOMAINS"
