#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_start() {
    local targets=("$@")
    log_info "===== AI-Studio 启动 ====="; echo ""
    if [[ ${#targets[@]} -eq 0 ]]; then
        echo -e "${CLR_BOLD}选择启动:${CLR_RESET}"; echo -e "  ${CLR_YELLOW}0)${CLR_RESET} 全部"; local i=1
        for comp in "${REGISTERED_COMPONENTS[@]}"; do
            local st; is_running "$comp" && st="${CLR_GREEN}●${CLR_RESET}" || { is_comp_installed "$comp" && st="${CLR_YELLOW}○${CLR_RESET}" || st="${CLR_DIM}○${CLR_RESET}"; }
            printf "  ${CLR_YELLOW}%d)${CLR_RESET} %-15s %s\n" "$i" "$comp" "$st"; ((i++))
        done
        echo -en "${CLR_CYAN}请选择: ${CLR_RESET}"; read -r choice
        if [[ "$choice" == "0" ]]; then targets=("${REGISTERED_COMPONENTS[@]}")
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#REGISTERED_COMPONENTS[@]})); then targets=("${REGISTERED_COMPONENTS[$((choice-1))]}")
        else log_error "无效"; return 1; fi
    fi
    local started=0 urls=()
    for comp in "${targets[@]}"; do
        echo -e "${CLR_CYAN}>>> 启动 $comp${CLR_RESET}"
        is_comp_installed "$comp" || { log_warn "未安装"; continue; }
        is_running "$comp" && { log_warn "已运行"; local p; p="$(get_comp_info "$comp" "PORT")"; [[ -n "$p" ]] && urls+=("http://localhost:$p"); continue; }
        local port; port="$(get_comp_info "$comp" "PORT")"
        if [[ -n "$port" ]]; then
            local ap; ap="$(handle_port_conflict "$port" "$comp")"
            [[ "$ap" != "$port" ]] && { set_comp_config "$comp" PORT "$ap"; port="$ap"; }
        fi
        comp_do "$comp" start && { ((started++)); log_success "$comp 启动"; [[ -n "$port" ]] && urls+=("http://localhost:$port"); } || log_error "$comp 失败"
    done
    echo ""; ((started>0)) && { success_box "启动 $started 个服务"
        [[ "$(get_config GLOBAL_AUTO_OPEN_BROWSER true)" == "true" && ${#urls[@]} -gt 0 ]] && { sleep 3; for u in "${urls[@]}"; do open_browser "$u"; done; }
    } || log_info "无服务启动"
}
cmd_start "$@"
