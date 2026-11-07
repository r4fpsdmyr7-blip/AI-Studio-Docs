#!/bin/bash

# ============================================================================
# AI Studio - ComfyUI Status Script
# File: components/comfyui/status.sh
#
# Structured overview of the component state: installation, process health,
# port binding, and recent log activity.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

APP_DIR="${COMPONENT_DIR}/app"

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_STATUS "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # --- Check 1: Installation Status ---
    if [[ ! -f "${APP_DIR}/main.py" ]] || [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        echo -e "  [${COLOR_RED}$(msg STATUS_NOT_INSTALLED_TAG)${COLOR_RESET}]"
        echo ""
        echo "  $(msg STATUS_NOT_INSTALLED_DESC)"
        echo -e "  $(msgf STATUS_HINT_INSTALL "${COLOR_CYAN}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}")"
        echo ""
        print_separator
        exit 1
    fi

    # --- Check 2: Process & Port Status ---
    local port_offset
    port_offset=$(get_config "DEFAULT_PORT_OFFSET" "global")
    port_offset=${port_offset:-0}
    local final_port=$((COMPONENT_PORT + port_offset))

    local status_line=""
    local info_items=()

    info_items+=("Component: ${COMPONENT_NAME}")
    info_items+=("Target Port: ${final_port}")
    info_items+=("Data Directory: app/models")

    if is_daemon_running "$COMPONENT_NAME"; then
        local proc_info
        proc_info=$(get_daemon_info "$COMPONENT_NAME")

        if [[ "$proc_info" == "zombie_or_orphaned" ]]; then
            status_line="${COLOR_YELLOW}[WARNING]${COLOR_RESET} Process exists but appears orphaned/zombie."
            info_items+=("Status: Orphaned/Zombie")
        else
            local pid uptime cpu mem cmd
            read -r pid uptime cpu mem cmd <<< "$proc_info"

            status_line="${COLOR_GREEN}[RUNNING]${COLOR_RESET} Healthy"
            info_items+=("PID: ${pid}")
            info_items+=("Uptime: ${uptime}")
            info_items+=("Resources: ${cpu}% CPU, ${mem}% MEM")

            if is_port_in_use "$final_port"; then
                info_items+=("Port Status: ${COLOR_GREEN}Listening on ${final_port}${COLOR_RESET}")
            else
                info_items+=("Port Status: ${COLOR_YELLOW}Process running, but port ${final_port} is NOT listening${COLOR_RESET}")
            fi
        fi
    else
        status_line="${COLOR_GRAY}[STOPPED]${COLOR_RESET} Not currently running"
        info_items+=("Status: Stopped")

        if is_port_in_use "$final_port"; then
            info_items+=("Port Status: ${COLOR_RED}WARNING - Port ${final_port} is occupied by another process!${COLOR_RESET}")
        else
            info_items+=("Port Status: ${COLOR_GREEN}Available${COLOR_RESET}")
        fi
    fi

    echo -e "  ${status_line}"
    echo ""
    print_info_block "Configuration & State" "${info_items[@]}"

    # --- Check 3: Recent Log Activity ---
    local log_file="${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log"
    echo -e "${COLOR_BOLD}$(msg STATUS_RECENT_LOGS)${COLOR_RESET}"
    if [[ -f "$log_file" ]]; then
        local recent_logs
        recent_logs=$(tail -n 5 "$log_file" | grep -v '^$' | sed 's/^/    /')
        if [[ -n "$recent_logs" ]]; then
            echo -e "${COLOR_GRAY}${recent_logs}${COLOR_RESET}"
        else
            echo "    ${COLOR_GRAY}$(msg STATUS_LOG_EMPTY)${COLOR_RESET}"
        fi
    else
        echo "    ${COLOR_GRAY}$(msg STATUS_NO_LOG)${COLOR_RESET}"
    fi

    echo ""
    print_separator

    if is_daemon_running "$COMPONENT_NAME"; then
        echo -e "  ${COLOR_CYAN}$(msg ACTIONS_LABEL):${COLOR_RESET}"
        echo "    $(msg STATUS_ACTION_STOP)   ${COLOR_GRAY}./ai-studio.sh stop ${COMPONENT_NAME}${COLOR_RESET}"
        echo "    $(msg STATUS_ACTION_LOGS) ${COLOR_GRAY}cat ${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log${COLOR_RESET}"
        echo "    $(msg STATUS_ACTION_BROWSER)   ${COLOR_GRAY}open http://localhost:${final_port}${COLOR_RESET}"
    else
        echo -e "  ${COLOR_CYAN}$(msg ACTIONS_LABEL):${COLOR_RESET}"
        echo "    $(msg STATUS_ACTION_START)  ${COLOR_GRAY}./ai-studio.sh start ${COMPONENT_NAME}${COLOR_RESET}"
        echo "    $(msg STATUS_ACTION_DIAGNOSE)  ${COLOR_GRAY}./ai-studio.sh diagnose ${COMPONENT_NAME}${COLOR_RESET}"
    fi
    echo ""
    print_separator

    exit 0
}

# Execute main function
main "$@"
