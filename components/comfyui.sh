#!/usr/bin/env bash
COMFYUI_COMP_NAME="comfyui"
COMFYUI_COMP_PORT="8188"
COMFYUI_COMP_DEPS="python3,pip3,git"
COMFYUI_COMP_DESC="节点式 AI 图像生成 (SDXL/FLUX)"
COMFYUI_COMP_DIR="$AI_STUDIO_DATA_DIR/comfyui"
comp_install() {
    log_info "安装 ComfyUI..."; require_command python3 || return 1; require_command git || return 1
    mkdir -p "$COMFYUI_COMP_DIR"
    [[ ! -d "$COMFYUI_COMP_DIR/ComfyUI" ]] && git clone "$(gh_url https://github.com/comfyanonymous/ComfyUI.git)" "$COMFYUI_COMP_DIR/ComfyUI" || return 1
    cd "$COMFYUI_COMP_DIR/ComfyUI"; python3 -m venv venv || return 1; source venv/bin/activate
    pip install --upgrade pip
    if is_apple_silicon; then pip install torch torchvision torchaudio
    else pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu; fi
    pip install -r requirements.txt
    [[ ! -d "custom_nodes/ComfyUI-Manager" ]] && { cd custom_nodes; git clone "$(gh_url https://github.com/ltdrdata/ComfyUI-Manager.git)" || true; cd - >/dev/null; }
    deactivate; cd - >/dev/null
    mkdir -p "$COMFYUI_COMP_DIR/ComfyUI/models"/{checkpoints,loras,vae,controlnet,clip}
    set_comp_config comfyui PORT "$(get_config COMFYUI_PORT 8188)"; set_comp_config comfyui DIR "$COMFYUI_COMP_DIR/ComfyUI"
    log_success "ComfyUI 安装完成"
}
comp_start() {
    local port; port="$(get_comp_config comfyui PORT 8188)"
    local dir; dir="$(get_comp_config comfyui DIR "$COMFYUI_COMP_DIR/ComfyUI")"
    log_info "启动 ComfyUI (端口: $port)..."; cd "$dir"; source venv/bin/activate
    local args="--listen 0.0.0.0 --port $port"; is_apple_silicon && args="$args --force-fp16"
    nohup python3 main.py $args > "$AI_STUDIO_LOG_DIR/comfyui.log" 2>&1 &
    local pid=$!; deactivate; cd - >/dev/null; save_pid comfyui "$pid"
    log_success "ComfyUI 已启动 (PID: $pid)"; auto_open_browser comfyui "$port"
}
comp_stop() { kill_service comfyui; }
comp_status() {
    is_running comfyui && { local port; port="$(get_comp_config comfyui PORT 8188)"; echo -e "  Web UI: http://localhost:$port"; }
    local dir; dir="$(get_comp_config comfyui DIR "$COMFYUI_COMP_DIR/ComfyUI")"
    [[ -d "$dir/models/checkpoints" ]] && echo -e "  Checkpoints: $(ls -1 "$dir/models/checkpoints" 2>/dev/null | wc -l | xargs) 个"
}
comp_update() {
    local dir; dir="$(get_comp_config comfyui DIR "$COMFYUI_COMP_DIR/ComfyUI")"
    log_info "更新 ComfyUI..."; cd "$dir"; git pull; source venv/bin/activate
    pip install -r requirements.txt --upgrade; cd custom_nodes/ComfyUI-Manager && git pull && cd - >/dev/null
    deactivate; cd - >/dev/null; log_success "ComfyUI 已更新"
}
comp_download_model() {
    local model="${1:-}"; [[ -z "$model" ]] && { log_error "用法: download_model <name>"; return 1; }
    local dir; dir="$(get_comp_config comfyui DIR "$COMFYUI_COMP_DIR/ComfyUI")"; local ckpt_dir="$dir/models/checkpoints"
    log_info "下载模型: $model"; source "$dir/venv/bin/activate"
    python3 -c "
from huggingface_hub import hf_hub_download
model_id = '$model'
if '/' in model_id:
    repo, fname = model_id.rsplit('/', 1)
    path = hf_hub_download(repo_id=repo, filename=fname + '.safetensors', local_dir='$ckpt_dir')
    print(f'下载到: {path}')
else: print('请提供完整 HF 路径: repo/filename')
" 2>/dev/null || log_error "下载失败"; deactivate
}
comp_uninstall() {
    log_info "卸载 ComfyUI..."; is_running comfyui && kill_service comfyui
    if confirm "删除所有模型?"; then rm -rf "$COMFYUI_COMP_DIR"; else rm -rf "$COMFYUI_COMP_DIR/ComfyUI"; fi
    log_success "ComfyUI 已卸载"
}
