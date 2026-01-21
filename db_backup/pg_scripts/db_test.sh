#!/bin/bash

# PostgreSQL Database Test Script
# PostgreSQL数据库测试脚本

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
source "$SCRIPT_DIR/db_config.sh"

# 显示使用说明
show_usage() {
    echo "PostgreSQL数据库测试工具"
    echo ""
    echo "使用方法:"
    echo "  $0                    # 运行完整测试"
    echo "  $0 --docker           # 仅测试Docker环境"
    echo "  $0 --connection       # 仅测试数据库连接"
    echo "  $0 --tools            # 仅测试PostgreSQL工具"
    echo "  $0 --backup           # 列出备份文件"
    echo ""
}

# 测试Docker环境
test_docker_environment() {
    log_info "测试Docker环境..."
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装"
        return 1
    fi
    
    # 检查Docker服务是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行"
        return 1
    fi
    
    log_success "Docker环境正常"
    return 0
}

# 测试PostgreSQL工具
test_postgres_tools() {
    log_info "测试PostgreSQL工具..."
    
    if check_pg_tools; then
        log_success "PostgreSQL工具正常"
        return 0
    else
        log_error "PostgreSQL工具异常"
        return 1
    fi
}

# 测试数据库连接
test_database_connections() {
    setup_encoding
    
    log_info "测试数据库连接..."
    
    local source_ok=false
    local target_ok=false
    
    # 测试源数据库
    echo ""
    echo "源数据库: ${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}"
    if test_db_connection "source"; then
        source_ok=true
    fi
    
    # 测试目标数据库
    echo ""
    echo "目标数据库: ${TARGET_DB_HOST}:${TARGET_DB_PORT}/${TARGET_DB_NAME}"
    if test_db_connection "target"; then
        target_ok=true
    fi
    
    echo ""
    if [ "$source_ok" = true ] && [ "$target_ok" = true ]; then
        log_success "所有数据库连接正常"
        return 0
    elif [ "$source_ok" = true ]; then
        log_warning "仅源数据库连接正常"
        return 1
    elif [ "$target_ok" = true ]; then
        log_warning "仅目标数据库连接正常"
        return 1
    else
        log_error "所有数据库连接失败"
        return 1
    fi
}

# 列出备份文件
list_backup_files() {
    log_info "备份文件列表:"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_warning "备份目录不存在: $BACKUP_DIR"
        return 1
    fi
    
    local backup_files=$(ls -t "$BACKUP_DIR"/${SOURCE_DB_NAME}_${SOURCE_DB_SCHEMA}_*.sql* 2>/dev/null)
    if [ -n "$backup_files" ]; then
        echo "$backup_files" | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            local date=$(stat -c %y "$file" | cut -d' ' -f1,2 | cut -d'.' -f1)
            echo "  📁 $(basename "$file") (${size}, ${date})"
        done
        return 0
    else
        log_warning "没有找到备份文件"
        return 1
    fi
}

# 完整测试
run_full_test() {
    log_info "开始完整测试..."
    echo ""
    
    local tests=(
        "test_docker_environment"
        "test_postgres_tools"
        "test_database_connections"
        "list_backup_files"
    )
    
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        echo ""
        if $test; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo "=========================================="
    log_info "测试结果统计:"
    echo "  通过: $passed"
    echo "  失败: $failed"
    echo "  总计: $((passed + failed))"
    
    if [ $failed -eq 0 ]; then
        log_success "所有测试通过！"
        return 0
    else
        log_error "有 $failed 个测试失败"
        return 1
    fi
}

# 主函数
main() {
    case "${1:-full}" in
        --docker|-d)
            test_docker_environment
            ;;
        --connection|-c)
            test_database_connections
            ;;
        --tools|-t)
            test_postgres_tools
            ;;
        --backup|-b)
            list_backup_files
            ;;
        --help|-h)
            show_usage
            ;;
        full|"")
            run_full_test
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