# 网站与个人相册说明

本说明介绍站点结构、资源目录映射、以及首页个人相册的使用方法。

## 站点结构
- 站点根：`html/` 挂载为容器 `/usr/share/nginx/html`
- 相册资源目录：通过 `RESOURCES_DIR` 指定主机侧目录（默认 `./resources`），挂载到容器 `/usr/share/nginx/html/resources`
- Nginx 主配置：`nginx.conf`
- 站点配置：`conf.d/default.conf`
- 证书目录：`certs/`（部署到容器 `/etc/nginx/certs`）

## 首页：个人相册
- 文件：`html/index.html`
- 行为：加载 `/resources/manifest.json`，展示 `images` 与 `videos` 列表。
- 失败回退：若清单不存在或为空，页面提示“当前没有图片/视频”。

## 资源清单 `resources/manifest.json`
示例结构：
```json
{
  "title": "我的相册",
  "images": [
    { "src": "photos/holiday1.jpg", "name": "假期合照" },
    "photos/cat.png"
  ],
  "videos": [
    { "src": "videos/trip.mp4", "name": "旅行记录" },
    "videos/birthday.mov"
  ]
}
```
- 路径规则：`src` 为相对 `resources/` 的路径，如 `resources/photos/holiday1.jpg` → `photos/holiday1.jpg`。
- 展示与下载：图片卡片点击打开原图；视频卡片提供 `controls` 播放与下载链接。

## 更换资源目录位置
- 编辑 [docker-compose.yml](../docker-compose.yml) 的卷映射已支持环境变量：
  `- ${RESOURCES_DIR:-./resources}:/usr/share/nginx/html/resources:ro`
- 设置新路径的两种方式：
  1) 修改 [.env](../.env) 中的 `RESOURCES_DIR=/absolute/or/relative/path`
  2) 运行时临时设置：
     ```bash
     RESOURCES_DIR=/data/media docker compose up -d nginx
     ```
- 变更后需要重新启动容器以应用新的挂载。清单路径仍为 `/resources/manifest.json`（容器内 URL 不变）。

## 资源目录浏览
已启用目录索引，可通过 `/resources/` 列表浏览与下载。若需要自定义样式或关闭索引，可在 `conf.d/default.conf` 调整：
```nginx
location /resources/ {
  root /usr/share/nginx/html;
  autoindex on;                # 启用目录索引
  autoindex_exact_size off;    # 友好显示大小
  autoindex_localtime on;      # 本地时间
}
```
修改后执行：
```bash
cd /data/ops_example/https_domain
docker compose exec nginx nginx -s reload
```

## 验证
- 访问首页：`https://taojunting.com/`
- 访问资源（如有）：`https://taojunting.com/resources/photos/holiday1.jpg`
- 清单更新后直接生效（静态文件，无需重启）。
