#!/usr/bin/env bash
# 同步 CodeMan Rules 到 opencode 的 instructions 引用（OpenCode 适配）
# 通过生成/更新项目级 opencode.json，将 .codeman/rules/*.mdc 加入 instructions 字段
# 用法：bash sync-rules.sh [PROJECT_DIR]

set -e

PROJECT_DIR="${1:-$(pwd)}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CODEMAN_RULES_DIR="${PROJECT_DIR}/.codeman/rules"
OPENCODE_CONFIG="${PROJECT_DIR}/opencode.json"

# 检查源目录
if [ ! -d "$CODEMAN_RULES_DIR" ]; then
    echo "  .codeman/rules/ 不存在，跳过 opencode rules 同步"
    exit 0
fi

# 收集所有 .mdc 规则文件路径（使用 glob 模式）
RULES_GLOB=".codeman/rules/*.mdc"

if [ -f "$OPENCODE_CONFIG" ]; then
    # 已有 opencode.json，用 python 安全更新
    python3 - "$OPENCODE_CONFIG" "$RULES_GLOB" << 'PYEOF'
import sys, json

config_path = sys.argv[1]
rules_glob = sys.argv[2]

with open(config_path, 'r') as f:
    content = f.read()

# 先尝试直接解析（标准 JSON），失败再安全移除 JSONC 注释
try:
    config = json.loads(content)
except json.JSONDecodeError:
    # 状态机方式移除注释，跳过字符串内的 // 和 /* */
    result = []
    i = 0
    in_string = False
    while i < len(content):
        c = content[i]
        if in_string:
            result.append(c)
            if c == '\\' and i + 1 < len(content):
                i += 1
                result.append(content[i])
            elif c == '"':
                in_string = False
        elif c == '"':
            in_string = True
            result.append(c)
        elif c == '/' and i + 1 < len(content):
            if content[i + 1] == '/':
                # 行注释：跳到行尾
                i += 2
                while i < len(content) and content[i] != '\n':
                    i += 1
                continue
            elif content[i + 1] == '*':
                # 块注释：跳到 */
                i += 2
                while i + 1 < len(content) and not (content[i] == '*' and content[i + 1] == '/'):
                    i += 1
                i += 2
                continue
            else:
                result.append(c)
        else:
            result.append(c)
        i += 1
    config = json.loads(''.join(result))

if 'instructions' not in config:
    config['instructions'] = []

if rules_glob not in config['instructions']:
    config['instructions'].append(rules_glob)
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f'  已将 {rules_glob} 追加到 opencode.json instructions')
else:
    print(f'  opencode.json 已包含 {rules_glob}')
PYEOF
else
    # 创建新的 opencode.json
    cat > "$OPENCODE_CONFIG" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": ["${RULES_GLOB}"]
}
EOF
    echo -e "${GREEN}  已创建 opencode.json，包含 .codeman/rules 引用${NC}"
fi

SYNCED=$(ls "$CODEMAN_RULES_DIR"/*.mdc 2>/dev/null | wc -l | tr -d ' ')
echo -e "${GREEN}  [OpenCode] 已同步 ${SYNCED} 个规范文件引用到 opencode.json instructions${NC}"
if [ "$SYNCED" -gt 0 ]; then
    echo -e "${YELLOW}  注意：opencode 将按 instructions 中的 glob 模式自动加载规范${NC}"
fi
