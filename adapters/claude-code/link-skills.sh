#!/usr/bin/env bash
# 将 CodeMan 各 Skill 以 Claude Code 要求的名称链接到 ~/.claude/skills/<name>/
# 官方要求：目录名须与 SKILL.md frontmatter 中的 name 一致，否则 /name 斜杠命令无法解析。
# 用法：bash link-skills.sh <CodeMan 安装目录，如 ~/.claude/skills/.codeman>

set -e

INSTALL_DIR="${1:?用法: bash link-skills.sh <CodeMan 安装目录>}"
DEST="${HOME}/.claude/skills"

mkdir -p "$DEST"

# 格式：斜杠命令名:源码子目录名
declare -a LINKS=(
    "codeman-orchestrator:orchestrator"
    "codeman-requirements:requirements"
    "codeman-design:design"
    "codeman-development:development"
    "codeman-testing:testing"
    "codeman-review:review"
    "codeman-fix:fix"
    "codeman-deploy:deploy"
    "codeman-evolve:evolve"
)

for entry in "${LINKS[@]}"; do
    slash_name="${entry%%:*}"
    folder="${entry#*:}"
    src="${INSTALL_DIR}/skills/${folder}"
    if [ ! -f "${src}/SKILL.md" ]; then
        echo "错误：缺少 ${src}/SKILL.md" >&2
        exit 1
    fi
    ln -sfn "${src}" "${DEST}/${slash_name}"
done

echo "  已建立 ${#LINKS[@]} 个符号链接：${DEST}/codeman-* → ${INSTALL_DIR}/skills/*"
