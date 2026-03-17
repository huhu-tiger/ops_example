# Apifox 文档站 + Tokengate/模型反代
# 用法：make reload
#
# 配置已挂载进容器，改 conf 后只需 reload，不必重建。
# 优先 openresty -s reload；pid 文件对不上时用 make reload-hup。

CONTAINER ?= nginx-apifox-proxy
COMPOSE   ?= docker compose
CONF      := /etc/nginx/nginx.conf
DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help

.PHONY: help reload reload-hup test up down logs ps restart

help:
	@echo "make reload      校验配置并平滑重载 nginx"
	@echo "make reload-hup  向 master 发 HUP（不读 pid 文件）"
	@echo "make test        仅校验 nginx 配置"
	@echo "make up          启动 / 更新容器"
	@echo "make down        停止并删除容器"
	@echo "make restart     重启容器"
	@echo "make logs        跟踪容器日志"
	@echo "make ps          查看容器状态"

test:
	docker exec $(CONTAINER) openresty -t -c $(CONF)

reload: test
	docker exec $(CONTAINER) openresty -c $(CONF) -s reload

reload-hup:
	docker kill -s HUP $(CONTAINER)

up:
	$(COMPOSE) -f $(DIR)docker-compose.yml up -d

down:
	$(COMPOSE) -f $(DIR)docker-compose.yml down

restart:
	$(COMPOSE) -f $(DIR)docker-compose.yml restart

logs:
	docker logs -f --tail=200 $(CONTAINER)

ps:
	docker ps --filter name=$(CONTAINER)
