#!/usr/bin/env bash
# ============================================================================
# DEPRECATED - ORPHANED CODE (not wired into the main program)
#
# This file belongs to an abandoned command-dispatch layer. It is NOT
# referenced by ai-studio.sh or any active lib/ module, and it references
# symbols that do not exist (load_libs, REGISTERED_COMPONENTS, CLR_*,
# AI_STUDIO_DATA_DIR, ...), so it cannot run as-is.
# Kept for historical reference only.
#
# The active architecture is:
#   ai-studio.sh -> lib/*.sh -> components/registry.sh -> components/<name>/
#
# Do NOT build new features on top of this file. See AGENTS.md for details.
# ============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_agent() {
    local action="${1:-list}"
    log_info "===== AI-Studio Agent 管理 ====="; echo ""
    case "$action" in
        list)
            info_box "已注册 Agent"
            echo -e "  ${CLR_CYAN}名称${CLR_RESET}              ${CLR_CYAN}类型${CLR_RESET}          ${CLR_CYAN}状态${CLR_RESET}"
            show_separator "-"
            echo -e "  open-webui-agent    Open WebUI      $(is_running open-webui && echo -e "${CLR_GREEN}活跃${CLR_RESET}" || echo -e "${CLR_RED}离线${CLR_RESET}")"
            echo -e "  sillytavern-agent   SillyTavern     $(is_running sillytavern && echo -e "${CLR_GREEN}活跃${CLR_RESET}" || echo -e "${CLR_RED}离线${CLR_RESET}")"
            echo -e "  browser-use-agent   Browser Use     $(is_running browser-use && echo -e "${CLR_GREEN}活跃${CLR_RESET}" || echo -e "${CLR_RED}离线${CLR_RESET}")"
            echo -e "  continue-dev-agent  Continue.dev    已配置"
            ;;
        config)
            local agent="${2:-}"; [[ -z "$agent" ]] && { log_error "用法: agent config <name>"; return 1; }
            info_box "Agent 配置: $agent"
            echo -e "  编辑: $AI_STUDIO_CONFIG_DIR/${agent}-agent.conf"
            ;;
        status)
            local agent="${2:-all}"
            [[ "$agent" == "all" ]] && { cmd_agent list; return; }
            comp_do "$agent" agent_status 2>/dev/null || log_warn "Agent $agent 无状态接口"
            ;;
        *)
            echo -e "${CLR_BOLD}Agent 子命令:${CLR_RESET}"
            echo -e "  list    - 列出所有 Agent"
            echo -e "  config  - 配置 Agent"
            echo -e "  status  - Agent 状态"
            ;;
    esac
}
cmd_agent "$@"
