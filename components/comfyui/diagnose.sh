#!/bin/bash

# ============================================================================
# AI Studio - ComfyUI Diagnose Script
# File: components/comfyui/diagnose.sh
#
# Generic diagnosis (process/port/logs/resources via lib/diagnose.sh) plus
# component-specific checks: entry file, virtualenv integrity, data directory.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/diagnose.sh"
source "$COMPONENT_DIR/metadata.sh"

APP_DIR="${COMPONENT_DIR}/app"

check_entry_file() {
    if [[ ! -f "${APP_DIR}/main.py" ]]; then
        echo "$(msgf INSTALL_ENTRY_MISSING "app/main.py")"
        echo "$(msg DIAG_HINT_REINSTALL)"
        return 1
    fi
    echo "$(msgf DIAG_ENTRY_OK "app/main.py")"
    return 0
}

check_venv_integrity() {
    local venv_path="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"
    if [[ ! -d "$venv_path" ]]; then
        echo "$(msg DIAG_VENV_MISSING)"
        echo "$(msg DIAG_HINT_REINSTALL)"
        return 1
    fi
    if [[ ! -f "$venv_path/bin/activate" ]] || [[ ! -f "$venv_path/bin/python" ]]; then
        echo "$(msg DIAG_VENV_BROKEN)"
        return 1
    fi
    echo "$(msg DIAG_VENV_OK)"
    return 0
}

check_data_directory() {
    local data_path="${APP_DIR}/models"
    if [[ ! -d "$data_path" ]]; then
        echo "$(msg DIAG_DATA_DIR_MISSING)"
        return 1
    fi
    if [[ ! -w "$data_path" ]]; then
        echo "$(msg DIAG_DATA_DIR_NOT_WRITABLE)"
        return 1
    fi
    echo "$(msg DIAG_DATA_DIR_OK)"
    return 0
}

main() {
    local is_deep=false
    local do_fix=false

    for arg in "$@"; do
        case "$arg" in
            --deep) is_deep=true ;;
            --fix) do_fix=true ;;
        esac
    done

    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_DIAGNOSE "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Generic diagnosis (process, port, logs, system resources)
    execute_diagnosis "$COMPONENT_NAME" "$@"
    local generic_issues=$?

    # Step 2: Component-specific checks
    if [[ $generic_issues -eq 0 ]] || [[ "$is_deep" == true ]]; then
        echo ""
        log_info "$(msgf DIAG_SPECIFIC_CHECKS "$COMPONENT_NAME")"
        local specific_issues=0

        local result
        result=$(check_entry_file)
        if [[ $? -ne 0 ]]; then specific_issues=$((specific_issues + 1)); fi
        echo -e "  [${COLOR_BLUE}ENTRY${COLOR_RESET}] $result"

        result=$(check_venv_integrity)
        if [[ $? -ne 0 ]]; then specific_issues=$((specific_issues + 1)); fi
        echo -e "  [${COLOR_BLUE}VENV${COLOR_RESET}] $result"

        result=$(check_data_directory)
        if [[ $? -ne 0 ]]; then specific_issues=$((specific_issues + 1)); fi
        echo -e "  [${COLOR_BLUE}DATA_DIR${COLOR_RESET}] $result"
    fi

    echo ""
    print_separator

    local total_issues=$((generic_issues + specific_issues))
    if [[ $total_issues -gt 0 ]]; then
        log_warn "$(msgf DIAG_ISSUES_FOUND "$COMPONENT_NAME" "$total_issues")"
        log_info "$(msg DIAG_HINT_DEEP_FIX)"
        print_separator
        exit 1
    else
        log_success "$(msgf DIAG_HEALTHY "$COMPONENT_NAME")"
        print_separator
        exit 0
    fi
}

# Execute main function
main "$@"
