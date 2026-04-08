#!/usr/bin/env bash
# 将 CodeMan 各 Skill 链接到 ~/.trae/skills/<name>/
# Trae 自动发现 .trae/skills/ 下的 SKILL.md 文件
# 用法：bash link-skills.sh <CodeMan 安装目录，如 ~/.trae/skills/.codeman>

set -e

INSTALL_DIR="${1:?用法: bash link-skills.sh <CodeMan 安装目录>}"
DEST="${HOME}/.trae/skills"

mkdir -p "$DEST"

# 格式：Skill名:源码子目录名
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
