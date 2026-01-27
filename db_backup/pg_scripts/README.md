# PostgreSQL 数据库备份脚本 - 简化版

简化的PostgreSQL数据库备份和恢复工具，使用Docker中的PostgreSQL工具。

## 🚀 快速开始

### 1. 配置数据库连接

```bash
# 查看当前配置
./db_configure.sh

# 编辑配置文件
./db_configure.sh --edit
```

### 2. 测试环境

```bash
# 完整测试
./db_test.sh

# 仅测试数据库连接
./db_test.sh --connection
```

### 3. 导出数据库

```bash
# 从源数据库导出
./db_export.sh
```

### 4. 导入数据库

```bash
# 导入最新备份到目标数据库
./db_import.sh
```

## 📁 脚本说明

- **`db_export.sh`** - 导出源数据库到备份文件
- **`db_import.sh`** - 导入最新备份到目标数据库
- **`db_configure.sh`** - 查看和编辑配置
- **`db_test.sh`** - 测试环境和连接
- **`db_config.sh`** - 配置文件（不直接运行）

## ⚙️ 配置说明

编辑 `db_config.sh` 文件中的以下配置：

```bash
# 源数据库 (导出)
SOURCE_DB_HOST="192.168.33.131"
SOURCE_DB_NAME="postgres"
SOURCE_DB_USER="username"
SOURCE_DB_PASSWORD="password"

# 目标数据库 (导入)
TARGET_DB_HOST="192.168.33.131"
TARGET_DB_NAME="newapi"
TARGET_DB_USER="username"
TARGET_DB_PASSWORD="password"

# Docker配置
USE_DOCKER_TOOLS=true
POSTGRES_DOCKER_IMAGE="model.vnet.com/sjhl/postgres:15"
```

## 🔧 使用流程

### 完整备份恢复流程

```bash
# 1. 测试环境
./db_test.sh

# 2. 导出源数据库
./db_export.sh

# 3. 导入到目标数据库
./db_import.sh
```

### 查看备份文件

```bash
# 列出所有备份文件
./db_test.sh --backup
```

## 🐳 Docker模式

默认使用Docker模式，优势：
- ✅ 无需安装PostgreSQL客户端
- ✅ 版本一致性
- ✅ 环境隔离

## 🛠️ 故障排除

### 常见问题

1. **Docker未运行**
   ```bash
   sudo systemctl start docker
   ```

2. **数据库连接失败**
   ```bash
   ./db_configure.sh --test
   ```

3. **没有备份文件**
   ```bash
   ./db_export.sh  # 先创建备份
   ```

## 📋 注意事项

- 导入操作会覆盖目标数据库的现有数据
- 备份文件自动压缩并保留30天
- 导入时需要输入 'YES' 确认操作
- 默认导入最新的备份文件

## 🔐 安全提醒

- 修改默认密码
- 设置适当的文件权限：`chmod 600 db_config.sh`
- 定期清理旧备份文件