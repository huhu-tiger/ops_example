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

## 获取证书与自动续期快速步骤
1) 确认域名 taojunting.com 已解析到此服务器，80/443 放行。
2) 启动 nginx（若未运行）：
```bash
cd /data/ops_example/https_domain
docker compose up -d nginx
```
3) 签发正式证书：
```bash
cd /data/ops_example/https_domain
DOMAIN=taojunting.com EMAIL=ws00310976@gmail.com ./gen_cert.sh issue
```
4) 验证文件生成：`ls certs` 应包含 `taojunting.com.key` 与 `taojunting.com.fullchain.cer`。
5) 查看 crontab 是否已安装 acme.sh 续期任务：
```bash
crontab -l | grep acme.sh || echo "(未找到 acme.sh 定时任务)"
```
如需手动添加系统级计划任务（示例 root 用户，每日 03:17）：
```
17 3 * * * root /root/.acme.sh/acme.sh --cron --home /root/.acme.sh >> /var/log/acme.sh-cron.log 2>&1
# 项目简述

本项目用于部署 Nginx（含 HTTPS 证书挂载）和展示个人相册主页。详细说明已拆分至 docs 目录。

## 目录结构
- docker-compose.yml：Nginx 服务定义与卷挂载
- nginx.conf：Nginx 主配置
- conf.d/：站点配置（含 taojunting.com vhost）
- html/：站点根（首页为个人相册）
- resources/：相册资源目录（图片/视频及清单）
- .env：Compose 环境变量（可用 RESOURCES_DIR 调整主机侧资源目录）
- certs/：证书输出目录
- docs/：详细文档
  - docs/certificates.md：证书签发、安装与自动续期
  - docs/website.md：站点结构与个人相册用法

## 快速入口
- 证书说明：docs/certificates.md
- 网站说明：docs/website.md
  - 说明如何通过 `RESOURCES_DIR` 更换资源目录位置，并在容器中以 `/resources` 提供访问。

## 快速启动
```bash
cd /data/ops_example/https_domain
docker compose up -d nginx
```
## 故障排查
- 验证 HTTP-01：浏览器访问 `http://taojunting.com/.well-known/acme-challenge/test` 能命中文件。
- 查看 nginx 日志：`./logs` 目录。
- 查看 acme.sh 日志：`~/.acme.sh/acme.sh --log` 可指定日志位置；缺省日志在 `~/.acme.sh/*.log`。


## 原理
