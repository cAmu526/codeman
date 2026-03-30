#!/usr/bin/env bash
# 同步 CodeMan Rules 到 .cursor/rules/
# 用法：bash sync-rules.sh [PROJECT_DIR] [CODEMAN_DIR]

set -e

PROJECT_DIR="${1:-$(pwd)}"
CODEMAN_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

GREEN='\033[0;32m'
NC='\033[0m'

# 创建 .cursor/rules/ 目录
mkdir -p "${PROJECT_DIR}/.cursor/rules"

# 同步 .codeman/rules/ 中的所有 .mdc 文件到 .cursor/rules/
# 加 codeman- 前缀，避免与用户已有规范冲突
SYNCED=0
for mdc_file in "${PROJECT_DIR}/.codeman/rules/"*.mdc; do
    if [ -f "$mdc_file" ]; then
        filename=$(basename "$mdc_file")
        target="${PROJECT_DIR}/.cursor/rules/codeman-${filename}"
        cp "$mdc_file" "$target"
        SYNCED=$((SYNCED + 1))
    fi
done

echo -e "${GREEN}  已同步 ${SYNCED} 个规范文件到 .cursor/rules/${NC}"
