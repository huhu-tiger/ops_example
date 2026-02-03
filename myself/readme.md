# myself

个人运维与脚本集合，包含代理配置和爬虫工具。

## 目录结构

```
myself/
├── proxy_v2ray/     # V2Ray 代理环境配置
│   ├── proxy_env.sh # 代理 set/unset 脚本
│   └── setup.sh     # 安装代理别名到 .bashrc
├── spider/          # 下载链接爬虫
│   ├── main.py
│   ├── requirements.txt
│   └── readme.md
└── readme.md
```

## proxy_v2ray

用于在终端快速开关 HTTP(S) 代理，并同步 npm 代理配置。

- **proxy_env.sh**：支持 `set <proxy_url>` 与 `unset`，设置/取消 `http_proxy`、`https_proxy` 及 npm 的 proxy/https-proxy。
- **setup.sh**：在 `~/.bashrc` 中追加别名：
  - `setproxy`：启用代理（默认 `http://39.155.179.4:20171`）
  - `unsetproxy`：取消代理

**使用**：执行一次 `./setup.sh`，然后 `source ~/.bashrc` 或重新登录，之后在终端输入 `setproxy` / `unsetproxy` 即可。

## spider

从指定网页抓取迅雷链接（`thunder://`）或磁力链接（`magnet:`）。

- **当前支持**：`dygang.net`
- **用法**：`python main.py <页面 URL>`
- **示例**：`python main.py https://www.dygang.net/yx/20251206/58574.htm`

依赖见 `spider/requirements.txt`，安装：`pip install -r spider/requirements.txt`。

更细的功能说明与待办见 `spider/readme.md`。
