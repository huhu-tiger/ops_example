#!/usr/bin/env bash
# 证书脚本公共方法（由 gen_cert_*.sh source，勿直接执行）
# 依赖调用方已设置: ACME EMAIL CERT_DIR KEY_FILE FULLCHAIN_FILE
# 可选: KEY_MODE CERT_MODE CERT_DIR_MODE（有默认）

: "${KEY_MODE:=600}"
: "${CERT_MODE:=644}"
: "${CERT_DIR_MODE:=755}"

cert_require_vars() {
  local missing=0 v
  for v in "$@"; do
    if [ -z "${!v:-}" ]; then
      echo "Error: 缺少变量 $v（请在调用方设置）" >&2
      missing=1
    fi
  done
  [ "$missing" = "0" ]
}

cert_ensure_acme() {
  cert_require_vars ACME EMAIL || return 1
  if [ ! -x "$ACME" ] && ! command -v "$ACME" >/dev/null 2>&1; then
    echo "Installing acme.sh for $EMAIL"
    curl https://get.acme.sh | sh -s email="$EMAIL"
  fi
  "$ACME" --set-default-ca --server letsencrypt
  "$ACME" --install-cronjob >/dev/null 2>&1 || true
}

cert_harden_files() {
  cert_require_vars KEY_FILE FULLCHAIN_FILE CERT_DIR || return 1
  if [ -f "$KEY_FILE" ]; then
    chmod "$KEY_MODE" "$KEY_FILE"
  fi
  if [ -f "$FULLCHAIN_FILE" ]; then
    chmod "$CERT_MODE" "$FULLCHAIN_FILE"
  fi
  if [ -d "$CERT_DIR" ]; then
    chmod "$CERT_DIR_MODE" "$CERT_DIR"
  fi
}

# openssl x509 单字段：cert_openssl_field <file> <flag> [sed_expr]
cert_openssl_field() {
  local cert="$1" flag="$2" sed_expr="${3:-}"
  local out
  out=$(openssl x509 -in "$cert" -noout "$flag" 2>/dev/null) || return 1
  if [ -n "$sed_expr" ]; then
    echo "$out" | sed "$sed_expr"
  else
    echo "$out"
  fi
}

cert_read_san() {
  local cert="$1" san
  san=$(openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null \
    | grep -v 'X509v3 Subject Alternative Name' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
  if [ -z "$san" ]; then
    san=$(openssl x509 -in "$cert" -noout -text 2>/dev/null \
      | awk '/Subject Alternative Name/{getline; gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')
  fi
  echo "$san"
}

# 仅打印有效期（结尾汇总用）
cert_print_validity() {
  local cert="${1:-${FULLCHAIN_FILE:-}}"
  if [ -z "$cert" ] || [ ! -f "$cert" ]; then
    echo "Error: 证书文件不存在: ${cert:-"(未指定)"}" >&2
    return 1
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    echo "Warning: 未找到 openssl，无法打印有效期" >&2
    return 0
  fi
  local not_before not_after
  not_before=$(cert_openssl_field "$cert" -startdate 's/^notBefore=//')
  not_after=$(cert_openssl_field "$cert" -enddate 's/^notAfter=//')
  echo
  echo "证书有效期: $not_before  →  $not_after"
}

# 完整证书信息
cert_print_info() {
  local cert="${1:-${FULLCHAIN_FILE:-}}"
  if [ -z "$cert" ] || [ ! -f "$cert" ]; then
    echo "Error: 证书文件不存在: ${cert:-"(未指定)"}" >&2
    return 1
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    echo "Warning: 未找到 openssl，无法解析证书详情" >&2
    return 0
  fi

  local subject issuer not_before not_after san fingerprint serial
  subject=$(cert_openssl_field "$cert" -subject 's/^subject=//')
  issuer=$(cert_openssl_field "$cert" -issuer 's/^issuer=//')
  not_before=$(cert_openssl_field "$cert" -startdate 's/^notBefore=//')
  not_after=$(cert_openssl_field "$cert" -enddate 's/^notAfter=//')
  san=$(cert_read_san "$cert")
  fingerprint=$(openssl x509 -in "$cert" -noout -fingerprint -sha256 2>/dev/null | sed 's/^sha256 Fingerprint=//')
  serial=$(cert_openssl_field "$cert" -serial 's/^serial=//')

  echo
  echo "========== 证书信息 =========="
  echo "文件:       $cert"
  echo "私钥:       ${KEY_FILE:-"(未设置)"}"
  echo "Subject:    $subject"
  echo "Issuer:     $issuer"
  echo "域名范围:   ${san:-"(未解析到 SAN，请检查证书)"}"
  echo "生效时间:   $not_before"
  echo "到期时间:   $not_after"
  echo "序列号:     $serial"
  echo "SHA256:     $fingerprint"
  echo "=============================="
}
