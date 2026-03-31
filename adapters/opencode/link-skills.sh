#!/usr/bin/env bash
# 将 CodeMan 各 Skill 链接到 opencode 原生 skills 路径
# opencode 搜索路径：.opencode/skills/<name>/SKILL.md
# 用法：bash link-skills.sh <CodeMan 安装目录> [PROJECT_DIR]

set -e

INSTALL_DIR="${1:?用法: bash link-skills.sh <CodeMan 安装目录> [PROJECT_DIR]}"
PROJECT_DIR="${2:-$(pwd)}"
DEST="${PROJECT_DIR}/.opencode/skills"

mkdir -p "$DEST"

# 格式：skill名:源码子目录名
# opencode 要求 name 为小写字母+单连字符，目录名须与 SKILL.md frontmatter 的 name 一致
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
    skill_name="${entry%%:*}"
    folder="${entry#*:}"
    src="${INSTALL_DIR}/skills/${folder}"
    if [ ! -f "${src}/SKILL.md" ]; then
        echo "错误：缺少 ${src}/SKILL.md" >&2
        exit 1
    fi
    ln -sfn "${src}" "${DEST}/${skill_name}"
done

echo "  已建立 ${#LINKS[@]} 个符号链接：${DEST}/codeman-* → ${INSTALL_DIR}/skills/*"
