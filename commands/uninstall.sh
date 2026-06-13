#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_uninstall() {
    local targets=("$@")
    log_info "===== AI-Studio 卸载 ====="; echo ""
    if [[ ${#targets[@]} -eq 0 ]]; then
        echo -e "${CLR_BOLD}选择卸载:${CLR_RESET}"
        echo -e "  ${CLR_RED}0)${CLR_RESET} 全部 (包括配置和数据)"; local i=1
        for comp in "${REGISTERED_COMPONENTS[@]}"; do printf "  ${CLR_RED}%d)${CLR_RESET} %s\n" "$i" "$comp"; ((i++)); done
        echo -en "${CLR_CYAN}请选择: ${CLR_RESET}"; read -r choice
        if [[ "$choice" == "0" ]]; then
            if confirm "${CLR_RED}确认卸载全部? 此操作不可恢复!${CLR_RESET}" "n"; then
                for comp in "${REGISTERED_COMPONENTS[@]}"; do is_running "$comp" && comp_do "$comp" stop; done
                for comp in "${REGISTERED_COMPONENTS[@]}"; do is_comp_installed "$comp" && comp_do "$comp" uninstall; done
                rm -rf "$AI_STUDIO_HOME"; success_box "已完全卸载 AI-Studio"
            fi; return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#REGISTERED_COMPONENTS[@]})); then targets=("${REGISTERED_COMPONENTS[$((choice-1))]}")
        else log_error "无效"; return 1; fi
    fi
    for comp in "${targets[@]}"; do
        echo -e "${CLR_CYAN}>>> 卸载 $comp${CLR_RESET}"
        is_comp_installed "$comp" || { log_warn "未安装"; continue; }
        is_running "$comp" && comp_do "$comp" stop
        if confirm "确认卸载 $comp?"; then
            comp_do "$comp" uninstall && { mark_comp_uninstalled "$comp"; log_success "$comp 已卸载"; } || log_error "$comp 卸载失败"
        fi
    done
}
cmd_uninstall "$@"
