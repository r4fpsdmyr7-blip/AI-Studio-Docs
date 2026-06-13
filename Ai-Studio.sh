#!/bin/bash

# =============================================================================
# AI Studio Manager for macOS
# =============================================================================
# 功能：管理 Open WebUI, SillyTavern, Continue.dev, FaaS, Browser Use, 
#       MLX, ComfyUI (SDXL/FLUX), MLX-Video 的部署、更新、诊断与卸载
# 作者：AI Assistant
# 日期：2026-05-31
# 版本：1.0.0
# =============================================================================

set -euo pipefail

# =============================================================================
# 配置区 - 可根据需要修改
# =============================================================================
readonly SCRIPT_VERSION="1.0.0"
readonly INSTALL_DIR="${HOME}/ai-studio"
readonly LOG_DIR="${INSTALL_DIR}/logs"
readonly BACKUP_DIR="${INSTALL_DIR}/backups"
readonly CONFIG_FILE="${INSTALL_DIR}/config.json"

# 各组件配置
declare -A COMPONENTS=(
    [open-webui]="Open WebUI|https://github.com/open-webui/open-webui.git|8080|http://localhost:8080"
    [sillytavern]="SillyTavern|https://github.com/SillyTavern/SillyTavern.git|8000|http://localhost:8000"
    [continue-dev]="Continue.dev|https://github.com/continuedev/continue.git|3000|http://localhost:3000"
    [faas]="FaaS|https://github.com/openfaas/faas.git|8081|http://localhost:8081"
    [browser-use]="Browser Use|https://github.com/browser-use/browser-use.git|8082|http://localhost:8082"
    [mlx]="MLX|https://github.com/ml-explore/mlx.git|N/A|local"
    [comfyui]="ComfyUI|https://github.com/comfyanonymous/ComfyUI.git|8188|http://localhost:8188"
    [mlx-video]="MLX-Video|https://github.com/ml-explore/mlx-video.git|N/A|local"
)

# =============================================================================
# 工具函数
# =============================================================================
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd 未安装，正在安装..."
        case "$cmd" in
            brew)
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                ;;
            git)
                brew install git
                ;;
            python3|pip3)
                brew install python@3.12
                ;;
            node|npm)
                brew install node
                ;;
            wget)
                brew install wget
                ;;
            *)
                log_error "无法自动安装 $cmd，请手动安装后重试"
                return 1
                ;;
        esac
        log_success "$cmd 安装完成"
    fi
}

check_dependencies() {
    log_info "检查系统依赖..."
    
    local deps=("brew" "git" "python3" "pip3" "node" "npm" "wget")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        log_success "所有基础依赖已满足"
        return 0
    fi
    
    log_info "发现缺失依赖: ${missing[*]}"
    for dep in "${missing[@]}"; do
        require_command "$dep"
    done
}

# =============================================================================
# 诊断功能
# =============================================================================
diagnose_simple() {
    log_info "=== 简单诊断 ==="
    echo ""
    
    echo "系统信息:"
    echo "  macOS版本: $(sw_vers -productVersion)"
    echo "  芯片类型: $(uname -m)"
    echo "  内存: $(sysctl -n hw.memsize | awk '{printf "%.1f GB", $1/1073741824}')"
    echo ""
    
    echo "依赖检查:"
    local deps=("brew" "git" "python3" "pip3" "node" "npm")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "$dep: $($dep --version 2>/dev/null | head -1)"
        else
            log_error "$dep: 未安装"
        fi
    done
    echo ""
    
    echo "组件安装状态:"
    for key in "${!COMPONENTS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
        if [ -d "${INSTALL_DIR}/${key}" ]; then
            log_success "${name}: 已安装"
        else
            log_warn "${name}: 未安装"
        fi
    done
    echo ""
    
    echo "端口占用情况:"
    local ports=(8080 8000 3000 8081 8082 8188)
    for port in "${ports[@]}"; do
        if lsof -i :${port} &> /dev/null; then
            log_warn "端口 ${port} 被占用: $(lsof -i :${port} -t | head -1)"
        else
            log_success "端口 ${port} 空闲"
        fi
    done
    echo ""
    
    echo "磁盘空间:"
    df -h / | awk 'NR==2 {printf "可用空间: %s (%s 使用)\n", $4, $5}'
    echo ""
    
    log_success "简单诊断完成"
}

diagnose_deep() {
    log_info "=== 深度诊断 ==="
    diagnose_simple
    
    echo "详细系统信息:"
    echo "  CPU核心数: $(sysctl -n hw.ncpu)"
    echo "  GPU: $(system_profiler SPDisplaysDataType 2>/dev/null | grep -A 2 "Chipset Model" | tail -1 || echo "N/A")"
    echo ""
    
    echo "Python环境:"
    python3 -c "
import sys
print(f'  Python路径: {sys.executable}')
print(f'  Python版本: {sys.version}')
try:
    import mlx
    print(f'  MLX版本: {mlx.__version__}')
except ImportError:
    print('  MLX: 未安装')
" 2>/dev/null || echo "  Python环境检查失败"
    echo ""
    
    echo "Node.js环境:"
    if command -v node &> /dev/null; then
        echo "  Node路径: $(which node)"
        echo "  npm路径: $(which npm)"
        echo "  Node版本: $(node --version)"
    fi
    echo ""
    
    echo "Git仓库状态:"
    for key in "${!COMPONENTS[@]}"; do
        if [ -d "${INSTALL_DIR}/${key}/.git" ]; then
            cd "${INSTALL_DIR}/${key}"
            local branch=$(git branch --show-current 2>/dev/null)
            local last_commit=$(git log --oneline -1 2>/dev/null)
            echo "  ${key}: branch=${branch}, last=${last_commit}"
            cd - &> /dev/null
        fi
    done
    echo ""
    
    echo "网络连通性测试:"
    for url in "github.com" "huggingface.co" "pypi.org"; do
        if ping -c 1 -W 2 "${url}" &> /dev/null; then
            log_success "${url}: 可达"
        else
            log_error "${url}: 不可达"
        fi
    done
    echo ""
    
    log_success "深度诊断完成"
}

# =============================================================================
# 部署功能
# =============================================================================
deploy_component() {
    local key="$1"
    IFS='|' read -r name repo_url port default_url <<< "${COMPONENTS[$key]}"
    
    log_info "开始部署 ${name}..."
    
    mkdir -p "${INSTALL_DIR}" "${LOG_DIR}" "${BACKUP_DIR}"
    
    case "$key" in
        open-webui)
            deploy_open_webui "$repo_url"
            ;;
        sillytavern)
            deploy_sillytavern "$repo_url"
            ;;
        continue-dev)
            deploy_continue "$repo_url"
            ;;
        faas)
            deploy_faas "$repo_url"
            ;;
        browser-use)
            deploy_browser_use "$repo_url"
            ;;
        mlx)
            deploy_mlx "$repo_url"
            ;;
        comfyui)
            deploy_comfyui "$repo_url"
            ;;
        mlx-video)
            deploy_mlx_video "$repo_url"
            ;;
        *)
            log_error "未知组件: ${key}"
            return 1
            ;;
    esac
    
    log_success "${name} 部署完成"
}

deploy_open_webui() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/open-webui"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 Open WebUI 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    
    pip install -e ".[docker]"
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
source venv/bin/activate
OLLAMA_BASE_URL=http://localhost:11434 \
WEBUI_SECRET_KEY=your-secret-key \
python -m open_webui --host 0.0.0.0 --port 8080
EOF
    chmod +x start.sh
}

deploy_sillytavern() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/sillytavern"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 SillyTavern 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    # 安装依赖
    npm install
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
node server.js --listen --port 8000
EOF
    chmod +x start.sh
}

deploy_continue() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/continue-dev"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 Continue.dev 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    npm install
    npm run build
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
npm run dev -- --port 3000
EOF
    chmod +x start.sh
}

deploy_faas() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/faas"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 FaaS 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    # 安装 arkade (FaaS CLI)
    if ! command -v arkade &> /dev/null; then
        curl -sLS https://get.arkade.dev | sudo sh
    fi
    
    arkade get faas-cli
    sudo mv faas-cli /usr/local/bin/
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
faas-cli up --port 8081
EOF
    chmod +x start.sh
}

deploy_browser_use() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/browser-use"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 Browser Use 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    
    pip install -e .
    pip install playwright
    playwright install
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
source venv/bin/activate
python -m browser_use.server --host 0.0.0.0 --port 8082
EOF
    chmod +x start.sh
}

deploy_mlx() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/mlx"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 MLX 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    
    pip install mlx mlx-examples
    
    log_info "MLX 部署完成 (本地库，无服务端口)"
}

deploy_comfyui() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/comfyui"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 ComfyUI 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    
    pip install torch torchvision
    pip install -r requirements.txt
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
source venv/bin/activate
python main.py --listen --port 8188 --front-end-version Comfy-Org/ComfyUI_frontend@latest
EOF
    chmod +x start.sh
}

deploy_mlx_video() {
    local repo_url="$1"
    local dir="${INSTALL_DIR}/mlx-video"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 MLX-Video 仓库..."
        git clone "${repo_url}" "${dir}"
    fi
    
    cd "${dir}"
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    
    pip install mlx video-processing
    
    log_info "MLX-Video 部署完成 (本地库，无服务端口)"
}

# =============================================================================
# 服务管理
# =============================================================================
start_service() {
    local key="$1"
    IFS='|' read -r name _ port default_url <<< "${COMPONENTS[$key]}"
    
    log_info "启动 ${name}..."
    
    if [ ! -f "${INSTALL_DIR}/${key}/start.sh" ]; then
        log_error "${name} 未部署或启动脚本不存在"
        return 1
    fi
    
    # 后台运行
    cd "${INSTALL_DIR}/${key}"
    nohup ./start.sh > "${LOG_DIR}/${key}.log" 2>&1 &
    echo $! > "${LOG_DIR}/${key}.pid"
    
    # 等待服务启动
    sleep 3
    
    # 检查是否成功启动
    if [ "$port" != "N/A" ]; then
        if lsof -i :${port} &> /dev/null; then
            log_success "${name} 已在端口 ${port} 启动"
            # 自动打开浏览器
            open "${default_url}"
        else
            log_error "${name} 启动失败，请查看日志: ${LOG_DIR}/${key}.log"
        fi
    else
        log_success "${name} 已启动 (本地库)"
    fi
}

stop_service() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    
    log_info "停止 ${name}..."
    
    if [ -f "${LOG_DIR}/${key}.pid" ]; then
        local pid=$(cat "${LOG_DIR}/${key}.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "${name} 已停止 (PID: ${pid})"
        else
            log_warn "${name} 进程不存在"
        fi
        rm -f "${LOG_DIR}/${key}.pid"
    else
        log_warn "${name} PID 文件不存在"
    fi
}

start_all_services() {
    log_info "启动所有已部署的服务..."
    for key in "${!COMPONENTS[@]}"; do
        if [ -f "${INSTALL_DIR}/${key}/start.sh" ]; then
            start_service "$key"
        fi
    done
}

stop_all_services() {
    log_info "停止所有运行中的服务..."
    for key in "${!COMPONENTS[@]}"; do
        if [ -f "${LOG_DIR}/${key}.pid" ]; then
            stop_service "$key"
        fi
    done
}

# =============================================================================
# 更新功能
# =============================================================================
update_component() {
    local key="$1"
    IFS='|' read -r name repo_url _ _ <<< "${COMPONENTS[$key]}"
    
    log_info "更新 ${name}..."
    
    cd "${INSTALL_DIR}/${key}"
    
    # 备份当前版本
    local timestamp=$(date +%Y%m%d_%H%M%S)
    tar -czf "${BACKUP_DIR}/${key}_${timestamp}.tar.gz" . 2>/dev/null || true
    
    # 拉取最新代码
    git pull origin main
    
    # 重新安装依赖
    case "$key" in
        open-webui|browser-use|comfyui|mlx|mlx-video)
            source venv/bin/activate
            pip install -e . --upgrade
            ;;
        sillytavern|continue-dev)
            npm install
            ;;
        faas)
            # FaaS 更新 CLI
            arkade get faas-cli
            ;;
    esac
    
    log_success "${name} 更新完成"
}

rollback_component() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    
    log_info "=== ${name} 版本回退 ==="
    
    # 列出可用备份
    local backups=($(ls -t "${BACKUP_DIR}/${key}_"*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_error "没有可用的备份版本"
        return 1
    fi
    
    echo "可用备份:"
    for i in "${!backups[@]}"; do
        local filename=$(basename "${backups[$i]}")
        echo "  $((i+1)). ${filename}"
    done
    
    read -p "选择要回退的版本 (1-${#backups[@]}): " choice
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        local selected="${backups[$((choice-1))]}"
        
        # 停止服务
        stop_service "$key"
        
        # 恢复备份
        cd "${INSTALL_DIR}/${key}"
        tar -xzf "${selected}"
        
        log_success "${name} 已回退到备份版本"
    else
        log_error "无效选择"
    fi
}

update_frontend() {
    log_info "更新所有前端组件..."
    
    local frontend_components=("open-webui" "sillytavern" "continue-dev" "comfyui")
    for key in "${frontend_components[@]}"; do
        if [ -d "${INSTALL_DIR}/${key}" ]; then
            update_component "$key"
        fi
    done
}

update_agents() {
    log_info "更新所有 Agent 组件..."
    
    local agent_components=("browser-use" "faas" "mlx")
    for key in "${agent_components[@]}"; do
        if [ -d "${INSTALL_DIR}/${key}" ]; then
            update_component "$key"
        fi
    done
}

update_models() {
    log_info "更新模型相关组件..."
    
    local model_components=("mlx" "mlx-video" "comfyui")
    for key in "${model_components[@]}"; do
        if [ -d "${INSTALL_DIR}/${key}" ]; then
            update_component "$key"
        fi
    done
}

# =============================================================================
# 状态查看
# =============================================================================
show_status() {
    log_info "=== 组件状态 ==="
    echo ""
    
    printf "%-20s %-10s %-10s %-20s\n" "组件" "状态" "端口" "进程"
    printf "%-20s %-10s %-10s %-20s\n" "--------------------" "----------" "----------" "--------------------"
    
    for key in "${!COMPONENTS[@]}"; do
        IFS='|' read -r name _ port _ <<< "${COMPONENTS[$key]}"
        
        local status="未安装"
        local pid_info="-"
        
        if [ -d "${INSTALL_DIR}/${key}" ]; then
            status="已安装"
        fi
        
        if [ -f "${LOG_DIR}/${key}.pid" ]; then
            local pid=$(cat "${LOG_DIR}/${key}.pid")
            if kill -0 "$pid" 2>/dev/null; then
                status="运行中"
                pid_info="PID: ${pid}"
            else
                status="已停止"
            fi
        fi
        
        printf "%-20s %-10s %-10s %-20s\n" "$name" "$status" "$port" "$pid_info"
    done
    echo ""
    
    echo "内存使用:"
    ps aux | grep -E "(node|python)" | grep -v grep | awk '{printf "  %-30s %s MB\n", $11, $6/1024}'
    echo ""
}

# =============================================================================
# 卸载功能
# =============================================================================
uninstall_component() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    
    log_info "卸载 ${name}..."
    
    # 停止服务
    stop_service "$key"
    
    # 删除目录
    rm -rf "${INSTALL_DIR}/${key}"
    rm -f "${LOG_DIR}/${key}."*
    
    log_success "${name} 已卸载"
}

uninstall_all() {
    log_warn "=== 警告：这将卸载所有组件并删除所有数据 ==="
    read -p "确定要继续吗？(yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        stop_all_services
        
        for key in "${!COMPONENTS[@]}"; do
            uninstall_component "$key"
        done
        
        rm -rf "${INSTALL_DIR}"
        log_success "所有组件已卸载"
    else
        log_info "取消卸载"
    fi
}

# =============================================================================
# 菜单系统
# =============================================================================
show_menu() {
    clear
    echo "=================================================="
    echo "         AI Studio Manager v${SCRIPT_VERSION}"
    echo "=================================================="
    echo ""
    echo "📦 部署管理:"
    echo "  1. 首次部署 (全部)"
    echo "  2. 选择性部署"
    echo ""
    echo "🚀 服务管理:"
    echo "  3. 启动所有服务"
    echo "  4. 停止所有服务"
    echo "  5. 启动单个服务"
    echo "  6. 停止单个服务"
    echo ""
    echo "📊 状态与诊断:"
    echo "  7. 查看状态"
    echo "  8. 简单诊断"
    echo "  9. 深度诊断"
    echo ""
    echo "🔄 更新管理:"
    echo "  10. 更新全部"
    echo "  11. 更新前端"
    echo "  12. 更新 Agent"
    echo "  13. 更新架构及模型"
    echo "  14. 版本回退"
    echo ""
    echo "🗑️  清理:"
    echo "  15. 卸载单个组件"
    echo "  16. 完全卸载"
    echo ""
    echo "  0. 退出"
    echo "=================================================="
    echo ""
}

select_component() {
    echo "可用组件:"
    local keys=("${!COMPONENTS[@]}")
    for i in "${!keys[@]}"; do
        IFS='|' read -r name _ _ _ <<< "${COMPONENTS[${keys[$i]}]}"
        echo "  $((i+1)). ${name}"
    done
    echo ""
    read -p "选择组件编号: " choice
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#keys[@]}" ]; then
        echo "${keys[$((choice-1))]}"
    else
        echo ""
    fi
}

# =============================================================================
# 主程序
# =============================================================================
main() {
    while true; do
        show_menu
        read -p "请选择操作 [0-16]: " choice
        
        case "$choice" in
            1)
                log_info "开始首次部署所有组件..."
                check_dependencies
                for key in "${!COMPONENTS[@]}"; do
                    deploy_component "$key"
                done
                log_success "首次部署完成！"
                ;;
            2)
                local key=$(select_component)
                if [ -n "$key" ]; then
                    check_dependencies
                    deploy_component "$key"
                else
                    log_error "无效选择"
                fi
                ;;
            3)
                start_all_services
                ;;
            4)
                stop_all_services
                ;;
            5)
                local key=$(select_component)
                if [ -n "$key" ]; then
                    start_service "$key"
                else
                    log_error "无效选择"
                fi
                ;;
            6)
                local key=$(select_component)
                if [ -n "$key" ]; then
                    stop_service "$key"
                else
                    log_error "无效选择"
                fi
                ;;
            7)
                show_status
                ;;
            8)
                diagnose_simple
                ;;
            9)
                diagnose_deep
                ;;
            10)
                for key in "${!COMPONENTS[@]}"; do
                    if [ -d "${INSTALL_DIR}/${key}" ]; then
                        update_component "$key"
                    fi
                done
                ;;
            11)
                update_frontend
                ;;
            12)
                update_agents
                ;;
            13)
                update_models
                ;;
            14)
                local key=$(select_component)
                if [ -n "$key" ]; then
                    rollback_component "$key"
                else
                    log_error "无效选择"
                fi
                ;;
            15)
                local key=$(select_component)
                if [ -n "$key" ]; then
                    uninstall_component "$key"
                else
                    log_error "无效选择"
                fi
                ;;
            16)
                uninstall_all
                ;;
            0)
                log_info "退出 AI Studio Manager"
                exit 0
                ;;
            *)
                log_error "无效选项，请重新选择"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 检查是否以交互方式运行
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "AI Studio Manager for macOS"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --deploy-all       首次部署所有组件"
    echo "  --start-all        启动所有服务"
    echo "  --stop-all         停止所有服务"
    echo "  --status           查看状态"
    echo "  --diagnose-simple  简单诊断"
    echo "  --diagnose-deep    深度诊断"
    echo "  --help, -h         显示帮助"
    echo ""
    exit 0
elif [[ "${1:-}" == "--deploy-all" ]]; then
    check_dependencies
    for key in "${!COMPONENTS[@]}"; do
        deploy_component "$key"
    done
elif [[ "${1:-}" == "--start-all" ]]; then
    start_all_services
elif [[ "${1:-}" == "--stop-all" ]]; then
    stop_all_services
elif [[ "${1:-}" == "--status" ]]; then
    show_status
elif [[ "${1:-}" == "--diagnose-simple" ]]; then
    diagnose_simple
elif [[ "${1:-}" == "--diagnose-deep" ]]; then
    diagnose_deep
else
    main
fi
