#!/usr/bin/env bash
# CodeMan v0.3 安装脚本
# 用法：bash /path/to/codeman/install.sh
# 自动检测 Cursor / Claude Code 环境，安装到对应目录

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CODEMAN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────
# 环境检测
# ─────────────────────────────────────────
CURSOR_INSTALL_DIR="${HOME}/.cursor/skills/.codeman"
CLAUDE_INSTALL_DIR="${HOME}/.claude/skills/.codeman"
CURSOR_RULES_DIR="${HOME}/.cursor/rules"
CLAUDE_DIR="${HOME}/.claude"

HAS_CURSOR=false
HAS_CLAUDE=false

# 检测 Cursor：存在 ~/.cursor/ 目录
[ -d "${HOME}/.cursor" ] && HAS_CURSOR=true

# 检测 Claude Code：存在 ~/.claude/ 目录，或 claude 命令可用
if [ -d "${HOME}/.claude" ] || command -v claude &>/dev/null 2>&1; then
    HAS_CLAUDE=true
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.3 安装${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "检测到的环境："
[ "$HAS_CURSOR" = true ] && echo -e "  ${GREEN}✅ Cursor${NC}" || echo -e "  ⬜ Cursor（未检测到 ~/.cursor/）"
[ "$HAS_CLAUDE" = true ] && echo -e "  ${GREEN}✅ Claude Code${NC}" || echo -e "  ⬜ Claude Code（未检测到 ~/.claude/ 或 claude 命令）"
echo ""

# 如果两者都未检测到，询问用户
if [ "$HAS_CURSOR" = false ] && [ "$HAS_CLAUDE" = false ]; then
    echo -e "${YELLOW}未自动检测到 Cursor 或 Claude Code。${NC}"
    echo "请选择安装目标："
    echo "  1) Cursor"
    echo "  2) Claude Code"
    echo "  3) 两者都安装"
    read -p "请输入选项 [1/2/3]: " ENV_CHOICE
    case "$ENV_CHOICE" in
        1) HAS_CURSOR=true ;;
        2) HAS_CLAUDE=true ;;
        3) HAS_CURSOR=true; HAS_CLAUDE=true ;;
        *) echo "无效选项，退出。"; exit 1 ;;
    esac
fi

# 如果两者都检测到，询问用户
if [ "$HAS_CURSOR" = true ] && [ "$HAS_CLAUDE" = true ]; then
    echo "检测到两个环境，请选择安装目标："
    echo "  1) 仅 Cursor"
    echo "  2) 仅 Claude Code"
    echo "  3) 两者都安装（推荐）"
    read -p "请输入选项 [1/2/3，默认 3]: " ENV_CHOICE
    case "$ENV_CHOICE" in
        1) HAS_CLAUDE=false ;;
        2) HAS_CURSOR=false ;;
        3|"") ;;
        *) echo "无效选项，退出。"; exit 1 ;;
    esac
fi

# ─────────────────────────────────────────
# 检查是否已安装（覆盖确认）
# ─────────────────────────────────────────
NEED_CONFIRM=false
[ "$HAS_CURSOR" = true ] && [ -d "$CURSOR_INSTALL_DIR" ] && NEED_CONFIRM=true
[ "$HAS_CLAUDE" = true ] && [ -d "$CLAUDE_INSTALL_DIR" ] && NEED_CONFIRM=true

if [ "$NEED_CONFIRM" = true ]; then
    echo -e "${YELLOW}检测到已有安装，是否重新安装（覆盖）？[y/N]: ${NC}"
    read -r REINSTALL
    if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
        echo "已取消。"
        exit 0
    fi
    echo -e "${YELLOW}正在覆盖安装...${NC}"
fi

echo ""

# ─────────────────────────────────────────
# 安装到 Cursor
# ─────────────────────────────────────────
if [ "$HAS_CURSOR" = true ]; then
    echo -e "${GREEN}[Cursor] Step 1: 安装框架到 ${CURSOR_INSTALL_DIR}...${NC}"
    mkdir -p "${CURSOR_INSTALL_DIR}"
    rsync -a --exclude='.git' --exclude='*.bak' "${CODEMAN_SRC}/" "${CURSOR_INSTALL_DIR}/"
    echo "  已安装到：${CURSOR_INSTALL_DIR}"

    echo -e "${GREEN}[Cursor] Step 2: 生成全局 bootstrap rule...${NC}"
    mkdir -p "${CURSOR_RULES_DIR}"
    CURSOR_BOOTSTRAP="${CURSOR_RULES_DIR}/codeman-bootstrap.mdc"

    cat > "${CURSOR_BOOTSTRAP}" << 'BOOTSTRAP_EOF'
---
description: "CodeMan 工作流框架。当用户提到 CodeMan、开始开发、初始化、新需求、继续、修复、状态、概览等关键词时自动加载。"
alwaysApply: true
---

# CodeMan 已安装

你已安装 CodeMan v0.3 全流程开发工作流框架。

## 核心规则

当用户说以下任意命令时，你必须立即读取并执行 orchestrator Skill：

```
Read ~/.cursor/skills/.codeman/skills/orchestrator/SKILL.md
```

**触发命令列表：**
- `CodeMan 初始化` — 在当前项目初始化 CodeMan（新项目或旧项目接入）
- `CodeMan 开始开发` — 启动完整开发流程
- `CodeMan 新需求：[描述]` — 版本迭代
- `CodeMan 继续` — 断点续做
- `CodeMan 修复：[描述]` — 轻量修复
- `CodeMan 状态` — 查看当前进度
- `CodeMan 概览` — 生成/更新项目概览文档（面向新成员）

## Skills 路径

所有 Skills 位于 `~/.cursor/skills/.codeman/skills/`：

| Skill | 路径 |
|-------|------|
| orchestrator（入口） | `~/.cursor/skills/.codeman/skills/orchestrator/SKILL.md` |
| requirements | `~/.cursor/skills/.codeman/skills/requirements/SKILL.md` |
| design | `~/.cursor/skills/.codeman/skills/design/SKILL.md` |
| development | `~/.cursor/skills/.codeman/skills/development/SKILL.md` |
| testing | `~/.cursor/skills/.codeman/skills/testing/SKILL.md` |
| review | `~/.cursor/skills/.codeman/skills/review/SKILL.md` |
| fix | `~/.cursor/skills/.codeman/skills/fix/SKILL.md` |
| deploy | `~/.cursor/skills/.codeman/skills/deploy/SKILL.md` |
| evolve | `~/.cursor/skills/.codeman/skills/evolve/SKILL.md` |

## 重要说明

- orchestrator 是唯一入口，所有场景都从它开始
- 不要直接调用其他 Skill，由 orchestrator 按流程调度
- 项目文档存放在项目的 `.codeman/docs/` 目录，跟着项目走
BOOTSTRAP_EOF

    echo "  已生成：${CURSOR_BOOTSTRAP}"
    echo ""
fi

# ─────────────────────────────────────────
# 安装到 Claude Code
# ─────────────────────────────────────────
if [ "$HAS_CLAUDE" = true ]; then
    echo -e "${GREEN}[Claude Code] Step 1: 安装框架到 ${CLAUDE_INSTALL_DIR}...${NC}"
    mkdir -p "${CLAUDE_INSTALL_DIR}"
    rsync -a --exclude='.git' --exclude='*.bak' "${CODEMAN_SRC}/" "${CLAUDE_INSTALL_DIR}/"
    echo "  已安装到：${CLAUDE_INSTALL_DIR}"

    echo -e "${GREEN}[Claude Code] Step 2: 生成全局 CLAUDE.md bootstrap 片段...${NC}"
    mkdir -p "${CLAUDE_DIR}"
    CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"

    # 生成 CodeMan 片段内容
    CODEMAN_BLOCK="<!-- CODEMAN START -->
# CodeMan 已安装

你已安装 CodeMan v0.3 全流程开发工作流框架。

## 核心规则

当用户说以下任意命令时，你必须立即读取并执行 orchestrator Skill：

\`\`\`
Read ~/.claude/skills/.codeman/skills/orchestrator/SKILL.md
\`\`\`

**触发命令列表：**
- \`CodeMan 初始化\` — 在当前项目初始化 CodeMan（新项目或旧项目接入）
- \`CodeMan 开始开发\` — 启动完整开发流程
- \`CodeMan 新需求：[描述]\` — 版本迭代
- \`CodeMan 继续\` — 断点续做
- \`CodeMan 修复：[描述]\` — 轻量修复
- \`CodeMan 状态\` — 查看当前进度
- \`CodeMan 概览\` — 生成/更新项目概览文档（面向新成员）

## Skills 路径

所有 Skills 位于 \`~/.claude/skills/.codeman/skills/\`（Claude Code 自动发现，可用 /skill-name 直接调用）：

| Skill | 斜杠命令 |
|-------|---------|
| orchestrator（入口） | \`/codeman-orchestrator\` |
| requirements | \`/codeman-requirements\` |
| design | \`/codeman-design\` |
| development | \`/codeman-development\` |
| testing | \`/codeman-testing\` |
| review | \`/codeman-review\` |
| fix | \`/codeman-fix\` |
| deploy | \`/codeman-deploy\` |
| evolve | \`/codeman-evolve\` |

## 重要说明

- orchestrator 是唯一入口，所有场景都从它开始
- 不要直接调用其他 Skill，由 orchestrator 按流程调度
- 项目文档存放在项目的 \`.codeman/docs/\` 目录，跟着项目走
<!-- CODEMAN END -->"

    if [ -f "$CLAUDE_MD" ]; then
        # 检查是否已有 CodeMan 片段
        if grep -q "<!-- CODEMAN START -->" "$CLAUDE_MD" 2>/dev/null; then
            # 替换已有片段（用 Python 处理多行替换，更可靠）
            python3 -c "
import re, sys
content = open('${CLAUDE_MD}').read()
block = '''${CODEMAN_BLOCK}'''
new_content = re.sub(r'<!-- CODEMAN START -->.*?<!-- CODEMAN END -->', block, content, flags=re.DOTALL)
open('${CLAUDE_MD}', 'w').write(new_content)
print('  已更新 CLAUDE.md 中的 CodeMan 片段')
"
        else
            # 追加到文件末尾
            echo "" >> "$CLAUDE_MD"
            echo "$CODEMAN_BLOCK" >> "$CLAUDE_MD"
            echo "  已追加 CodeMan 片段到 ${CLAUDE_MD}"
        fi
    else
        # 创建新文件
        echo "$CODEMAN_BLOCK" > "$CLAUDE_MD"
        echo "  已创建 ${CLAUDE_MD}"
    fi

    echo ""
fi

# ─────────────────────────────────────────
# 验证安装
# ─────────────────────────────────────────
echo -e "${GREEN}验证安装...${NC}"

ALL_OK=true
SKILLS=("orchestrator" "requirements" "design" "development" "testing" "review" "fix" "deploy" "evolve")

if [ "$HAS_CURSOR" = true ]; then
    echo "  [Cursor]"
    for skill in "${SKILLS[@]}"; do
        skill_path="${CURSOR_INSTALL_DIR}/skills/${skill}/SKILL.md"
        if [ -f "$skill_path" ]; then
            echo -e "    ${GREEN}✅ ${skill}${NC}"
        else
            echo -e "    ${RED}❌ ${skill}（文件缺失）${NC}"
            ALL_OK=false
        fi
    done
    CURSOR_BOOTSTRAP="${CURSOR_RULES_DIR}/codeman-bootstrap.mdc"
    if [ -f "$CURSOR_BOOTSTRAP" ]; then
        echo -e "    ${GREEN}✅ codeman-bootstrap.mdc${NC}"
    else
        echo -e "    ${RED}❌ codeman-bootstrap.mdc（生成失败）${NC}"
        ALL_OK=false
    fi
fi

if [ "$HAS_CLAUDE" = true ]; then
    echo "  [Claude Code]"
    for skill in "${SKILLS[@]}"; do
        skill_path="${CLAUDE_INSTALL_DIR}/skills/${skill}/SKILL.md"
        if [ -f "$skill_path" ]; then
            echo -e "    ${GREEN}✅ ${skill}${NC}"
        else
            echo -e "    ${RED}❌ ${skill}（文件缺失）${NC}"
            ALL_OK=false
        fi
    done
    CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ] && grep -q "CODEMAN START" "$CLAUDE_MD" 2>/dev/null; then
        echo -e "    ${GREEN}✅ ~/.claude/CLAUDE.md（CodeMan 片段已注入）${NC}"
    else
        echo -e "    ${RED}❌ ~/.claude/CLAUDE.md（CodeMan 片段缺失）${NC}"
        ALL_OK=false
    fi
fi

# ─────────────────────────────────────────
# 完成
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  CodeMan 安装完成！${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [ "$HAS_CURSOR" = true ]; then
        echo -e "${YELLOW}[Cursor] 下一步：${NC}"
        echo "  1. 重启 Cursor（让 bootstrap rule 生效）"
        echo "  2. 打开任意项目，在 Agent 对话中说："
        echo "     CodeMan 初始化"
        echo ""
    fi
    if [ "$HAS_CLAUDE" = true ]; then
        echo -e "${YELLOW}[Claude Code] 下一步：${NC}"
        echo "  1. 打开任意项目，在 Claude Code 中说："
        echo "     CodeMan 初始化"
        echo "  或直接使用斜杠命令："
        echo "     /codeman-orchestrator"
        echo ""
    fi
    echo "  CodeMan 会自动识别是新项目还是旧项目，并完成初始化。"
else
    echo -e "${RED}  安装过程中有错误，请检查上方输出。${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
echo ""
