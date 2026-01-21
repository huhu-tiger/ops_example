#!/bin/bash

# PostgreSQL Database Configuration Script
# PostgreSQL数据库配置脚本

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
source "$SCRIPT_DIR/db_config.sh"

# 显示使用说明
show_usage() {
    echo "PostgreSQL数据库配置工具"
    echo ""
    echo "使用方法:"
    echo "  $0                    # 显示当前配置"
    echo "  $0 --edit             # 编辑配置文件"
    echo "  $0 --test             # 测试数据库连接"
    echo "  $0 --docker           # 测试Docker环境"
    echo ""
}

# 显示配置信息
show_simple_config() {
    echo ""
    echo "=========================================="
    echo "           数据库配置信息"
    echo "=========================================="
    echo ""
    echo "源数据库 (导出):"
    echo "  ${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME} (${SOURCE_DB_USER})"
    echo ""
    echo "目标数据库 (导入):"
    echo "  ${TARGET_DB_HOST}:${TARGET_DB_PORT}/${TARGET_DB_NAME} (${TARGET_DB_USER})"
    echo ""
    echo "Docker配置:"
    echo "  使用Docker工具: $USE_DOCKER_TOOLS"
    echo "  PostgreSQL镜像: $POSTGRES_DOCKER_IMAGE"
    echo ""
    echo "备份配置:"
    echo "  备份目录: $BACKUP_DIR"
    echo "  保留天数: $BACKUP_RETENTION_DAYS"
    echo "=========================================="
}

# 测试数据库连接
test_connections() {
    setup_encoding
    
    echo ""
    echo "测试数据库连接..."
    echo ""
    
    # 测试源数据库
    echo "源数据库: ${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}"
    if test_db_connection "source" &>/dev/null; then
        log_success "源数据库连接正常"
    else
        log_error "源数据库连接失败"
    fi
    
    echo ""
    
    # 测试目标数据库
    echo "目标数据库: ${TARGET_DB_HOST}:${TARGET_DB_PORT}/${TARGET_DB_NAME}"
    if test_db_connection "target" &>/dev/null; then
        log_success "目标数据库连接正常"
    else
        log_error "目标数据库连接失败"
    fi
}

# 测试Docker环境
test_docker() {
    setup_encoding
    
    echo ""
    echo "测试Docker环境..."
    echo ""
    
    if check_pg_tools; then
        log_success "Docker PostgreSQL工具正常"
    else
        log_error "Docker PostgreSQL工具异常"
    fi
}

# 编辑配置文件
edit_config() {
    log_info "编辑配置文件: $SCRIPT_DIR/db_config.sh"
    
    if command -v nano &> /dev/null; then
        nano "$SCRIPT_DIR/db_config.sh"
    elif command -v vim &> /dev/null; then
        vim "$SCRIPT_DIR/db_config.sh"
    elif command -v vi &> /dev/null; then
        vi "$SCRIPT_DIR/db_config.sh"
    else
        log_error "未找到文本编辑器 (nano, vim, vi)"
        log_info "请手动编辑文件: $SCRIPT_DIR/db_config.sh"
        return 1
    fi
    
    log_success "配置文件编辑完成"
}

# 主函数
main() {
    case "${1:-show}" in
        --edit|-e)
            edit_config
            ;;
        --test|-t)
            test_connections
            ;;
        --docker|-d)
            test_docker
            ;;
        --help|-h)
            show_usage
            ;;
        show|"")
            show_simple_config
            ;;
        *)
            log_error "无效参数: $1"
            show_usage
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"