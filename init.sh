#!/usr/bin/env bash
# CodeMan v0.3 初始化脚本
# 由 AI 通过 Shell 工具调用，或手动执行：bash ~/.cursor/skills/.codeman/init.sh
# 在目标项目根目录执行

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# CodeMan 框架固定安装路径（install.sh 安装后路径固定）
CODEMAN_DIR="${HOME}/.cursor/skills/.codeman"
# 如果安装路径不存在（开发调试时），回退到脚本所在目录
if [ ! -d "$CODEMAN_DIR" ]; then
    CODEMAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# 目标项目目录（执行脚本时的当前目录）
PROJECT_DIR="$(pwd)"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CodeMan v0.3 初始化${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "目标项目：${PROJECT_DIR}"
echo ""

# 检查是否已初始化
if [ -d "${PROJECT_DIR}/.codeman" ]; then
    echo -e "${YELLOW}警告：该项目已有 .codeman/ 目录。${NC}"
    read -p "是否重新初始化？这将覆盖现有配置（文档不会被删除）[y/N]: " REINIT
    if [[ ! "$REINIT" =~ ^[Yy]$ ]]; then
        echo "已取消。"
        exit 0
    fi
fi

# ─────────────────────────────────────────
# 自动检测技术栈
# ─────────────────────────────────────────
DETECTED_FE_FRAMEWORK=""
DETECTED_STYLING=""
DETECTED_UNIT_TEST=""
DETECTED_BE_LANG=""
DETECTED_BE_FRAMEWORK=""

detect_tech_stack() {
    echo -e "${CYAN}正在扫描项目特征文件...${NC}"

    # 检测 package.json
    if [ -f "${PROJECT_DIR}/package.json" ]; then
        local PKG
        PKG=$(cat "${PROJECT_DIR}/package.json")

        # 前端框架检测（优先级：next > react > vue）
        if echo "$PKG" | grep -q '"next"'; then
            DETECTED_FE_FRAMEWORK="nextjs"
        elif echo "$PKG" | grep -q '"react"'; then
            DETECTED_FE_FRAMEWORK="react"
        elif echo "$PKG" | grep -q '"vue"'; then
            DETECTED_FE_FRAMEWORK="vue"
        fi

        # 样式方案检测
        if echo "$PKG" | grep -q '"tailwindcss"'; then
            DETECTED_STYLING="tailwind"
        elif echo "$PKG" | grep -q '"styled-components"'; then
            DETECTED_STYLING="styled-components"
        fi

        # 前端测试框架检测
        if echo "$PKG" | grep -q '"vitest"'; then
            DETECTED_UNIT_TEST="vitest"
        elif echo "$PKG" | grep -q '"jest"'; then
            DETECTED_UNIT_TEST="jest"
        fi

        # 后端 Node.js 检测（有 express/koa/fastify 且无前端框架，或明确是后端项目）
        if echo "$PKG" | grep -qE '"express"|"koa"|"fastify"'; then
            DETECTED_BE_LANG="nodejs"
            DETECTED_BE_FRAMEWORK="express"
        fi
    fi

    # tailwind.config.* 文件检测（补充 package.json 未声明的情况）
    if [ -z "$DETECTED_STYLING" ] && ls "${PROJECT_DIR}"/tailwind.config.* 2>/dev/null | grep -q .; then
        DETECTED_STYLING="tailwind"
    fi

    # CSS Modules 检测（查找 *.module.css 文件）
    if [ -z "$DETECTED_STYLING" ] && find "${PROJECT_DIR}" -maxdepth 3 -name "*.module.css" 2>/dev/null | grep -q .; then
        DETECTED_STYLING="css-modules"
    fi

    # 辅助函数：在根目录和常见后端子目录中查找特征文件，返回找到的完整路径
    _find_be_file() {
        local filename="$1"
        local search_dirs=("." "server" "backend" "api" "app" "src")
        for dir in "${search_dirs[@]}"; do
            if [ -f "${PROJECT_DIR}/${dir}/${filename}" ]; then
                echo "${PROJECT_DIR}/${dir}/${filename}"
                return 0
            fi
        done
        return 1
    }

    # 辅助函数：将绝对路径转为相对于 PROJECT_DIR 的相对路径（用于摘要显示）
    _rel_path() {
        echo "${1#${PROJECT_DIR}/}"
    }

    # Go 检测（根目录 + 常见子目录）
    GO_MOD=$(_find_be_file "go.mod" || true)
    if [ -n "$GO_MOD" ]; then
        DETECTED_BE_LANG="go"
        DETECTED_BE_FILE="$(_rel_path "$GO_MOD")"
        if grep -q "gin-gonic/gin" "$GO_MOD" 2>/dev/null; then
            DETECTED_BE_FRAMEWORK="gin"
        elif grep -q "labstack/echo" "$GO_MOD" 2>/dev/null; then
            DETECTED_BE_FRAMEWORK="echo"
        else
            DETECTED_BE_FRAMEWORK="gin"
        fi
    fi

    # Python 检测（根目录 + 常见子目录）
    REQ_TXT=$(_find_be_file "requirements.txt" || true)
    PYPROJECT=$(_find_be_file "pyproject.toml" || true)
    if [ -n "$REQ_TXT" ] || [ -n "$PYPROJECT" ]; then
        DETECTED_BE_LANG="python"
        DETECTED_BE_FILE="$(_rel_path "${REQ_TXT:-$PYPROJECT}")"
        if grep -qi "fastapi" "${REQ_TXT:-/dev/null}" 2>/dev/null || \
           grep -qi "fastapi" "${PYPROJECT:-/dev/null}" 2>/dev/null; then
            DETECTED_BE_FRAMEWORK="fastapi"
        else
            DETECTED_BE_FRAMEWORK="python"
        fi
    fi

    # 打印检测摘要
    echo ""
    echo -e "${CYAN}┌─ 检测结果 ──────────────────────────────┐${NC}"
    if [ -n "$DETECTED_FE_FRAMEWORK" ]; then
        echo -e "${CYAN}│${NC}  前端框架：${GREEN}${DETECTED_FE_FRAMEWORK}${NC}"
    else
        echo -e "${CYAN}│${NC}  前端框架：未检测到"
    fi
    if [ -n "$DETECTED_STYLING" ]; then
        echo -e "${CYAN}│${NC}  样式方案：${GREEN}${DETECTED_STYLING}${NC}"
    else
        echo -e "${CYAN}│${NC}  样式方案：未检测到"
    fi
    if [ -n "$DETECTED_UNIT_TEST" ]; then
        echo -e "${CYAN}│${NC}  测试框架：${GREEN}${DETECTED_UNIT_TEST}${NC}"
    else
        echo -e "${CYAN}│${NC}  测试框架：未检测到"
    fi
    if [ -n "$DETECTED_BE_LANG" ]; then
        BE_DISPLAY="${DETECTED_BE_LANG}"
        [ -n "$DETECTED_BE_FRAMEWORK" ] && BE_DISPLAY="${BE_DISPLAY} (${DETECTED_BE_FRAMEWORK})"
        [ -n "$DETECTED_BE_FILE" ] && BE_DISPLAY="${BE_DISPLAY}  ← ${DETECTED_BE_FILE}"
        echo -e "${CYAN}│${NC}  后端语言：${GREEN}${BE_DISPLAY}${NC}"
    else
        echo -e "${CYAN}│${NC}  后端语言：未检测到"
    fi
    echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
    echo ""
}

detect_tech_stack

# 根据检测结果推断项目类型
DETECTED_PROJECT_TYPE=""
if [ -n "$DETECTED_FE_FRAMEWORK" ] && [ -n "$DETECTED_BE_LANG" ]; then
    DETECTED_PROJECT_TYPE="fullstack"
elif [ -n "$DETECTED_FE_FRAMEWORK" ]; then
    DETECTED_PROJECT_TYPE="frontend"
elif [ -n "$DETECTED_BE_LANG" ]; then
    DETECTED_PROJECT_TYPE="backend"
fi

# ─────────────────────────────────────────
# 一次性总览确认（检测到足够信息时）
# ─────────────────────────────────────────
DETECTED_PROJECT_NAME="$(basename "$PROJECT_DIR")"
ALL_CONFIRMED=false

_has_detection() {
    [ -n "$DETECTED_PROJECT_TYPE" ]
}

if _has_detection; then
    echo -e "${GREEN}检测到以下项目信息，请确认：${NC}"
    echo ""
    echo -e "  项目名称：${GREEN}${DETECTED_PROJECT_NAME}${NC}"

    case "$DETECTED_PROJECT_TYPE" in
        frontend)  echo -e "  项目类型：${GREEN}前端${NC}" ;;
        backend)   echo -e "  项目类型：${GREEN}后端${NC}" ;;
        fullstack) echo -e "  项目类型：${GREEN}全栈${NC}" ;;
    esac

    [ -n "$DETECTED_FE_FRAMEWORK" ] && echo -e "  前端框架：${GREEN}${DETECTED_FE_FRAMEWORK}${NC}"
    [ -n "$DETECTED_STYLING" ]      && echo -e "  样式方案：${GREEN}${DETECTED_STYLING}${NC}"
    [ -n "$DETECTED_UNIT_TEST" ]    && echo -e "  测试框架：${GREEN}${DETECTED_UNIT_TEST}${NC}"
    if [ -n "$DETECTED_BE_LANG" ]; then
        BE_DISPLAY="${DETECTED_BE_LANG}"
        [ -n "$DETECTED_BE_FRAMEWORK" ] && BE_DISPLAY="${BE_DISPLAY} (${DETECTED_BE_FRAMEWORK})"
        [ -n "$DETECTED_BE_FILE" ] && BE_DISPLAY="${BE_DISPLAY}  ← ${DETECTED_BE_FILE}"
        echo -e "  后端语言：${GREEN}${BE_DISPLAY}${NC}"
    fi

    echo ""
    read -p "以上信息是否正确？[Y/n/手动逐项配置]: " CONFIRM_ALL
    if [[ -z "$CONFIRM_ALL" || "$CONFIRM_ALL" =~ ^[Yy]$ ]]; then
        ALL_CONFIRMED=true
        PROJECT_NAME="$DETECTED_PROJECT_NAME"
        PROJECT_TYPE="$DETECTED_PROJECT_TYPE"
        echo -e "${GREEN}✓ 配置已确认${NC}"
        echo ""
    fi
fi

# ─────────────────────────────────────────
# Step 1: 项目名称（未一键确认时才问）
# ─────────────────────────────────────────
if [ "$ALL_CONFIRMED" = false ]; then
    echo -e "${GREEN}Step 1: 项目信息配置${NC}"
    echo ""
    read -p "项目名称 [${DETECTED_PROJECT_NAME}]: " PROJECT_NAME
    PROJECT_NAME="${PROJECT_NAME:-${DETECTED_PROJECT_NAME}}"
fi

# ─────────────────────────────────────────
# Step 2: 项目类型（未一键确认时才问）
# ─────────────────────────────────────────
if [ "$ALL_CONFIRMED" = false ]; then
    echo ""
    echo -e "${GREEN}Step 2: 项目类型${NC}"
    echo ""

    if [ -n "$DETECTED_PROJECT_TYPE" ]; then
        case "$DETECTED_PROJECT_TYPE" in
            frontend)  DETECTED_TYPE_LABEL="前端（纯前端项目）" ;;
            backend)   DETECTED_TYPE_LABEL="后端（纯后端项目）" ;;
            fullstack) DETECTED_TYPE_LABEL="全栈（前后端一体）" ;;
        esac
        echo -e "  已检测到：${GREEN}${DETECTED_TYPE_LABEL}${NC}"
        read -p "  确认使用此类型？[Y/n/手动]: " CONFIRM_TYPE
        if [[ -z "$CONFIRM_TYPE" || "$CONFIRM_TYPE" =~ ^[Yy]$ ]]; then
            PROJECT_TYPE="$DETECTED_PROJECT_TYPE"
            echo -e "  ${GREEN}✓ 使用检测结果：${PROJECT_TYPE}${NC}"
        else
            echo ""
            echo "  项目类型："
            echo "    1) 前端（纯前端项目）"
            echo "    2) 后端（纯后端项目）"
            echo "    3) 全栈（前后端一体）"
            read -p "  请选择 [1-3]: " PROJECT_TYPE_NUM
            case "$PROJECT_TYPE_NUM" in
                1) PROJECT_TYPE="frontend" ;;
                2) PROJECT_TYPE="backend" ;;
                3) PROJECT_TYPE="fullstack" ;;
                *) PROJECT_TYPE="fullstack" ;;
            esac
        fi
    else
        echo "  项目类型："
        echo "    1) 前端（纯前端项目）"
        echo "    2) 后端（纯后端项目）"
        echo "    3) 全栈（前后端一体）"
        read -p "  请选择 [1-3]: " PROJECT_TYPE_NUM
        case "$PROJECT_TYPE_NUM" in
            1) PROJECT_TYPE="frontend" ;;
            2) PROJECT_TYPE="backend" ;;
            3) PROJECT_TYPE="fullstack" ;;
            *) PROJECT_TYPE="fullstack" ;;
        esac
    fi
fi

# ─────────────────────────────────────────
# Step 3: 前端技术栈（自动推断 + 确认）
# ─────────────────────────────────────────
FRONTEND_FRAMEWORK="none"
FRONTEND_LANGUAGE="typescript"
FRONTEND_STYLING="none"
FRONTEND_RULES=()

_select_fe_framework_manual() {
    echo ""
    echo "  前端框架："
    echo "    1) React"
    echo "    2) Next.js"
    echo "    3) Vue"
    echo "    4) 其他/无"
    read -p "  请选择 [1-4]: " FE_FRAMEWORK_NUM
    case "$FE_FRAMEWORK_NUM" in
        1) FRONTEND_FRAMEWORK="react"; FRONTEND_RULES+=("react-component") ;;
        2) FRONTEND_FRAMEWORK="nextjs"; FRONTEND_RULES+=("react-component" "nextjs-routing") ;;
        3) FRONTEND_FRAMEWORK="vue" ;;
        *) FRONTEND_FRAMEWORK="none" ;;
    esac
}

_select_fe_styling_manual() {
    echo ""
    echo "  样式方案："
    echo "    1) Tailwind CSS"
    echo "    2) CSS Modules"
    echo "    3) styled-components"
    echo "    4) 其他"
    read -p "  请选择 [1-4]: " STYLING_NUM
    case "$STYLING_NUM" in
        1) FRONTEND_STYLING="tailwind" ;;
        2) FRONTEND_STYLING="css-modules" ;;
        3) FRONTEND_STYLING="styled-components" ;;
        *) FRONTEND_STYLING="other" ;;
    esac
}

_select_fe_test_manual() {
    echo ""
    echo "  前端测试框架："
    echo "    1) Vitest"
    echo "    2) Jest"
    echo "    3) 其他"
    read -p "  请选择 [1-3]: " FE_TEST_NUM
    case "$FE_TEST_NUM" in
        1) UNIT_TEST="vitest"; FRONTEND_RULES+=("vitest-testing") ;;
        2) UNIT_TEST="jest" ;;
        *) UNIT_TEST="other" ;;
    esac
}

if [[ "$PROJECT_TYPE" == "frontend" || "$PROJECT_TYPE" == "fullstack" ]]; then
    if [ "$ALL_CONFIRMED" = true ]; then
        # 一键确认时直接应用检测结果，无需再问
        FRONTEND_FRAMEWORK="${DETECTED_FE_FRAMEWORK:-none}"
        case "$DETECTED_FE_FRAMEWORK" in
            react)  FRONTEND_RULES+=("react-component") ;;
            nextjs) FRONTEND_RULES+=("react-component" "nextjs-routing") ;;
        esac
        FRONTEND_STYLING="${DETECTED_STYLING:-none}"
        UNIT_TEST="${DETECTED_UNIT_TEST:-other}"
        [ "$UNIT_TEST" = "vitest" ] && FRONTEND_RULES+=("vitest-testing")
    else
        echo ""
        echo -e "${GREEN}Step 3: 前端技术栈${NC}"
        echo ""

        HAS_FE_DETECTION=false
        [ -n "$DETECTED_FE_FRAMEWORK" ] && HAS_FE_DETECTION=true

        if [ "$HAS_FE_DETECTION" = true ]; then
            FE_SUMMARY="${DETECTED_FE_FRAMEWORK}"
            [ -n "$DETECTED_STYLING" ] && FE_SUMMARY="${FE_SUMMARY} + ${DETECTED_STYLING}"
            [ -n "$DETECTED_UNIT_TEST" ] && FE_SUMMARY="${FE_SUMMARY} + ${DETECTED_UNIT_TEST}"

            echo -e "  已检测到：${GREEN}${FE_SUMMARY}${NC}"
            read -p "  确认使用此配置？[Y/n/手动]: " CONFIRM_FE
            if [[ -z "$CONFIRM_FE" || "$CONFIRM_FE" =~ ^[Yy]$ ]]; then
                FRONTEND_FRAMEWORK="$DETECTED_FE_FRAMEWORK"
                case "$DETECTED_FE_FRAMEWORK" in
                    react)  FRONTEND_RULES+=("react-component") ;;
                    nextjs) FRONTEND_RULES+=("react-component" "nextjs-routing") ;;
                esac
                FRONTEND_STYLING="${DETECTED_STYLING:-none}"
                UNIT_TEST="${DETECTED_UNIT_TEST:-other}"
                [ "$UNIT_TEST" = "vitest" ] && FRONTEND_RULES+=("vitest-testing")
                echo -e "  ${GREEN}✓ 前端技术栈已确认${NC}"
            else
                _select_fe_framework_manual
                _select_fe_styling_manual
                _select_fe_test_manual
            fi
        else
            _select_fe_framework_manual
            _select_fe_styling_manual
            _select_fe_test_manual
        fi
    fi
fi

# ─────────────────────────────────────────
# Step 4: 后端技术栈（自动推断 + 确认）
# ─────────────────────────────────────────
BACKEND_LANGUAGE="none"
BACKEND_FRAMEWORK="none"
BACKEND_RULES=()

_select_be_manual() {
    echo ""
    echo "  后端语言/框架："
    echo "    1) Node.js + Express/Koa"
    echo "    2) Go"
    echo "    3) Python + FastAPI"
    echo "    4) 其他"
    read -p "  请选择 [1-4]: " BE_LANG_NUM
    case "$BE_LANG_NUM" in
        1) BACKEND_LANGUAGE="nodejs"; BACKEND_FRAMEWORK="express"; BACKEND_RULES+=("nodejs-express") ;;
        2) BACKEND_LANGUAGE="go"; BACKEND_FRAMEWORK="gin"; BACKEND_RULES+=("go-error-handling") ;;
        3) BACKEND_LANGUAGE="python"; BACKEND_FRAMEWORK="fastapi"; BACKEND_RULES+=("python-fastapi") ;;
        *) BACKEND_LANGUAGE="other" ;;
    esac
}

if [[ "$PROJECT_TYPE" == "backend" || "$PROJECT_TYPE" == "fullstack" ]]; then
    if [ "$ALL_CONFIRMED" = true ]; then
        # 一键确认时直接应用检测结果，无需再问
        BACKEND_LANGUAGE="${DETECTED_BE_LANG:-none}"
        BACKEND_FRAMEWORK="${DETECTED_BE_FRAMEWORK:-none}"
        case "$DETECTED_BE_LANG" in
            nodejs)  BACKEND_RULES+=("nodejs-express") ;;
            go)      BACKEND_RULES+=("go-error-handling") ;;
            python)  BACKEND_RULES+=("python-fastapi") ;;
        esac
    else
        echo ""
        echo -e "${GREEN}Step 4: 后端技术栈${NC}"
        echo ""

        if [ -n "$DETECTED_BE_LANG" ]; then
            BE_SUMMARY="${DETECTED_BE_LANG}"
            [ -n "$DETECTED_BE_FRAMEWORK" ] && BE_SUMMARY="${BE_SUMMARY} (${DETECTED_BE_FRAMEWORK})"

            echo -e "  已检测到：${GREEN}${BE_SUMMARY}${NC}"
            read -p "  确认使用此配置？[Y/n/手动]: " CONFIRM_BE
            if [[ -z "$CONFIRM_BE" || "$CONFIRM_BE" =~ ^[Yy]$ ]]; then
                BACKEND_LANGUAGE="$DETECTED_BE_LANG"
                BACKEND_FRAMEWORK="${DETECTED_BE_FRAMEWORK:-other}"
                case "$DETECTED_BE_LANG" in
                    nodejs)  BACKEND_RULES+=("nodejs-express") ;;
                    go)      BACKEND_RULES+=("go-error-handling") ;;
                    python)  BACKEND_RULES+=("python-fastapi") ;;
                esac
                echo -e "  ${GREEN}✓ 后端技术栈已确认${NC}"
            else
                _select_be_manual
            fi
        else
            _select_be_manual
        fi
    fi
fi

# ─────────────────────────────────────────
# Step 5: 测试配置
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}Step 5: 测试配置${NC}"
echo ""

read -p "是否启用 UI 视觉测试（Midscene.js）？[y/N]: " ENABLE_UI_TEST
UI_VISUAL_TESTING="false"
if [[ "$ENABLE_UI_TEST" =~ ^[Yy]$ ]]; then
    UI_VISUAL_TESTING="true"
fi

read -p "是否启用非功能测试（性能/安全/可访问性）？[y/N]: " ENABLE_L5
L5_NONFUNCTIONAL="false"
if [[ "$ENABLE_L5" =~ ^[Yy]$ ]]; then
    L5_NONFUNCTIONAL="true"
fi

# ─────────────────────────────────────────
# Step 6: Token 配置
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}Step 6: Token 成本配置${NC}"
echo ""
read -p "Token 警告阈值（默认 100000）: " TOKEN_WARNING
TOKEN_WARNING="${TOKEN_WARNING:-100000}"
read -p "Token 硬限制（默认 500000）: " TOKEN_LIMIT
TOKEN_LIMIT="${TOKEN_LIMIT:-500000}"

# ─────────────────────────────────────────
# Step 7: 创建目录结构
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}Step 7: 创建 .codeman/ 目录结构...${NC}"

mkdir -p "${PROJECT_DIR}/.codeman/docs/prd"
mkdir -p "${PROJECT_DIR}/.codeman/docs/design"
mkdir -p "${PROJECT_DIR}/.codeman/docs/api"
mkdir -p "${PROJECT_DIR}/.codeman/docs/tests"
mkdir -p "${PROJECT_DIR}/.codeman/docs/reviews"
mkdir -p "${PROJECT_DIR}/.codeman/docs/deploy"
mkdir -p "${PROJECT_DIR}/.codeman/skills"
mkdir -p "${PROJECT_DIR}/.codeman/rules"
mkdir -p "${PROJECT_DIR}/.codeman/templates"

# ─────────────────────────────────────────
# Step 8: 复制文档模板
# ─────────────────────────────────────────
echo -e "${GREEN}Step 8: 初始化文档模板...${NC}"

# STATUS.md
cp "${CODEMAN_DIR}/templates/STATUS.md" "${PROJECT_DIR}/.codeman/docs/STATUS.md"
sed -i.bak "s/{{YYYY-MM-DDTHH:MM:SS}}/$(date +%Y-%m-%dT%H:%M:%S)/g" "${PROJECT_DIR}/.codeman/docs/STATUS.md"
sed -i.bak "s/{{init|requirements|design|development|testing|fixing|deploy-ready|completed}}/init/g" "${PROJECT_DIR}/.codeman/docs/STATUS.md"
rm -f "${PROJECT_DIR}/.codeman/docs/STATUS.md.bak"

# DIRECTIVES.md
cp "${CODEMAN_DIR}/templates/DIRECTIVES.md" "${PROJECT_DIR}/.codeman/docs/DIRECTIVES.md"

# INDEX 文件
cp "${CODEMAN_DIR}/templates/prd/INDEX.md" "${PROJECT_DIR}/.codeman/docs/prd/INDEX.md"
cp "${CODEMAN_DIR}/templates/design/INDEX.md" "${PROJECT_DIR}/.codeman/docs/design/INDEX.md"
cp "${CODEMAN_DIR}/templates/api/INDEX.md" "${PROJECT_DIR}/.codeman/docs/api/INDEX.md"
cp "${CODEMAN_DIR}/templates/tests/INDEX.md" "${PROJECT_DIR}/.codeman/docs/tests/INDEX.md"
cp "${CODEMAN_DIR}/templates/reviews/INDEX.md" "${PROJECT_DIR}/.codeman/docs/reviews/INDEX.md"
cp "${CODEMAN_DIR}/templates/deploy/INDEX.md" "${PROJECT_DIR}/.codeman/docs/deploy/INDEX.md"

# 复制所有模板到 .codeman/templates/
cp -r "${CODEMAN_DIR}/templates/"* "${PROJECT_DIR}/.codeman/templates/"

# ─────────────────────────────────────────
# Step 9: 生成 config.yaml
# ─────────────────────────────────────────
echo -e "${GREEN}Step 9: 生成 config.yaml...${NC}"

cat > "${PROJECT_DIR}/.codeman/config.yaml" << EOF
# CodeMan 项目配置
# 生成时间：$(date +%Y-%m-%dT%H:%M:%S)

project:
  name: "${PROJECT_NAME}"
  type: "${PROJECT_TYPE}"
  version: "1.0.0"

tech_stack:
  frontend:
    framework: "${FRONTEND_FRAMEWORK}"
    language: "${FRONTEND_LANGUAGE}"
    styling: "${FRONTEND_STYLING}"
  backend:
    language: "${BACKEND_LANGUAGE}"
    framework: "${BACKEND_FRAMEWORK}"
  testing:
    unit: "${UNIT_TEST:-vitest}"
    e2e: "playwright"
    ui_visual: "$([ "$UI_VISUAL_TESTING" == "true" ] && echo "midscene" || echo "none")"

testing:
  unit_coverage_threshold:
    business_logic: 80
    utility_functions: 90
  ui_visual_testing: ${UI_VISUAL_TESTING}
  l5_nonfunctional: ${L5_NONFUNCTIONAL}

token_limits:
  warning_threshold: ${TOKEN_WARNING}
  hard_limit: ${TOKEN_LIMIT}
  preferred_model: "sonnet"

workflow:
  auto_git_commit: true
  require_review_before_code: true
  require_review_after_code: true
  max_fix_rounds: 3

security:
  ignore_patterns:
    - ".env"
    - ".env.*"
    - "*.pem"
    - "*.key"
    - "secrets/**"
    - "credentials/**"

tools:
  playwright_mcp: true
  midscene_config:
    model: "qwen-vl-max"
    timeout: 30000
EOF

# ─────────────────────────────────────────
# Step 10: 安装规范文件 + 生成待生成清单
# ─────────────────────────────────────────
echo -e "${GREEN}Step 10: 安装规范文件...${NC}"

# L1 全局规范（始终安装）
cp "${CODEMAN_DIR}/rules/global-git-convention.mdc" "${PROJECT_DIR}/.codeman/rules/"
cp "${CODEMAN_DIR}/rules/global-code-quality.mdc" "${PROJECT_DIR}/.codeman/rules/"
cp "${CODEMAN_DIR}/rules/global-security-baseline.mdc" "${PROJECT_DIR}/.codeman/rules/"

# L2 项目层规范：有内置模板则直接复制，否则记录到 PENDING-RULES.md 由 AI 动态生成
PENDING_RULES=()

_install_or_pend_rule() {
    local category="$1"  # frontend / backend
    local rule="$2"      # 规范文件名（不含 .mdc）
    local desc="$3"      # 规范描述（用于 PENDING-RULES.md）
    local template_path="${CODEMAN_DIR}/rules/templates/${category}/${rule}.mdc"

    if [ -f "$template_path" ]; then
        cp "$template_path" "${PROJECT_DIR}/.codeman/rules/proj-${rule}.mdc"
        echo "  已安装规范（内置模板）：proj-${rule}.mdc"
    else
        PENDING_RULES+=("proj-${rule}.mdc|${desc}")
        echo "  待 AI 生成规范：proj-${rule}.mdc（${desc}）"
    fi
}

# 前端规范安装
if [[ "$PROJECT_TYPE" == "frontend" || "$PROJECT_TYPE" == "fullstack" ]]; then
    case "$FRONTEND_FRAMEWORK" in
        react)
            _install_or_pend_rule "frontend" "react-component" "React 组件开发规范"
            ;;
        nextjs)
            _install_or_pend_rule "frontend" "react-component" "React 组件开发规范"
            _install_or_pend_rule "frontend" "nextjs-routing" "Next.js 路由与页面规范"
            ;;
        vue)
            _install_or_pend_rule "frontend" "vue-component" "Vue 组件开发规范"
            ;;
        svelte)
            _install_or_pend_rule "frontend" "svelte-component" "Svelte 组件开发规范"
            ;;
        angular)
            _install_or_pend_rule "frontend" "angular-component" "Angular 组件开发规范"
            ;;
        *)
            if [ -n "$FRONTEND_FRAMEWORK" ] && [ "$FRONTEND_FRAMEWORK" != "none" ]; then
                _install_or_pend_rule "frontend" "${FRONTEND_FRAMEWORK}-component" "${FRONTEND_FRAMEWORK} 组件开发规范"
            fi
            ;;
    esac

    # 样式规范
    case "$FRONTEND_STYLING" in
        tailwind)
            _install_or_pend_rule "frontend" "tailwind-styling" "Tailwind CSS 样式规范"
            ;;
        css-modules)
            _install_or_pend_rule "frontend" "css-modules-styling" "CSS Modules 样式规范"
            ;;
        styled-components)
            _install_or_pend_rule "frontend" "styled-components-styling" "styled-components 样式规范"
            ;;
    esac

    # 测试规范
    case "$UNIT_TEST" in
        vitest)
            _install_or_pend_rule "frontend" "vitest-testing" "Vitest 单元测试规范"
            ;;
        jest)
            _install_or_pend_rule "frontend" "jest-testing" "Jest 单元测试规范"
            ;;
        *)
            if [ -n "$UNIT_TEST" ] && [ "$UNIT_TEST" != "other" ]; then
                _install_or_pend_rule "frontend" "${UNIT_TEST}-testing" "${UNIT_TEST} 测试规范"
            fi
            ;;
    esac
fi

# 后端规范安装
if [[ "$PROJECT_TYPE" == "backend" || "$PROJECT_TYPE" == "fullstack" ]]; then
    case "$BACKEND_LANGUAGE" in
        nodejs)
            _install_or_pend_rule "backend" "nodejs-express" "Node.js Express 后端规范"
            ;;
        go)
            _install_or_pend_rule "backend" "go-error-handling" "Go 错误处理与代码规范"
            ;;
        python)
            _install_or_pend_rule "backend" "python-fastapi" "Python FastAPI 后端规范"
            ;;
        java)
            _install_or_pend_rule "backend" "java-spring" "Java Spring Boot 后端规范"
            ;;
        ruby)
            _install_or_pend_rule "backend" "ruby-rails" "Ruby on Rails 后端规范"
            ;;
        rust)
            _install_or_pend_rule "backend" "rust-backend" "Rust 后端开发规范"
            ;;
        *)
            if [ -n "$BACKEND_LANGUAGE" ] && [ "$BACKEND_LANGUAGE" != "none" ] && [ "$BACKEND_LANGUAGE" != "other" ]; then
                _install_or_pend_rule "backend" "${BACKEND_LANGUAGE}-backend" "${BACKEND_LANGUAGE} 后端开发规范"
            fi
            ;;
    esac
fi

# 生成 PENDING-RULES.md（如果有待生成的规范）
if [ ${#PENDING_RULES[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}  生成待生成规范清单（将由 AI 在首次运行时自动创建）...${NC}"

    PENDING_FILE="${PROJECT_DIR}/.codeman/rules/PENDING-RULES.md"
    cat > "$PENDING_FILE" << PENDING_EOF
# 待生成规范清单

> 由 init.sh 在初始化时生成，由 orchestrator skill 在首次运行时自动处理。
> 对每个 \`- [ ]\` 条目，AI 将根据技术栈生成对应的 .mdc 规范文件并同步到 .cursor/rules/。

## 检测到的技术栈

PENDING_EOF

    [ -n "$FRONTEND_FRAMEWORK" ] && [ "$FRONTEND_FRAMEWORK" != "none" ] && \
        echo "- 前端框架：${FRONTEND_FRAMEWORK}" >> "$PENDING_FILE"
    [ -n "$FRONTEND_STYLING" ] && [ "$FRONTEND_STYLING" != "none" ] && \
        echo "- 样式方案：${FRONTEND_STYLING}" >> "$PENDING_FILE"
    [ -n "$UNIT_TEST" ] && [ "$UNIT_TEST" != "other" ] && \
        echo "- 测试框架：${UNIT_TEST}" >> "$PENDING_FILE"
    [ -n "$BACKEND_LANGUAGE" ] && [ "$BACKEND_LANGUAGE" != "none" ] && [ "$BACKEND_LANGUAGE" != "other" ] && \
        echo "- 后端语言：${BACKEND_LANGUAGE}$([ -n "$BACKEND_FRAMEWORK" ] && echo " (${BACKEND_FRAMEWORK})")" >> "$PENDING_FILE"

    echo "" >> "$PENDING_FILE"
    echo "## 待生成规范" >> "$PENDING_FILE"
    echo "" >> "$PENDING_FILE"

    for entry in "${PENDING_RULES[@]}"; do
        filename="${entry%%|*}"
        desc="${entry##*|}"
        echo "- [ ] ${filename} — ${desc}" >> "$PENDING_FILE"
    done

    echo ""
    echo "  已写入：.codeman/rules/PENDING-RULES.md"
    echo "  首次说 'CodeMan 开始开发' 时 AI 将自动生成这些规范。"
fi

# 生成 Rules INDEX.md
cat > "${PROJECT_DIR}/.codeman/rules/INDEX.md" << 'EOF'
# Rules 规范索引

> 最后更新：自动维护

| 规范名 | 文件 | 层级 | 适用范围 | alwaysApply |
|--------|------|------|---------|-------------|
EOF

for mdc_file in "${PROJECT_DIR}/.codeman/rules/"*.mdc; do
    if [ -f "$mdc_file" ]; then
        filename=$(basename "$mdc_file")
        echo "| ${filename%.mdc} | ${filename} | L1/L2 | 见文件描述 | - |" >> "${PROJECT_DIR}/.codeman/rules/INDEX.md"
    fi
done

# 生成 Skills INDEX.md
cat > "${PROJECT_DIR}/.codeman/skills/INDEX.md" << 'EOF'
# Skills 索引

> 动态 Skills 目录（由自进化引擎创建）

| Skill 名 | 目录 | 触发条件 | 创建日期 |
|---------|------|---------|---------|
EOF

# ─────────────────────────────────────────
# Step 11: 同步到 Cursor
# ─────────────────────────────────────────
echo -e "${GREEN}Step 11: 同步到 Cursor...${NC}"

bash "${CODEMAN_DIR}/adapters/cursor/sync-rules.sh" "${PROJECT_DIR}" "${CODEMAN_DIR}"

# ─────────────────────────────────────────
# Step 12: 检查冲突
# ─────────────────────────────────────────
echo -e "${GREEN}Step 12: 检查规范冲突...${NC}"

CONFLICT_FOUND=false

if [ -f "${PROJECT_DIR}/.cursorrules" ]; then
    echo -e "${YELLOW}  发现已有 .cursorrules 文件。${NC}"
    echo "  CodeMan 规范已加 'codeman-' 前缀，不会覆盖您的现有规范。"
    CONFLICT_FOUND=true
fi

if [ -d "${PROJECT_DIR}/.cursor/rules" ]; then
    EXISTING_RULES=$(ls "${PROJECT_DIR}/.cursor/rules/"*.mdc 2>/dev/null | grep -v "codeman-" | wc -l)
    if [ "$EXISTING_RULES" -gt 0 ]; then
        echo -e "${YELLOW}  发现 ${EXISTING_RULES} 个已有 Cursor Rules。${NC}"
        echo "  CodeMan 规范已加 'codeman-' 前缀，不会覆盖您的现有规范。"
        CONFLICT_FOUND=true
    fi
fi

if [ "$CONFLICT_FOUND" = false ]; then
    echo "  未发现规范冲突。"
fi

# ─────────────────────────────────────────
# 检测项目类型（新项目 or 旧项目）
# ─────────────────────────────────────────

# 判断是否有业务源码：检查常见源码目录/文件是否存在
HAS_SOURCE_CODE=false
SOURCE_INDICATORS=(
    "src" "app" "lib" "pkg" "cmd"          # 通用源码目录
    "pages" "components" "views"            # 前端目录
    "main.go" "main.py" "index.js" "index.ts" "server.js" "server.ts"  # 入口文件
)

for indicator in "${SOURCE_INDICATORS[@]}"; do
    if [ -e "${PROJECT_DIR}/${indicator}" ]; then
        HAS_SOURCE_CODE=true
        break
    fi
done

if [ "$HAS_SOURCE_CODE" = true ]; then
    PROJECT_TYPE_RESULT="legacy"
else
    PROJECT_TYPE_RESULT="new"
fi

# ─────────────────────────────────────────
# 完成
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  CodeMan 初始化完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "已创建："
echo "  .codeman/           ← CodeMan 工作目录"
echo "  .codeman/config.yaml"
echo "  .codeman/docs/      ← 文档体系"
echo "  .codeman/rules/     ← 项目规范"
echo "  .cursor/rules/      ← 已同步到 Cursor"
echo ""

# 输出结构化摘要（供 AI 读取，判断下一步流程）
echo "CODEMAN_INIT_RESULT"
echo "project_type: ${PROJECT_TYPE_RESULT}"
echo "has_source_code: ${HAS_SOURCE_CODE}"
echo "project_name: ${PROJECT_NAME}"
echo "tech_stack: frontend=${FRONTEND_FRAMEWORK:-none} backend=${BACKEND_LANGUAGE:-none}"
echo "codeman_dir: ${PROJECT_DIR}/.codeman"
echo "END_CODEMAN_INIT_RESULT"
echo ""
