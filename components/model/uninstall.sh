#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Uninstall Script
# File: components/model/uninstall.sh
# 
# Handles the safe removal of the MLX model repository management scripts.
# Due to the massive size of model assets (e.g., 35B LLMs, FLUX), this script 
# implements strict confirmation protocols to prevent accidental data loss.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Argument Parsing
# ============================================================================

KEEP_DATA=true # DEFAULT TO TRUE for models to prevent accidental massive deletions
FORCE_UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --purge-models) # Specific flag for models to explicitly delete the heavy assets
            KEEP_DATA=false
            shift
            ;;
        --force)
            FORCE_UNINSTALL=true
            shift
            ;;
        *)
            log_error "$(msgf UNINSTALL_UNKNOWN_ARG "$1")"
            log_info "$(msgf MODEL_UNINSTALL_USAGE "$COMPONENT_NAME")"
            log_info "$(msg MODEL_UNINSTALL_DEFAULT_NOTE)"
            exit 1
            ;;
    esac
done

# ============================================================================
# 4. Core Uninstall Logic
# ============================================================================

check_installation() {
    if [[ ! -d "$COMPONENT_DATA_DIR" ]] && [[ ! -f "${AI_STUDIO_ROOT}/logs/model-manager.log" ]]; then
        log_info "$(msgf MODEL_UNINSTALL_NOTHING "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

# Calculate and display the size of models to be deleted
show_deletion_impact() {
    if [[ -d "$COMPONENT_DATA_DIR" ]]; then
        local total_size
        total_size=$(du -sh "$COMPONENT_DATA_DIR" 2>/dev/null | awk '{print $1}')
        echo ""
        echo -e "${COLOR_RED}$(msg MODEL_UNINSTALL_WARN_BANNER)${COLOR_RESET}"
        echo -e "${COLOR_RED}$(msg MODEL_UNINSTALL_WARN_1)${COLOR_RESET}"
        echo -e "${COLOR_RED}$(msg MODEL_UNINSTALL_WARN_2)${COLOR_RESET}"
        echo ""
        echo -e "  $(msgf MODEL_UNINSTALL_TARGET_DIR "${COLOR_GRAY}${COMPONENT_DATA_DIR}${COLOR_RESET}")"
        echo -e "  $(msgf MODEL_UNINSTALL_SPACE_FREED "${COLOR_BOLD}${total_size:-Unknown}${COLOR_RESET}")"
        echo ""
        echo -e "${COLOR_RED}$(msg MODEL_UNINSTALL_UNDOABLE)${COLOR_RESET}"
    fi
}

confirm_destruction() {
    if [[ "$FORCE_UNINSTALL" == true ]]; then
        return 0 # Skip confirmation in force mode
    fi

    show_deletion_impact

    # Require explicit, full-string confirmation for destructive action
    local confirm_input
    read -r -p "$(echo -e "${COLOR_RED}$(msg MODEL_UNINSTALL_CONFIRM_PROMPT) ${COLOR_RESET}")" confirm_input
    
    if [[ "$confirm_input" == "DELETE ALL MODELS" ]]; then
        log_warn "$(msg MODEL_UNINSTALL_CONFIRMED)"
        return 0
    else
        log_info "$(msg MODEL_UNINSTALL_CANCELLED)"
        exit 0
    fi
}

cleanup_files() {
    log_info "$(msg UNINSTALL_CLEANING)"
    
    # 1. Clean up global log file
    local log_file="${AI_STUDIO_ROOT}/logs/model-manager.log"
    if [[ -f "$log_file" ]]; then
        rm -f "$log_file"
        log_info "$(msg MODEL_UNINSTALL_LOG_CLEARED)"
    fi

    # 2. Clean up component-specific config file (if any)
    local conf_file="${AI_STUDIO_ROOT}/config/${COMPONENT_NAME}.conf"
    if [[ -f "$conf_file" ]]; then
        rm -f "$conf_file"
        log_info "$(msg MODEL_UNINSTALL_CONF_CLEARED)"
    fi

    # 3. Handle the main data directory based on KEEP_DATA flag
    if [[ "$KEEP_DATA" == true ]]; then
        log_success "$(msgf MODEL_UNINSTALL_PRESERVED_AT "${COLOR_CYAN}${COMPONENT_DATA_DIR}${COLOR_RESET}")"
        log_info "$(msg MODEL_UNINSTALL_ONLY_LOGS)"
    else
        if [[ -d "$COMPONENT_DATA_DIR" ]]; then
            log_warn "$(msgf MODEL_UNINSTALL_DELETING "$COMPONENT_DATA_DIR")"
            if rm -rf "$COMPONENT_DATA_DIR"; then
                log_success "$(msg MODEL_UNINSTALL_DELETED)"
            else
                log_error "$(msg MODEL_UNINSTALL_DELETE_FAILED)"
            fi
        fi
    fi
}

# ============================================================================
# 5. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_RED}  $(msgf BANNER_UNINSTALL "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_installation; then
        print_separator
        exit 0
    fi

    # Step 2: Strict Confirmation (if purging)
    if [[ "$KEEP_DATA" == false ]]; then
        confirm_destruction
    else
        log_info "$(msg MODEL_UNINSTALL_DEFAULT_MODE)"
        log_info "$(msg MODEL_UNINSTALL_DEFAULT_MODE_2)"
    fi

    # Step 3: Execute Cleanup
    echo ""
    cleanup_files

    # Step 4: Completion
    echo ""
    print_separator
    log_success "$(msgf MODEL_UNINSTALL_DONE "$COMPONENT_NAME")"
    echo ""
    
    if [[ "$KEEP_DATA" == true ]]; then
        echo -e "${COLOR_CYAN}$(msg LBL_NOTE):${COLOR_RESET}"
        echo "  $(msgf MODEL_UNINSTALL_STILL_INTACT "$COMPONENT_DATA_DIR")"
        echo "  $(msg MODEL_UNINSTALL_STILL_ACCESSIBLE)"
    else
        echo -e "${COLOR_YELLOW}$(msg LBL_NOTE):${COLOR_RESET}"
        echo "  $(msg MODEL_UNINSTALL_ALL_DELETED)"
        echo "  $(msg MODEL_UNINSTALL_NEED_REDOWNLOAD)"
    fi
    
    echo ""
    echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
    echo "  $(msg UNINSTALL_HINT_LIST)"
    echo ""
    rm -f "${COMPONENT_DIR}/.installed"

    echo ""
    print_separator
    
    exit 0
}

# Execute main function
main "$@"
