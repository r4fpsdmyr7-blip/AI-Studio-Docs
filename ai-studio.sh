#!/bin/bash
# ============================================================================
# AI Studio - Main Entry Script
# A unified platform for managing and deploying AI tools
# 
# CRITICAL FIX: 
# 1. Removed 'set -e' to prevent unexpected crashes during routing.
# 2. Removed undefined 'init_logging' call.
# 3. Fixed undefined 'show_all_components_status' and 'show_environment_status'.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$SCRIPT_DIR"

# Import core libraries
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/lang.sh"       # UI 消息层（i18n），须在 config.sh 之后
source "$AI_STUDIO_ROOT/lib/env-check.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$AI_STUDIO_ROOT/lib/browser.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/diagnose.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$AI_STUDIO_ROOT/components/registry.sh"

VERSION="1.0.0"
VERSION_DATE="2026-06-13"

show_help() {
cat << EOF
AI Studio v${VERSION}
$(msg APP_TAGLINE)

$(msg USAGE_HINT):
  $(basename "$0") <command> [arguments] [options]

$(msg HELP_CORE_COMMANDS):
  env check|install|status       $(msg HELP_ENV_DESC)
  install <component|all>        $(msg HELP_INSTALL_DESC)
  start <component|all>          $(msg HELP_START_DESC)
  stop <component|all>           $(msg HELP_STOP_DESC)
  restart <component|all>        $(msg HELP_RESTART_DESC)
  status [component]             $(msg HELP_STATUS_DESC)
  update <component|all>         $(msg HELP_UPDATE_DESC)
    --target <type>              $(msg HELP_UPDATE_TARGET): frontend|agent|architecture|models
  uninstall <component>          $(msg HELP_UNINSTALL_DESC)
    --keep-data                  $(msg HELP_KEEP_DATA)
    --force                      $(msg HELP_FORCE)
  diagnose <component>           $(msg HELP_DIAGNOSE_DESC)
    --deep                       $(msg HELP_DEEP)
    --fix                        $(msg HELP_FIX)
  list                           $(msg HELP_LIST_DESC)
  help                           $(msg HELP_HELP_DESC)
  version                        $(msg HELP_VERSION_DESC)
  lang [show|list|set CODE]      $(msg HELP_LANG_CMD)

$(msg HELP_GLOBAL_OPTIONS):
  --lang <zh|en>                 $(msg HELP_LANG_DESC)

$(msg HELP_COMPONENTS):
  open-webui, sillytavern, continue-dev, fazm, browser-use,
  mlx, comfyui, mlx-video, qwen3, model

$(msg HELP_EXAMPLES):
  $(basename "$0") env check
  $(basename "$0") install open-webui
  $(basename "$0") start open-webui
  $(basename "$0") status
  $(basename "$0") update comfyui --target models
  $(basename "$0") diagnose sillytavern --deep
EOF
}

show_version() {
    echo "AI Studio v${VERSION} (${VERSION_DATE})"
}

handle_env_command() {
    local subcommand="$1"
    if [[ "$subcommand" == "check" ]]; then
        log_info "$(msg ENV_CHECK_START)"
        check_all_requirements
    elif [[ "$subcommand" == "install" ]]; then
        log_info "$(msg ENV_INSTALL_START)"
        install_all_dependencies
    elif [[ "$subcommand" == "status" ]]; then
        log_info "$(msg ENV_STATUS_TITLE):"
        # Fallback to check if show_environment_status is not defined in env-check.sh
        if declare -f show_environment_status >/dev/null 2>&1; then
            show_environment_status
        else
            check_all_requirements
        fi
    else
        log_error "$(msg ENV_SUBCOMMAND_UNKNOWN): $subcommand"
        show_help
        exit 1
    fi
}

handle_component_command() {
    local command="$1"
    local component="$2"
    shift 2 || true # Shift safely
    
    # Validate component name
    if [[ "$component" != "all" ]]; then
        if ! is_valid_component "$component"; then
            log_error "$(msg COMPONENT_UNKNOWN): $component"
            log_info "$(msgf SEE_COMPONENT_LIST "$(basename "$0")")"
            exit 1
        fi
    fi
    
    # Get component script path
    local component_dir="$AI_STUDIO_ROOT/components/$component"
    local script_path="$component_dir/${command}.sh"
    
    # Check if script exists (skip for 'all' operations)
    if [[ "$component" != "all" ]] && [[ ! -f "$script_path" ]]; then
        log_error "$(msgf COMPONENT_OP_UNSUPPORTED "$component" "$command")"
        exit 1
    fi
    
    # Execute component script based on command
    if [[ "$command" == "install" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "$(msg INSTALL_ALL)"
            for comp in $(get_all_components); do
                log_info "$(msgf INSTALLING_COMPONENT "$comp")"
                "$AI_STUDIO_ROOT/components/$comp/install.sh" "$@"
            done
        else
            log_info "$(msgf INSTALLING_COMPONENT "$component")"
            "$script_path" "$@"
        fi
    elif [[ "$command" == "start" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "$(msg START_ALL)"
            for comp in $(get_all_components); do
                log_info "$(msgf STARTING_COMPONENT "$comp")"
                "$AI_STUDIO_ROOT/components/$comp/start.sh" "$@"
            done
        else
            log_info "$(msgf STARTING_COMPONENT "$component")"
            "$script_path" "$@"
            # Note: The component's start.sh already handles opening the browser 
        fi
    elif [[ "$command" == "stop" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "$(msg STOP_ALL)"
            for comp in $(get_all_components); do
                log_info "$(msgf STOPPING_COMPONENT "$comp")"
                "$AI_STUDIO_ROOT/components/$comp/stop.sh" "$@"
            done
        else
            log_info "$(msgf STOPPING_COMPONENT "$component")"
            "$script_path" "$@"
        fi
    elif [[ "$command" == "restart" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "$(msg RESTART_ALL)"
            for comp in $(get_all_components); do
                log_info "$(msgf RESTARTING_COMPONENT "$comp")"
                "$AI_STUDIO_ROOT/components/$comp/stop.sh" "$@"
                sleep 2
                "$AI_STUDIO_ROOT/components/$comp/start.sh" "$@"
            done
        else
            log_info "$(msgf RESTARTING_COMPONENT "$component")"
            "$AI_STUDIO_ROOT/components/$component/stop.sh" "$@"
            sleep 2
            "$AI_STUDIO_ROOT/components/$component/start.sh" "$@"
        fi
    elif [[ "$command" == "status" ]]; then
        if [[ -z "$component" ]] || [[ "$component" == "all" ]]; then
            list_components # Fixed: was show_all_components_status
        else
            "$script_path" "$@"
        fi
    elif [[ "$command" == "update" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "$(msg UPDATE_ALL)"
            for comp in $(get_all_components); do
                log_info "$(msgf UPDATING_COMPONENT "$comp")"
                "$AI_STUDIO_ROOT/components/$comp/update.sh" "$@"
            done
        else
            log_info "$(msgf UPDATING_COMPONENT "$component")"
            "$script_path" "$@"
        fi
    elif [[ "$command" == "uninstall" ]]; then
        log_info "$(msgf UNINSTALLING_COMPONENT "$component")"
        "$script_path" "$@"
    elif [[ "$command" == "diagnose" ]]; then
        log_info "$(msgf DIAGNOSING_COMPONENT "$component")"
        "$script_path" "$@"
    else
        log_error "$(msg UNKNOWN_COMMAND): $command"
        exit 1
    fi
}

list_components() {
    echo ""
    echo "$(msg LIST_HEADER):"
    echo ""
    for comp in $(get_all_components); do
        local desc
        desc=$(get_component_description "$comp")
        local port
        port=$(get_component_port "$comp")
        local status_icon="[ ]"
        
        if is_component_installed "$comp"; then
            if is_component_running "$comp"; then
                status_icon="[R]"
            else
                status_icon="[I]"
            fi
        fi
        
        printf "  %s %-20s %s" "$status_icon" "$comp" "$desc"
        if [[ -n "$port" ]]; then
            printf " (%s: %s)" "$(msg LABEL_PORT)" "$port"
        fi
        echo ""
    done
    echo ""
    echo "$(msg LIST_LEGEND):"
    echo "  [R] $(msg LEGEND_RUNNING)  [I] $(msg LEGEND_INSTALLED)  [ ] $(msg LEGEND_NOT_INSTALLED)"
    echo ""
}

main() {
    # CRITICAL FIX: Removed 'init_logging' call. 
    # Log functions are ready immediately after sourcing lib/common.sh.
    
    # 提取全局选项 --lang <zh|en>（可出现在任意位置，早于命令解析）
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang)
                if [[ -z "${2:-}" ]] || ! lang_set "${2:-}"; then
                    log_error "$(msg UNKNOWN_COMMAND): ${2:-<empty>} ($(msg USAGE_HINT): --lang zh|en)"
                    exit 1
                fi
                shift 2
                ;;
            --lang=*)
                if ! lang_set "${1#--lang=}"; then
                    log_error "$(msg UNKNOWN_COMMAND): ${1#--lang=} ($(msg USAGE_HINT): --lang zh|en)"
                    exit 1
                fi
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    if [[ ${#args[@]} -gt 0 ]]; then
        set -- "${args[@]}"
    else
        set --
    fi

    # Check arguments
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    # Command routing
    if [[ "$command" == "help" ]] || [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        show_help
    elif [[ "$command" == "version" ]] || [[ "$command" == "--version" ]] || [[ "$command" == "-v" ]]; then
        show_version
    elif [[ "$command" == "env" ]]; then
        handle_env_command "$@"
    elif [[ "$command" == "list" ]]; then
        list_components
    elif [[ "$command" == "lang" ]]; then
        lang_command "$@"
    elif [[ "$command" == "install" ]] || [[ "$command" == "start" ]] || [[ "$command" == "stop" ]] || [[ "$command" == "restart" ]] || [[ "$command" == "status" ]] || [[ "$command" == "update" ]] || [[ "$command" == "uninstall" ]] || [[ "$command" == "diagnose" ]]; then
        if [[ $# -eq 0 ]]; then
            log_error "$(msg MISSING_COMPONENT_ARG)"
            show_help
            exit 1
        fi
        handle_component_command "$command" "$@"
    else
        log_error "$(msg UNKNOWN_COMMAND): $command"
        show_help
        exit 1
    fi
}

# Execute main function
main "$@"
