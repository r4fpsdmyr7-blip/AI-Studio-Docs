#!/usr/bin/env bash
# =============================================================================
# macOS Local AI Stack Manager (Apple Silicon Optimized)
# Components: Open WebUI, SillyTavern, Continue.dev, Fazm, Browser-Use,
#             MLX, ComfyUI (SDXL/FLUX), MLX-Video, Ollama
# Author: AI Assistant
# =============================================================================

set -o pipefail
STACK_DIR="$HOME/.local/ai-stack"
VENV_DIR="$STACK_DIR/venv"
LOG_DIR="$STACK_DIR/logs"
PID_DIR="$STACK_DIR/pids"
CONFIG_FILE="$STACK_DIR/config.env"

# 端口定义
WEBUI_PORT=3000
ST_PORT=8000
COMFY_PORT=8188

# 颜色输出
GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; NC="\033[0m"

log() { echo -e "${CYAN}[AI-Stack]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# 依赖检查
check_dep() { command -v "$1" >/dev/null 2>&1 || error "Missing dependency: $1. Please install it first."; }

init_dirs() {
  mkdir -p "$STACK_DIR" "$LOG_DIR" "$PID_DIR" "$STACK_DIR/repos" "$STACK_DIR/models"
}

# =============================================================================
# 1. 首次部署
# =============================================================================
deploy_first_time() {
  log "🚀 开始首次部署 (Apple Silicon Optimized)..."
  init_dirs

  # 检查基础工具
  command -v brew >/dev/null 2>&1 || { error "Homebrew not found. Install it first."; }
  
  log "📦 安装系统依赖..."
  brew install --quiet git python@3.11 node tmux docker ollama wget curl

  log "🐍 配置 Python 虚拟环境..."
  python3.11 -m venv "$VENV_DIR"
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip setuptools wheel
  
  # 安装 AI 核心 Python 包
  log "📥 安装 MLX, Browser-Use, Fazm, MLX-Video 依赖..."
  pip install mlx mlx-lm mlx-whisper
  pip install browser-use fazm
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu # ComfyUI fallback
  pip install git+https://github.com/THUDM/MLX-Video.git

  log "🌐 克隆核心仓库..."
  cd "$STACK_DIR/repos"
  [ ! -d "ComfyUI" ] && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git
  [ ! -d "sillytavern" ] && git clone --depth 1 https://github.com/SillyTavern/SillyTavern.git
  
  # 安装 SillyTavern 依赖
  cd "$STACK_DIR/repos/sillytavern" && npm install --quiet

  log "📥 下载 ComfyUI 管理器及基础依赖..."
  cd "$STACK_DIR/repos/ComfyUI/custom_nodes"
  [ ! -d "ComfyUI-Manager" ] && git clone https://github.com/ltdrdata/ComfyUI-Manager.git

  log "🤖 配置 Ollama 后端..."
  brew services start ollama
  ollama pull qwen2.5:7b 2>/dev/null || true
  ollama pull llama3.2:3b 2>/dev/null || true

  log "🔌 安装 Continue.dev (VS Code 插件)..."
  if command -v code >/dev/null 2>&1; then
    code --install-extension continue.continue 2>/dev/null || warn "VS Code CLI not in PATH. Install Continue manually."
  else
    warn "VS Code CLI not found. Install Continue.dev manually from Marketplace."
  fi

  # 保存配置
  cat > "$CONFIG_FILE" <<EOF
OPEN_WEBUI_PORT=$WEBUI_PORT
SILLYTAVERN_PORT=$ST_PORT
COMFYUI_PORT=$COMFY_PORT
OLLAMA_URL=http://localhost:11434
DEPLOY_DATE=$(date +%F)
EOF
  success "首次部署完成！运行 ./ai-stack-manager.sh 进入主菜单。"
}

# =============================================================================
# 2. 启动服务 & 自动唤起浏览器
# =============================================================================
start_services() {
  log "⚡ 启动本地 AI 架构..."
  init_dirs

  # Ollama
  if ! pgrep -f "ollama serve" >/dev/null; then
    log "🧠 启动 Ollama..."
    nohup ollama serve > "$LOG_DIR/ollama.log" 2>&1 &
    sleep 2
  fi

  # Open WebUI (Docker)
  if ! docker ps | grep -q open-webui; then
    log "🌐 启动 Open WebUI (Docker)..."
    docker run -d --name open-webui --network=host -p $WEBUI_PORT:8080 \
      -v open-webui:/app/backend/data \
      -e OLLAMA_BASE_URL=http://localhost:11434 \
      ghcr.io/open-webui/open-webui:main
  fi

  # SillyTavern
  tmux has-session -t st-session 2>/dev/null || {
    log "🎭 启动 SillyTavern..."
    tmux new-session -d -s st-session "cd $STACK_DIR/repos/sillytavern && node server.js --listen $ST_PORT"
  }

  # ComfyUI
  tmux has-session -t comfy-session 2>/dev/null || {
    log "🎨 启动 ComfyUI..."
    source "$VENV_DIR/bin/activate"
    cd "$STACK_DIR/repos/ComfyUI"
    tmux new-session -d -s comfy-session "python main.py --port $COMFY_PORT --listen"
  }

  sleep 5
  log "🌍 自动唤起浏览器..."
  (sleep 8 && open "http://localhost:$WEBUI_PORT" "http://localhost:$ST_PORT" "http://localhost:$COMFY_PORT") &
  success "所有服务已启动！正在打开界面..."
}

# =============================================================================
# 3. 查看状态
# =============================================================================
check_status() {
  log "📊 服务状态检查："
  echo -e "-----------------------------"
  
  # Ollama
  if pgrep -f "ollama serve" >/dev/null; then success "Ollama: 运行中 (PID: $(pgrep -f 'ollama serve'))"; 
  else error "Ollama: 已停止"; fi

  # Docker
  if docker ps | grep -q open-webui; then success "Open WebUI: 运行中 (Port $WEBUI_PORT)";
  else error "Open WebUI: 已停止"; fi

  # SillyTavern
  if tmux has-session -t st-session 2>/dev/null; then success "SillyTavern: 运行中 (Port $ST_PORT)";
  else error "SillyTavern: 已停止"; fi

  # ComfyUI
  if tmux has-session -t comfy-session 2>/dev/null; then success "ComfyUI: 运行中 (Port $COMFY_PORT)";
  else error "ComfyUI: 已停止"; fi

  echo -e "-----------------------------"
  echo "🌐 访问地址:"
  echo "   Open WebUI : http://localhost:$WEBUI_PORT"
  echo "   SillyTavern: http://localhost:$ST_PORT"
  echo "   ComfyUI    : http://localhost:$COMFY_PORT"
  echo "   Continue   : VS Code 侧边栏 → Continue"
  echo "   Ollama API : http://localhost:11434"
}

# =============================================================================
# 4. 更新组件
# =============================================================================
update_components() {
  log "🔄 开始更新组件..."
  init_dirs
  
  echo "1) 更新前端 (Open WebUI / SillyTavern)"
  echo "2) 更新 Agent/架构 (MLX / Fazm / Browser-Use)"
  echo "3) 更新 ComfyUI & 插件"
  echo "4) 更新模型 (Ollama Pull)"
  echo "0) 返回主菜单"
  read -p "请选择 > " choice

  case $choice in
    1) docker pull ghcr.io/open-webui/open-webui:main
       cd "$STACK_DIR/repos/sillytavern" && git pull && npm install
       success "前端更新完成" ;;
    2) source "$VENV_DIR/bin/activate"
       pip install --upgrade mlx mlx-lm browser-use fazm
       success "Agent/架构更新完成" ;;
    3) cd "$STACK_DIR/repos/ComfyUI" && git pull
       cd custom_nodes/ComfyUI-Manager && git pull
       success "ComfyUI 更新完成" ;;
    4) echo "输入模型名 (如 qwen2.5:7b, flux.1-dev):"
       read model
       ollama pull "$model" 2>/dev/null || warn "模型拉取失败，请检查网络或模型名" ;;
    *) return ;;
  esac
  update_components
}

# =============================================================================
# 5. 自我诊断
# =============================================================================
self_diagnose() {
  log "🔍 系统诊断中..."
  echo -e "-----------------------------"
  
  # 硬件
  echo "🖥️ 芯片: $(sysctl -n machdep.cpu.brand_string | head -c 30)..."
  echo "💾 内存: $(vm_stat | awk '/Pages active/ {print $3 * 4096 / 1073741824 "GB"}')"
  echo "💿 磁盘剩余: $(df -h / | awk 'NR==2 {print $4}')"

  # 端口占用
  echo -e "-----------------------------"
  for port in 11434 $WEBUI_PORT $ST_PORT $COMFY_PORT; do
    if lsof -i :$port >/dev/null 2>&1; then success "端口 $port 已监听"; else warn "端口 $port 未监听"; fi
  done

  # API 测试
  echo -e "-----------------------------"
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags | grep -q 200; then
    success "Ollama API 响应正常"
  else
    error "Ollama API 无响应"
  fi

  # MPS 支持
  echo -e "-----------------------------"
  python3 -c "import torch; print('✅ MPS Available' if torch.backends.mps.is_available() else '⚠️ MPS Not Available')" 2>/dev/null || echo "⚠️ PyTorch 未加载或环境未激活"
}

# =============================================================================
# 6. 停止服务
# =============================================================================
stop_services() {
  log "🛑 正在安全停止所有服务..."
  
  # Docker
  docker stop open-webui 2>/dev/null || true
  docker rm open-webui 2>/dev/null || true
  
  # tmux
  tmux kill-session -t st-session 2>/dev/null || true
  tmux kill-session -t comfy-session 2>/dev/null || true
  
  # Ollama
  pkill -f "ollama serve" 2>/dev/null || true
  brew services stop ollama 2>/dev/null || true
  
  success "所有服务已停止。"
}

# =============================================================================
# 7. 彻底卸载
# =============================================================================
uninstall_all() {
  read -p "⚠️  警告：这将删除所有本地 AI 数据、模型及配置。确认继续？(y/N) " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { log "已取消卸载。"; return; }

  log "🗑️ 开始彻底清理..."
  stop_services
  
  # 删除目录
  rm -rf "$STACK_DIR"
  
  # 清理 Docker
  docker volume rm open-webui 2>/dev/null || true
  docker image rm ghcr.io/open-webui/open-webui:main 2>/dev/null || true
  
  # 清理 Ollama 模型 (谨慎)
  rm -rf ~/.ollama/models
  
  success "卸载完成。建议手动运行: brew uninstall ollama docker"
}

# =============================================================================
# 主菜单
# =============================================================================
main_menu() {
  while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗"
    echo "║           macOS Local AI Stack Manager v2.0              ║"
    echo "╚══════════════════════════════════════════════════════╝${NC}"
    echo "1) 🚀 首次部署 / 初始化"
    echo "2) ⚡ 启动服务 (自动开浏览器)"
    echo "3) 📊 查看状态"
    echo "4) 🔄 更新组件 (前端/Agent/模型)"
    echo "5) 🔍 自我诊断"
    echo "6) 🛑 停止服务"
    echo "7) 🗑️  彻底卸载"
    echo "0) 🚪 退出"
    echo "----------------------------------------"
    read -p "请选择操作 > " choice

    case $choice in
      1) deploy_first_time ;;
      2) start_services ;;
      3) check_status ;;
      4) update_components ;;
      5) self_diagnose ;;
      6) stop_services ;;
      7) uninstall_all ;;
      0) log "👋 再见！"; exit 0 ;;
      *) warn "无效输入，请重试。" ;;
    esac
    
    read -n1 -p "按任意键继续..." ; echo
  done
}

# 启动入口
if [[ "$1" == "--auto-start" ]]; then
  start_services
else
  main_menu
fi
