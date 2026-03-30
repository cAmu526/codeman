#!/usr/bin/env bash
# CodeMan v0.3 全局卸载脚本
# 删除 ~/.cursor/skills/.codeman/ 和 ~/.cursor/rules/codeman-bootstrap.mdc
# 用法：bash /path/to/codeman/uninstall.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="${HOME}/.cursor/skills/.codeman"
BOOTSTRAP_FILE="${HOME}/.cursor/rules/codeman-bootstrap.mdc"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.3 全局卸载${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─────────────────────────────────────────
# 检查是否已安装
# ─────────────────────────────────────────
HAS_INSTALL_DIR=false
HAS_BOOTSTRAP=false

[ -d "$INSTALL_DIR" ] && HAS_INSTALL_DIR=true
[ -f "$BOOTSTRAP_FILE" ] && HAS_BOOTSTRAP=true

if [ "$HAS_INSTALL_DIR" = false ] && [ "$HAS_BOOTSTRAP" = false ]; then
    echo "未检测到 CodeMan 全局安装。"
    echo "  ${INSTALL_DIR} 不存在"
    echo "  ${BOOTSTRAP_FILE} 不存在"
    echo ""
    echo "无需卸载。"
    exit 0
fi

# ─────────────────────────────────────────
# 展示即将执行的操作
# ─────────────────────────────────────────
echo -e "${YELLOW}即将执行以下操作：${NC}"
if [ "$HAS_INSTALL_DIR" = true ]; then
    echo "  1. 删除框架目录：${INSTALL_DIR}"
fi
if [ "$HAS_BOOTSTRAP" = true ]; then
    echo "  2. 删除 bootstrap rule：${BOOTSTRAP_FILE}"
fi
echo ""
echo -e "${GREEN}以下内容不受影响：${NC}"
echo "  各业务项目中的 .codeman/docs/ 文档资产"
echo ""

read -p "确认卸载？[y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "已取消。"
    exit 0
fi

# ─────────────────────────────────────────
# 执行卸载
# ─────────────────────────────────────────
echo ""

if [ "$HAS_INSTALL_DIR" = true ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "  ${GREEN}✅ 已删除 ${INSTALL_DIR}${NC}"
fi

if [ "$HAS_BOOTSTRAP" = true ]; then
    rm -f "$BOOTSTRAP_FILE"
    echo -e "  ${GREEN}✅ 已删除 ${BOOTSTRAP_FILE}${NC}"
fi

# ─────────────────────────────────────────
# 完成
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  CodeMan 全局卸载完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}请重启 Cursor 使变更生效。${NC}"
echo ""
echo "各业务项目中的 .codeman/ 目录未被删除。"
echo "如需清理某个项目的 CodeMan 配置，请在该项目根目录执行："
echo "  bash ~/.cursor/skills/.codeman/uninit.sh"
echo ""
echo "如需重新安装，请执行："
echo "  bash /path/to/codeman/install.sh"
echo ""
