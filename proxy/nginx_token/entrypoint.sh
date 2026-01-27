#!/bin/sh
# 启动前创建日志文件并赋予写权限，保证 worker(nobody) 能写入；否则 log_by_lua 写文件会静默失败，仅 stdout 有输出
touch /var/log/nginx/llm_proxy.log 2>/dev/null || true
chmod 666 /var/log/nginx/llm_proxy.log 2>/dev/null || true
exec openresty -c /etc/nginx/nginx.conf -g "daemon off;"
