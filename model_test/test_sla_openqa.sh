#!/bin/bash

# ============================================================================
# EvalScope 压测命令 - 使用 OpenQA 数据集
# ============================================================================
# 目标: 自动寻找满足 P99 首字延迟 (TTFT) <= 2秒 的最大并发数
# 数据集: OpenQA (真实问答数据，自动从 ModelScope 下载)
# 优点: 不需要 tokenizer，测试真实场景
# ============================================================================

# 激活 conda 环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate model_test

# 设置使用 ModelScope（而不是 HuggingFace）
export USE_MODELSCOPE_HUB=1
export MODELSCOPE_CACHE=/root/.cache/modelscope

echo "=========================================="
echo "压测配置: OpenQA 数据集"
echo "=========================================="
echo "数据集: OpenQA (真实问答)"
echo "并发范围: 2 - 128"
echo "每级请求数: 50"
echo "SLA 目标: P99 TTFT <= 2秒"
echo "=========================================="
echo ""

# 执行压测
evalscope perf \
  --model deepseek-v3.2 \
  --url http://61.49.53.5:30002/v1/chat/completions \
  --api openai \
  --dataset openqa \
  --max-tokens 2048 \
  --temperature 0.1 \
  --top-p 1.0 \
  --sla-auto-tune \
  --sla-variable parallel \
  --sla-params '[{"p99_ttft": "<=2"}]' \
  --parallel 2 \
  --sla-upper-bound 128 \
  --stream 


# 压测完成后，生成可视化图表
echo ""
echo "=========================================="
echo "正在生成可视化图表..."
echo "=========================================="
python3 visualize_results.py

echo ""
echo "=========================================="
echo "压测完成！"
echo "=========================================="
echo "查看结果:"
echo "  - 文本报告: outputs/*/deepseek-v3.2/performance_summary.txt"
echo "  - SLA 摘要: outputs/*/deepseek-v3.2/sla_summary.json"
echo "  - 可视化图表: outputs/charts/performance_metrics.png"
echo "=========================================="
