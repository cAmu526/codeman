#!/usr/bin/env bash
# 输出 Cursor Agent Skills 注册指引
# Cursor 目前不支持通过脚本自动注册 Skills，需要手动操作
# 用法：bash register-skills.sh [CODEMAN_DIR]

CODEMAN_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Cursor Skills 注册指引${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}请在 Cursor 中手动注册以下 Skills：${NC}"
echo ""
echo "操作步骤："
echo "  1. 打开 Cursor Settings（Cmd+,）"
echo "  2. 找到 Agent → Skills"
echo "  3. 点击 '+ Add Skill'"
echo "  4. 逐一添加以下路径："
echo ""

SKILLS=(
    "orchestrator:主编排入口（必须注册）"
    "requirements:需求分析"
    "design:技术方案"
    "development:开发实现"
    "testing:测试验证"
    "review:自动 Review"
    "fix:修复闭环"
    "deploy:部署清单"
    "evolve:自进化引擎"
)

for skill_info in "${SKILLS[@]}"; do
    skill_name="${skill_info%%:*}"
    skill_desc="${skill_info##*:}"
    skill_path="${CODEMAN_DIR}/skills/${skill_name}/SKILL.md"
    echo -e "  ${GREEN}${skill_desc}${NC}"
    echo "  路径：${skill_path}"
    echo ""
done

echo -e "${YELLOW}注意：orchestrator Skill 是入口，必须注册。其他 Skill 建议全部注册。${NC}"
echo ""

# 检查 Skills 文件是否存在
echo "检查 Skills 文件..."
ALL_OK=true
for skill_info in "${SKILLS[@]}"; do
    skill_name="${skill_info%%:*}"
    skill_path="${CODEMAN_DIR}/skills/${skill_name}/SKILL.md"
    if [ -f "$skill_path" ]; then
        echo -e "  ${GREEN}✅ ${skill_name}${NC}"
    else
        echo -e "  ❌ ${skill_name}（文件不存在：${skill_path}）"
        ALL_OK=false
    fi
done

echo ""
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}所有 Skills 文件就绪，可以注册。${NC}"
else
    echo -e "${YELLOW}部分 Skills 文件缺失，请检查 CodeMan 安装是否完整。${NC}"
fi
echo ""
