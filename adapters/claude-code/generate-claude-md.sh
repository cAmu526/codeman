#!/usr/bin/env bash
# 生成/更新项目级 .claude/CLAUDE.md 中的 CodeMan 片段（Claude Code 适配）
# 用法：bash generate-claude-md.sh [PROJECT_DIR] [CODEMAN_DIR]

set -e

PROJECT_DIR="${1:-$(pwd)}"
CODEMAN_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLAUDE_DIR="${PROJECT_DIR}/.claude"
CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"

mkdir -p "${CLAUDE_DIR}"

# 读取项目配置（如果存在）
PROJECT_NAME="本项目"
if [ -f "${PROJECT_DIR}/.codeman/config.yaml" ]; then
    _name=$(grep "^  name:" "${PROJECT_DIR}/.codeman/config.yaml" 2>/dev/null | head -1 | sed 's/.*name: *//' | tr -d '"')
    [ -n "$_name" ] && PROJECT_NAME="$_name"
fi

# 构建 CodeMan 片段
CODEMAN_BLOCK='<!-- CODEMAN START -->
# CodeMan 工作流框架

'"${PROJECT_NAME}"' 已接入 CodeMan v0.3 全流程开发工作流框架。

## 核心规则

当用户说以下任意命令时，你必须立即读取并执行 orchestrator Skill：

```
Read ~/.claude/skills/.codeman/skills/orchestrator/SKILL.md
```

**触发命令列表：**
- `CodeMan 初始化` — 在当前项目初始化 CodeMan（新项目或旧项目接入）
- `CodeMan 开始开发` — 启动完整开发流程
- `CodeMan 新需求：[描述]` — 版本迭代
- `CodeMan 继续` — 断点续做
- `CodeMan 修复：[描述]` — 轻量修复
- `CodeMan 状态` — 查看当前进度
- `CodeMan 概览` — 生成/更新项目概览文档（面向新成员）

## 项目文档体系

项目文档存放在 `.codeman/docs/` 目录：
- `STATUS.md` — 当前工作流阶段和功能点进度
- `DIRECTIVES.md` — 关键指令和约束（每个 Skill 执行前必读）
- `prd/` — 需求文档碎片
- `design/` — 技术方案碎片
- `api/` — API 文档碎片
- `tests/` — 测试文档碎片
- `reviews/` — Review 报告
- `deploy/` — 部署清单

## 重要说明

- orchestrator 是唯一入口，所有场景都从它开始
- 不要直接调用其他 Skill，由 orchestrator 按流程调度
- 每次执行 Skill 前必须先读取 `.codeman/docs/DIRECTIVES.md`
<!-- CODEMAN END -->'

if [ -f "$CLAUDE_MD" ]; then
    if grep -q "<!-- CODEMAN START -->" "$CLAUDE_MD" 2>/dev/null; then
        # 替换已有片段
        python3 - "$CLAUDE_MD" "$CODEMAN_BLOCK" << 'PYEOF'
import sys, re

filepath = sys.argv[1]
new_block = sys.argv[2]

with open(filepath, 'r') as f:
    content = f.read()

new_content = re.sub(
    r'<!-- CODEMAN START -->.*?<!-- CODEMAN END -->',
    new_block,
    content,
    flags=re.DOTALL
)

with open(filepath, 'w') as f:
    f.write(new_content)

print(f'  已更新 {filepath} 中的 CodeMan 片段')
PYEOF
    else
        # 追加到文件末尾
        {
            echo ""
            echo "$CODEMAN_BLOCK"
        } >> "$CLAUDE_MD"
        echo -e "${GREEN}  已追加 CodeMan 片段到 ${CLAUDE_MD}${NC}"
    fi
else
    # 创建新文件
    echo "$CODEMAN_BLOCK" > "$CLAUDE_MD"
    echo -e "${GREEN}  已创建 ${CLAUDE_MD}${NC}"
fi

echo -e "${YELLOW}  Claude Code 将在每次会话开始时自动加载此文件${NC}"
