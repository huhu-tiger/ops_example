#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# 使用方法 — 阿里云 DNS-01 通配符证书（Let's Encrypt，免费）
#
# 前置条件:
#   1. 域名权威 NS 已指向阿里云（hichina/alidns）；Cloudflare NS 请改用 dns_cf
#   2. 准备阿里云 AccessKey（非登录密码），需有云解析读写权限
#   3. 本机可访问外网（安装/调用 acme.sh、Let's Encrypt、阿里云 API）
#
# 快速开始:
#   export Ali_Key="AccessKeyId"
#   export Ali_Secret="AccessKeySecret"
#   ./gen_cert_wildcard_aliyun.sh issue          # 签发默认 *.app.vnetclaw.com
#   ./gen_cert_wildcard_aliyun.sh info           # 查看证书与有效期
#
# 子命令:
#   issue         申请并安装到 certs/（默认）
#   renew         续期并安装
#   force-renew   强制续期并安装
#   install       仅安装已有证书到 certs/
#   info / help   查看证书信息 / 帮助
#
# 常用环境变量:
#   BASE_DOMAIN=app.example.com   # 主域名；通配符默认为 *.$BASE_DOMAIN
#   STAGING=1                     # 走 Let's Encrypt 测试环境
#   DNSSLEEP=120                  # 签发时等待 DNS 生效秒数（0=关闭）
#   CHECK_NS=0                    # 跳过阿里云 NS 预检（不推荐）
#   DIG_SERVER=223.5.5.5          # NS 预检用的公网 DNS（避开内网分裂视图）
#
# 示例:
#   STAGING=1 ./gen_cert_wildcard_aliyun.sh issue
#   BASE_DOMAIN=app.example.com ./gen_cert_wildcard_aliyun.sh issue
#
# 产出:
#   certs/<BASE_DOMAIN>.key
#   certs/<BASE_DOMAIN>.fullchain.cer
#   结束时打印证书详情与有效期（不重载 nginx）
#
# 默认值只在下方「常量」改一处；公共方法见 lib/cert_common.sh
# =============================================================================

# ========== 常量（唯一真源）==========
readonly DEFAULT_BASE_DOMAIN="app.vnetclaw.com"
readonly DEFAULT_EMAIL="ws00310976@gmail.com"
readonly DEFAULT_STAGING="0"
readonly DEFAULT_DNS_PROVIDER="dns_ali"
readonly DEFAULT_DNSSLEEP="120"   # 仅 issue/force-renew；0=关闭
readonly DEFAULT_CHECK_NS="1"     # 签发前检查阿里云 NS；0=跳过
readonly DEFAULT_DIG_SERVER="223.5.5.5"  # NS 预检；空=本机默认递归（不推荐）
readonly DEFAULT_ACTION="issue"
readonly KEY_MODE="600"
readonly CERT_MODE="644"
readonly CERT_DIR_MODE="755"
readonly ALIYUN_NS_PATTERN='alidns|hichina|aliyun'
# =====================================

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/cert_common.sh
source "$BASE_DIR/lib/cert_common.sh"

BASE_DOMAIN=${BASE_DOMAIN:-$DEFAULT_BASE_DOMAIN}
WILDCARD=${WILDCARD:-"*.${BASE_DOMAIN}"}
EMAIL=${EMAIL:-$DEFAULT_EMAIL}
CERT_DIR=${CERT_DIR:-"$BASE_DIR/certs"}
ACME=${ACME:-"$HOME/.acme.sh/acme.sh"}
STAGING=${STAGING:-$DEFAULT_STAGING}
DNS_PROVIDER=${DNS_PROVIDER:-$DEFAULT_DNS_PROVIDER}
DNSSLEEP=${DNSSLEEP:-$DEFAULT_DNSSLEEP}
CHECK_NS=${CHECK_NS:-$DEFAULT_CHECK_NS}
DIG_SERVER=${DIG_SERVER:-$DEFAULT_DIG_SERVER}

KEY_FILE="$CERT_DIR/$BASE_DOMAIN.key"
FULLCHAIN_FILE="$CERT_DIR/$BASE_DOMAIN.fullchain.cer"

usage() {
  cat <<EOF
Usage: $(basename "$0") [issue|renew|force-renew|install|info|help]

阿里云 DNS API 申请通配符证书（Let's Encrypt，证书免费）。
结束时统一打印证书有效期（不重载 nginx）。

默认域名: ${DEFAULT_BASE_DOMAIN} + *.${DEFAULT_BASE_DOMAIN}

Env vars:
  BASE_DOMAIN   主域名 (default: ${DEFAULT_BASE_DOMAIN})
  WILDCARD      通配符 (default: *.\$BASE_DOMAIN)
  EMAIL         联系邮箱 (default: ${DEFAULT_EMAIL})
  CERT_DIR      证书输出目录 (default: <script_dir>/certs)
  ACME          acme.sh 路径 (default: \$HOME/.acme.sh/acme.sh)
  STAGING       使用 LE 测试环境 0/1 (default: ${DEFAULT_STAGING})
  DNS_PROVIDER  acme.sh DNS 插件 (default: ${DEFAULT_DNS_PROVIDER})
  DNSSLEEP      仅 issue/force-renew 时固定等待秒数 (default: ${DEFAULT_DNSSLEEP}；0=关闭)
  CHECK_NS      签发前检查权威 NS 是否阿里云 (default: ${DEFAULT_CHECK_NS}；0=跳过)
  DIG_SERVER    NS 预检查询的 DNS (default: ${DEFAULT_DIG_SERVER}；空=本机递归)
  Ali_Key       阿里云 AccessKey ID（必填，签发/续期时）
  Ali_Secret    阿里云 AccessKey Secret（必填，签发/续期时）

示例:
  export Ali_Key="LTAI..."
  export Ali_Secret="..."
  $0 issue

  STAGING=1 $0 issue
  BASE_DOMAIN=app.example.com $0 issue
  $0 info
EOF
}

# ---------- 本脚本专用 ----------

root_domain_candidates() {
  local d="$1"
  local -a parts
  IFS='.' read -r -a parts <<< "$d"
  local n=${#parts[@]}
  if [ "$n" -lt 2 ]; then
    echo "$d"
    return
  fi
  echo "${parts[*]: -2}" | tr ' ' '.'
  if [ "$n" -ge 3 ]; then
    echo "${parts[*]: -3}" | tr ' ' '.'
  fi
}

ensure_ali_creds() {
  if [ -z "${Ali_Key:-}" ] || [ -z "${Ali_Secret:-}" ]; then
    echo "Error: 请先设置阿里云 AccessKey 环境变量 Ali_Key 与 Ali_Secret" >&2
    echo "  export Ali_Key=\"你的AccessKeyId\"" >&2
    echo "  export Ali_Secret=\"你的AccessKeySecret\"" >&2
    exit 1
  fi
}

# 用公网 DIG_SERVER 查 NS，避免内网分裂视图（本机递归可能返回私有 NS）
dig_ns() {
  local name="$1"
  if [ -n "${DIG_SERVER:-}" ]; then
    dig @"$DIG_SERVER" +short +time=3 +tries=2 NS "$name" 2>/dev/null || true
  else
    dig +short +time=3 +tries=2 NS "$name" 2>/dev/null || true
  fi
}

check_aliyun_ns() {
  if [ "$CHECK_NS" != "1" ]; then
    return 0
  fi
  if ! command -v dig >/dev/null 2>&1; then
    echo "Warning: 未找到 dig，跳过 NS 预检（可安装 dnsutils）" >&2
    return 0
  fi

  local dig_via="${DIG_SERVER:-本机递归}"
  echo "NS check via DNS: $dig_via"

  local cand ns found=0
  while read -r cand; do
    [ -z "$cand" ] && continue
    ns=$(dig_ns "$cand" | tr '\n' ' ')
    if echo "$ns" | grep -Eiq "$ALIYUN_NS_PATTERN"; then
      echo "NS check OK: $cand -> $ns"
      found=1
      break
    fi
    if [ -n "$ns" ]; then
      echo "NS for $cand: $ns"
    fi
  done < <(root_domain_candidates "$BASE_DOMAIN")

  if [ "$found" != "1" ]; then
    echo "Error: 未检测到阿里云权威 NS（查询 DNS: $dig_via）。dns_ali 只能改阿里云解析；若 NS 在 Cloudflare 等，请换域名或改用对应 DNS 插件。" >&2
    echo "  可设 CHECK_NS=0 跳过预检，或 DIG_SERVER=8.8.8.8 换公网 DNS（不推荐跳过）。" >&2
    exit 1
  fi
}

run_acme() {
  local with_dnssleep="${1:-0}"
  shift
  local -a cmd=("$@")
  if [ "$STAGING" = "1" ]; then
    cmd+=(--test)
  fi
  if [ "$with_dnssleep" = "1" ] && [ "${DNSSLEEP:-0}" != "0" ]; then
    cmd+=(--dnssleep "$DNSSLEEP")
  fi
  "$ACME" "${cmd[@]}"
}

install_cert() {
  mkdir -p "$CERT_DIR"
  local reloadcmd="chmod $KEY_MODE '$KEY_FILE' 2>/dev/null; chmod $CERT_MODE '$FULLCHAIN_FILE' 2>/dev/null; true"
  "$ACME" --install-cert -d "$BASE_DOMAIN" \
    --key-file "$KEY_FILE" \
    --fullchain-file "$FULLCHAIN_FILE" \
    --reloadcmd "$reloadcmd"
  cert_harden_files
  echo "Installed cert to $KEY_FILE / $FULLCHAIN_FILE"
}

# 签发/续期公共前置：凭证 + acme；issue 额外 NS 预检
prepare_dns_action() {
  local need_ns_check="${1:-0}"
  ensure_ali_creds
  cert_ensure_acme
  if [ "$need_ns_check" = "1" ]; then
    check_aliyun_ns
  fi
}

do_issue() {
  prepare_dns_action 1
  echo "--- Issuing wildcard cert: $BASE_DOMAIN + $WILDCARD (DNS-01 / $DNS_PROVIDER) ---"
  run_acme 1 --issue -d "$BASE_DOMAIN" -d "$WILDCARD" --dns "$DNS_PROVIDER"
  install_cert
}

do_renew() {
  local force="${1:-0}"
  prepare_dns_action 0
  if [ "$force" = "1" ]; then
    echo "--- Force-renewing cert for $BASE_DOMAIN ---"
    run_acme 1 --renew -d "$BASE_DOMAIN" --force
  else
    echo "--- Renewing cert for $BASE_DOMAIN ---"
    run_acme 0 --renew -d "$BASE_DOMAIN"
  fi
  install_cert
}

do_install() {
  cert_ensure_acme
  echo "--- Installing cert for $BASE_DOMAIN ---"
  install_cert
}

# ---------- main ----------

action=${1:-$DEFAULT_ACTION}
case "$action" in
  help|-h|--help)
    usage
    exit 0
    ;;
  issue|renew|force-renew|install|info)
    ;;
  *)
    echo "Unknown action: $action" >&2
    usage
    exit 1
    ;;
esac

echo "Using BASE_DOMAIN=$BASE_DOMAIN, WILDCARD=$WILDCARD, EMAIL=$EMAIL, CERT_DIR=$CERT_DIR, STAGING=$STAGING, DNS=$DNS_PROVIDER, DNSSLEEP=$DNSSLEEP, CHECK_NS=$CHECK_NS, DIG_SERVER=${DIG_SERVER:-本机递归}"

case "$action" in
  issue)        do_issue ;;
  renew)        do_renew 0 ;;
  force-renew)  do_renew 1 ;;
  install)      do_install ;;
  info)         ;; # 结尾统一打印
esac

cert_print_info "$FULLCHAIN_FILE"
cert_print_validity "$FULLCHAIN_FILE"
echo "Done: $action for $BASE_DOMAIN / $WILDCARD"
