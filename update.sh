#!/usr/bin/env bash
# CodeMan v0.3 框架升级脚本
# 将源码目录的最新版本同步到 ~/.cursor/skills/.codeman/，并更新各项目的规范
# 用法：bash /path/to/codeman/update.sh
#
# 保护策略：
#   - Skills / rules / templates 全量覆盖（框架内置，以源码为准）
#   - 各项目 .codeman/docs/ 中的实际文档不会被触碰
#   - 各项目 .codeman/rules/proj-*.mdc（用户自定义规范）不会被覆盖

set -e

CODEMAN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.cursor/skills/.codeman"
CURSOR_RULES_DIR="${HOME}/.cursor/rules"
BOOTSTRAP_FILE="${CURSOR_RULES_DIR}/codeman-bootstrap.mdc"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.3 框架升级${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─────────────────────────────────────────
# Step 1: 检查是否已安装
# ─────────────────────────────────────────
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}未检测到已安装的 CodeMan（${INSTALL_DIR} 不存在）。${NC}"
    echo "请先运行 install.sh 完成初次安装："
    echo "  bash ${CODEMAN_SRC}/install.sh"
    exit 1
fi

echo "源码目录：${CODEMAN_SRC}"
echo "安装目录：${INSTALL_DIR}"
echo ""

# ─────────────────────────────────────────
# Step 2: 将最新源码同步到安装目录
# ─────────────────────────────────────────
echo -e "${GREEN}Step 1: 同步框架文件到安装目录...${NC}"

rsync -a --delete \
    --exclude='.git' \
    --exclude='*.bak' \
    "${CODEMAN_SRC}/" "${INSTALL_DIR}/"

echo "  ✅ Skills、rules、templates 已全量更新"

# ─────────────────────────────────────────
# Step 3: 更新全局 bootstrap rule
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}Step 2: 更新全局 bootstrap rule...${NC}"

mkdir -p "${CURSOR_RULES_DIR}"

cat > "${BOOTSTRAP_FILE}" << 'BOOTSTRAP_EOF'
---
description: "CodeMan 工作流框架。当用户提到 CodeMan、开始开发、初始化、新需求、继续、修复、状态等关键词时自动加载。"
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

echo "  ✅ codeman-bootstrap.mdc 已更新"

# ─────────────────────────────────────────
# Step 4: 验证关键文件
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}Step 3: 验证关键文件...${NC}"

ALL_OK=true
SKILLS=("orchestrator" "requirements" "design" "development" "testing" "review" "fix" "deploy" "evolve")

for skill in "${SKILLS[@]}"; do
    skill_path="${INSTALL_DIR}/skills/${skill}/SKILL.md"
    if [ -f "$skill_path" ]; then
        echo -e "  ${GREEN}✅ skills/${skill}${NC}"
    else
        echo -e "  ${RED}❌ skills/${skill}（文件缺失）${NC}"
        ALL_OK=false
    fi
done

# ─────────────────────────────────────────
# 完成
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  框架升级完成！${NC}"
else
    echo -e "${RED}  升级过程中有文件缺失，请检查上方输出。${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}说明：${NC}"
echo "  - ~/.cursor/skills/.codeman/ 已同步最新框架"
echo "  - 各项目 .codeman/docs/ 中的文档未被触碰"
echo "  - 各项目 proj-*.mdc 自定义规范未被覆盖"
echo "  - 重启 Cursor 让变更生效"
echo ""
