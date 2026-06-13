#!/usr/bin/env bash
# =============================================================================
# AI Studio Manager for macOS v2.1 (Single-File Modular Architecture)
# =============================================================================
# 核心特性：内部模块化设计、双重校验机制、网络优化、自动打开浏览器
# =============================================================================
set -uo pipefail

# =============================================================================
# [模块 1] 全局配置
# =============================================================================
readonly SCRIPT_VERSION="2.1.0-MODULAR"
readonly INSTALL_DIR="${HOME}/ai-studio"
readonly LOG_DIR="${INSTALL_DIR}/logs"
readonly BACKUP_DIR="${INSTALL_DIR}/backups"

# 网络优化：强制 HTTP/1.1 防 CANCEL，禁用 Git 密码提示防假死
readonly GIT_NET_OPTS=(-c http.version=HTTP/1.1 -c http.postBuffer=524288000)
export GIT_TERMINAL_PROMPT=0

# PyPI 国内镜像源加速
readonly PIP_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"
readonly PIP_TRUSTED="pypi.tuna.tsinghua.edu.cn"

readonly COMP_KEYS=(open-webui sillytavern continue-dev faas browser-use mlx comfyui mlx-video)
declare -A COMPONENTS=(
    [open-webui]="Open WebUI|https://github.com/open-webui/open-webui.git|8080|http://localhost:8080"
    [sillytavern]="SillyTavern|https://github.com/SillyTavern/SillyTavern.git|8000|http://localhost:8000"
    [continue-dev]="Continue.dev|https://github.com/continuedev/continue.git|3000|http://localhost:3000"
    [faas]="FaaS|https://github.com/openfaas/faas.git|8081|http://localhost:8081"
    [browser-use]="Browser Use|https://github.com/browser-use/browser-use.git|8082|http://localhost:8082"
    [mlx]="MLX|https://github.com/ml-explore/mlx.git|N/A|local"
    [comfyui]="ComfyUI|https://github.com/comfyanonymous/ComfyUI.git|8188|http://localhost:8188"
    [mlx-video]="MLX-Video|https://github.com/Blaizzy/mlx-video.git|N/A|local"
)

# 全局变量：用于函数间返回数据
VENV_PIP=""
VENV_PYTHON=""
SELECTED_COMPONENT=""

# =============================================================================
# [模块 2] 核心工具库 (Core Utils)
# =============================================================================
log_info()    { echo -e "\033[0;34m[INFO]\033[0m $1" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2; }
log_warn()    { echo -e "\033[0;33m[WARN]\033[0m $1" >&2; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

check_dependencies() {
    log_info "检查系统依赖..."
    local deps=("git" "python3" "node" "npm" "curl" "brew")
    local missing=()
    for dep in "${deps[@]}"; do command -v "$dep" &> /dev/null || missing+=("$dep"); done
    if [[ "$OSTYPE" == "darwin"* ]] && ! xcode-select -p &>/dev/null; then 
        missing+=("xcode-select (请运行: xcode-select --install)")
    fi
    if [ ${#missing[@]} -eq 0 ]; then log_success "所有基础依赖已满足"; return 0; fi
    log_warn "发现缺失依赖: ${missing[*]}"
    [[ "${1:-}" != "--ignore-missing" ]] && exit 1
    return 0
}

setup_venv() {
    local dir="$1"
    local venv_python="${dir}/venv/bin/python"
    if [ ! -f "$venv_python" ]; then
        log_info "创建 Python 虚拟环境: ${dir}/venv"
        python3 -m venv "${dir}/venv" 2>&1 || { log_error "venv 创建失败"; return 1; }
        "${dir}/venv/bin/pip" install --upgrade pip setuptools wheel -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" &>/dev/null
    fi
    VENV_PIP="${dir}/venv/bin/pip"
    VENV_PYTHON="${venv_python}"
    return 0
}

# =============================================================================
# [模块 3] Git 与网络工具 (Git Utils)
# =============================================================================
safe_git_clone() {
    local repo_url="$1" dir="$2"
    if [ -d "${dir}" ] && [ ! -d "${dir}/.git" ]; then
        log_warn "发现残留目录 ${dir}，正在清理..."
        rm -rf "${dir}"
    fi
    if [ ! -d "${dir}/.git" ]; then
        log_info "克隆 ${repo_url}..."
        git "${GIT_NET_OPTS[@]}" clone --depth 1 "${repo_url}" "${dir}" || {
            log_error "克隆失败 (网络错误或仓库不存在)"
            return 1
        }
    fi
    return 0
}

# =============================================================================
# [模块 4] 服务管理 (Service Management) - 🌟 含启动前拦截校验
# =============================================================================
wait_for_service() {
    local port="$1" retries=0 max_retries=30
    while (( retries < max_retries )); do
        if command -v curl &>/dev/null; then
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "http://localhost:${port}" 2>/dev/null)
            [[ "$http_code" =~ ^(200|301|302|303|307|401|403|404)$ ]] && return 0
        fi
        if command -v lsof &>/dev/null && lsof -i :${port} -t &>/dev/null; then sleep 1; return 0; fi
        sleep 1; ((retries++))
    done
    return 1
}

start_service() {
    local key="$1"
    IFS='|' read -r name _ port default_url <<< "${COMPONENTS[$key]}"
    log_info "启动 ${name}..."
    if [ "$port" != "N/A" ] && [ ! -f "${INSTALL_DIR}/${key}/start.sh" ]; then
        log_error "${name} 未部署或启动脚本不存在"; return 1
    fi
    if [ "$port" != "N/A" ]; then
        cd "${INSTALL_DIR}/${key}" || return 1
        
        # 🌟 核心修复：启动前拦截校验 (针对 Open WebUI)
        if [[ "$key" == "open-webui" ]] && [ -f "venv/bin/python" ]; then
            if ! ./venv/bin/python -c "import open_webui" 2>/dev/null; then
                log_error "🛑 拦截启动：检测到 Open WebUI 核心模块缺失！"
                log_warn "部署可能未成功。请运行菜单 [15] 卸载后重新部署，或手动执行: venv/bin/pip install -e ."
                return 1
            fi
        fi

        nohup ./start.sh >> "${LOG_DIR}/${key}.log" 2>&1 &
        local pid=$!
        echo "$pid" > "${LOG_DIR}/${key}.pid"
        log_info "等待服务就绪 (最多 30s)..."
        if wait_for_service "$port"; then
            log_success "${name} 已在端口 ${port} 启动 (PID: ${pid})"
            command -v open &>/dev/null && open "${default_url}" 2>/dev/null
        else
            log_error "${name} 启动超时，请查看日志: ${LOG_DIR}/${key}.log"
        fi
    else
        log_info "${name} 为本地框架，无需启动后台服务。"
    fi
}

stop_service() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    log_info "停止 ${name}..."
    local pid_file="${LOG_DIR}/${key}.pid"
    if [ -f "$pid_file" ]; then
        local pid; read -r pid < "$pid_file" 2>/dev/null || pid=""
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true; sleep 2; kill -9 "$pid" 2>/dev/null || true
            log_success "${name} 已停止"
        fi
        rm -f "$pid_file"
    else
        log_warn "${name} 未找到运行进程"
    fi
}

# =============================================================================
# [模块 5] 部署模块 (Deploy Modules) - 🌟 含部署后严格校验
# =============================================================================
deploy_open_webui() {
    local repo_url="$1" dir="${INSTALL_DIR}/open-webui"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    setup_venv "${dir}" || return 1
    
    log_info "安装 Open WebUI 依赖 (包含 PyTorch，可能需要 10-30 分钟)..."
    local pip_log="${LOG_DIR}/pip_openwebui_install.log"
    mkdir -p "$LOG_DIR"
    
    # 执行安装并记录详细日志
    if ! "$VENV_PIP" install -e . -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" > "$pip_log" 2>&1; then
        log_error "依赖安装失败！请查看详细日志: $pip_log"
        return 1
    fi
    
    # 🌟 核心修复：安装后严格校验模块是否可用
    log_info "验证 Open WebUI 模块完整性..."
    if ! "${VENV_PYTHON}" -c "import open_webui" 2>/dev/null; then
        log_error "❌ 验证失败：open_webui 模块未正确安装！"
        log_warn "常见原因：前端构建(npm run build)失败或 PyTorch 下载中断。"
        log_warn "请查看日志定位问题: tail -100 $pip_log"
        return 1
    fi
    log_success "Open WebUI 模块验证通过"
    
    # 只有校验通过，才生成 start.sh
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
exec python -m open_webui --host 0.0.0.0 --port 8080
EOF
    chmod +x start.sh
}

deploy_sillytavern() {
    local repo_url="$1" dir="${INSTALL_DIR}/sillytavern"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    npm install --silent 2>/dev/null || npm install || { log_error "npm install 失败"; return 1; }
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec node server.js --listen --port 8000
EOF
    chmod +x start.sh
}

deploy_continue() {
    local repo_url="$1" dir="${INSTALL_DIR}/continue-dev"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    npm install --silent 2>/dev/null || npm install
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec npm run dev -- --port 3000
EOF
    chmod +x start.sh
}

deploy_faas() {
    local repo_url="$1" dir="${INSTALL_DIR}/faas"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    command -v faas-cli &>/dev/null || brew install openfaas/tap/faas-cli 2>&1 || { log_error "faas-cli 安装失败"; return 1; }
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec faas-cli up --port 8081 2>&1
EOF
    chmod +x start.sh
}

deploy_browser_use() {
    local repo_url="$1" dir="${INSTALL_DIR}/browser-use"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    setup_venv "${dir}" || return 1
    "$VENV_PIP" install -e . -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "pip install 警告"
    "$VENV_PIP" install playwright -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1
    ./venv/bin/playwright install chromium 2>/dev/null || true
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
exec python main.py --port 8082 2>/dev/null || echo "请检查 browser-use 官方启动方式"
EOF
    chmod +x start.sh
}

deploy_mlx() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    setup_venv "${dir}" || return 1
    "$VENV_PIP" install mlx mlx-examples -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "MLX 安装警告"
}

deploy_comfyui() {
    local repo_url="$1" dir="${INSTALL_DIR}/comfyui"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    setup_venv "${dir}" || return 1
    [[ -f "requirements.txt" ]] && "$VENV_PIP" install -r requirements.txt -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "依赖安装警告"
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
exec python main.py --listen --port 8188
EOF
    chmod +x start.sh
}

deploy_mlx_video() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx-video"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    setup_venv "${dir}" || return 1
    [[ -f "requirements.txt" ]] && "$VENV_PIP" install -r requirements.txt -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || "$VENV_PIP" install mlx -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1
}

deploy_component() {
    local key="$1"
    IFS='|' read -r name repo_url port _ <<< "${COMPONENTS[$key]}"
    log_info "开始部署 ${name}..."
    mkdir -p "${INSTALL_DIR}" "${LOG_DIR}" "${BACKUP_DIR}"
    case "$key" in
        open-webui) deploy_open_webui "$repo_url" || return 1 ;;
        sillytavern) deploy_sillytavern "$repo_url" || return 1 ;;
        continue-dev) deploy_continue "$repo_url" || return 1 ;;
        faas) deploy_faas "$repo_url" || return 1 ;;
        browser-use) deploy_browser_use "$repo_url" || return 1 ;;
        mlx) deploy_mlx "$repo_url" || return 1 ;;
        comfyui) deploy_comfyui "$repo_url" || return 1 ;;
        mlx-video) deploy_mlx_video "$repo_url" || return 1 ;;
        *) log_error "未知组件: ${key}"; return 1 ;;
    esac
    log_success "${name} 部署完成"
}

# =============================================================================
# [模块 6] 菜单与主逻辑 (Menu & Main)
# =============================================================================
select_component() {
    SELECTED_COMPONENT=""
    echo "可用组件列表:" >&2
    for i in "${!COMP_KEYS[@]}"; do
        local key="${COMP_KEYS[$i]}"
        IFS='|' read -r name _ port url <<< "${COMPONENTS[$key]}"
        printf "  %2d. %-15s 端口:%-6s\n" "$((i+1))" "$name" "$port" >&2
    done
    read -p "选择组件编号 (1-${#COMP_KEYS[@]}, 回车取消): " choice >&2
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#COMP_KEYS[@]} )); then
        SELECTED_COMPONENT="${COMP_KEYS[$((choice-1))]}"
        return 0
    fi
    return 1
}

show_menu() {
    clear
    echo "=================================================="
    echo "   AI Studio Manager v${SCRIPT_VERSION} (Modular)"
    echo "=================================================="
    echo "  1. 部署全部组件   2. 选择性部署 (单个)"
    echo "  3. 启动全部服务   4. 停止全部服务"
    echo "  5. 启动单个服务   6. 停止单个服务"
    echo "  7. 查看组件状态   0. 退出"
    echo "=================================================="
}

main() {
    while true; do
        show_menu
        read -p "请选择操作 [0-7]: " choice
        case "$choice" in
            1) check_dependencies "--ignore-missing"
               for k in "${COMP_KEYS[@]}"; do deploy_component "$k" || true; done ;;
            2) select_component && check_dependencies "--ignore-missing" && deploy_component "$SELECTED_COMPONENT" ;;
            3) for k in "${COMP_KEYS[@]}"; do [ -f "${INSTALL_DIR}/${k}/start.sh" ] && start_service "$k"; done ;;
            4) for k in "${COMP_KEYS[@]}"; do stop_service "$k"; done ;;
            5) select_component && start_service "$SELECTED_COMPONENT" ;;
            6) select_component && stop_service "$SELECTED_COMPONENT" ;;
            7) for k in "${COMP_KEYS[@]}"; do
                   IFS='|' read -r name _ port _ <<< "${COMPONENTS[$k]}"
                   [ -d "${INSTALL_DIR}/${k}" ] && echo "✅ ${name}: 已安装" || echo "❌ ${name}: 未安装"
               done ;;
            0) exit 0 ;;
            *) log_error "无效选项" ;;
        esac
        echo ""; read -p "✅ 按回车键继续..." -r
    done
}

main "$@"
