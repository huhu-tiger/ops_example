#!/usr/bin/env bash
set -euo pipefail

# Configuration via env vars with sensible defaults
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
DOMAIN=${DOMAIN:-ali.taojunting.com}
EMAIL=${EMAIL:-ws00310976@gmail.com}
WEBROOT=${WEBROOT:-./html}          # For HTTP-01 challenge
CERT_DIR=${CERT_DIR:-./certs}
COMPOSE_FILE=${COMPOSE_FILE:-"$BASE_DIR/docker-compose.yml"}
ACME=${ACME:-"$HOME/.acme.sh/acme.sh"}
echo "Using DOMAIN=$DOMAIN, EMAIL=$EMAIL, WEBROOT=$WEBROOT, CERT_DIR=$CERT_DIR, COMPOSE_FILE=$COMPOSE_FILE, ACME=$ACME"
# Ensure acme.sh is installed and on latest auto-upgrade
if ! command -v "$ACME" >/dev/null 2>&1; then
  echo "Installing acme.sh for $EMAIL"
  curl https://get.acme.sh | sh -s email="$EMAIL"
fi
# "$ACME" --upgrade --auto-upgrade
"$ACME" --set-default-ca --server letsencrypt

# Issue certificate with HTTP-01 using the provided webroot
"$ACME" --issue -d "$DOMAIN" -w "$WEBROOT"

# Install cert and key into the mounted certs directory and reload nginx
mkdir -p "$CERT_DIR"
"$ACME" --install-cert -d "$DOMAIN" \
  --key-file "$CERT_DIR/$DOMAIN.key" \
  --fullchain-file "$CERT_DIR/$DOMAIN.fullchain.cer" \
  --reloadcmd "docker compose -f $COMPOSE_FILE exec nginx nginx -s reload"

echo "Certificate deployed to $CERT_DIR for $DOMAIN and nginx reloaded."

echo "Renewal is handled by acme.sh's cron job; to force renew:"
echo "  $ACME --renew -d $DOMAIN --force"
