#!/usr/bin/env bash
# CodeMan v0.3 全局卸载脚本
# 同时清理 Cursor 和 Claude Code 两个环境的安装
# 用法：bash /path/to/codeman/uninstall.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CURSOR_INSTALL_DIR="${HOME}/.cursor/skills/.codeman"
CURSOR_BOOTSTRAP="${HOME}/.cursor/rules/codeman-bootstrap.mdc"
CLAUDE_INSTALL_DIR="${HOME}/.claude/skills/.codeman"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.3 全局卸载${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─────────────────────────────────────────
# 检查各环境安装情况
# ─────────────────────────────────────────
HAS_CURSOR_INSTALL=false
HAS_CURSOR_BOOTSTRAP=false
HAS_CLAUDE_INSTALL=false
HAS_CLAUDE_MD_BLOCK=false

[ -d "$CURSOR_INSTALL_DIR" ] && HAS_CURSOR_INSTALL=true
[ -f "$CURSOR_BOOTSTRAP" ] && HAS_CURSOR_BOOTSTRAP=true
[ -d "$CLAUDE_INSTALL_DIR" ] && HAS_CLAUDE_INSTALL=true
if [ -f "$CLAUDE_MD" ] && grep -q "<!-- CODEMAN START -->" "$CLAUDE_MD" 2>/dev/null; then
    HAS_CLAUDE_MD_BLOCK=true
fi

# 检查是否有任何安装
if [ "$HAS_CURSOR_INSTALL" = false ] && [ "$HAS_CURSOR_BOOTSTRAP" = false ] && \
   [ "$HAS_CLAUDE_INSTALL" = false ] && [ "$HAS_CLAUDE_MD_BLOCK" = false ]; then
    echo "未检测到 CodeMan 全局安装。"
    echo ""
    echo "无需卸载。"
    exit 0
fi

# ─────────────────────────────────────────
# 展示即将执行的操作
# ─────────────────────────────────────────
echo -e "${YELLOW}检测到以下 CodeMan 安装：${NC}"
echo ""

if [ "$HAS_CURSOR_INSTALL" = true ] || [ "$HAS_CURSOR_BOOTSTRAP" = true ]; then
    echo "  [Cursor]"
    [ "$HAS_CURSOR_INSTALL" = true ] && echo "    - 框架目录：${CURSOR_INSTALL_DIR}"
    [ "$HAS_CURSOR_BOOTSTRAP" = true ] && echo "    - Bootstrap rule：${CURSOR_BOOTSTRAP}"
fi

if [ "$HAS_CLAUDE_INSTALL" = true ] || [ "$HAS_CLAUDE_MD_BLOCK" = true ]; then
    echo "  [Claude Code]"
    [ "$HAS_CLAUDE_INSTALL" = true ] && echo "    - 框架目录：${CLAUDE_INSTALL_DIR}"
    [ "$HAS_CLAUDE_MD_BLOCK" = true ] && echo "    - CLAUDE.md 中的 CodeMan 片段：${CLAUDE_MD}"
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

# 卸载 Cursor
if [ "$HAS_CURSOR_INSTALL" = true ]; then
    rm -rf "$CURSOR_INSTALL_DIR"
    echo -e "  ${GREEN}✅ 已删除 ${CURSOR_INSTALL_DIR}${NC}"
fi

if [ "$HAS_CURSOR_BOOTSTRAP" = true ]; then
    rm -f "$CURSOR_BOOTSTRAP"
    echo -e "  ${GREEN}✅ 已删除 ${CURSOR_BOOTSTRAP}${NC}"
fi

# 卸载 Claude Code
if [ "$HAS_CLAUDE_INSTALL" = true ]; then
    rm -rf "$CLAUDE_INSTALL_DIR"
    echo -e "  ${GREEN}✅ 已删除 ${CLAUDE_INSTALL_DIR}${NC}"
fi

if [ "$HAS_CLAUDE_MD_BLOCK" = true ]; then
    # 从 CLAUDE.md 中移除 CodeMan 片段（保留其他内容）
    python3 - "$CLAUDE_MD" << 'PYEOF'
import sys, re

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

# 移除 CodeMan 片段（包括前后空行）
new_content = re.sub(
    r'\n*<!-- CODEMAN START -->.*?<!-- CODEMAN END -->\n*',
    '\n',
    content,
    flags=re.DOTALL
).strip()

if new_content:
    with open(filepath, 'w') as f:
        f.write(new_content + '\n')
    print(f"  已从 {filepath} 移除 CodeMan 片段（保留其他内容）")
else:
    import os
    os.remove(filepath)
    print(f"  已删除 {filepath}（文件已为空）")
PYEOF
fi

# ─────────────────────────────────────────
# 完成
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  CodeMan 全局卸载完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$HAS_CURSOR_INSTALL" = true ] || [ "$HAS_CURSOR_BOOTSTRAP" = true ]; then
    echo -e "${YELLOW}请重启 Cursor 使变更生效。${NC}"
fi
echo ""
echo "各业务项目中的 .codeman/ 目录未被删除。"
echo "如需清理某个项目的 CodeMan 配置，请在该项目根目录执行："
echo "  bash /path/to/codeman/uninit.sh"
echo ""
echo "如需重新安装，请执行："
echo "  bash /path/to/codeman/install.sh"
echo ""
