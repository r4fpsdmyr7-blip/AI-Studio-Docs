#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_stop() {
    local targets=("$@")
    log_info "===== AI-Studio 停止 ====="; echo ""
    if [[ ${#targets[@]} -eq 0 ]]; then
        echo -e "${CLR_BOLD}选择停止:${CLR_RESET}"; echo -e "  ${CLR_YELLOW}0)${CLR_RESET} 全部"; local i=1
        for comp in "${REGISTERED_COMPONENTS[@]}"; do
            is_running "$comp" && printf "  ${CLR_YELLOW}%d)${CLR_RESET} %-15s ${CLR_GREEN}●${CLR_RESET}\n" "$i" "$comp" || printf "  ${CLR_DIM}%d)  %-15s ○${CLR_RESET}\n" "$i" "$comp"
            ((i++))
        done
        echo -en "${CLR_CYAN}请选择: ${CLR_RESET}"; read -r choice
        if [[ "$choice" == "0" ]]; then targets=("${REGISTERED_COMPONENTS[@]}")
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#REGISTERED_COMPONENTS[@]})); then targets=("${REGISTERED_COMPONENTS[$((choice-1))]}")
        else log_error "无效"; return 1; fi
    fi
    local stopped=0
    for comp in "${targets[@]}"; do
        echo -e "${CLR_CYAN}>>> 停止 $comp${CLR_RESET}"
        is_running "$comp" || { log_warn "未运行"; continue; }
        comp_do "$comp" stop && { ((stopped++)); log_success "$comp 已停"; } || log_error "$comp 失败"
    done
    echo ""; ((stopped>0)) && success_box "停止 $stopped 个" || log_info "无运行服务"
}
cmd_stop "$@"
