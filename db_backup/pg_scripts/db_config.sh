#!/bin/bash

# PostgreSQL Database Configuration
# PostgreSQL数据库配置文件

# ===========================================
# 源数据库配置 (用于导出)
# ===========================================
export SOURCE_DB_HOST="192.168.33.131"
export SOURCE_DB_PORT="5432"
export SOURCE_DB_NAME="postgres"
export SOURCE_DB_USER="username"
export SOURCE_DB_PASSWORD="password"
export SOURCE_DB_SCHEMA="public"

# 源数据库连接令牌 (完整连接字符串)
export SOURCE_DB_TOKEN="postgresql://${SOURCE_DB_USER}:${SOURCE_DB_PASSWORD}@${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}"

# ===========================================
# 目标数据库配置 (用于导入)
# ===========================================
export TARGET_DB_HOST="192.168.33.131"
export TARGET_DB_PORT="5432"
export TARGET_DB_NAME="newapi"
export TARGET_DB_USER="username"
export TARGET_DB_PASSWORD="password"
export TARGET_DB_SCHEMA="public"

# 目标数据库连接令牌 (完整连接字符串)
export TARGET_DB_TOKEN="postgresql://${TARGET_DB_USER}:${TARGET_DB_PASSWORD}@${TARGET_DB_HOST}:${TARGET_DB_PORT}/${TARGET_DB_NAME}"

# ===========================================
# Docker配置
# ===========================================
export POSTGRES_DOCKER_IMAGE="model.vnet.com/sjhl/postgres:15"
export USE_DOCKER_TOOLS=true  # 是否使用Docker中的PostgreSQL工具
export DOCKER_NETWORK="host"  # Docker网络模式，host模式可直接访问宿主机网络

# ===========================================
# 备份配置
# ===========================================
export BACKUP_DIR="./backups"
export BACKUP_RETENTION_DAYS=30  # 备份文件保留天数

# ===========================================
# 字符集配置
# ===========================================
export DB_ENCODING="UTF8"           # 数据库字符编码
export CLIENT_ENCODING="UTF8"       # 客户端字符编码
export LC_COLLATE="en_US.UTF-8"     # 排序规则
export LC_CTYPE="en_US.UTF-8"       # 字符分类
export LANG="en_US.UTF-8"           # 系统语言环境
export LC_ALL="en_US.UTF-8"         # 所有本地化设置

# ===========================================
# 颜色输出配置
# ===========================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# ===========================================
# 日志函数
# ===========================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

log_config() {
    echo -e "${CYAN}[CONFIG]${NC} $1"
}

# ===========================================
# PostgreSQL工具检查函数
# ===========================================
check_pg_tools() {
    log_info "检查PostgreSQL客户端工具..."
    
    if [ "$USE_DOCKER_TOOLS" = true ]; then
        log_info "使用Docker模式: $POSTGRES_DOCKER_IMAGE"
        
        # 检查Docker是否可用
        if ! command -v docker &> /dev/null; then
            log_error "Docker 未找到，请安装Docker"
            echo ""
            log_info "安装指南:"
            echo "  Ubuntu/Debian: sudo apt-get install docker.io"
            echo "  CentOS/RHEL:   sudo yum install docker"
            echo "  macOS:         brew install docker"
            echo ""
            return 1
        fi
        
        # 检查Docker服务是否运行
        if ! docker info &> /dev/null; then
            log_error "Docker服务未运行，请启动Docker服务"
            echo ""
            log_info "启动Docker服务:"
            echo "  sudo systemctl start docker"
            echo "  sudo systemctl enable docker"
            echo ""
            return 1
        fi
        
        # 检查Docker镜像是否存在
        log_info "检查PostgreSQL Docker镜像..."
        if ! docker image inspect "$POSTGRES_DOCKER_IMAGE" &> /dev/null; then
            log_warning "PostgreSQL镜像不存在，正在拉取: $POSTGRES_DOCKER_IMAGE"
            if docker pull "$POSTGRES_DOCKER_IMAGE"; then
                log_success "PostgreSQL镜像拉取成功"
            else
                log_error "PostgreSQL镜像拉取失败"
                return 1
            fi
        else
            log_debug "找到PostgreSQL镜像: $POSTGRES_DOCKER_IMAGE"
        fi
        
        # 测试Docker中的PostgreSQL工具
        log_info "测试Docker中的PostgreSQL工具..."
        local pg_dump_version=$(docker run --rm "$POSTGRES_DOCKER_IMAGE" pg_dump --version 2>/dev/null)
        local psql_version=$(docker run --rm "$POSTGRES_DOCKER_IMAGE" psql --version 2>/dev/null)
        
        if [ -n "$pg_dump_version" ] && [ -n "$psql_version" ]; then
            log_success "Docker PostgreSQL工具检查通过"
            log_debug "pg_dump: $pg_dump_version"
            log_debug "psql: $psql_version"
        else
            log_error "Docker中的PostgreSQL工具测试失败"
            return 1
        fi
        
    else
        # 原有的本地工具检查逻辑
        local missing_tools=()
        
        # 检查pg_dump
        if ! command -v pg_dump &> /dev/null; then
            missing_tools+=("pg_dump")
        else
            local pg_dump_version=$(pg_dump --version | head -n1)
            log_debug "找到 pg_dump: $pg_dump_version"
        fi
        
        # 检查psql
        if ! command -v psql &> /dev/null; then
            missing_tools+=("psql")
        else
            local psql_version=$(psql --version | head -n1)
            log_debug "找到 psql: $psql_version"
        fi
        
        # 如果有缺失的工具，显示安装指南
        if [ ${#missing_tools[@]} -gt 0 ]; then
            log_error "缺少以下PostgreSQL客户端工具: ${missing_tools[*]}"
            echo ""
            log_info "安装指南:"
            echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
            echo "  CentOS/RHEL:   sudo yum install postgresql"
            echo "  macOS:         brew install postgresql"
            echo ""
            log_info "或者设置 USE_DOCKER_TOOLS=true 使用Docker模式"
            echo ""
            return 1
        fi
        
        log_success "本地PostgreSQL客户端工具检查通过"
    fi
    
    # 检查gzip (用于压缩)
    if ! command -v gzip &> /dev/null; then
        log_warning "gzip 未找到，备份文件将不会被压缩"
    else
        log_debug "找到 gzip: $(gzip --version | head -n1)"
    fi
    
    return 0
}

# ===========================================
# Docker命令包装函数
# ===========================================
docker_pg_dump() {
    if [ "$USE_DOCKER_TOOLS" = true ]; then
        # 构建Docker卷映射，确保备份文件可以写入宿主机
        local backup_dir_abs=$(realpath "$BACKUP_DIR")
        
        # 确保备份目录存在
        mkdir -p "$backup_dir_abs"
        
        docker run --rm \
            --network="$DOCKER_NETWORK" \
            -v "$backup_dir_abs:/backups" \
            -e PGPASSWORD="$PGPASSWORD" \
            -e PGCLIENTENCODING="$PGCLIENTENCODING" \
            "$POSTGRES_DOCKER_IMAGE" \
            pg_dump "$@"
    else
        pg_dump "$@"
    fi
}

docker_psql() {
    if [ "$USE_DOCKER_TOOLS" = true ]; then
        # 如果有输入文件，需要映射到容器中
        local volume_args=""
        local file_arg=""
        
        # 检查参数中是否有--file参数
        for arg in "$@"; do
            if [[ "$arg" == --file=* ]]; then
                local file_path="${arg#--file=}"
                local file_dir=$(dirname "$(realpath "$file_path")")
                local file_name=$(basename "$file_path")
                volume_args="-v $file_dir:/input"
                file_arg="--file=/input/$file_name"
            fi
        done
        
        # 构建新的参数列表，替换文件路径
        local new_args=()
        for arg in "$@"; do
            if [[ "$arg" == --file=* ]]; then
                new_args+=("$file_arg")
            else
                new_args+=("$arg")
            fi
        done
        
        docker run --rm -i \
            --network="$DOCKER_NETWORK" \
            $volume_args \
            -e PGPASSWORD="$PGPASSWORD" \
            -e PGCLIENTENCODING="$PGCLIENTENCODING" \
            "$POSTGRES_DOCKER_IMAGE" \
            psql "${new_args[@]}"
    else
        psql "$@"
    fi
}

# 用于管道输入的psql包装函数
docker_psql_pipe() {
    if [ "$USE_DOCKER_TOOLS" = true ]; then
        docker run --rm -i \
            --network="$DOCKER_NETWORK" \
            -e PGPASSWORD="$PGPASSWORD" \
            -e PGCLIENTENCODING="$PGCLIENTENCODING" \
            "$POSTGRES_DOCKER_IMAGE" \
            psql "$@"
    else
        psql "$@"
    fi
}

# ===========================================
# 字符集设置函数
# ===========================================
setup_encoding() {
    log_info "设置字符集环境..."
    
    # 设置PostgreSQL客户端编码
    export PGCLIENTENCODING="$CLIENT_ENCODING"
    
    # 设置系统语言环境
    export LANG="$LANG"
    export LC_ALL="$LC_ALL"
    export LC_COLLATE="$LC_COLLATE"
    export LC_CTYPE="$LC_CTYPE"
    
    log_debug "PGCLIENTENCODING: $PGCLIENTENCODING"
    log_debug "LANG: $LANG"
    log_debug "LC_ALL: $LC_ALL"
    
    # 检查系统是否支持UTF-8
    if locale -a 2>/dev/null | grep -q "en_US.utf8\|en_US.UTF-8"; then
        log_success "系统支持UTF-8字符集"
    else
        log_warning "系统可能不支持UTF-8字符集，可能会出现字符编码问题"
        log_info "建议安装UTF-8语言包: sudo apt-get install locales"
    fi
}

# ===========================================
# 字符集验证函数
# ===========================================
verify_encoding() {
    local db_type="$1"  # "source" 或 "target"
    local host port dbname user password
    
    if [ "$db_type" = "source" ]; then
        host="$SOURCE_DB_HOST"
        port="$SOURCE_DB_PORT"
        dbname="$SOURCE_DB_NAME"
        user="$SOURCE_DB_USER"
        password="$SOURCE_DB_PASSWORD"
    elif [ "$db_type" = "target" ]; then
        host="$TARGET_DB_HOST"
        port="$TARGET_DB_PORT"
        dbname="$TARGET_DB_NAME"
        user="$TARGET_DB_USER"
        password="$TARGET_DB_PASSWORD"
    else
        log_error "无效的数据库类型: $db_type"
        return 1
    fi
    
    log_info "验证${db_type}数据库字符集..."
    
    export PGPASSWORD="$password"
    
    # 获取数据库编码信息
    local db_encoding=$(docker_psql_pipe \
        --host="$host" \
        --port="$port" \
        --username="$user" \
        --dbname="$dbname" \
        --tuples-only \
        --quiet \
        --command="SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = '$dbname';" 2>/dev/null | xargs)
    
    local db_collate=$(docker_psql_pipe \
        --host="$host" \
        --port="$port" \
        --username="$user" \
        --dbname="$dbname" \
        --tuples-only \
        --quiet \
        --command="SELECT datcollate FROM pg_database WHERE datname = '$dbname';" 2>/dev/null | xargs)
    
    local db_ctype=$(docker_psql_pipe \
        --host="$host" \
        --port="$port" \
        --username="$user" \
        --dbname="$dbname" \
        --tuples-only \
        --quiet \
        --command="SELECT datctype FROM pg_database WHERE datname = '$dbname';" 2>/dev/null | xargs)
    
    unset PGPASSWORD
    
    if [ -n "$db_encoding" ]; then
        log_success "${db_type}数据库字符集信息:"
        echo "  编码: $db_encoding"
        echo "  排序规则: $db_collate"
        echo "  字符分类: $db_ctype"
        
        # 检查是否为UTF-8兼容编码
        if [[ "$db_encoding" =~ ^(UTF8|UTF-8)$ ]]; then
            log_success "数据库使用UTF-8编码，兼容性良好"
        else
            log_warning "数据库使用非UTF-8编码($db_encoding)，可能存在字符兼容性问题"
        fi
        
        return 0
    else
        log_error "无法获取${db_type}数据库字符集信息"
        return 1
    fi
}

# ===========================================
# 数据库连接测试函数
# ===========================================
test_db_connection() {
    local db_type="$1"  # "source" 或 "target"
    local host port dbname user password
    
    if [ "$db_type" = "source" ]; then
        host="$SOURCE_DB_HOST"
        port="$SOURCE_DB_PORT"
        dbname="$SOURCE_DB_NAME"
        user="$SOURCE_DB_USER"
        password="$SOURCE_DB_PASSWORD"
        log_info "测试源数据库连接..."
    elif [ "$db_type" = "target" ]; then
        host="$TARGET_DB_HOST"
        port="$TARGET_DB_PORT"
        dbname="$TARGET_DB_NAME"
        user="$TARGET_DB_USER"
        password="$TARGET_DB_PASSWORD"
        log_info "测试目标数据库连接..."
    else
        log_error "无效的数据库类型: $db_type"
        return 1
    fi
    
    log_config "连接到: ${host}:${port}/${dbname} (用户: ${user})"
    
    export PGPASSWORD="$password"
    
    # 测试连接并获取版本信息
    local result=$(docker_psql_pipe \
        --host="$host" \
        --port="$port" \
        --username="$user" \
        --dbname="$dbname" \
        --command="SELECT version();" \
        --tuples-only \
        --quiet 2>&1)
    
    local exit_code=$?
    unset PGPASSWORD
    
    if [ $exit_code -eq 0 ]; then
        log_success "${db_type}数据库连接成功!"
        log_debug "数据库版本: $(echo "$result" | xargs)"
        return 0
    else
        log_error "${db_type}数据库连接失败!"
        log_error "错误信息: $result"
        return 1
    fi
}

# ===========================================
# 显示配置信息函数
# ===========================================
show_config() {
    echo ""
    echo "=========================================="
    echo "           数据库配置信息"
    echo "=========================================="
    echo ""
    log_config "源数据库 (导出):"
    echo "  主机: $SOURCE_DB_HOST:$SOURCE_DB_PORT"
    echo "  数据库: $SOURCE_DB_NAME"
    echo "  用户: $SOURCE_DB_USER"
    echo "  模式: $SOURCE_DB_SCHEMA"
    echo "  令牌: $SOURCE_DB_TOKEN"
    echo ""
    log_config "目标数据库 (导入):"
    echo "  主机: $TARGET_DB_HOST:$TARGET_DB_PORT"
    echo "  数据库: $TARGET_DB_NAME"
    echo "  用户: $TARGET_DB_USER"
    echo "  模式: $TARGET_DB_SCHEMA"
    echo "  令牌: $TARGET_DB_TOKEN"
    echo ""
    log_config "Docker配置:"
    echo "  使用Docker工具: $USE_DOCKER_TOOLS"
    echo "  PostgreSQL镜像: $POSTGRES_DOCKER_IMAGE"
    echo "  Docker网络模式: $DOCKER_NETWORK"
    echo ""
    log_config "备份配置:"
    echo "  备份目录: $BACKUP_DIR"
    echo "  保留天数: $BACKUP_RETENTION_DAYS"
    echo ""
    log_config "字符集配置:"
    echo "  数据库编码: $DB_ENCODING"
    echo "  客户端编码: $CLIENT_ENCODING"
    echo "  排序规则: $LC_COLLATE"
    echo "  字符分类: $LC_CTYPE"
    echo "  系统语言: $LANG"
    echo "=========================================="
}