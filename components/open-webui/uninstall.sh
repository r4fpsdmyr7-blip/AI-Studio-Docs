#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Uninstall Script
# File: components/open-webui/uninstall.sh
# 
# Handles the safe removal of the Open WebUI component, including stopping 
# services, cleaning up source code/dependencies, and optionally preserving 
# user data based on user flags.
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
        log_info "${COMPONENT_NAME} does not appear to be installed. Nothing to uninstall."
        return 1
    fi
    return 0
}

stop_service_safely() {
    if is_daemon_running "$COMPONENT_NAME"; then
        log_info "Stopping ${COMPONENT_NAME} service before uninstallation..."
        if ! stop_daemon "$COMPONENT_NAME" 15; then
            if [[ "$FORCE_UNINSTALL" == true ]]; then
                log_warn "Failed to stop gracefully. Force killing due to --force flag..."
                kill_process_on_port "$COMPONENT_PORT" 2>/dev/null || true
            else
                log_error "Failed to stop ${COMPONENT_NAME} gracefully."
                log_info "Please stop the service manually or use the --force flag."
                return 1
            fi
        fi
    fi
    return 0
}

confirm_uninstall() {
    if [[ "$FORCE_UNINSTALL" == true ]]; then
        return 0 # Skip confirmation in force mode
    fi

    local warning_msg="Are you sure you want to uninstall ${COMPONENT_NAME}?"
    if [[ "$KEEP_DATA" == false ]]; then
        warning_msg="${warning_msg} ${COLOR_RED}THIS WILL DELETE ALL USER DATA AND MODELS!${COLOR_RESET}"
    else
        warning_msg="${warning_msg} ${COLOR_YELLOW}(User data will be preserved)${COLOR_RESET}"
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
    
    # If keeping data, also exclude the data directory
    if [[ "$KEEP_DATA" == true ]]; then
        # Remove trailing slash for consistent matching
        local data_dir_name="${COMPONENT_DATA_DIR%/}"
        data_dir_name="${data_dir_name#./}" # Remove leading ./ if present
        exclude_args+=("-name" "$data_dir_name" "-o")
        log_info "Preserving user data directory: ${COMPONENT_DATA_DIR}"
    else
        log_warn "Deleting user data directory: ${COMPONENT_DATA_DIR}"
    fi

    # Remove the last "-o" from the array
    unset 'exclude_args[${#exclude_args[@]}-1]'

    # Execute find and delete everything EXCEPT the kept files/directories
    # -mindepth 1 ensures we don't delete the component directory itself, just its contents
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

    # Clean up component-specific config file
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

    # Step 2: Stop service
    if ! stop_service_safely; then
        print_separator
        exit 1
    fi

    # Step 3: User Confirmation
    confirm_uninstall

    # Step 4: Execute Cleanup
    echo ""
    cleanup_files

    # Step 5: Completion
    echo ""
    print_separator
    log_success "${COMPONENT_NAME} has been successfully uninstalled!"
    echo ""
    
    if [[ "$KEEP_DATA" == true ]]; then
        log_info "Your data and models have been preserved in: ${COLOR_CYAN}${COMPONENT_DIR}/${COMPONENT_DATA_DIR}${COLOR_RESET}"
        log_info "You can safely reinstall the component later without losing your data."
    else
        log_warn "All local data, models, and configurations for this component have been permanently deleted."
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
