#!/usr/bin/env bash
OPEN_WEBUI_COMP_NAME="open-webui"
OPEN_WEBUI_COMP_PORT="3000"
OPEN_WEBUI_COMP_DEPS="python3,pip3"
OPEN_WEBUI_COMP_DESC="AI 聊天界面 (支持 Ollama/OpenAI)"
OPEN_WEBUI_COMP_DIR="$AI_STUDIO_DATA_DIR/open-webui"
comp_install() {
    log_info "安装 Open WebUI..."; mkdir -p "$OPEN_WEBUI_COMP_DIR"
    require_command python3 "brew install python" || return 1
    python3 -m venv "$OPEN_WEBUI_COMP_DIR/venv" || return 1
    source "$OPEN_WEBUI_COMP_DIR/venv/bin/activate"
    pip install --upgrade pip; pip install open-webui; deactivate
    set_comp_config open-webui PORT "$(get_config OPEN_WEBUI_PORT 3000)"
    set_comp_config open-webui DATA_DIR "$OPEN_WEBUI_COMP_DIR"
    log_success "Open WebUI 安装完成"
}
comp_start() {
    local port; port="$(get_comp_config open-webui PORT 3000)"
    local data_dir; data_dir="$(get_comp_config open-webui DATA_DIR "$OPEN_WEBUI_COMP_DIR")"
    log_info "启动 Open WebUI (端口: $port)..."
    source "$data_dir/venv/bin/activate"
    DATA_DIR="$data_dir" PORT="$port" nohup open-webui serve > "$AI_STUDIO_LOG_DIR/open-webui.log" 2>&1 &
    local pid=$!; deactivate; save_pid open-webui "$pid"
    log_success "Open WebUI 已启动 (PID: $pid)"; auto_open_browser open-webui "$port"
}
comp_stop() { log_info "停止 Open WebUI..."; kill_service open-webui; }
comp_status() { is_running open-webui && { local port; port="$(get_comp_config open-webui PORT 3000)"; echo -e "  Web UI: http://localhost:$port"; echo -e "  API:    http://localhost:$port/api"; }; }
comp_update() {
    local data_dir; data_dir="$(get_comp_config open-webui DATA_DIR "$OPEN_WEBUI_COMP_DIR")"
    log_info "更新 Open WebUI..."; source "$data_dir/venv/bin/activate"
    pip install --upgrade open-webui; deactivate; log_success "Open WebUI 已更新"
}
comp_uninstall() {
    log_info "卸载 Open WebUI..."; is_running open-webui && kill_service open-webui
    rm -rf "$OPEN_WEBUI_COMP_DIR"; log_success "Open WebUI 已卸载"
}
