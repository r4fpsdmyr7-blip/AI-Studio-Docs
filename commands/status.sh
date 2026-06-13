#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_status() {
    local target="${1:-}"
    log_info "===== AI-Studio 状态 ====="; echo ""
    if [[ -n "$target" && "$target" != "all" ]]; then
        component_exists "$target" || { log_error "未知: $target"; return 1; }
        local port desc; port="$(get_comp_info "$target" "PORT")"; desc="$(get_comp_info "$target" "DESC")"
        info_box "组件: $target"
        echo -e "  描述: $desc"; echo -e "  端口: ${port:-N/A}"
        is_comp_installed "$target" && echo -e "  安装: ${CLR_GREEN}已安装${CLR_RESET}" || echo -e "  安装: ${CLR_RED}未安装${CLR_RESET}"
        if is_running "$target"; then
            local pid; pid="$(get_pid "$target")"
            echo -e "  状态: ${CLR_GREEN}● 运行中${CLR_RESET} (PID: $pid)"; echo -e "  URL:  http://localhost:${port:-?}"
        else echo -e "  状态: ${CLR_RED}○ 已停止${CLR_RESET}"; fi
        echo ""; comp_do "$target" status 2>/dev/null || true
    else
        get_all_status
        info_box "系统"
        echo -e "  平台: $AI_STUDIO_OS / $AI_STUDIO_ARCH"
        is_apple_silicon && echo -e "  芯片: ${CLR_GREEN}Apple Silicon${CLR_RESET}" || echo -e "  芯片: Intel"
        echo -e "  数据: $AI_STUDIO_DATA_DIR"
        [[ -d "$AI_STUDIO_DATA_DIR" ]] && echo -e "  大小: $(du -sh "$AI_STUDIO_DATA_DIR" 2>/dev/null | cut -f1)"
    fi; echo ""
}
cmd_status "$@"
