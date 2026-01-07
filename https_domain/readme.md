# 证书生成脚本使用说明

本仓库包含 `docker-compose.yml` 与 `gen_cert.sh`，用于在 nginx 容器中挂载由 acme.sh 签发的证书。

## 前置条件
- 已安装 Docker 与 docker compose。
- 域名已解析到本机或能通过 HTTP-01 验证的服务器。
- `docker-compose.yml` 中的 nginx 服务会挂载 `./certs` 到容器的 `/etc/nginx/certs`。

## 目录说明
- docker-compose.yml：nginx 服务定义，挂载 html/conf.d/certs/logs。
- gen_cert.sh：证书申请与安装脚本，默认 HTTP-01。
- html/：HTTP-01 挑战使用的 webroot（自建）。
- certs/：证书输出目录（脚本会创建）。
- conf.d/：nginx 站点配置，需引用挂载的证书文件。

## 快速使用（HTTP-01）
```bash
chmod +x ./gen_cert.sh
./gen_cert.sh
# 如需覆盖默认值：DOMAIN=your.domain.com EMAIL=you@example.com WEBROOT=./html ./gen_cert.sh
```

可用环境变量（均有默认值）：
- DOMAIN：目标域名（默认 ali.taojunting.com）。
- EMAIL：申请邮箱（默认 ws00310976@gmail.com）。
- WEBROOT：HTTP-01 验证目录，需与 nginx 站点根一致（默认 ./html）。
- CERT_DIR：证书保存目录（默认 ./certs，与 compose 挂载对齐）。
- COMPOSE_FILE：docker compose 文件路径（默认 ./docker-compose.yml）。
- ACME：acme.sh 可执行路径（默认 $HOME/.acme.sh/acme.sh）。

脚本流程简述：
1) 如未安装 acme.sh，则下载安装并开启 auto-upgrade，并设置默认 CA 为 Let’s Encrypt：`acme.sh --set-default-ca --server letsencrypt`。
2) 使用 HTTP-01 在指定 WEBROOT 下签发 DOMAIN 证书。
3) 将 key/fullchain 安装到 CERT_DIR，并调用 `docker compose -f ./docker-compose.yml exec nginx nginx -s reload` 热加载证书。

## nginx 配置示例（conf.d 内）
```nginx
server {
		listen 80;
		listen 443 ssl;
		server_name your.domain.com;

		root /usr/share/nginx/html;

		ssl_certificate     /etc/nginx/certs/your.domain.com.fullchain.cer;
		ssl_certificate_key /etc/nginx/certs/your.domain.com.key;

		location /.well-known/acme-challenge/ {
				root /usr/share/nginx/html;
		}
}
```

## 续期说明
- acme.sh 安装后会自动写入用户级 cron，证书临期时自动续期，无需额外配置。
- 续期完成后会执行安装阶段的 reload 命令：`docker compose -f ./docker-compose.yml exec nginx nginx -s reload`，nginx 将加载新证书。
- 检查计划任务：`~/.acme.sh/acme.sh --cron --home ~/.acme.sh`（仅检查，不续期）；查看 cron：`crontab -l`。
- 手动强制续期（测试或提前续期）：
  ```bash
  ~/.acme.sh/acme.sh --renew -d ali.taojunting.com --force
  ```
- 若改用 DNS-01 或新增域名，重新执行签发命令（带上新的参数），后续续期会沿用最新配置。

## 故障排查
- 验证 HTTP-01：浏览器访问 `http://your.domain.com/.well-known/acme-challenge/test` 能命中文件。
- 查看 nginx 日志：`./logs` 目录。
- 查看 acme.sh 日志：`~/.acme.sh/acme.sh --log` 可指定日志位置；缺省日志在 `~/.acme.sh/*.log`。
