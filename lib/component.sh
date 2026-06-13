#!/usr/bin/env bash
declare -a REGISTERED_COMPONENTS=()
register_component() { local n="$1"; [[ ! " ${REGISTERED_COMPONENTS[*]} " =~ " ${n} " ]] && { REGISTERED_COMPONENTS+=("$n"); log_debug "注册: $n"; }; }
load_component() {
    local f="$AI_STUDIO_COMPONENTS_DIR/${1}.sh"
    [[ -f "$f" ]] && { source "$f"; register_component "$1"; return 0; }
    log_error "组件不存在: $1"; return 1
}
load_all_components() {
    for f in "$AI_STUDIO_COMPONENTS_DIR"/*.sh; do
        [[ -f "$f" ]] && { source "$f"; register_component "$(basename "$f" .sh)"; }
    done
    log_debug "已加载 ${#REGISTERED_COMPONENTS[@]} 个组件"
}
get_comp_info() { local var="${1^^}_COMP_${2}"; var="${var//-/_}"; echo "${!var:-}"; }
comp_do() {
    local name="$1" action="$2"; shift 2
    component_exists "$name" || load_component "$name" || return 1
    local func="comp_${action}"
    declare -f "$func" &>/dev/null || { log_error "$name 不支持: $action"; return 1; }
    export CURRENT_COMPONENT="$name"
    comp_log "$name" "INFO" "操作: $action"
    "$func" "$@"; local rc=$?
    comp_log "$name" "INFO" "完成: $action (rc=$rc)"; return $rc
}
comp_do_all() {
    local action="$1"; shift; local failed=0
    for comp in "${REGISTERED_COMPONENTS[@]}"; do
        echo -e "\n${CLR_CYAN}>>> $comp${CLR_RESET}"
        comp_do "$comp" "$action" "$@" || ((failed++))
    done
    return $failed
}
comp_do_selected() {
    local action="$1"; shift
    [[ $# -eq 0 || "${1:-}" == "all" ]] && { comp_do_all "$action"; return $?; }
    local failed=0
    for comp in "$@"; do echo -e "\n${CLR_CYAN}>>> $comp${CLR_RESET}"; comp_do "$comp" "$action" || ((failed++)); done
    return $failed
}
component_exists() { [[ " ${REGISTERED_COMPONENTS[*]} " =~ " ${1} " ]]; }
get_all_status() {
    echo ""; print_table_row "组件" "状态" "端口" "URL"; show_separator "-"
    for name in "${REGISTERED_COMPONENTS[@]}"; do
        local port; port="$(get_comp_info "$name" "PORT")"
        if is_running "$name"; then
            print_table_row "$name" "${CLR_GREEN}● 运行中${CLR_RESET}" "${port:-N/A}" "http://localhost:${port:-?}"
        else
            print_table_row "$name" "${CLR_RED}○ 已停止${CLR_RESET}" "${port:-N/A}" "-"
        fi
    done; echo ""
}
is_comp_installed() { [[ -f "$AI_STUDIO_DATA_DIR/${1}/.installed" ]]; }
mark_comp_installed() { mkdir -p "$AI_STUDIO_DATA_DIR/${1}"; echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$AI_STUDIO_DATA_DIR/${1}/.installed"; }
mark_comp_uninstalled() { rm -f "$AI_STUDIO_DATA_DIR/${1}/.installed"; }
auto_open_browser() {
    local name="$1" port="$2"
    [[ "$(get_config GLOBAL_AUTO_OPEN_BROWSER true)" == "true" && -n "$port" ]] || return 0
    sleep 2; wait_for_service "http://localhost:$port" 30 "$name" && open_browser "http://localhost:$port"
}
install_comp_deps() {
    local deps; deps="$(get_comp_info "$1" "DEPS")"; [[ -z "$deps" ]] && return 0
    IFS=',' read -ra arr <<< "$deps"
    for dep in "${arr[@]}"; do
        dep="$(echo "$dep" | xargs)"; check_command "$dep" && continue
        log_warn "安装依赖: $dep"
        case "$dep" in
            python3) [[ "$AI_STUDIO_OS" == "macos" ]] && brew install python 2>/dev/null || true ;;
            node|npm) [[ "$AI_STUDIO_OS" == "macos" ]] && brew install node 2>/dev/null || true ;;
            git) [[ "$AI_STUDIO_OS" == "macos" ]] && { xcode-select --install 2>/dev/null || brew install git 2>/dev/null; } || true ;;
            *) log_warn "请手动安装: $dep" ;;
        esac
    done
}
