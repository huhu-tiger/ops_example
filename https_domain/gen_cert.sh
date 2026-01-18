#!/usr/bin/env bash
set -euo pipefail

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
DOMAIN=${DOMAIN:-taojunting.com}
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
  DOMAIN       FQDN (default: $DOMAIN)
  EMAIL        Contact email (default: $EMAIL)
  WEBROOT      Webroot for HTTP-01 (default: $WEBROOT)
  CERT_DIR     Output certs dir (default: $CERT_DIR)
  COMPOSE_FILE docker-compose file (default: $COMPOSE_FILE)
  ACME         acme.sh path (default: $ACME)
  STAGING      Use LE staging (0/1) (default: $STAGING)
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

echo "Using DOMAIN=$DOMAIN, EMAIL=$EMAIL, WEBROOT=$WEBROOT, CERT_DIR=$CERT_DIR, STAGING=$STAGING"

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
  mkdir -p "$CERT_DIR"
  "$ACME" --install-cert -d "$DOMAIN" \
    --key-file "$CERT_DIR/$DOMAIN.key" \
    --fullchain-file "$CERT_DIR/$DOMAIN.fullchain.cer" \
    --reloadcmd "docker compose -f $COMPOSE_FILE exec nginx nginx -s reload"
  echo "Installed cert to $CERT_DIR for $DOMAIN"
}

case "$action" in
  issue)
    ensure_acme
    ensure_webroot
    ensure_nginx
    if [ "$STAGING" = "1" ]; then
      "$ACME" --issue -d "$DOMAIN" -w "$WEBROOT" --test
    else
      "$ACME" --issue -d "$DOMAIN" -w "$WEBROOT"
    fi
    install_cert
    ;;
  renew)
    ensure_acme
    if [ "$STAGING" = "1" ]; then
      "$ACME" --renew -d "$DOMAIN" --test || true
    else
      "$ACME" --renew -d "$DOMAIN" || true
    fi
    install_cert
    ;;
  force-renew)
    ensure_acme
    if [ "$STAGING" = "1" ]; then
      "$ACME" --renew -d "$DOMAIN" --force --test || true
    else
      "$ACME" --renew -d "$DOMAIN" --force || true
    fi
    install_cert
    ;;
  install)
    ensure_acme
    install_cert
    ;;
  reload)
    docker compose -f "$COMPOSE_FILE" exec nginx nginx -s reload
    ;;
esac

echo "Done: $action for $DOMAIN"
