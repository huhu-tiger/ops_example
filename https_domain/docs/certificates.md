# 证书与自动续期说明

本说明涵盖使用 `gen_cert.sh` 申请 taojunting.com 证书、部署到 Nginx、以及自动续期的机制与排障方法。

## 前置条件
- 已安装 Docker 与 docker compose。
- 域名 taojunting.com 已解析到本机并且 80/443 端口可达。
- 站点根挂载：`docker-compose.yml` 将本地 `./html` 挂载为容器 `/usr/share/nginx/html`，用于 HTTP-01 验证；`./certs` 挂载为 `/etc/nginx/certs` 用于证书部署。

## 脚本与默认配置
- 脚本：`gen_cert.sh`
- 默认环境变量：
  - DOMAIN: taojunting.com
  - EMAIL: ws00310976@gmail.com
  - WEBROOT: ./html
  - CERT_DIR: ./certs
  - COMPOSE_FILE: ./docker-compose.yml（脚本内按绝对路径传递）
  - ACME: ~/.acme.sh/acme.sh
  - STAGING: 0（关闭 Let’s Encrypt 测试环境）

## 常用命令
```bash
# 查看帮助
./gen_cert.sh help

# 启动 nginx（若未运行）
cd /data/ops_example/https_domain
docker compose up -d nginx

# 正式环境签发（生产）
DOMAIN=taojunting.com EMAIL=ws00310976@gmail.com ./gen_cert.sh issue

# 测试环境签发（不计配额）
DOMAIN=taojunting.com EMAIL=ws00310976@gmail.com STAGING=1 ./gen_cert.sh issue

# 续期（按当前配置）
DOMAIN=taojunting.com ./gen_cert.sh renew

# 强制续期（测试或提前）
DOMAIN=taojunting.com ./gen_cert.sh force-renew

# 仅安装部署（已签发过）
DOMAIN=taojunting.com ./gen_cert.sh install

# 热重载 Nginx
./gen_cert.sh reload
```

签发成功后，证书文件将出现在 `./certs/taojunting.com.key` 与 `./certs/taojunting.com.fullchain.cer`，Nginx 会自动热重载。

## 自动续期机制
- 安装/调用时机：脚本的 `ensure_acme()` 会执行 `acme.sh --install-cronjob`，在当前用户 crontab 安装续期任务。
- 续期触发：acme.sh 默认每天多次运行 `--cron`；证书接近到期（约 60 天）会自动续期。
- 自动部署与重载：首次 `install-cert` 已记录部署目标与 `--reloadcmd`，续期成功会更新 `./certs` 并执行 `docker compose exec nginx nginx -s reload`。
- 检查任务：
```bash
crontab -l | grep acme.sh || echo "(未找到 acme.sh 定时任务)"
~/.acme.sh/acme.sh --cron --home ~/.acme.sh   # 手动仿真执行
```
- 系统级计划任务（可选）：
```bash
17 3 * * * root /root/.acme.sh/acme.sh --cron --home /root/.acme.sh >> /var/log/acme.sh-cron.log 2>&1
```
（按实际用户与 home 路径调整，并通过 `systemctl reload cron/crond` 使其生效）

## Nginx 配置要点
- 站点配置文件：`conf.d/default.conf`
- 关键片段：
```nginx
server {
  listen 80;
  server_name taojunting.com;
  location /.well-known/acme-challenge/ { root /usr/share/nginx/html; }
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl;
  server_name taojunting.com;
  root /usr/share/nginx/html;
  ssl_certificate     /etc/nginx/certs/taojunting.com.fullchain.cer;
  ssl_certificate_key /etc/nginx/certs/taojunting.com.key;
}
```

## 排障建议
- 验证 HTTP-01 路径：
```bash
echo test-ok > html/.well-known/acme-challenge/health-check
curl -sk https://taojunting.com/.well-known/acme-challenge/health-check
```
应返回 `test-ok`。
- 查看 Nginx 日志：`./logs`
- 查看 acme.sh 日志：`~/.acme.sh/*.log`
- 如遇验证失败：检查域名解析与 80 端口是否放行，确认 `WEBROOT` 与站点根一致。
