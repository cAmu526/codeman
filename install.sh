#!/usr/bin/env bash
# CodeMan 安装脚本
# 用法：bash /path/to/codeman/install.sh
# 自动检测 Cursor / Claude Code / OpenCode 环境，安装到对应目录

set -e

# ─────────────────────────────────────────
# 远程安装检测（curl -fsSL ... | bash）
# ─────────────────────────────────────────
CODEMAN_REPO="https://github.com/cAmu526/codeman.git"
CODEMAN_REMOTE_DIR="${HOME}/.codeman"

if [ ! -f "${BASH_SOURCE[0]}" ] 2>/dev/null; then
    echo "检测到远程安装模式..."

    if [ -d "${CODEMAN_REMOTE_DIR}/.git" ]; then
        echo "已有本地源码，正在拉取最新版本..."
        git -C "${CODEMAN_REMOTE_DIR}" pull --quiet
    else
        echo "正在克隆 CodeMan 源码..."
        git clone --quiet "${CODEMAN_REPO}" "${CODEMAN_REMOTE_DIR}"
    fi

    # 检测已安装的 IDE
    INSTALLED=""
    [ -d "${HOME}/.cursor/skills/.codeman/skills" ] && INSTALLED="${INSTALLED} Cursor"
    [ -d "${HOME}/.claude/skills/.codeman/skills" ] && INSTALLED="${INSTALLED} Claude_Code"
    [ -d "${HOME}/.trae/skills/.codeman/skills" ] && INSTALLED="${INSTALLED} Trae"

    if [ -n "$INSTALLED" ]; then
        echo ""
        echo "检测到以下 IDE 已安装 CodeMan："
        for ide in $INSTALLED; do
            echo "  - ${ide//_/ }"
        done
        echo ""
        echo "选择操作："
        echo "  1) 升级全部已安装环境（推荐）"
        echo "  2) 重新进入完整安装流程"
        read -p "请输入选项 [1/2，默认 1]: " choice </dev/tty
        if [ "$choice" = "2" ]; then
            exec bash "${CODEMAN_REMOTE_DIR}/install.sh" "$@" </dev/tty
        else
            exec bash "${CODEMAN_REMOTE_DIR}/update.sh" "$@"
        fi
    else
        exec bash "${CODEMAN_REMOTE_DIR}/install.sh" "$@" </dev/tty
    fi
fi

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
OPENCODE_INSTALL_DIR="${HOME}/.claude/skills/.codeman"
TRAE_INSTALL_DIR="${HOME}/.trae/skills/.codeman"
CURSOR_RULES_DIR="${HOME}/.cursor/rules"
CLAUDE_DIR="${HOME}/.claude"
OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
TRAE_RULES_DIR="${HOME}/.trae/rules"

HAS_CURSOR=false
HAS_CLAUDE=false
HAS_OPENCODE=false
HAS_TRAE=false

# 检测 Cursor：存在 ~/.cursor/ 目录
[ -d "${HOME}/.cursor" ] && HAS_CURSOR=true

# 检测 Claude Code：存在 ~/.claude/ 目录，或 claude 命令可用
if [ -d "${HOME}/.claude" ] || command -v claude &>/dev/null 2>&1; then
    HAS_CLAUDE=true
fi

# 检测 OpenCode：opencode 命令可用，或存在 ~/.config/opencode/ 目录
if command -v opencode &>/dev/null 2>&1 || [ -d "${HOME}/.config/opencode" ]; then
    HAS_OPENCODE=true
fi

# 检测 Trae：存在 ~/.trae/ 目录
[ -d "${HOME}/.trae" ] && HAS_TRAE=true

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v1.0 安装${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─────────────────────────────────────────
# 基础环境检测（缺失则阻断）
# ─────────────────────────────────────────
echo -e "${GREEN}基础环境检测：${NC}"
MISSING_DEPS=false

if command -v git &>/dev/null; then
    echo -e "  ${GREEN}✅ git（$(git --version | head -1)）${NC}"
else
    echo -e "  ${RED}❌ git — 未安装${NC}"
    echo "     CodeMan 依赖 git 进行版本控制（分支、commit、diff）"
    echo "     安装方式：brew install git（macOS）/ apt install git（Linux）"
    MISSING_DEPS=true
fi

if command -v node &>/dev/null; then
    echo -e "  ${GREEN}✅ Node.js（$(node --version)）${NC}"
else
    echo -e "  ${RED}❌ Node.js — 未安装${NC}"
    echo "     CodeMan 的测试和编码阶段依赖 Node.js 运行环境"
    echo "     安装方式：brew install node（macOS）/ 参考 https://nodejs.org/"
    MISSING_DEPS=true
fi

if command -v npm &>/dev/null; then
    echo -e "  ${GREEN}✅ npm（$(npm --version)）${NC}"
else
    if [ "$MISSING_DEPS" = false ]; then
        # Node.js 装了但 npm 没有，不太常见
        echo -e "  ${YELLOW}⚠️  npm — 未找到（通常随 Node.js 一起安装）${NC}"
    fi
fi
echo ""

if [ "$MISSING_DEPS" = true ]; then
    echo -e "${RED}基础环境不满足，请先安装缺失的依赖后重新运行 install.sh${NC}"
    exit 1
fi

echo "检测到的 AI IDE："
[ "$HAS_CURSOR" = true ] && echo -e "  ${GREEN}✅ Cursor${NC}" || echo -e "  ⬜ Cursor（未检测到 ~/.cursor/）"
[ "$HAS_CLAUDE" = true ] && echo -e "  ${GREEN}✅ Claude Code${NC}" || echo -e "  ⬜ Claude Code（未检测到 ~/.claude/ 或 claude 命令）"
[ "$HAS_OPENCODE" = true ] && echo -e "  ${GREEN}✅ OpenCode${NC}" || echo -e "  ⬜ OpenCode（未检测到 opencode 命令）"
[ "$HAS_TRAE" = true ] && echo -e "  ${GREEN}✅ Trae${NC}" || echo -e "  ⬜ Trae（未检测到 ~/.trae/）"
echo ""

# 统计检测到的环境数量
ENV_COUNT=0
[ "$HAS_CURSOR" = true ] && ENV_COUNT=$((ENV_COUNT + 1))
[ "$HAS_CLAUDE" = true ] && ENV_COUNT=$((ENV_COUNT + 1))
[ "$HAS_OPENCODE" = true ] && ENV_COUNT=$((ENV_COUNT + 1))
[ "$HAS_TRAE" = true ] && ENV_COUNT=$((ENV_COUNT + 1))

# 如果都未检测到，询问用户
if [ "$ENV_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}未自动检测到任何 AI IDE 环境。${NC}"
    echo "请选择安装目标："
    echo "  1) Cursor"
    echo "  2) Claude Code"
    echo "  3) OpenCode"
    echo "  4) Trae"
    echo "  5) 全部安装"
    read -p "请输入选项 [1/2/3/4/5]: " ENV_CHOICE
    case "$ENV_CHOICE" in
        1) HAS_CURSOR=true ;;
        2) HAS_CLAUDE=true ;;
        3) HAS_OPENCODE=true ;;
        4) HAS_TRAE=true ;;
        5) HAS_CURSOR=true; HAS_CLAUDE=true; HAS_OPENCODE=true; HAS_TRAE=true ;;
        *) echo "无效选项，退出。"; exit 1 ;;
    esac
fi

# 如果检测到多个环境，询问用户
if [ "$ENV_COUNT" -gt 1 ]; then
    echo "检测到多个环境，请选择安装目标："
    echo "  1) 仅 Cursor"
    echo "  2) 仅 Claude Code"
    echo "  3) 仅 OpenCode"
    echo "  4) 仅 Trae"
    echo "  5) 全部安装（推荐）"
    read -p "请输入选项 [1/2/3/4/5，默认 5]: " ENV_CHOICE
    case "$ENV_CHOICE" in
        1) HAS_CLAUDE=false; HAS_OPENCODE=false; HAS_TRAE=false ;;
        2) HAS_CURSOR=false; HAS_OPENCODE=false; HAS_TRAE=false ;;
        3) HAS_CURSOR=false; HAS_CLAUDE=false; HAS_TRAE=false ;;
        4) HAS_CURSOR=false; HAS_CLAUDE=false; HAS_OPENCODE=false ;;
        5|"") ;;
        *) echo "无效选项，退出。"; exit 1 ;;
    esac
fi

# ─────────────────────────────────────────
# 检查是否已安装（覆盖确认）
# ─────────────────────────────────────────
NEED_CONFIRM=false
[ "$HAS_CURSOR" = true ] && [ -d "$CURSOR_INSTALL_DIR" ] && NEED_CONFIRM=true
[ "$HAS_CLAUDE" = true ] && [ -d "$CLAUDE_INSTALL_DIR" ] && NEED_CONFIRM=true
[ "$HAS_TRAE" = true ] && [ -d "$TRAE_INSTALL_DIR" ] && NEED_CONFIRM=true

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

你已安装 CodeMan v1.0 全流程开发工作流框架。

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
- `CodeMan 添加规则：[描述]` — 创建项目级编码规范（生成 .codeman/rules/proj-*.mdc 并同步到 IDE）
- `CodeMan 升级` — 升级 CodeMan 框架并更新当前项目配置

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

    # Claude Code：skill 须在 ~/.claude/skills/<name>/ 且 <name> 与 SKILL.md 的 name 一致，否则 /codeman-orchestrator 报 Unknown skill
    echo -e "${GREEN}[Claude Code] Step 1b: 链接 ~/.claude/skills/codeman-*（斜杠命令）...${NC}"
    bash "${CODEMAN_SRC}/adapters/claude-code/link-skills.sh" "${CLAUDE_INSTALL_DIR}"

    echo -e "${GREEN}[Claude Code] Step 2: 生成全局 CLAUDE.md bootstrap 片段...${NC}"
    mkdir -p "${CLAUDE_DIR}"
    CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"

    # 生成 CodeMan 片段内容
    CODEMAN_BLOCK="<!-- CODEMAN START -->
# CodeMan 已安装

你已安装 CodeMan v1.0 全流程开发工作流框架。

## 核心规则

当用户说以下任意命令时，你必须立即读取并执行 orchestrator Skill：

\`\`\`
Read ~/.claude/skills/.codeman/skills/orchestrator/SKILL.md
\`\`\`

**触发命令列表（只有以下命令，不要编造其他命令）：**
- \`CodeMan 初始化\` — 在当前项目初始化 CodeMan（新项目或旧项目接入）
- \`CodeMan 开始开发\` — 启动完整开发流程
- \`CodeMan 新需求：[描述]\` — 版本迭代
- \`CodeMan 继续\` — 断点续做
- \`CodeMan 修复：[描述]\` — 轻量修复
- \`CodeMan 状态\` — 查看当前进度
- \`CodeMan 概览\` — 生成/更新项目概览文档（面向新成员）
- \`CodeMan 同步\` — 同步文档（同事改了代码后补全缺失文档）
- \`CodeMan 迭代：[内容]\` — 批量迭代（混合新功能 + Bug 修复 + 优化，自动分类排序）
- \`CodeMan 添加规则：[描述]\` — 创建项目级编码规范（生成 .codeman/rules/proj-*.mdc 并同步到 IDE）
- \`CodeMan 升级\` — 升级 CodeMan 框架并更新当前项目配置

## 阶段衔接规则（重要）

CodeMan 的工作流是分阶段执行的。**每个 Skill 完成后，必须按该 Skill 文件末尾"完成后"章节的指示操作**：

1. 向用户展示完成摘要和下一步提示
2. 用户确认后，通过 \`Read {Skill路径}\` 加载并执行下一个 Skill
3. **严禁**在阶段完成后自行总结然后停下来等用户输入命令
4. **严禁**编造不存在的命令（如 \"CodeMan 开始测试\"、\"CodeMan 进入编码\" 等）
5. 如果不确定下一步是什么，说 \`CodeMan 继续\` 让 orchestrator 根据 STATUS.md 判断

## Skills 路径

框架源文件在 \`~/.claude/skills/.codeman/skills/\`。Claude Code 的斜杠命令要求 \`~/.claude/skills/<name>/\` 与 SKILL.md 里 \`name\` 一致；安装/升级脚本已创建 \`~/.claude/skills/codeman-*\` 符号链接，请用下方命令调用：

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
- 每个 Skill 执行过程中必须严格遵循其 SKILL.md 的所有步骤，包括更新 STATUS.md
<!-- CODEMAN END -->"

    if [ -f "$CLAUDE_MD" ]; then
        # 检查是否已有 CodeMan 片段
        if grep -q "<!-- CODEMAN START -->" "$CLAUDE_MD" 2>/dev/null; then
            # 替换已有片段（用 Python 处理多行替换，更可靠）
            python3 - "$CLAUDE_MD" "$CODEMAN_BLOCK" << 'PYEOF'
import sys, re
filepath = sys.argv[1]
new_block = sys.argv[2]
with open(filepath, 'r') as f:
    content = f.read()
new_content = re.sub(
    r'<!-- CODEMAN START -->.*?<!-- CODEMAN END -->',
    lambda m: new_block,
    content,
    flags=re.DOTALL
)
with open(filepath, 'w') as f:
    f.write(new_content)
print('  已更新 CLAUDE.md 中的 CodeMan 片段')
PYEOF
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
# 安装到 OpenCode
# ─────────────────────────────────────────
if [ "$HAS_OPENCODE" = true ]; then
    echo -e "${GREEN}[OpenCode] Step 1: 安装框架到 ${OPENCODE_INSTALL_DIR}...${NC}"
    mkdir -p "${OPENCODE_INSTALL_DIR}"
    rsync -a --exclude='.git' --exclude='*.bak' "${CODEMAN_SRC}/" "${OPENCODE_INSTALL_DIR}/"
    echo "  已安装到：${OPENCODE_INSTALL_DIR}"

    # OpenCode 通过 Claude Code 兼容层读取 ~/.claude/skills/<name>/SKILL.md
    # 确保符号链接已创建
    echo -e "${GREEN}[OpenCode] Step 1b: 链接 ~/.claude/skills/codeman-*（skills）...${NC}"
    bash "${CODEMAN_SRC}/adapters/claude-code/link-skills.sh" "${OPENCODE_INSTALL_DIR}"

    # 生成全局 AGENTS.md bootstrap 片段
    # OpenCode 优先读取 ~/.config/opencode/AGENTS.md，其次 ~/.claude/CLAUDE.md
    echo -e "${GREEN}[OpenCode] Step 2: 生成全局 AGENTS.md bootstrap 片段...${NC}"
    mkdir -p "${OPENCODE_CONFIG_DIR}"
    AGENTS_MD="${OPENCODE_CONFIG_DIR}/AGENTS.md"

    CODEMAN_BLOCK_OPENCODE='<!-- CODEMAN START -->
# CodeMan 已安装

你已安装 CodeMan v1.0 全流程开发工作流框架。

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
- `CodeMan 添加规则：[描述]` — 创建项目级编码规范（生成 .codeman/rules/proj-*.mdc 并同步到 IDE）
- `CodeMan 升级` — 升级 CodeMan 框架并更新当前项目配置

## 阶段衔接规则（重要）

CodeMan 的工作流是分阶段执行的。**每个 Skill 完成后，必须按该 Skill 文件末尾"完成后"章节的指示操作**：

1. 向用户展示完成摘要和下一步提示
2. 用户确认后，通过 `Read {Skill路径}` 加载并执行下一个 Skill
3. **严禁**在阶段完成后自行总结然后停下来等用户输入命令
4. **严禁**编造不存在的命令（如"CodeMan 开始测试"、"CodeMan 进入编码"等）
5. 如果不确定下一步是什么，说 `CodeMan 继续` 让 orchestrator 根据 STATUS.md 判断

## Skills 路径

OpenCode 通过 Claude Code 兼容层读取 `~/.claude/skills/<name>/SKILL.md`。安装脚本已创建 `~/.claude/skills/codeman-*` 符号链接。

| Skill | 名称 |
|-------|------|
| orchestrator（入口） | codeman-orchestrator |
| requirements | codeman-requirements |
| design | codeman-design |
| development | codeman-development |
| testing | codeman-testing |
| review | codeman-review |
| fix | codeman-fix |
| deploy | codeman-deploy |
| evolve | codeman-evolve |

## 重要说明

- orchestrator 是唯一入口，所有场景都从它开始
- 不要直接调用其他 Skill，由 orchestrator 按流程调度
- 项目文档存放在项目的 `.codeman/docs/` 目录，跟着项目走
- 每个 Skill 执行过程中必须严格遵循其 SKILL.md 的所有步骤，包括更新 STATUS.md
<!-- CODEMAN END -->'

    if [ -f "$AGENTS_MD" ]; then
        if grep -q "<!-- CODEMAN START -->" "$AGENTS_MD" 2>/dev/null; then
            python3 - "$AGENTS_MD" "$CODEMAN_BLOCK_OPENCODE" << 'PYEOF'
import sys, re
filepath = sys.argv[1]
new_block = sys.argv[2]
with open(filepath, 'r') as f:
    content = f.read()
new_content = re.sub(
    r'<!-- CODEMAN START -->.*?<!-- CODEMAN END -->',
    lambda m: new_block,
    content,
    flags=re.DOTALL
)
with open(filepath, 'w') as f:
    f.write(new_content)
print('  已更新 AGENTS.md 中的 CodeMan 片段')
PYEOF
        else
            echo "" >> "$AGENTS_MD"
            echo "$CODEMAN_BLOCK_OPENCODE" >> "$AGENTS_MD"
            echo "  已追加 CodeMan 片段到 ${AGENTS_MD}"
        fi
    else
        echo "$CODEMAN_BLOCK_OPENCODE" > "$AGENTS_MD"
        echo "  已创建 ${AGENTS_MD}"
    fi

    echo ""
fi

# ─────────────────────────────────────────
# 安装到 Trae
# ─────────────────────────────────────────
if [ "$HAS_TRAE" = true ]; then
    echo -e "${GREEN}[Trae] Step 1: 安装框架到 ${TRAE_INSTALL_DIR}...${NC}"
    mkdir -p "${TRAE_INSTALL_DIR}"
    rsync -a --exclude='.git' --exclude='*.bak' "${CODEMAN_SRC}/" "${TRAE_INSTALL_DIR}/"
    echo "  已安装到：${TRAE_INSTALL_DIR}"

    # Trae：skill 位于 ~/.trae/skills/<name>/，自动发现
    echo -e "${GREEN}[Trae] Step 1b: 链接 ~/.trae/skills/codeman-*...${NC}"
    bash "${CODEMAN_SRC}/adapters/trae/link-skills.sh" "${TRAE_INSTALL_DIR}"

    echo -e "${GREEN}[Trae] Step 2: 生成全局 bootstrap rule...${NC}"
    mkdir -p "${TRAE_RULES_DIR}"
    TRAE_BOOTSTRAP="${TRAE_RULES_DIR}/codeman-bootstrap.md"

    cat > "${TRAE_BOOTSTRAP}" << 'BOOTSTRAP_EOF'
---
description: "CodeMan 工作流框架。当用户提到 CodeMan、开始开发、初始化、新需求、继续、修复、状态、概览等关键词时自动加载。"
alwaysApply: true
---

# CodeMan 已安装

你已安装 CodeMan v1.0 全流程开发工作流框架。

## 核心规则

当用户说以下任意命令时，你必须立即读取并执行 orchestrator Skill：

```
Read ~/.trae/skills/.codeman/skills/orchestrator/SKILL.md
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
- `CodeMan 添加规则：[描述]` — 创建项目级编码规范（生成 .codeman/rules/proj-*.mdc 并同步到 IDE）
- `CodeMan 升级` — 升级 CodeMan 框架并更新当前项目配置

## 阶段衔接规则（重要）

CodeMan 的工作流是分阶段执行的。**每个 Skill 完成后，必须按该 Skill 文件末尾"完成后"章节的指示操作**：

1. 向用户展示完成摘要和下一步提示
2. 用户确认后，通过 `Read {Skill路径}` 加载并执行下一个 Skill
3. **严禁**在阶段完成后自行总结然后停下来等用户输入命令
4. **严禁**编造不存在的命令（如"CodeMan 开始测试"、"CodeMan 进入编码"等）
5. 如果不确定下一步是什么，说 `CodeMan 继续` 让 orchestrator 根据 STATUS.md 判断

## Skills 路径

所有 Skills 位于 `~/.trae/skills/.codeman/skills/`：

| Skill | 路径 |
|-------|------|
| orchestrator（入口） | `~/.trae/skills/.codeman/skills/orchestrator/SKILL.md` |
| requirements | `~/.trae/skills/.codeman/skills/requirements/SKILL.md` |
| design | `~/.trae/skills/.codeman/skills/design/SKILL.md` |
| development | `~/.trae/skills/.codeman/skills/development/SKILL.md` |
| testing | `~/.trae/skills/.codeman/skills/testing/SKILL.md` |
| review | `~/.trae/skills/.codeman/skills/review/SKILL.md` |
| fix | `~/.trae/skills/.codeman/skills/fix/SKILL.md` |
| deploy | `~/.trae/skills/.codeman/skills/deploy/SKILL.md` |
| evolve | `~/.trae/skills/.codeman/skills/evolve/SKILL.md` |

## 重要说明

- orchestrator 是唯一入口，所有场景都从它开始
- 不要直接调用其他 Skill，由 orchestrator 按流程调度
- 项目文档存放在项目的 `.codeman/docs/` 目录，跟着项目走
- 每个 Skill 执行过程中必须严格遵循其 SKILL.md 的所有步骤，包括更新 STATUS.md
BOOTSTRAP_EOF

    echo "  已生成：${TRAE_BOOTSTRAP}"
    echo ""
fi

# ─────────────────────────────────────────
# 第三方 Skills（可选）
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  第三方 Skills（可选）${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "CodeMan 支持挂载第三方 Skills 增强工作流。"
echo "以下是推荐的 Skills（安装后可在项目中按需启用）："
echo ""
echo "  1) superpowers       — 协作式头脑风暴 + 子代理派遣开发（含 2 个 Skills）"
echo -e "     ${BLUE}https://github.com/obra/superpowers${NC}"
echo "  2) wireframe         — HTML 线框图生成（5 套 UX 方案）"
echo -e "     ${BLUE}https://github.com/Magdoub/claude-wireframe-skill${NC}"
echo "  3) ui-design-brain   — 60+ UI 组件最佳实践规则库"
echo -e "     ${BLUE}https://github.com/carmahhawwari/ui-design-brain${NC}"
echo ""
echo "请选择："
echo "  a) 全部安装（推荐）"
echo "  b) 选择安装（输入编号，如 1,3）"
echo "  c) 跳过"
echo "  d) 自定义（输入 GitHub 仓库 URL）"
echo ""
read -p "请输入选项 [a/b/c/d，默认 a]: " EXT_CHOICE
EXT_CHOICE="${EXT_CHOICE:-a}"

# 推荐 Skills 定义：name|url|skill_path|suggested_hook|suggested_output|description
RECOMMENDED_1="superpowers|https://github.com/obra/superpowers|skills/brainstorming/SKILL.md|requirements.before_step1|docs/superpowers/specs/|协作式头脑风暴 + 浏览器可视化 mockup"
RECOMMENDED_2="wireframe|https://github.com/Magdoub/claude-wireframe-skill|SKILL.md|requirements.after_step5|wireframe/|HTML 线框图生成（5 套 UX 方案）"
RECOMMENDED_3="ui-design-brain|https://github.com/carmahhawwari/ui-design-brain|SKILL.md|development.before_step1||60+ UI 组件最佳实践规则库"

# 安装单个第三方 Skill 到所有已选 IDE
install_ext_skill() {
    local name="$1" url="$2"
    echo -e "  ${GREEN}正在克隆 ${name}...${NC}"
    local tmp_dir="/tmp/codeman-ext-${name}"
    rm -rf "$tmp_dir"
    if ! git clone --depth 1 "$url" "$tmp_dir" 2>/dev/null; then
        echo -e "  ${RED}❌ 克隆失败：${url}${NC}"
        return 1
    fi
    if [ "$HAS_CURSOR" = true ]; then
        rm -rf "${HOME}/.cursor/skills/${name}"
        cp -r "$tmp_dir" "${HOME}/.cursor/skills/${name}"
    fi
    if [ "$HAS_CLAUDE" = true ]; then
        rm -rf "${HOME}/.claude/skills/${name}"
        cp -r "$tmp_dir" "${HOME}/.claude/skills/${name}"
    fi
    if [ "$HAS_OPENCODE" = true ]; then
        rm -rf "${HOME}/.claude/skills/${name}"
        cp -r "$tmp_dir" "${HOME}/.claude/skills/${name}"
    fi
    if [ "$HAS_TRAE" = true ]; then
        rm -rf "${HOME}/.trae/skills/${name}"
        cp -r "$tmp_dir" "${HOME}/.trae/skills/${name}"
    fi
    rm -rf "$tmp_dir"
    echo -e "  ${GREEN}✅ ${name} 已安装${NC}"
    return 0
}

# 收集要安装的 Skills
EXT_INSTALL_LIST=()

case "$EXT_CHOICE" in
    a|A)
        EXT_INSTALL_LIST=("$RECOMMENDED_1" "$RECOMMENDED_2" "$RECOMMENDED_3")
        ;;
    b|B)
        read -p "请输入要安装的编号（逗号分隔，如 1,3）: " EXT_NUMS
        for num in $(echo "$EXT_NUMS" | tr ',' ' '); do
            case "$num" in
                1) EXT_INSTALL_LIST+=("$RECOMMENDED_1") ;;
                2) EXT_INSTALL_LIST+=("$RECOMMENDED_2") ;;
                3) EXT_INSTALL_LIST+=("$RECOMMENDED_3") ;;
                *) echo -e "  ${YELLOW}跳过无效编号：${num}${NC}" ;;
            esac
        done
        ;;
    d|D)
        # 自定义安装循环
        while true; do
            echo ""
            read -p "请输入 GitHub 仓库 URL（输入空行结束）: " CUSTOM_URL
            [ -z "$CUSTOM_URL" ] && break

            echo -e "  ${GREEN}正在克隆...${NC}"
            CUSTOM_TMP="/tmp/codeman-ext-custom"
            rm -rf "$CUSTOM_TMP"
            if ! git clone --depth 1 "$CUSTOM_URL" "$CUSTOM_TMP" 2>/dev/null; then
                echo -e "  ${RED}❌ 克隆失败，请检查 URL${NC}"
                continue
            fi

            # 检测 SKILL.md
            echo "  检测 SKILL.md 文件..."
            SKILL_FILES=$(find "$CUSTOM_TMP" -name "SKILL.md" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)
            if [ -z "$SKILL_FILES" ]; then
                echo -e "  ${RED}❌ 未找到 SKILL.md 文件，跳过${NC}"
                rm -rf "$CUSTOM_TMP"
                continue
            fi
            echo "  找到以下 SKILL.md："
            SKILL_INDEX=0
            SKILL_PATHS=()
            while IFS= read -r sf; do
                SKILL_INDEX=$((SKILL_INDEX + 1))
                REL_PATH="${sf#$CUSTOM_TMP/}"
                SKILL_PATHS+=("$REL_PATH")
                # 读取 description
                DESC=$(grep -A1 "^description:" "$sf" 2>/dev/null | head -1 | sed 's/^description: *"*//;s/"*$//')
                echo "    ${SKILL_INDEX}) ${REL_PATH}"
                [ -n "$DESC" ] && echo "       ${DESC}"
            done <<< "$SKILL_FILES"

            if [ "$SKILL_INDEX" -gt 1 ]; then
                read -p "  选择要使用的 SKILL.md [1-${SKILL_INDEX}，默认 1]: " SKILL_PICK
                SKILL_PICK="${SKILL_PICK:-1}"
            else
                SKILL_PICK=1
            fi
            CHOSEN_SKILL_PATH="${SKILL_PATHS[$((SKILL_PICK - 1))]}"

            read -p "  请为这个 Skill 命名（用于目录名）: " CUSTOM_NAME
            if [ -z "$CUSTOM_NAME" ]; then
                echo -e "  ${YELLOW}名称不能为空，跳过${NC}"
                rm -rf "$CUSTOM_TMP"
                continue
            fi

            echo ""
            echo "  你想在哪个阶段使用它？"
            echo "    1) requirements（需求分析）"
            echo "    2) design（技术方案）"
            echo "    3) development（开发实现）"
            echo "    4) testing（测试验证）"
            echo "    5) review（Review）"
            echo "    6) fix（修复闭环）"
            echo "    7) deploy（部署清单）"
            read -p "  请输入编号 [1-7]: " PHASE_NUM
            case "$PHASE_NUM" in
                1) CUSTOM_PHASE="requirements" ;;
                2) CUSTOM_PHASE="design" ;;
                3) CUSTOM_PHASE="development" ;;
                4) CUSTOM_PHASE="testing" ;;
                5) CUSTOM_PHASE="review" ;;
                6) CUSTOM_PHASE="fix" ;;
                7) CUSTOM_PHASE="deploy" ;;
                *) CUSTOM_PHASE="requirements" ;;
            esac

            echo "  在该阶段的什么时机？"
            echo "    1) before_step1（阶段开始前）"
            echo "    2) after_step{N}（某步之后）"
            read -p "  请选择 [默认 1]: " TIMING_CHOICE
            TIMING_CHOICE="${TIMING_CHOICE:-1}"
            if [ "$TIMING_CHOICE" = "2" ]; then
                read -p "  在第几步之后？请输入步骤号: " STEP_NUM
                CUSTOM_HOOK="${CUSTOM_PHASE}.after_step${STEP_NUM}"
            else
                CUSTOM_HOOK="${CUSTOM_PHASE}.before_step1"
            fi

            read -p "  它的产出目录（相对项目根目录，如 docs/specs/，无则留空）: " CUSTOM_OUTPUT

            # 读取 description
            CUSTOM_DESC=$(grep -A1 "^description:" "$CUSTOM_TMP/$CHOSEN_SKILL_PATH" 2>/dev/null | head -1 | sed 's/^description: *"*//;s/"*$//')
            [ -z "$CUSTOM_DESC" ] && CUSTOM_DESC="自定义第三方 Skill"

            EXT_INSTALL_LIST+=("${CUSTOM_NAME}|${CUSTOM_URL}|${CHOSEN_SKILL_PATH}|${CUSTOM_HOOK}|${CUSTOM_OUTPUT}|${CUSTOM_DESC}")
            rm -rf "$CUSTOM_TMP"
            echo -e "  ${GREEN}✅ 已添加 ${CUSTOM_NAME}${NC}"

            read -p "  继续添加？[y/N]: " ADD_MORE
            [[ ! "$ADD_MORE" =~ ^[Yy]$ ]] && break
        done
        ;;
    c|C|*)
        echo -e "  ${YELLOW}跳过第三方 Skills 安装${NC}"
        ;;
esac

# 执行安装并生成注册表
EXT_REGISTRY="[]"
if [ ${#EXT_INSTALL_LIST[@]} -gt 0 ]; then
    echo ""
    echo -e "${GREEN}安装第三方 Skills...${NC}"
    REGISTRY_ENTRIES=""
    for entry in "${EXT_INSTALL_LIST[@]}"; do
        IFS='|' read -r ext_name ext_url ext_skill ext_hook ext_output ext_desc <<< "$entry"
        if install_ext_skill "$ext_name" "$ext_url"; then
            # 构建 JSON 条目
            [ -n "$REGISTRY_ENTRIES" ] && REGISTRY_ENTRIES="${REGISTRY_ENTRIES},"
            REGISTRY_ENTRIES="${REGISTRY_ENTRIES}
  {
    \"name\": \"${ext_name}\",
    \"source\": \"${ext_url}\",
    \"skill_path\": \"${ext_skill}\",
    \"suggested_hook\": \"${ext_hook}\",
    \"suggested_output\": \"${ext_output}\",
    \"description\": \"${ext_desc}\"
  }"
        fi
    done

    # superpowers 包含多个 Skills，自动追加 subagent-driven-development
    if echo "$REGISTRY_ENTRIES" | grep -q '"superpowers"'; then
        REGISTRY_ENTRIES="${REGISTRY_ENTRIES},
  {
    \"name\": \"superpowers\",
    \"source\": \"https://github.com/obra/superpowers\",
    \"skill_path\": \"skills/subagent-driven-development/SKILL.md\",
    \"suggested_hook\": \"development.execution\",
    \"suggested_output\": \"\",
    \"description\": \"Superpowers 逐任务子代理派遣 + 两阶段 Review\"
  }"
        echo -e "  ${GREEN}✅ superpowers 已自动注册 brainstorming + subagent-driven-development${NC}"
    fi

    if [ -n "$REGISTRY_ENTRIES" ]; then
        EXT_REGISTRY="[${REGISTRY_ENTRIES}
]"
        # 写入注册表到各 IDE 的 .codeman 目录
        if [ "$HAS_CURSOR" = true ]; then
            echo "$EXT_REGISTRY" > "${CURSOR_INSTALL_DIR}/external-skills-registry.json"
        fi
        if [ "$HAS_CLAUDE" = true ] || [ "$HAS_OPENCODE" = true ]; then
            echo "$EXT_REGISTRY" > "${CLAUDE_INSTALL_DIR}/external-skills-registry.json"
        fi
        if [ "$HAS_TRAE" = true ]; then
            echo "$EXT_REGISTRY" > "${TRAE_INSTALL_DIR}/external-skills-registry.json"
        fi
        echo ""
        echo -e "  ${GREEN}✅ 注册表已写入 external-skills-registry.json${NC}"
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
    if [ -f "${HOME}/.claude/skills/codeman-orchestrator/SKILL.md" ]; then
        echo -e "    ${GREEN}✅ ~/.claude/skills/codeman-*（斜杠命令链接）${NC}"
    else
        echo -e "    ${RED}❌ ~/.claude/skills/codeman-*（斜杠命令链接缺失，请重新运行 install.sh）${NC}"
        ALL_OK=false
    fi
    CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ] && grep -q "CODEMAN START" "$CLAUDE_MD" 2>/dev/null; then
        echo -e "    ${GREEN}✅ ~/.claude/CLAUDE.md（CodeMan 片段已注入）${NC}"
    else
        echo -e "    ${RED}❌ ~/.claude/CLAUDE.md（CodeMan 片段缺失）${NC}"
        ALL_OK=false
    fi
fi

if [ "$HAS_OPENCODE" = true ]; then
    echo "  [OpenCode]"
    for skill in "${SKILLS[@]}"; do
        skill_path="${OPENCODE_INSTALL_DIR}/skills/${skill}/SKILL.md"
        if [ -f "$skill_path" ]; then
            echo -e "    ${GREEN}✅ ${skill}${NC}"
        else
            echo -e "    ${RED}❌ ${skill}（文件缺失）${NC}"
            ALL_OK=false
        fi
    done
    if [ -f "${HOME}/.claude/skills/codeman-orchestrator/SKILL.md" ]; then
        echo -e "    ${GREEN}✅ ~/.claude/skills/codeman-*（skills 链接）${NC}"
    else
        echo -e "    ${RED}❌ ~/.claude/skills/codeman-*（skills 链接缺失）${NC}"
        ALL_OK=false
    fi
    OPENCODE_AGENTS="${OPENCODE_CONFIG_DIR}/AGENTS.md"
    if [ -f "$OPENCODE_AGENTS" ] && grep -q "CODEMAN START" "$OPENCODE_AGENTS" 2>/dev/null; then
        echo -e "    ${GREEN}✅ ~/.config/opencode/AGENTS.md（CodeMan 片段已注入）${NC}"
    else
        echo -e "    ${RED}❌ ~/.config/opencode/AGENTS.md（CodeMan 片段缺失）${NC}"
        ALL_OK=false
    fi
fi

if [ "$HAS_TRAE" = true ]; then
    echo "  [Trae]"
    for skill in "${SKILLS[@]}"; do
        skill_path="${TRAE_INSTALL_DIR}/skills/${skill}/SKILL.md"
        if [ -f "$skill_path" ]; then
            echo -e "    ${GREEN}✅ ${skill}${NC}"
        else
            echo -e "    ${RED}❌ ${skill}（文件缺失）${NC}"
            ALL_OK=false
        fi
    done
    if [ -f "${HOME}/.trae/skills/codeman-orchestrator/SKILL.md" ]; then
        echo -e "    ${GREEN}✅ ~/.trae/skills/codeman-*（skills 链接）${NC}"
    else
        echo -e "    ${RED}❌ ~/.trae/skills/codeman-*（skills 链接缺失）${NC}"
        ALL_OK=false
    fi
    TRAE_BOOTSTRAP="${TRAE_RULES_DIR}/codeman-bootstrap.md"
    if [ -f "$TRAE_BOOTSTRAP" ]; then
        echo -e "    ${GREEN}✅ codeman-bootstrap.md（alwaysApply）${NC}"
    else
        echo -e "    ${RED}❌ codeman-bootstrap.md（生成失败）${NC}"
        ALL_OK=false
    fi
fi

# ─────────────────────────────────────────
# 记录源码路径，供 CodeMan 升级命令使用
# ─────────────────────────────────────────
[ "$HAS_CURSOR" = true ] && echo "${CODEMAN_SRC}" > "${CURSOR_INSTALL_DIR}/.source-path"
[ "$HAS_CLAUDE" = true ] && echo "${CODEMAN_SRC}" > "${CLAUDE_INSTALL_DIR}/.source-path"
[ "$HAS_TRAE" = true ] && echo "${CODEMAN_SRC}" > "${TRAE_INSTALL_DIR}/.source-path"

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
    if [ "$HAS_OPENCODE" = true ]; then
        echo -e "${YELLOW}[OpenCode] 下一步：${NC}"
        echo "  1. 打开任意项目目录，在 OpenCode 中说："
        echo "     CodeMan 初始化"
        echo ""
    fi
    if [ "$HAS_TRAE" = true ]; then
        echo -e "${YELLOW}[Trae] 下一步：${NC}"
        echo "  1. 打开任意项目，在 Trae 的 AI 对话中说："
        echo "     CodeMan 初始化"
        echo ""
    fi
    echo "  CodeMan 会自动识别是新项目还是旧项目，并完成初始化。"
    echo ""
    echo -e "${BLUE}升级方式：${NC}"
    echo "  方式 1（推荐）：在项目中说 CodeMan 升级（升级框架 + 升级项目配置）"
    echo "  方式 2：curl -fsSL https://raw.githubusercontent.com/cAmu526/codeman/main/install.sh | bash（仅升级框架）"
else
    echo -e "${RED}  安装过程中有错误，请检查上方输出。${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
echo ""
