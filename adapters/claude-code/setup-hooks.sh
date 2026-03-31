#!/usr/bin/env bash
# 配置 Claude Code Hooks（可选）
# 在 .claude/settings.json 中注册 CodeMan 质量门禁 hooks
# 用法：bash setup-hooks.sh [PROJECT_DIR]
#
# 支持的 hooks：
#   - PostToolUse(Write/Edit): 代码写入后自动运行 lint（如配置了 lint 命令）
#   - Stop: 会话结束前提示更新 STATUS.md

set -e

PROJECT_DIR="${1:-$(pwd)}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLAUDE_DIR="${PROJECT_DIR}/.claude"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

mkdir -p "${CLAUDE_DIR}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude Code Hooks 配置（可选）${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "可配置以下 hooks 增强 CodeMan 工作流："
echo ""
echo "  1) lint-on-write  — 代码写入后自动运行 lint 检查"
echo "  2) status-reminder — 会话结束前提示同步 STATUS.md"
echo "  3) 两者都配置"
echo "  4) 跳过（不配置 hooks）"
echo ""
read -p "请选择 [1/2/3/4，默认 4]: " HOOK_CHOICE

if [ "${HOOK_CHOICE:-4}" = "4" ]; then
    echo "已跳过 hooks 配置。"
    exit 0
fi

# 检测 lint 命令
LINT_CMD=""
if [ "${HOOK_CHOICE}" = "1" ] || [ "${HOOK_CHOICE}" = "3" ]; then
    echo ""
    echo "请输入 lint 命令（例如：npm run lint 或 eslint src/）："
    echo "留空则跳过 lint hook"
    read -p "lint 命令: " LINT_CMD
fi

# 生成 hooks 配置
python3 - "$SETTINGS_FILE" "$HOOK_CHOICE" "$LINT_CMD" << 'PYEOF'
import sys, json, os

settings_file = sys.argv[1]
hook_choice = sys.argv[2]
lint_cmd = sys.argv[3] if len(sys.argv) > 3 else ""

# 读取已有配置
if os.path.exists(settings_file):
    with open(settings_file, 'r') as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            settings = {}
else:
    settings = {}

if 'hooks' not in settings:
    settings['hooks'] = {}

# 配置 lint hook
if hook_choice in ('1', '3') and lint_cmd:
    settings['hooks']['PostToolUse'] = settings['hooks'].get('PostToolUse', [])
    lint_hook = {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
            {
                "type": "command",
                "command": lint_cmd + " 2>&1 || true"
            }
        ]
    }
    # 移除已有的 lint hook（避免重复）
    settings['hooks']['PostToolUse'] = [
        h for h in settings['hooks']['PostToolUse']
        if not any('lint' in str(cmd.get('command', '')) for cmd in h.get('hooks', []))
    ]
    settings['hooks']['PostToolUse'].append(lint_hook)
    print(f"  已配置 lint hook: {lint_cmd}")

# 配置 status reminder hook
if hook_choice in ('2', '3'):
    settings['hooks']['Stop'] = settings['hooks'].get('Stop', [])
    status_hook = {
        "hooks": [
            {
                "type": "prompt",
                "prompt": "如果本次会话修改了代码，请检查 .codeman/docs/STATUS.md 是否需要更新。如果需要，请更新后再结束。"
            }
        ]
    }
    # 移除已有的 status hook（避免重复）
    settings['hooks']['Stop'] = [
        h for h in settings['hooks']['Stop']
        if not any('STATUS.md' in str(hk.get('prompt', '')) for hk in h.get('hooks', []))
    ]
    settings['hooks']['Stop'].append(status_hook)
    print("  已配置 STATUS.md 提醒 hook")

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print(f"  配置已写入 {settings_file}")
PYEOF

echo ""
echo -e "${GREEN}Hooks 配置完成！${NC}"
echo -e "${YELLOW}说明：${NC}"
echo "  - hooks 在每次 Claude Code 会话中自动生效"
echo "  - 如需修改，直接编辑 ${SETTINGS_FILE}"
echo ""
