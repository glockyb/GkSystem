#!/bin/bash
# 添加示例评分数据

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
log_info "添加示例评分数据"
echo "=========================================="
echo ""

cd "$SCRIPT_DIR/backend"
source ../venv/bin/activate

log_info "运行 Python 脚本添加评分数据..."
python3 ../add-sample-ratings.py

echo ""
log_success "完成！"

