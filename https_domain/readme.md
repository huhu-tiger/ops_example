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

## 默认配置（来自 gen_cert.sh）
- DOMAIN: ali.taojunting.com
- EMAIL: ws00310976@gmail.com
- WEBROOT: ./html
- CERT_DIR: ./certs
- COMPOSE_FILE: ./docker-compose.yml（脚本内按绝对路径传递）
- ACME: ~/.acme.sh/acme.sh
- STAGING: 0（关闭 Let’s Encrypt 测试环境）

## 快速使用（HTTP-01）
```bash
chmod +x ./gen_cert.sh
./gen_cert.sh help
# 签发（生产）：
DOMAIN=ali.taojunting.com EMAIL=ws00310976@gmail.com ./gen_cert.sh issue
# 签发（LE 测试环境，不计配额）：
DOMAIN=ali.taojunting.com EMAIL=ws00310976@gmail.com STAGING=1 ./gen_cert.sh issue
# 续期（按当前配置）：
DOMAIN=ali.taojunting.com ./gen_cert.sh renew
# 强制续期：
DOMAIN=ali.taojunting.com ./gen_cert.sh force-renew
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
2) 使用 HTTP-01 在指定 WEBROOT 下签发 DOMAIN 证书（支持 STAGING=1 使用 LE 测试环境）。
3) 将 key/fullchain 安装到 CERT_DIR，并调用 `docker compose -f ./docker-compose.yml exec nginx nginx -s reload` 热加载证书。

## 脚本命令与参数
- 动作：`issue`、`renew`、`force-renew`、`install`、`reload`、`help`
- 环境变量：`DOMAIN`、`EMAIL`、`WEBROOT`、`CERT_DIR`、`COMPOSE_FILE`、`ACME`、`STAGING`
- ACME 校验：使用 HTTP-01，webroot 必须与 nginx 的站点根一致（本例为 `./html` 挂载到 `/usr/share/nginx/html`）。

## nginx 配置示例（conf.d 内）
```nginx
server {
		listen 80;
		server_name ali.taojunting.com;

    location /.well-known/acme-challenge/ {
        root /usr/share/nginx/html;
    }

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name ali.taojunting.com;

		root /usr/share/nginx/html;
		ssl_certificate     /etc/nginx/certs/ali.taojunting.com.fullchain.cer;
		ssl_certificate_key /etc/nginx/certs/ali.taojunting.com.key;

		location /.well-known/acme-challenge/ {
				root /usr/share/nginx/html;
		}
}
```

## 续期说明
acme.sh 默认通过 cron 定时执行续期逻辑，本项目在安装证书时已配置 nginx 热加载：
- 自动续期机制：安装 acme.sh 时会在当前用户的 crontab 写入每日多次的执行条目。
- 自动重载：脚本安装证书时设置了 `--reloadcmd`，续期完成后将执行 `docker compose -f ./docker-compose.yml exec nginx nginx -s reload`。

### 续期原理
- 首次签发与部署：执行 `issue` 后，脚本会调用 `acme.sh --install-cert`，acme.sh 会在其域名配置中记录“部署目标”（`CERT_DIR` 中的 key/fullchain 目标路径）与 `--reloadcmd`。
- 定时检查：系统的 cron（或用户 crontab）周期性运行 `acme.sh --cron`。当证书接近到期（LE 证书有效期 90 天，acme.sh 默认在签发约 60 天后续期）时，触发自动续期。
- 续期动作：acme.sh 成功续期后会按已记录的部署目标将新的证书文件复制到 `./certs` 中对应文件（如 `ali.taojunting.com.key` 与 `ali.taojunting.com.fullchain.cer`），随后执行已保存的 `--reloadcmd` 热加载 Nginx。
- 重要前置：若从未执行过 `--install-cert`（即未通过 `issue`/`install` 指定部署路径），cron 续期只会更新 `~/.acme.sh` 下的证书，不会同步到 `./certs`，也不会触发 Nginx reload。
- 文件映射：`docker-compose.yml` 将本地 `./certs` 挂载到容器 `/etc/nginx/certs`，因此文件更新后 Nginx reload 即生效。

验证与排障：
- 查看定时任务：
  ```bash
  crontab -l | grep acme.sh || echo "(当前用户尚无 acme.sh 定时任务)"
  ```
- 手动仿真续期（不会强制更新，便于检查流程与日志）：
  ```bash
  ~/.acme.sh/acme.sh --cron --home ~/.acme.sh
  ```
- 手动强制续期（测试或提前续期）：
  ```bash
  DOMAIN=ali.taojunting.com ./gen_cert.sh force-renew
  ```
- 日志位置：`~/.acme.sh/*.log`；如遇验证失败，先用 HTTP 访问 `/.well-known/acme-challenge/` 路径自检。

注意：若以 root 用户执行脚本，crontab 将写入 root 用户；若以普通用户执行，则写入该用户的 crontab。请确保续期时有权限执行 `docker compose exec nginx`。

### 系统级定时任务（/etc/crontab，可选）
acme.sh 默认会写入“用户 crontab”。若你希望使用系统级 cron（便于集中管理日志与权限），可以在 `/etc/crontab`（或新建 `/etc/cron.d/acme-sh`）中添加：

```bash
# 建议的全局环境
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 每日 03:17 执行续期（以 root 为例），并输出到日志
17 3 * * * root /root/.acme.sh/acme.sh --cron --home /root/.acme.sh >> /var/log/acme.sh-cron.log 2>&1
```

- 非 root 用户请将路径与用户字段替换为实际用户，例如 `/home/ubuntu/.acme.sh` 与 `ubuntu`。
- 使配置生效：
  - Debian/Ubuntu:
    ```bash
    sudo systemctl reload cron || sudo service cron reload
    ```
  - RHEL/CentOS/AlmaLinux:
    ```bash
    sudo systemctl reload crond || sudo service crond reload
    ```
- 验证：
  ```bash
  grep acme.sh /etc/crontab || true
  sudo systemctl status cron --no-pager 2>/dev/null || sudo systemctl status crond --no-pager
  ```

补充：本项目安装证书时已设置 `--reloadcmd`，续期完成后会自动执行 `docker compose -f ./docker-compose.yml exec nginx nginx -s reload`，无需在 cron 中重复写 reload。需要手动热加载时也可执行：

```bash
./gen_cert.sh reload
```

## 故障排查
- 验证 HTTP-01：浏览器访问 `http://ali.taojunting.com/.well-known/acme-challenge/test` 能命中文件。
- 查看 nginx 日志：`./logs` 目录。
- 查看 acme.sh 日志：`~/.acme.sh/acme.sh --log` 可指定日志位置；缺省日志在 `~/.acme.sh/*.log`。


## 原理
