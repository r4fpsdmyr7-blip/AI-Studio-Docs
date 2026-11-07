#!/bin/bash

# ============================================================================
# AI Studio - Browser Use Uninstall Script (library-type component)
# File: components/browser-use/uninstall.sh
#
# Removes the component virtualenv and (optionally) the data directory.
# Playwright browsers live in the global cache ~/Library/Caches/ms-playwright
# and are intentionally left untouched (other apps may share them).
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
            log_error "$(msgf UNINSTALL_UNKNOWN_ARG "$1")"
            log_info "$(msgf UNINSTALL_USAGE "$COMPONENT_NAME")"
            exit 1
            ;;
    esac
done

# ============================================================================
# 4. Core Uninstall Logic
# ============================================================================

check_installation() {
    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] && [[ ! -f "${COMPONENT_DIR}/.installed" ]]; then
        log_info "$(msgf UNINSTALL_NOT_INSTALLED "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

confirm_uninstall() {
    if [[ "$FORCE_UNINSTALL" == true ]]; then
        return 0 # Skip confirmation in force mode
    fi

    local warning_msg="$(msgf UNINSTALL_CONFIRM "$COMPONENT_NAME")"
    if [[ "$KEEP_DATA" == false ]]; then
        warning_msg="${warning_msg} ${COLOR_RED}$(msg UNINSTALL_CONFIRM_DELETE)${COLOR_RESET}"
    else
        warning_msg="${warning_msg} ${COLOR_YELLOW}$(msg UNINSTALL_CONFIRM_KEEP)${COLOR_RESET}"
    fi

    if ! confirm_action "$warning_msg" "N"; then
        log_info "$(msg UNINSTALL_CANCELLED)"
        exit 0
    fi
}

cleanup_files() {
    log_info "$(msg UNINSTALL_CLEANING)"

    # Entries to KEEP: the standard AI Studio interface scripts
    local keep_names=(
        "install.sh"
        "start.sh"
        "stop.sh"
        "status.sh"
        "update.sh"
        "diagnose.sh"
        "uninstall.sh"
        "metadata.sh"
    )

    # If keeping data, also keep the data directory (session data, logs)
    if [[ "$KEEP_DATA" == true ]]; then
        local data_dir_name="${COMPONENT_DATA_DIR%/}"
        data_dir_name="${data_dir_name#./}"
        keep_names+=("$data_dir_name")
        log_info "$(msgf UNINSTALL_KEEP_DATA "$COMPONENT_DATA_DIR")"
    else
        log_warn "$(msgf UNINSTALL_DELETE_DATA "$COMPONENT_DATA_DIR")"
    fi

    # Remove everything except the kept entries.
    # Implemented as an explicit loop instead of `find -prune -exec rm -rf`:
    # some find implementations (toybox/busybox) ignore -mindepth when -prune
    # is present and hand the component directory itself to the exec, which
    # would delete the whole directory including the scripts we must keep.
    local entry name cleanup_failed=false
    for entry in "$COMPONENT_DIR"/* "$COMPONENT_DIR"/.[!.]* "$COMPONENT_DIR"/..?*; do
        [[ -e "$entry" ]] || continue
        name="$(basename "$entry")"
        case " ${keep_names[*]} " in
            *" $name "*) continue ;;
        esac
        if ! rm -rf "$entry"; then
            cleanup_failed=true
        fi
    done

    if [[ "$cleanup_failed" == true ]]; then
        log_error "$(msg UNINSTALL_CLEAN_FAILED)"
    else
        log_success "$(msg UNINSTALL_REMOVED_OK)"
    fi

    # Clean up component-specific log file
    local log_file="${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log"
    if [[ -f "$log_file" ]]; then
        rm -f "$log_file"
        log_info "$(msg UNINSTALL_LOG_CLEARED)"
    fi

    # Clean up component-specific config file (if any)
    local conf_file="${AI_STUDIO_ROOT}/config/${COMPONENT_NAME}.conf"
    if [[ -f "$conf_file" ]]; then
        rm -f "$conf_file"
        log_info "$(msg UNINSTALL_CONF_CLEARED)"
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

    # Step 2: User Confirmation
    confirm_uninstall

    # Step 3: Execute Cleanup
    echo ""
    cleanup_files

    # Step 4: Completion
    echo ""
    print_separator
    log_success "$(msgf UNINSTALL_SUCCESS_COMPONENT "$COMPONENT_NAME")"
    echo ""

    if [[ "$KEEP_DATA" == true ]]; then
        log_info "$(msgf UNINSTALL_DATA_PRESERVED "${COLOR_CYAN}${COMPONENT_DIR}/${COMPONENT_DATA_DIR}${COLOR_RESET}")"
        log_info "$(msg UNINSTALL_REINSTALL_HINT)"
    else
        log_info "$(msg UNINSTALL_DATA_DELETED)"
        log_info "$(msg MLX_UNINSTALL_NO_IMPACT)"
    fi
    log_info "$(msg BU_UNINSTALL_BROWSERS_NOTE)"

    echo ""
    echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
    echo "  $(msg UNINSTALL_HINT_LIST)"
    echo "  $(msg UNINSTALL_HINT_INSTALL_OTHER)"
    echo ""
    rm -f "${COMPONENT_DIR}/.installed"

    echo ""
    print_separator

    exit 0
}

# Execute main function
main "$@"
