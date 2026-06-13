#!/usr/bin/env bash
###############################################################################
# ai-studio.sh - macOS MLX AI Studio 全生命周期管理脚本
# 功能：首次部署 | 日常启动(自动开浏览器) | 状态查看 | 架构/模型更新 | 自我修复 | 停止 | 卸载
# 架构：MLX (Apple Silicon) + Pi Agent + Qwen (文本) + Stable Diffusion (图像)
# 兼容：macOS 13+ / Apple Silicon (M1/M2/M3/M4)
###############################################################################

set -euo pipefail

# ================= 配置区 =================
INSTALL_DIR="${HOME}/ai-studio"
VENV_DIR="${INSTALL_DIR}/venv"
MODELS_DIR="${INSTALL_DIR}/models"
LOG_DIR="${INSTALL_DIR}/logs"
LOG_FILE="${LOG_DIR}/studio.log"
PID_FILE="${INSTALL_DIR}/.studio.pid"
SERVER_HOST="127.0.0.1"
SERVER_PORT="7860"

# 模型与依赖配置 (可根据实际HF仓库修改)
QWEN_MODEL="mlx-community/Qwen2.5-7B-Instruct-4bit"
SD_MODEL="stabilityai/stable-diffusion-2-1"
PI_AGENT_PKG="pi-agent"  # 若为私有仓库，可改为 git clone 逻辑
PYTHON_BIN="python3.11"

# ================= 工具函数 =================
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg" | tee -a "$LOG_FILE"
}

check_arm64() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    log "❌ 错误: MLX 仅支持 Apple Silicon (M1/M2/M3/M4)。当前架构: $(uname -m)"
    exit 1
  fi
}

check_brew() {
  if ! command -v brew &>/dev/null; then
    log "⚙️  Homebrew 未安装，正在自动安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

activate_venv() {
  if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    log "❌ 虚拟环境不存在，请先运行 './ai-studio.sh setup'"
    exit 1
  fi
  source "${VENV_DIR}/bin/activate"
}

get_server_pid() {
  lsof -ti:${SERVER_PORT} 2>/dev/null || echo ""
}

# ================= 核心功能 =================
do_setup() {
  [[ -d "$INSTALL_DIR" ]] && log "⚠️  检测到已有安装目录，将执行覆盖部署..."
  mkdir -p "$MODELS_DIR" "$LOG_DIR"

  check_arm64
  check_brew

  log "⚙️  安装系统依赖 (Python, Git, LFS, HuggingFace CLI)..."
  brew install --quiet "${PYTHON_BIN}" git git-lfs || true
  git lfs install

  log "⚙️  创建 Python 虚拟环境..."
  "${PYTHON_BIN}" -m venv "$VENV_DIR"
  activate_venv

  log "⚙️  安装 Python 依赖包..."
  pip install --quiet --upgrade pip
  pip install --quiet \
    mlx \
    mlx-vlm \
    huggingface-hub \
    gradio \
    fastapi \
    uvicorn \
    requests \
    pi-agent 2>/dev/null || log "⚠️  Pi Agent 包安装跳过/警告，请确认包名或替换为 git clone 逻辑"

  log "⚙️  预加载模型 (Qwen + SD)..."
  huggingface-cli download "$QWEN_MODEL" --local-dir "${MODELS_DIR}/qwen" --local-dir-use-symlinks False --resume-download
  huggingface-cli download "$SD_MODEL" --local-dir "${MODELS_DIR}/sd" --local-dir-use-symlinks False --resume-download

  log "⚙️  生成桥接服务脚本 (app.py)..."
  cat > "${INSTALL_DIR}/app.py" << 'PYEOF'
import gradio as gr
import subprocess
import json
import os
from mlx_vlm import generate, load_model
from diffusers import StableDiffusionPipeline

# 初始化模型 (懒加载节省内存)
qwen_pipe = None
sd_pipe = None

def load_models():
    global qwen_pipe, sd_pipe
    if qwen_pipe is None:
        qwen_pipe = load_model(os.environ.get("QWEN_PATH", "./models/qwen"))
    if sd_pipe is None:
        sd_pipe = StableDiffusionPipeline.from_pretrained(os.environ.get("SD_PATH", "./models/sd"))
        sd_pipe.to("mps")  # MLX 加速

def process_input(user_input):
    load_models()
    # 简单意图识别：包含"画"/"image"/"生成图片"等关键词时调用SD，否则走Qwen
    keywords = ["画", "image", "图片", "生成图", "绘图"]
    if any(kw in user_input for kw in keywords):
        prompt = user_input.replace("画", "").replace("图片", "").strip()
        img = sd_pipe(prompt).images[0]
        return None, img
    else:
        # 调用 Qwen 生成文本
        response = generate(qwen_pipe, user_input, max_tokens=512)
        return response, None

with gr.Blocks(title="AI Studio (MLX + Qwen + SD)") as demo:
    gr.Markdown("### 🍎 MLX AI Studio | Qwen 文本 + Stable Diffusion 绘图")
    with gr.Row():
        inp = gr.Textbox(label="输入提示词 (含'画'字自动切换绘图模式)", lines=2)
        btn = gr.Button("运行")
    with gr.Row():
        out_text = gr.Textbox(label="Qwen 回复")
        out_img = gr.Image(label="生成图像")
    btn.click(process_input, inp, [out_text, out_img])

if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=7860)
PYEOF

  log "✅ 首次部署完成！运行 './ai-studio.sh start' 启动服务。"
}

do_start() {
  pid=$(get_server_pid)
  if [[ -n "$pid" ]]; then
    log "⚠️  服务已在运行 (PID: $pid)。正在打开浏览器..."
    open "http://${SERVER_HOST}:${SERVER_PORT}" &
    return 0
  fi

  activate_venv
  export QWEN_PATH="${MODELS_DIR}/qwen"
  export SD_PATH="${MODELS_DIR}/sd"

  log "🚀 启动 AI Studio 服务 (端口 ${SERVER_PORT})..."
  cd "$INSTALL_DIR"
  nohup python app.py > "${LOG_DIR}/server.out" 2>&1 &
  echo $! > "$PID_FILE"

  # 等待服务就绪
  log "⏳ 等待服务启动..."
  for i in {1..30}; do
    if lsof -i:${SERVER_PORT} >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if lsof -i:${SERVER_PORT} >/dev/null 2>&1; then
    log "✅ 服务启动成功！正在自动打开浏览器..."
    open "http://${SERVER_HOST}:${SERVER_PORT}" &
  else
    log "❌ 服务启动失败，请查看日志: ${LOG_DIR}/server.out"
    exit 1
  fi
}

do_status() {
  pid=$(get_server_pid)
  if [[ -z "$pid" ]]; then
    log "🔴 服务状态: 未运行"
  else
    mem=$(ps -p "$pid" -o rss= | awk '{printf "%.1f MB", $1/1024}')
    log "🟢 服务状态: 运行中 (PID: $pid | 内存占用: $mem)"
  fi
  log "📦 虚拟环境: $([ -d "$VENV_DIR" ] && echo '✅ 已就绪' || echo '❌ 未安装')"
  log "📦 模型目录: $([ -d "$MODELS_DIR/qwen" ] && [ -d "$MODELS_DIR/sd" ] && echo '✅ 已下载' || echo '❌ 缺失')"
  log "📄 最近日志:"
  tail -n 5 "$LOG_FILE" 2>/dev/null || echo "(无)"
}

do_update() {
  log "🔄 检查并更新依赖与模型..."
  activate_venv
  pip install --quiet --upgrade mlx mlx-vlm gradio huggingface-hub
  log "⏬ 同步 Qwen 模型更新..."
  huggingface-cli download "$QWEN_MODEL" --local-dir "${MODELS_DIR}/qwen" --local-dir-use-symlinks False --resume-download
  log "⏬ 同步 SD 模型更新..."
  huggingface-cli download "$SD_MODEL" --local-dir "${MODELS_DIR}/sd" --local-dir-use-symlinks False --resume-download
  log "✅ 更新完成。若需生效，请执行 './ai-studio.sh stop && ./ai-studio.sh start'"
}

do_repair() {
  log "🛠️ 开始自我修复流程..."
  # 1. 停止旧进程
  do_stop 2>/dev/null || true

  # 2. 清理损坏的虚拟环境
  if [[ -d "$VENV_DIR" ]]; then
    log "🗑️  重建虚拟环境..."
    rm -rf "$VENV_DIR"
    "${PYTHON_BIN}" -m venv "$VENV_DIR"
    activate_venv
    pip install --quiet --upgrade pip
  fi

  # 3. 修复权限与缓存
  log "🧹 清理 HuggingFace 损坏缓存..."
  rm -rf ~/.cache/huggingface/hub/*.tmp 2>/dev/null || true
  chmod -R u+rw "$INSTALL_DIR"

  # 4. 重新验证核心包
  log "📦 验证核心包完整性..."
  pip install --quiet --force-reinstall mlx gradio
  log "✅ 修复完成。请运行 './ai-studio.sh start' 测试。"
}

do_stop() {
  pid=$(get_server_pid)
  if [[ -z "$pid" ]]; then
    log "ℹ️  服务未运行。"
    return 0
  fi
  log "🛑 正在停止服务 (PID: $pid)..."
  kill "$pid" 2>/dev/null || true
  sleep 2
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  log "✅ 服务已停止。"
}

do_uninstall() {
  read -r -p "⚠️  确认彻底卸载 AI Studio？(删除所有模型/环境/配置) [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 0

  do_stop 2>/dev/null || true
  log "🗑️  正在删除安装目录..."
  rm -rf "$INSTALL_DIR"
  log "🗑️  清理全局缓存 (可选)..."
  rm -rf ~/.cache/huggingface 2>/dev/null || true
  log "✅ 卸载完成。"
}

# ================= 交互菜单 =================
show_menu() {
  echo "========================================="
  echo " 🍎 AI Studio (MLX) 管理控制台"
  echo "========================================="
  echo " 1) 首次部署 (Setup)"
  echo " 2) 启动服务 & 自动打开浏览器 (Start)"
  echo " 3) 查看运行状态 (Status)"
  echo " 4) 更新 MLX 架构与模型 (Update)"
  echo " 5) 自我修复 (Repair)"
  echo " 6) 停止服务 (Stop)"
  echo " 7) 彻底卸载 (Uninstall)"
  echo " 0) 退出"
  echo "========================================="
  read -r -p "请输入选项 [0-7]: " choice
  case $choice in
    1) do_setup ;;
    2) do_start ;;
    3) do_status ;;
    4) do_update ;;
    5) do_repair ;;
    6) do_stop ;;
    7) do_uninstall ;;
    0) exit 0 ;;
    *) echo "❌ 无效选项"; sleep 1; show_menu ;;
  esac
}

# ================= 入口 =================
main() {
  [[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"

  if [[ $# -eq 0 ]]; then
    show_menu
  else
    case "$1" in
      setup)   do_setup ;;
      start)   do_start ;;
      status)  do_status ;;
      update)  do_update ;;
      repair)  do_repair ;;
      stop)    do_stop ;;
      uninstall) do_uninstall ;;
      *) echo "用法: $0 [setup|start|status|update|repair|stop|uninstall]"; exit 1 ;;
    esac
  fi
}

main "$@"
