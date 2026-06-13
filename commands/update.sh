#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_update() {
    local targets=("$@")
    log_info "===== AI-Studio 更新 ====="; echo ""
    [[ ${#targets[@]} -eq 0 ]] && targets=("${REGISTERED_COMPONENTS[@]}")
    local updated=0
    for comp in "${targets[@]}"; do
        echo -e "${CLR_CYAN}>>> 更新 $comp${CLR_RESET}"
        is_comp_installed "$comp" || { log_warn "未安装,跳过"; continue; }
        comp_do "$comp" update && { ((updated++)); log_success "$comp 已更新"; } || log_error "$comp 更新失败"
    done
    echo ""; ((updated>0)) && success_box "更新 $updated 个组件" || log_info "无组件更新"
}
cmd_update "$@"
