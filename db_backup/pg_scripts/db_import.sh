#!/bin/bash

# PostgreSQL Database Import Script
# 导入PostgreSQL数据库脚本

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
source "$SCRIPT_DIR/db_config.sh"

# 检查是否有 --force 参数
FORCE_IMPORT=false
if [ "$1" = "--force" ]; then
    FORCE_IMPORT=true
fi

# 获取最新备份文件
get_latest_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        ls -t "$BACKUP_DIR"/${SOURCE_DB_NAME}_${SOURCE_DB_SCHEMA}_*.sql* 2>/dev/null | head -n1
    fi
}

# 设置字符集环境
setup_encoding

# 检查PostgreSQL工具
if ! check_pg_tools; then
    exit 1
fi

# 获取最新备份文件
BACKUP_FILE=$(get_latest_backup)
if [ -z "$BACKUP_FILE" ]; then
    log_error "未找到备份文件"
    log_info "请先运行 db_export.sh 创建备份"
    exit 1
fi

log_info "找到最新备份文件: $(basename "$BACKUP_FILE")"
log_info "文件大小: $(du -h "$BACKUP_FILE" | cut -f1)"

# 测试目标数据库连接
log_info "连接目标数据库: ${TARGET_DB_HOST}:${TARGET_DB_PORT}/${TARGET_DB_NAME}"
if ! test_db_connection "target"; then
    log_error "无法连接到目标数据库，请检查配置"
    exit 1
fi

# 确认导入操作
echo ""
log_warning "⚠️  重要提醒："
echo "  - 这将清空并覆盖目标数据库中的所有数据"
echo "  - 目标数据库: ${TARGET_DB_HOST}:${TARGET_DB_PORT}/${TARGET_DB_NAME}"
echo "  - 备份文件: $(basename "$BACKUP_FILE")"
echo ""

if [ "$FORCE_IMPORT" = false ]; then
    read -p "确定要继续导入吗？(输入 'YES' 确认): " -r
    if [ "$REPLY" != "YES" ]; then
        log_warning "取消导入操作"
        exit 0
    fi
else
    log_info "使用 --force 参数，跳过确认"
fi

# 清空目标数据库
log_info "正在清空目标数据库..."
export PGPASSWORD="$TARGET_DB_PASSWORD"

# 安装必要的扩展
log_info "安装必要的扩展..."
docker_psql_pipe \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --command="CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null && log_success "vector扩展已安装" || log_warning "vector扩展安装失败，可能需要手动安装"

# 完整清理目标数据库中的所有对象
log_info "清理所有数据库对象..."

# 1. 删除所有表（CASCADE删除相关对象）
log_info "删除所有表..."
TABLES=$(docker_psql_pipe \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --tuples-only \
    --quiet \
    --command="SELECT tablename FROM pg_tables WHERE schemaname = '$TARGET_DB_SCHEMA';" 2>/dev/null)

if [ -n "$TABLES" ]; then
    echo "$TABLES" | while read -r table; do
        if [ -n "$table" ]; then
            table=$(echo "$table" | xargs)  # 去除空格
            log_debug "删除表: $table"
            docker_psql_pipe \
                --host="$TARGET_DB_HOST" \
                --port="$TARGET_DB_PORT" \
                --username="$TARGET_DB_USER" \
                --dbname="$TARGET_DB_NAME" \
                --command="DROP TABLE IF EXISTS \"$table\" CASCADE;" 2>/dev/null
        fi
    done
fi

# 2. 删除所有函数
log_info "删除所有函数..."
docker_psql_pipe \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --command="
DO \$\$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = '$TARGET_DB_SCHEMA' 
        AND p.proname NOT IN ('vector_in', 'vector_out', 'vector_recv', 'vector_send', 'vector_typmod_in', 'vector_typmod_out')
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || quote_ident(func_record.proname) || '(' || func_record.args || ') CASCADE';
    END LOOP;
END \$\$;" 2>/dev/null

# 3. 删除所有聚合
log_info "删除所有聚合..."
docker_psql_pipe \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --command="
DO \$\$
DECLARE
    agg_record RECORD;
BEGIN
    FOR agg_record IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = '$TARGET_DB_SCHEMA' AND p.prokind = 'a'
    LOOP
        EXECUTE 'DROP AGGREGATE IF EXISTS ' || quote_ident(agg_record.proname) || '(' || agg_record.args || ') CASCADE';
    END LOOP;
END \$\$;" 2>/dev/null

# 4. 删除所有运算符
log_info "删除所有运算符..."
docker_psql_pipe \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --command="
DO \$\$
DECLARE
    op_record RECORD;
BEGIN
    FOR op_record IN 
        SELECT o.oprname, 
               COALESCE(tl.typname, 'NONE') as left_type,
               tr.typname as right_type
        FROM pg_operator o
        JOIN pg_namespace n ON o.oprnamespace = n.oid
        LEFT JOIN pg_type tl ON o.oprleft = tl.oid
        JOIN pg_type tr ON o.oprright = tr.oid
        WHERE n.nspname = '$TARGET_DB_SCHEMA'
    LOOP
        IF op_record.left_type = 'NONE' THEN
            EXECUTE 'DROP OPERATOR IF EXISTS ' || op_record.oprname || ' (' || op_record.right_type || ', NONE) CASCADE';
        ELSE
            EXECUTE 'DROP OPERATOR IF EXISTS ' || op_record.oprname || ' (' || op_record.left_type || ', ' || op_record.right_type || ') CASCADE';
        END IF;
    END LOOP;
END \$\$;" 2>/dev/null

# 5. 删除所有自定义类型（除了vector扩展的类型）
log_info "删除所有自定义类型..."
docker_psql_pipe \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --command="
DO \$\$
DECLARE
    type_record RECORD;
BEGIN
    FOR type_record IN 
        SELECT t.typname
        FROM pg_type t 
        JOIN pg_namespace n ON t.typnamespace = n.oid 
        WHERE n.nspname = '$TARGET_DB_SCHEMA' 
        AND t.typtype != 'c'
        AND t.typname NOT IN ('vector', 'halfvec', 'bit', 'sparsevec')
    LOOP
        EXECUTE 'DROP TYPE IF EXISTS ' || quote_ident(type_record.typname) || ' CASCADE';
    END LOOP;
END \$\$;" 2>/dev/null

# 6. 删除所有序列
log_info "删除所有序列..."
SEQUENCES=$(docker_psql_pipe \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --tuples-only \
    --quiet \
    --command="SELECT sequencename FROM pg_sequences WHERE schemaname = '$TARGET_DB_SCHEMA';" 2>/dev/null)

if [ -n "$SEQUENCES" ]; then
    echo "$SEQUENCES" | while read -r seq; do
        if [ -n "$seq" ]; then
            seq=$(echo "$seq" | xargs)  # 去除空格
            log_debug "删除序列: $seq"
            docker_psql_pipe \
                --host="$TARGET_DB_HOST" \
                --port="$TARGET_DB_PORT" \
                --username="$TARGET_DB_USER" \
                --dbname="$TARGET_DB_NAME" \
                --command="DROP SEQUENCE IF EXISTS \"$seq\" CASCADE;" 2>/dev/null
        fi
    done
fi

log_success "目标数据库已完全清空"

# 设置密码环境变量
export PGPASSWORD="$TARGET_DB_PASSWORD"

log_info "正在导入数据库..."

# 检查文件是否压缩
if [[ "$BACKUP_FILE" == *.gz ]]; then
    log_info "检测到压缩文件，正在解压并导入..."
    
    # 构建psql参数
    PSQL_ARGS=(
        --host="$TARGET_DB_HOST"
        --port="$TARGET_DB_PORT"
        --username="$TARGET_DB_USER"
        --dbname="$TARGET_DB_NAME"
        --set client_encoding="$CLIENT_ENCODING"
    )
    
    # 解压并过滤掉数据库创建命令，然后通过管道导入
    log_info "过滤备份文件中的数据库创建命令..."
    gunzip -c "$BACKUP_FILE" | \
    grep -v "^CREATE DATABASE" | \
    grep -v "^DROP DATABASE" | \
    grep -v "^\\connect postgres" | \
    sed '/^COMMENT ON DATABASE/d' | \
    docker_psql_pipe "${PSQL_ARGS[@]}"
else
    log_info "处理未压缩的备份文件..."
    
    # 创建临时过滤文件
    TEMP_FILE="/tmp/filtered_backup_$(date +%s).sql"
    log_info "创建临时过滤文件: $TEMP_FILE"
    
    # 过滤掉数据库创建命令
    grep -v "^CREATE DATABASE" "$BACKUP_FILE" | \
    grep -v "^DROP DATABASE" | \
    grep -v "^\\connect postgres" | \
    sed '/^COMMENT ON DATABASE/d' > "$TEMP_FILE"
    
    # 构建psql参数
    PSQL_ARGS=(
        --host="$TARGET_DB_HOST"
        --port="$TARGET_DB_PORT"
        --username="$TARGET_DB_USER"
        --dbname="$TARGET_DB_NAME"
        --set client_encoding="$CLIENT_ENCODING"
        --file="$TEMP_FILE"
    )
    
    # 执行导入
    docker_psql "${PSQL_ARGS[@]}"
    
    # 清理临时文件
    rm -f "$TEMP_FILE"
fi

# 检查导入结果
if [ $? -eq 0 ]; then
    log_success "数据库导入成功!"
    
    # 验证导入结果
    log_info "验证导入结果..."
    table_count=$(docker_psql_pipe \
      --host="$TARGET_DB_HOST" \
      --port="$TARGET_DB_PORT" \
      --username="$TARGET_DB_USER" \
      --dbname="$TARGET_DB_NAME" \
      --tuples-only \
      --quiet \
      --command="SELECT count(*) FROM information_schema.tables WHERE table_schema = '$TARGET_DB_SCHEMA';" 2>/dev/null)
    
    if [ -n "$table_count" ]; then
        log_success "导入验证通过，共导入 $(echo $table_count | xargs) 个表"
    fi
else
    log_error "数据库导入失败!"
    exit 1
fi

# 清除密码环境变量
unset PGPASSWORD

log_success "导入完成: $(date)"