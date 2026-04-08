#!/usr/bin/env bash
# 同步 CodeMan Rules 到 .trae/rules/（Trae 适配）
# Trae 使用 .md 格式（非 .mdc），支持 alwaysApply/globs/description frontmatter
# 用法：bash sync-rules.sh [PROJECT_DIR]

set -e

PROJECT_DIR="${1:-$(pwd)}"

GREEN='\033[0;32m'
NC='\033[0m'

CODEMAN_RULES_DIR="${PROJECT_DIR}/.codeman/rules"
TRAE_RULES_DIR="${PROJECT_DIR}/.trae/rules"

# 检查源目录
if [ ! -d "$CODEMAN_RULES_DIR" ]; then
    echo "  .codeman/rules/ 不存在，跳过 Trae rules 同步"
    exit 0
fi

# 创建 .trae/rules/ 目录
mkdir -p "${TRAE_RULES_DIR}"

SYNCED=0

for mdc_file in "${CODEMAN_RULES_DIR}/"*.mdc; do
    [ -f "$mdc_file" ] || continue

    filename=$(basename "$mdc_file" .mdc)
    target="${TRAE_RULES_DIR}/codeman-${filename}.md"

    # 转换 .mdc -> .md：
    # Trae 原生支持 alwaysApply/globs/description，直接改扩展名即可
    cp "$mdc_file" "$target"

    SYNCED=$((SYNCED + 1))
done

echo -e "${GREEN}  [Trae] 已同步 ${SYNCED} 个规范文件到 .trae/rules/${NC}"
