#!/bin/bash

# PostgreSQL Database Export Script
# 导出PostgreSQL数据库脚本

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
source "$SCRIPT_DIR/db_config.sh"

# 设置字符集环境
setup_encoding

# 检查PostgreSQL工具
if ! check_pg_tools; then
    exit 1
fi

# 测试源数据库连接
log_info "连接源数据库: ${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}"
if ! test_db_connection "source"; then
    log_error "无法连接到源数据库，请检查配置"
    exit 1
fi

# 导出文件配置
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${SOURCE_DB_NAME}_${SOURCE_DB_SCHEMA}_${TIMESTAMP}.sql"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

log_info "开始导出数据库..."
log_info "导出文件: ${BACKUP_FILE}"

# 设置密码环境变量
export PGPASSWORD="$SOURCE_DB_PASSWORD"

# 构建pg_dump参数 - 包含完整的数据库对象
PG_DUMP_ARGS=(
    --host="$SOURCE_DB_HOST"
    --port="$SOURCE_DB_PORT"
    --username="$SOURCE_DB_USER"
    --dbname="$SOURCE_DB_NAME"
    --no-password
    --verbose
    --clean
    --if-exists
    --format=plain
    --encoding="$DB_ENCODING"
    --no-owner
    --no-privileges
    --schema="$SOURCE_DB_SCHEMA"
    --blobs
)

# 如果使用Docker，需要调整文件路径
if [ "$USE_DOCKER_TOOLS" = true ]; then
    backup_filename=$(basename "$BACKUP_FILE")
    PG_DUMP_ARGS+=(--file="/backups/$backup_filename")
else
    PG_DUMP_ARGS+=(--file="$BACKUP_FILE")
fi

# 执行导出
docker_pg_dump "${PG_DUMP_ARGS[@]}"

# 检查导出结果
if [ $? -eq 0 ]; then
    log_success "数据库导出成功!"
    log_info "备份文件: $BACKUP_FILE"
    log_info "文件大小: $(du -h "$BACKUP_FILE" | cut -f1)"
    
    # 压缩备份文件
    if command -v gzip &> /dev/null; then
        log_info "正在压缩备份文件..."
        gzip "$BACKUP_FILE"
        if [ $? -eq 0 ]; then
            BACKUP_FILE="${BACKUP_FILE}.gz"
            log_success "备份文件已压缩: $BACKUP_FILE"
            log_info "压缩后大小: $(du -h "$BACKUP_FILE" | cut -f1)"
        fi
    fi
    
    # 清理旧备份文件
    OLD_FILES=$(find "$BACKUP_DIR" -name "${SOURCE_DB_NAME}_${SOURCE_DB_SCHEMA}_*.sql*" -type f -mtime +${BACKUP_RETENTION_DAYS} 2>/dev/null)
    if [ -n "$OLD_FILES" ]; then
        echo "$OLD_FILES" | xargs rm -f
        log_info "已清理 $(echo "$OLD_FILES" | wc -l) 个旧备份文件"
    fi
else
    log_error "数据库导出失败!"
    exit 1
fi

# 清除密码环境变量
unset PGPASSWORD

log_success "导出完成: $(date)"