#!/usr/bin/env bash
# CodeMan v0.3 项目反初始化脚本
# 清理当前项目中的 CodeMan 配置（Rules、Skills、模板），保留 .codeman/docs/ 文档资产
# 用法：在项目根目录执行 bash ~/.cursor/skills/.codeman/uninit.sh

set -e

PROJECT_DIR="$(pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.3 项目反初始化${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查是否已初始化
if [ ! -d "${PROJECT_DIR}/.codeman" ]; then
    echo "未找到 .codeman/ 目录，当前项目未初始化 CodeMan。"
    exit 0
fi

echo -e "${YELLOW}即将执行以下操作：${NC}"
echo "  1. 删除 .cursor/rules/ 中的 codeman-* 规范文件"
echo "  2. 删除 .codeman/rules/ 目录"
echo "  3. 删除 .codeman/skills/ 目录"
echo "  4. 删除 .codeman/config.yaml"
echo "  5. 删除 .codeman/templates/ 目录"
echo ""
echo -e "${GREEN}以下内容将被保留（文档是项目资产）：${NC}"
echo "  .codeman/docs/      ← PRD、技术方案、测试报告等文档"
echo ""

read -p "确认反初始化？[y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "已取消。"
    exit 0
fi

# ─────────────────────────────────────────
# 1. 删除 Cursor Rules 中的 codeman-* 文件
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}清理 Cursor Rules...${NC}"
if [ -d "${PROJECT_DIR}/.cursor/rules" ]; then
    REMOVED=0
    for mdc_file in "${PROJECT_DIR}/.cursor/rules/codeman-"*.mdc; do
        if [ -f "$mdc_file" ]; then
            rm "$mdc_file"
            REMOVED=$((REMOVED + 1))
        fi
    done
    echo "  已删除 ${REMOVED} 个 codeman-*.mdc 规范文件"
else
    echo "  .cursor/rules/ 目录不存在，跳过"
fi

# ─────────────────────────────────────────
# 2. 删除 .codeman/ 中的非文档内容
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}清理 .codeman/ 配置...${NC}"

[ -d "${PROJECT_DIR}/.codeman/rules" ] && rm -rf "${PROJECT_DIR}/.codeman/rules" && echo "  ✅ 删除 .codeman/rules/"
[ -d "${PROJECT_DIR}/.codeman/skills" ] && rm -rf "${PROJECT_DIR}/.codeman/skills" && echo "  ✅ 删除 .codeman/skills/"
[ -d "${PROJECT_DIR}/.codeman/templates" ] && rm -rf "${PROJECT_DIR}/.codeman/templates" && echo "  ✅ 删除 .codeman/templates/"
[ -f "${PROJECT_DIR}/.codeman/config.yaml" ] && rm "${PROJECT_DIR}/.codeman/config.yaml" && echo "  ✅ 删除 .codeman/config.yaml"

# ─────────────────────────────────────────
# 完成
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  项目反初始化完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}文档已保留：${NC}"
echo "  .codeman/docs/   ← 您的 PRD、技术方案、测试报告等文档"
echo ""
echo "如需完全删除，请手动执行："
echo "  rm -rf .codeman/"
echo ""
echo "如需卸载 CodeMan 全局框架，请执行："
echo "  bash ~/.cursor/skills/.codeman/uninstall.sh"
echo ""
