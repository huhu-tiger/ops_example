# DeepSeek-V3.2 压测脚本使用指南

## 项目简介

本项目提供了一套完整的 DeepSeek-V3.2 模型性能压测工具，基于 EvalScope 框架实现。支持多种测试场景和 SLA 自动调优功能。

## 快速开始

### 环境准备

```bash
# 1. 激活 conda 环境
conda activate model_test

# 2. 安装依赖
pip install evalscope transformers pandas matplotlib
```

### 运行压测

**推荐：使用 OpenQA 数据集（开箱即用）**
```bash
chmod +x test_sla_openqa.sh
./test_sla_openqa.sh
```

**可选：使用 Random 数据集（需要 tokenizer）**
```bash
chmod +x test_sla_random.sh
./test_sla_random.sh
```

## 脚本说明

### 1. test_openqa.sh - 基础压测（OpenQA 数据集）
**特点：**
- 使用 OpenQA 真实问答数据集
- 无需下载 tokenizer
- 自动从 ModelScope 下载数据集
- 测试多个固定并发级别（1, 2, 4, 8, 16, 32）
- 适合全面了解性能表现

**运行：**
```bash
./test_openqa.sh
```

### 2. test_sla_openqa.sh - SLA 自动调优（OpenQA 数据集）
**特点：**
- 使用 OpenQA 真实问答数据集
- 无需下载 tokenizer
- 自动寻找满足 SLA 目标的最大并发数
- SLA 目标：P99 首字延迟 (TTFT) <= 2秒
- 并发范围：2 - 128
- 适合生产环境容量规划

**运行：**
```bash
./test_sla_openqa.sh
```

### 3. test_sla_random.sh - SLA 自动调优（Random 数据集）
**特点：**
- 随机生成指定长度的 prompt（512-1024 tokens）
- 可精确控制输入长度
- 需要提前配置 tokenizer
- 自动寻找满足 SLA 目标的最大并发数
- 适合测试特定长度输入场景

**运行前准备：**
```bash
# tokenizer 会自动从 HuggingFace/ModelScope 下载
# 如遇网络问题，可手动下载后修改脚本中的 TOKENIZER_PATH
./test_sla_random.sh
```

## 压测配置详解

### 默认配置
- **模型**: deepseek-v3.2
- **API 地址**: http://61.49.53.5:30002/v1/chat/completions
- **SLA 目标**: P99 首字延迟 (TTFT) <= 2秒
- **并发范围**: 2 - 128
- **每级请求数**: 50（SLA 模式）/ 变化（基础模式）
- **输出 tokens**: 最多 2048
- **温度**: 0.1
- **Top-p**: 1.0

### 修改 SLA 目标

编辑脚本中的 `--sla-params` 参数：

```bash
# P99 首字延迟 <= 1秒
--sla-params '[{"p99_ttft": "<=1"}]'

# P99 总延迟 <= 3秒
--sla-params '[{"p99_latency": "<=3"}]'

# 寻找最大 TPS（吞吐量）
--sla-params '[{"tps": "max"}]'

# 多个条件组合
--sla-params '[{"p99_ttft": "<=2"}, {"tps": ">=1000"}]'
```

### 修改并发范围

```bash
--parallel 4              # 初始并发数
--sla-upper-bound 256     # 最大并发数上限
```

### 修改请求数量

```bash
--number 100              # 每个并发级别发送 100 个请求
```

### 修改 Prompt 长度（仅 Random 数据集）

```bash
--min-prompt-length 1024  # 最小 1024 tokens
--max-prompt-length 2048  # 最大 2048 tokens
```

### 修改 API 地址

```bash
--url http://your-api-server:port/v1/chat/completions
```

## 查看测试结果

### 1. 控制台实时输出
脚本运行时会实时显示：
- 当前测试的并发级别
- SLA 检查结果（通过/失败）
- 性能指标表格
- 自动调优进度

### 2. 文本报告
```bash
# 查看最新的性能摘要
cat outputs/*/deepseek-v3.2*/performance_summary.txt
```

### 3. SLA 摘要（JSON 格式）
```bash
# 查看 SLA 测试结果
cat outputs/*/deepseek-v3.2*/sla_summary.json
```

### 4. 可视化图表
```bash
# 图表自动生成在
outputs/charts/performance_metrics.png
```

图表包含：
- 总延迟分布（P50, P90, P99）
- 首字延迟 (TTFT) 分布
- 单字延迟 (TPOT) 分布
- 延迟时间序列

## 性能指标说明

| 指标 | 说明 |
|------|------|
| **RPS** | 每秒请求数 (Requests Per Second) |
| **TPS** | 每秒 Token 数 (Tokens Per Second) |
| **Latency** | 总延迟 - 从发送请求到接收完整响应的时间 |
| **TTFT** | 首字延迟 (Time To First Token) - 从发送请求到收到第一个 token 的时间 |
| **TPOT** | 单字延迟 (Time Per Output Token) - 生成每个 token 的平均时间 |
| **P50/P90/P99** | 百分位数 - 例如 P99 表示 99% 的请求延迟不超过此值 |

## 故障排查

### 问题1: tokenizer 未找到
```bash
# 错误信息: tokenizer-path is required for random dataset
# 解决方案: 脚本会自动下载，如遇网络问题可手动指定本地路径
```

### 问题2: transformers 模块未安装
```bash
# 错误: cannot import name 'AutoTokenizer'
# 解决方案:
pip install transformers
```

### 问题3: 数据集下载失败
```bash
# 网络问题导致 ModelScope 下载失败
# 解决方案: 设置代理或使用镜像源
export USE_MODELSCOPE_HUB=1
export MODELSCOPE_CACHE=/root/.cache/modelscope
```

### 问题4: API 连接失败
```bash
# 错误: Connection refused
# 解决方案: 检查 API 服务是否运行，确认地址和端口正确
curl http://61.49.53.5:30002/v1/models
```

### 问题5: 权限不足
```bash
# 错误: Permission denied
# 解决方案: 添加执行权限
chmod +x test_*.sh
```

## 环境要求

- **Python**: 3.8+
- **Conda 环境**: model_test
- **核心依赖**:
  - evalscope (压测框架)
  - transformers (tokenizer 支持)
  - pandas, matplotlib (可视化)

## 项目结构

```
.
├── README.md                   # 本文档
├── query_template.json         # 查询模板（用于 Random 数据集）
├── test_openqa.sh              # 基础压测 - OpenQA 数据集
├── test_sla_openqa.sh          # SLA 自动调优 - OpenQA 数据集
├── test_sla_random.sh          # SLA 自动调优 - Random 数据集
└── outputs/                    # 压测结果输出目录
    ├── [timestamp]/
    │   └── deepseek-v3.2*/
    │       ├── performance_summary.txt    # 性能摘要报告
    │       ├── sla_summary.json           # SLA 测试结果
    │       └── *.jsonl                    # 详细请求日志
    └── charts/
        └── performance_metrics.png        # 性能可视化图表
```

## 使用建议

1. **首次测试**: 使用 `test_sla_openqa.sh`，无需额外配置，快速了解模型性能
2. **生产规划**: 根据实际业务场景调整 SLA 目标，找到最优并发配置
3. **特定场景**: 使用 `test_sla_random.sh` 测试特定长度的输入
4. **全面评估**: 使用 `test_openqa.sh` 测试多个并发级别，绘制完整性能曲线

## 常见使用场景

### 场景1: 快速验证服务可用性
```bash
./test_sla_openqa.sh
# 快速测试并找到满足 2秒 TTFT 的最大并发数
```

### 场景2: 容量规划
```bash
# 修改 test_sla_openqa.sh 中的 SLA 目标
# 例如: --sla-params '[{"p99_ttft": "<=1.5"}]'
./test_sla_openqa.sh
```

### 场景3: 长文本性能测试
```bash
# 修改 test_sla_random.sh 中的 prompt 长度
# 例如: --min-prompt-length 2048 --max-prompt-length 4096
./test_sla_random.sh
```

### 场景4: 全面性能分析
```bash
# 使用基础压测脚本测试多个并发级别
./test_openqa.sh
# 然后查看可视化图表
```

## 技术支持

如遇问题，请检查：
1. Conda 环境是否正确激活
2. API 服务是否正常运行
3. 网络连接是否正常
4. 依赖包是否完整安装

## 许可证

本项目仅供内部测试使用。
