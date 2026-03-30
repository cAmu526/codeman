#!/usr/bin/env bash
# CodeMan v0.3 安装脚本
# 用法：bash /path/to/codeman/install.sh
# 将 CodeMan 安装到 ~/.cursor/skills/.codeman/，全局生效

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CODEMAN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.cursor/skills/.codeman"
CURSOR_RULES_DIR="${HOME}/.cursor/rules"
BOOTSTRAP_FILE="${CURSOR_RULES_DIR}/codeman-bootstrap.mdc"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.3 安装${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─────────────────────────────────────────
# 检查是否已安装
# ─────────────────────────────────────────
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}检测到已有安装：${INSTALL_DIR}${NC}"
    read -p "是否重新安装（覆盖）？[y/N]: " REINSTALL
    if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
        echo "已取消。"
        exit 0
    fi
    echo -e "${YELLOW}正在覆盖安装...${NC}"
fi

# ─────────────────────────────────────────
# Step 1: 复制框架到 ~/.cursor/skills/.codeman/
# ─────────────────────────────────────────
echo -e "${GREEN}Step 1: 安装框架到 ${INSTALL_DIR}...${NC}"

mkdir -p "${INSTALL_DIR}"
# 复制所有内容，排除 .git 目录
rsync -a --exclude='.git' --exclude='*.bak' "${CODEMAN_SRC}/" "${INSTALL_DIR}/"

echo "  已安装到：${INSTALL_DIR}"

# ─────────────────────────────────────────
# Step 2: 生成 codeman-bootstrap.mdc
# ─────────────────────────────────────────
echo -e "${GREEN}Step 2: 生成 Cursor 全局 bootstrap rule...${NC}"

mkdir -p "${CURSOR_RULES_DIR}"

cat > "${BOOTSTRAP_FILE}" << 'BOOTSTRAP_EOF'
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

echo "  已生成：${BOOTSTRAP_FILE}"

# ─────────────────────────────────────────
# Step 3: 验证安装
# ─────────────────────────────────────────
echo -e "${GREEN}Step 3: 验证安装...${NC}"

ALL_OK=true
SKILLS=("orchestrator" "requirements" "design" "development" "testing" "review" "fix" "deploy" "evolve")

for skill in "${SKILLS[@]}"; do
    skill_path="${INSTALL_DIR}/skills/${skill}/SKILL.md"
    if [ -f "$skill_path" ]; then
        echo -e "  ${GREEN}✅ ${skill}${NC}"
    else
        echo -e "  ${RED}❌ ${skill}（文件缺失：${skill_path}）${NC}"
        ALL_OK=false
    fi
done

if [ -f "$BOOTSTRAP_FILE" ]; then
    echo -e "  ${GREEN}✅ codeman-bootstrap.mdc${NC}"
else
    echo -e "  ${RED}❌ codeman-bootstrap.mdc（生成失败）${NC}"
    ALL_OK=false
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
    echo "安装位置：${INSTALL_DIR}"
    echo "Bootstrap：${BOOTSTRAP_FILE}"
    echo ""
    echo -e "${YELLOW}下一步：${NC}"
    echo "  1. 重启 Cursor（让 bootstrap rule 生效）"
    echo "  2. 打开任意项目，在 Agent 对话中说："
    echo "     CodeMan 初始化"
    echo ""
    echo "  CodeMan 会自动识别是新项目还是旧项目，并完成初始化。"
else
    echo -e "${RED}  安装过程中有错误，请检查上方输出。${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
echo ""
