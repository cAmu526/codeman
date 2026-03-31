#!/usr/bin/env bash
# 同步 CodeMan Rules 到 .claude/rules/（Claude Code 适配）
# 将 .codeman/rules/*.mdc 转换为 Claude Code 的 .md 格式并同步
# 用法：bash sync-rules.sh [PROJECT_DIR]

set -e

PROJECT_DIR="${1:-$(pwd)}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CODEMAN_RULES_DIR="${PROJECT_DIR}/.codeman/rules"
CLAUDE_RULES_DIR="${PROJECT_DIR}/.claude/rules"

# 检查源目录
if [ ! -d "$CODEMAN_RULES_DIR" ]; then
    echo "  .codeman/rules/ 不存在，跳过 Claude Code rules 同步"
    exit 0
fi

# 创建 .claude/rules/ 目录
mkdir -p "${CLAUDE_RULES_DIR}"

SYNCED=0

for mdc_file in "${CODEMAN_RULES_DIR}/"*.mdc; do
    [ -f "$mdc_file" ] || continue

    filename=$(basename "$mdc_file" .mdc)
    target="${CLAUDE_RULES_DIR}/codeman-${filename}.md"

    # 转换 .mdc -> .md：
    # 1. 保留 description 字段
    # 2. 将 globs 转换为 paths（Claude Code 使用 paths 字段）
    # 3. 移除 alwaysApply（Claude Code 通过 CLAUDE.md 实现全局生效）
    python3 - "$mdc_file" "$target" << 'PYEOF'
import sys, re

src = sys.argv[1]
dst = sys.argv[2]

with open(src, 'r') as f:
    content = f.read()

# 处理 YAML frontmatter
if content.startswith('---'):
    end_idx = content.index('---', 3)
    frontmatter = content[3:end_idx].strip()
    body = content[end_idx+3:].strip()

    lines = frontmatter.split('\n')
    new_lines = []
    for line in lines:
        if line.startswith('alwaysApply:'):
            # 移除 alwaysApply，Claude Code 通过 CLAUDE.md 全局生效
            continue
        elif line.startswith('globs:'):
            # 将 globs 转换为 paths（Claude Code 路径匹配字段）
            new_lines.append(line.replace('globs:', 'paths:', 1))
        else:
            new_lines.append(line)

    new_frontmatter = '\n'.join(new_lines)
    result = f'---\n{new_frontmatter}\n---\n\n{body}\n'
else:
    result = content

with open(dst, 'w') as f:
    f.write(result)
PYEOF

    SYNCED=$((SYNCED + 1))
done

echo -e "${GREEN}  [Claude Code] 已同步 ${SYNCED} 个规范文件到 .claude/rules/${NC}"
if [ "$SYNCED" -gt 0 ]; then
    echo -e "${YELLOW}  注意：.claude/rules/ 中的规范在 Claude Code 中按 paths 匹配自动加载${NC}"
fi
