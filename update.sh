#!/usr/bin/env bash
# CodeMan v0.9.1 框架升级脚本
# 将源码目录的最新版本同步到安装目录，同时支持 Cursor 和 Claude Code
# 用法：bash /path/to/codeman/update.sh
#
# 保护策略：
#   - Skills / rules / templates 全量覆盖（框架内置，以源码为准）
#   - 各项目 .codeman/docs/ 中的实际文档不会被触碰
#   - 各项目 .codeman/rules/proj-*.mdc（用户自定义规范）不会被覆盖

set -e

CODEMAN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURSOR_INSTALL_DIR="${HOME}/.cursor/skills/.codeman"
CURSOR_RULES_DIR="${HOME}/.cursor/rules"
CURSOR_BOOTSTRAP="${CURSOR_RULES_DIR}/codeman-bootstrap.mdc"

CLAUDE_INSTALL_DIR="${HOME}/.claude/skills/.codeman"
CLAUDE_DIR="${HOME}/.claude"
CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.9.1 框架升级${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─────────────────────────────────────────
# 检测已安装的环境
# ─────────────────────────────────────────
HAS_CURSOR=false
HAS_CLAUDE=false

[ -d "$CURSOR_INSTALL_DIR" ] && HAS_CURSOR=true
[ -d "$CLAUDE_INSTALL_DIR" ] && HAS_CLAUDE=true

if [ "$HAS_CURSOR" = false ] && [ "$HAS_CLAUDE" = false ]; then
    echo -e "${YELLOW}未检测到已安装的 CodeMan。${NC}"
    echo "请先运行 install.sh 完成初次安装："
    echo "  bash ${CODEMAN_SRC}/install.sh"
    exit 1
fi

echo "源码目录：${CODEMAN_SRC}"
[ "$HAS_CURSOR" = true ] && echo "Cursor 安装目录：${CURSOR_INSTALL_DIR}"
[ "$HAS_CLAUDE" = true ] && echo "Claude Code 安装目录：${CLAUDE_INSTALL_DIR}"
echo ""

# ─────────────────────────────────────────
# Step 1: 同步框架文件
# ─────────────────────────────────────────
echo -e "${GREEN}Step 1: 同步框架文件到安装目录...${NC}"

if [ "$HAS_CURSOR" = true ]; then
    rsync -a --delete \
        --exclude='.git' \
        --exclude='*.bak' \
        "${CODEMAN_SRC}/" "${CURSOR_INSTALL_DIR}/"
    echo "  ✅ [Cursor] Skills、rules、templates 已全量更新"
fi

if [ "$HAS_CLAUDE" = true ]; then
    rsync -a --delete \
        --exclude='.git' \
        --exclude='*.bak' \
        "${CODEMAN_SRC}/" "${CLAUDE_INSTALL_DIR}/"
    echo "  ✅ [Claude Code] Skills、rules、templates 已全量更新"
    bash "${CODEMAN_SRC}/adapters/claude-code/link-skills.sh" "${CLAUDE_INSTALL_DIR}"
fi

# ─────────────────────────────────────────
# Step 2: 更新 Bootstrap
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}Step 2: 更新 Bootstrap...${NC}"

if [ "$HAS_CURSOR" = true ]; then
    mkdir -p "${CURSOR_RULES_DIR}"
    cat > "${CURSOR_BOOTSTRAP}" << 'BOOTSTRAP_EOF'
---
description: "CodeMan 工作流框架。当用户提到 CodeMan、开始开发、初始化、新需求、继续、修复、状态、概览等关键词时自动加载。"
alwaysApply: true
---

# CodeMan 已安装

你已安装 CodeMan v0.9.1 全流程开发工作流框架。

## 核心规则

当用户说以下任意命令时，你必须立即读取并执行 orchestrator Skill：

```
Read ~/.cursor/skills/.codeman/skills/orchestrator/SKILL.md
```

**触发命令列表（只有以下命令，不要编造其他命令）：**
- `CodeMan 初始化` — 在当前项目初始化 CodeMan（新项目或旧项目接入）
- `CodeMan 开始开发` — 启动完整开发流程
- `CodeMan 新需求：[描述]` — 版本迭代
- `CodeMan 继续` — 断点续做
- `CodeMan 修复：[描述]` — 轻量修复
- `CodeMan 状态` — 查看当前进度
- `CodeMan 概览` — 生成/更新项目概览文档（面向新成员）
- `CodeMan 同步` — 同步文档（同事改了代码后补全缺失文档）
- `CodeMan 迭代：[内容]` — 批量迭代（混合新功能 + Bug 修复 + 优化，自动分类排序）

## 阶段衔接规则（重要）

CodeMan 的工作流是分阶段执行的。**每个 Skill 完成后，必须按该 Skill 文件末尾"完成后"章节的指示操作**：

1. 向用户展示完成摘要和下一步提示
2. 用户确认后，通过 `Read {Skill路径}` 加载并执行下一个 Skill
3. **严禁**在阶段完成后自行总结然后停下来等用户输入命令
4. **严禁**编造不存在的命令（如"CodeMan 开始测试"、"CodeMan 进入编码"等）
5. 如果不确定下一步是什么，说 `CodeMan 继续` 让 orchestrator 根据 STATUS.md 判断

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
- 每个 Skill 执行过程中必须严格遵循其 SKILL.md 的所有步骤，包括更新 STATUS.md
BOOTSTRAP_EOF
    echo "  ✅ [Cursor] codeman-bootstrap.mdc 已更新"
fi

if [ "$HAS_CLAUDE" = true ]; then
    # 更新 CLAUDE.md 中的 CodeMan 片段
    CODEMAN_BLOCK='<!-- CODEMAN START -->
# CodeMan 已安装

你已安装 CodeMan v0.9.1 全流程开发工作流框架。

## 核心规则

当用户说以下任意命令时，你必须立即读取并执行 orchestrator Skill：

```
Read ~/.claude/skills/.codeman/skills/orchestrator/SKILL.md
```

**触发命令列表（只有以下命令，不要编造其他命令）：**
- `CodeMan 初始化` — 在当前项目初始化 CodeMan（新项目或旧项目接入）
- `CodeMan 开始开发` — 启动完整开发流程
- `CodeMan 新需求：[描述]` — 版本迭代
- `CodeMan 继续` — 断点续做
- `CodeMan 修复：[描述]` — 轻量修复
- `CodeMan 状态` — 查看当前进度
- `CodeMan 概览` — 生成/更新项目概览文档（面向新成员）
- `CodeMan 同步` — 同步文档（同事改了代码后补全缺失文档）
- `CodeMan 迭代：[内容]` — 批量迭代（混合新功能 + Bug 修复 + 优化，自动分类排序）

## Skills 路径

框架源文件在 `~/.claude/skills/.codeman/skills/`。Claude Code 的斜杠命令要求 `~/.claude/skills/<name>/` 与 SKILL.md 里 `name` 一致；安装/升级脚本已创建 `~/.claude/skills/codeman-*` 符号链接，请用下方命令调用：

| Skill | 斜杠命令 |
|-------|---------|
| orchestrator（入口） | `/codeman-orchestrator` |
| requirements | `/codeman-requirements` |
| design | `/codeman-design` |
| development | `/codeman-development` |
| testing | `/codeman-testing` |
| review | `/codeman-review` |
| fix | `/codeman-fix` |
| deploy | `/codeman-deploy` |
| evolve | `/codeman-evolve` |

## 重要说明

- orchestrator 是唯一入口，所有场景都从它开始
- 不要直接调用其他 Skill，由 orchestrator 按流程调度
- 项目文档存放在项目的 `.codeman/docs/` 目录，跟着项目走
- 每个 Skill 执行过程中必须严格遵循其 SKILL.md 的所有步骤，包括更新 STATUS.md
<!-- CODEMAN END -->'

    if [ -f "$CLAUDE_MD" ] && grep -q "<!-- CODEMAN START -->" "$CLAUDE_MD" 2>/dev/null; then
        python3 -c "
import re
content = open('${CLAUDE_MD}').read()
block = '''${CODEMAN_BLOCK}'''
new_content = re.sub(r'<!-- CODEMAN START -->.*?<!-- CODEMAN END -->', block, content, flags=re.DOTALL)
open('${CLAUDE_MD}', 'w').write(new_content)
"
        echo "  ✅ [Claude Code] ~/.claude/CLAUDE.md 已更新"
    elif [ -f "$CLAUDE_MD" ]; then
        echo "" >> "$CLAUDE_MD"
        echo "$CODEMAN_BLOCK" >> "$CLAUDE_MD"
        echo "  ✅ [Claude Code] 已追加 CodeMan 片段到 ~/.claude/CLAUDE.md"
    else
        mkdir -p "${CLAUDE_DIR}"
        echo "$CODEMAN_BLOCK" > "$CLAUDE_MD"
        echo "  ✅ [Claude Code] 已创建 ~/.claude/CLAUDE.md"
    fi
fi

# ─────────────────────────────────────────
# Step 3: 验证关键文件
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}Step 3: 验证关键文件...${NC}"

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
    if [ -f "${HOME}/.claude/skills/codeman-orchestrator/SKILL.md" ]; then
        echo -e "    ${GREEN}✅ ~/.claude/skills/codeman-*（斜杠命令链接）${NC}"
    else
        echo -e "    ${RED}❌ ~/.claude/skills/codeman-*（斜杠命令链接缺失）${NC}"
        ALL_OK=false
    fi
fi

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
[ "$HAS_CURSOR" = true ] && echo "  - ~/.cursor/skills/.codeman/ 已同步最新框架"
[ "$HAS_CLAUDE" = true ] && echo "  - ~/.claude/skills/.codeman/ 已同步最新框架"
echo "  - 各项目 .codeman/docs/ 中的文档未被触碰"
echo "  - 各项目 proj-*.mdc 自定义规范未被覆盖"
[ "$HAS_CURSOR" = true ] && echo "  - 重启 Cursor 让变更生效"
echo ""
