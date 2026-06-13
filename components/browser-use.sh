#!/usr/bin/env bash
BROWSER_USE_COMP_NAME="browser-use"
BROWSER_USE_COMP_PORT="9222"
BROWSER_USE_COMP_DEPS="python3,pip3"
BROWSER_USE_COMP_DESC="AI 浏览器自动化 Agent"
BROWSER_USE_COMP_DIR="$AI_STUDIO_DATA_DIR/browser-use"
comp_install() {
    log_info "安装 Browser Use..."; require_command python3 || return 1
    mkdir -p "$BROWSER_USE_COMP_DIR"; python3 -m venv "$BROWSER_USE_COMP_DIR/venv" || return 1
    source "$BROWSER_USE_COMP_DIR/venv/bin/activate"; pip install --upgrade pip
    pip install browser-use playwright; playwright install chromium; deactivate
    set_comp_config browser-use PORT "$(get_config BROWSER_USE_PORT 9222)"
    set_comp_config browser-use DIR "$BROWSER_USE_COMP_DIR"
    log_success "Browser Use 安装完成"
}
comp_start() {
    local port; port="$(get_comp_config browser-use PORT 9222)"
    local dir; dir="$(get_comp_config browser-use DIR "$BROWSER_USE_COMP_DIR")"
    log_info "启动 Browser Use (CDP 端口: $port)..."; source "$dir/venv/bin/activate"
    local chrome_path=""
    [[ "$AI_STUDIO_OS" == "macos" ]] && chrome_path="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if [[ -x "$chrome_path" ]]; then
        nohup "$chrome_path" --remote-debugging-port="$port" --user-data-dir="$dir/chrome-profile" > "$AI_STUDIO_LOG_DIR/browser-use.log" 2>&1 &
        save_pid browser-use "$!"; log_success "Browser Use 已启动 (CDP: $port)"
    else
        log_warn "未找到 Chrome, 使用 Playwright"
        cat > "$dir/start_cdp.py" << 'PYEOF'
import asyncio, os
from playwright.async_api import async_playwright
async def main():
    p = await async_playwright().start()
    b = await p.chromium.launch(headless=False, args=[f"--remote-debugging-port={os.environ.get('PORT', '9222')}"])
    print(f"Browser started on port {os.environ.get('PORT', '9222')}")
    await asyncio.Event().wait()
asyncio.run(main())
PYEOF
        PORT="$port" nohup python3 "$dir/start_cdp.py" > "$AI_STUDIO_LOG_DIR/browser-use.log" 2>&1 &
        save_pid browser-use "$!"
    fi
    deactivate
}
comp_stop() { kill_service browser-use; }
comp_status() { is_running browser-use && { local port; port="$(get_comp_config browser-use PORT 9222)"; echo -e "  CDP: ws://localhost:$port"; }; }
comp_update() {
    local dir; dir="$(get_comp_config browser-use DIR "$BROWSER_USE_COMP_DIR")"
    log_info "更新 Browser Use..."; source "$dir/venv/bin/activate"
    pip install --upgrade browser-use playwright; playwright install chromium; deactivate
    log_success "Browser Use 已更新"
}
comp_uninstall() {
    log_info "卸载 Browser Use..."; is_running browser-use && kill_service browser-use
    rm -rf "$BROWSER_USE_COMP_DIR"; log_success "Browser Use 已卸载"
}
