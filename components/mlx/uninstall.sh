#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Uninstall Script
# File: components/mlx/uninstall.sh
# 
# Handles the safe removal of the MLX framework component. Since MLX is 
# isolated within its own virtual environment, uninstallation is clean and 
# does not affect system-wide Python packages or other AI components.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Argument Parsing
# ============================================================================

KEEP_DATA=false
FORCE_UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --force)
            FORCE_UNINSTALL=true
            shift
            ;;
        *)
            log_error "Unknown uninstall argument: $1"
            log_info "Usage: ./ai-studio.sh uninstall ${COMPONENT_NAME} [--keep-data] [--force]"
            exit 1
            ;;
    esac
done

# ============================================================================
# 4. Core Uninstall Logic
# ============================================================================

check_installation() {
    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        log_info "${COMPONENT_NAME} virtual environment does not exist. Nothing to uninstall."
        return 1
    fi
    return 0
}

confirm_uninstall() {
    if [[ "$FORCE_UNINSTALL" == true ]]; then
        return 0 # Skip confirmation in force mode
    fi

    local warning_msg="Are you sure you want to uninstall the ${COMPONENT_NAME} framework?"
    if [[ "$KEEP_DATA" == false ]]; then
        warning_msg="${warning_msg} ${COLOR_YELLOW}This will delete the isolated Python virtual environment.${COLOR_RESET}"
    else
        warning_msg="${warning_msg} ${COLOR_GREEN}(The virtual environment will be preserved)${COLOR_RESET}"
    fi

    if ! confirm_action "$warning_msg" "N"; then
        log_info "Uninstallation cancelled by user."
        exit 0
    fi
}

cleanup_files() {
    log_info "Cleaning up component files..."
    
    # Define files to KEEP (the standard AI Studio interface scripts)
    local keep_files=(
        "install.sh"
        "start.sh"
        "stop.sh"
        "status.sh"
        "update.sh"
        "diagnose.sh"
        "uninstall.sh"
        "metadata.sh"
    )
    
    # Build find exclude arguments
    local exclude_args=()
    for file in "${keep_files[@]}"; do
        exclude_args+=("-name" "$file" "-o")
    done
    
    # If keeping data, also exclude the virtual environment directory
    if [[ "$KEEP_DATA" == true ]]; then
        local venv_dir_name="${COMPONENT_VENV_DIR%/}"
        exclude_args+=("-name" "$venv_dir_name" "-o")
        log_info "Preserving virtual environment directory: ${COMPONENT_VENV_DIR}"
    else
        log_warn "Deleting virtual environment directory: ${COMPONENT_VENV_DIR}"
    fi

    # Remove the last "-o" from the array
    unset 'exclude_args[${#exclude_args[@]}-1]'

    # Execute find and delete everything EXCEPT the kept files/directories
    if find "$COMPONENT_DIR" -mindepth 1 -maxdepth 1 \( "${exclude_args[@]}" \) -prune -o -exec rm -rf {} +; then
        log_success "Component source code and dependencies removed."
    else
        log_error "Failed to clean up some files. You may need to remove them manually."
    fi

    # Clean up component-specific log file
    local log_file="${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log"
    if [[ -f "$log_file" ]]; then
        rm -f "$log_file"
        log_info "Cleared component log file."
    fi

    # Clean up component-specific config file (if any)
    local conf_file="${AI_STUDIO_ROOT}/config/${COMPONENT_NAME}.conf"
    if [[ -f "$conf_file" ]]; then
        rm -f "$conf_file"
        log_info "Cleared component configuration file."
    fi
}

# ============================================================================
# 5. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_RED}  Uninstalling: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_installation; then
        print_separator
        exit 0
    fi

    # Step 2: User Confirmation
    confirm_uninstall

    # Step 3: Execute Cleanup
    echo ""
    cleanup_files

    # Step 4: Completion
    echo ""
    print_separator
    log_success "${COMPONENT_NAME} has been successfully uninstalled!"
    echo ""
    
    if [[ "$KEEP_DATA" == true ]]; then
        log_info "Your virtual environment has been preserved in: ${COLOR_CYAN}${COMPONENT_DIR}/${COMPONENT_VENV_DIR}${COLOR_RESET}"
        log_info "You can safely reinstall the component later without re-downloading all Python packages."
    else
        log_info "The isolated Python environment has been completely removed."
        log_info "This does not affect your system-wide Python installation or other components."
    fi
    
    echo ""
    echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
    echo "  • View remaining components: ./ai-studio.sh list"
    echo "  • Install a different component: ./ai-studio.sh install <component>"
    echo ""
    print_separator
    
    exit 0
}

# Execute main function
main "$@"
