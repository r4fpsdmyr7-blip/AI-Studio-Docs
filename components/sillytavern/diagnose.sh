#!/bin/bash

# ============================================================================
# AI Studio - SillyTavern Diagnose Script
# File: components/sillytavern/diagnose.sh
#
# Generic diagnosis (process/port/logs/resources via lib/diagnose.sh) plus
# component-specific checks: entry file, node_modules, node runtime.
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

# Check that the upstream entry file exists
check_entry_file() {
    if [[ ! -f "${APP_DIR}/server.js" ]]; then
        echo "$(msgf INSTALL_ENTRY_MISSING "app/server.js")"
        echo "$(msg DIAG_HINT_REINSTALL)"
        return 1
    fi
    echo "$(msgf DIAG_ENTRY_OK "app/server.js")"
    return 0
}

# Check that Node.js dependencies are installed
check_node_deps() {
    if [[ ! -d "${APP_DIR}/node_modules" ]]; then
        echo "$(msg DIAG_NODE_DEPS_MISSING)"
        echo "$(msg DIAG_HINT_REINSTALL)"
        return 1
    fi
    echo "$(msgf DIAG_ENTRY_OK "node_modules")"
    return 0
}

# Check the Node.js runtime itself
check_node_runtime() {
    if ! command_exists node; then
        echo "$(msg DIAG_NODE_MISSING)"
        return 1
    fi
    echo "$(msgf DIAG_ENTRY_OK "$(node --version)")"
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

        result=$(check_node_deps)
        if [[ $? -ne 0 ]]; then specific_issues=$((specific_issues + 1)); fi
        echo -e "  [${COLOR_BLUE}DEPS${COLOR_RESET}] $result"

        result=$(check_node_runtime)
        if [[ $? -ne 0 ]]; then specific_issues=$((specific_issues + 1)); fi
        echo -e "  [${COLOR_BLUE}NODE${COLOR_RESET}] $result"
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
