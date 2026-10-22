#!/bin/bash

# ============================================================================
# AI Studio - Xcode Command Line Tools Installer (env/install-xcode-cli.sh)
# Automates the detection and installation of macOS development tools required 
# for compiling AI dependencies (e.g., llama.cpp, ONNX Runtime).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 2. Source core libraries
source "$AI_STUDIO_ROOT/lib/common.sh"

# ============================================================================
# 3. Core Installation Logic
# ============================================================================

# Check if Xcode Command Line Tools are installed and functional
check_xcode_cli() {
    # Check if the path is registered
    local cli_path
    cli_path=$(xcode-select -p 2>/dev/null)
    
    if [[ "$cli_path" == "/Library/Developer/CommandLineTools" ]] && [[ -d "$cli_path" ]]; then
        # Verify a core compiler exists to ensure it's not a broken installation
        if [[ -x "$cli_path/usr/bin/clang" ]] && [[ -x "$cli_path/usr/bin/make" ]]; then
            local version
            version=$(clang --version | head -n 1 | awk '{print $3, $4}')
            log_info "$(msgf ENVX_VERSION_OK "$version")"
            return 0
        else
            log_warn "$(msg ENVX_BROKEN)"
            return 1
        fi
    else
        log_info "$(msg ENVX_NOT_INSTALLED)"
        return 1
    fi
}

# Trigger the macOS native installation dialog
trigger_installation() {
    log_info "$(msg ENVX_TRIGGERING)"
    log_warn "${COLOR_YELLOW}$(msg ENVX_DIALOG_NOTE)${COLOR_RESET}"
    echo ""
    
    # This command triggers the GUI popup. It returns immediately, but the popup stays on screen.
    xcode-select --install
    
    # We must wait for the user to complete the GUI installation.
    # A simple 'read' prompt is the most reliable way to pause the script and let the user catch up.
    echo ""
    read -r -p "$(echo -e "${COLOR_CYAN}$(msg ENVX_PROMPT_ENTER)${COLOR_RESET}")"
    
    echo ""
    log_info "$(msg ENVX_VERIFYING)"
}

# Attempt to fix a corrupted or stuck CLT installation
fix_corrupted_cli() {
    log_warn "$(msg ENVX_RESETTING)"
    log_info "$(msg ENVX_RESET_PRIVILEGE)"
    
    if sudo rm -rf /Library/Developer/CommandLineTools; then
        log_success "$(msg ENVX_OLD_REMOVED)"
        log_info "$(msg ENVX_RERUN)"
        return 0
    else
        log_error "$(msg ENVX_REMOVE_FAILED)"
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msg ENVX_BANNER)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  $(msg ENVX_SUBTITLE)${COLOR_RESET}"
    print_separator
    echo ""

    if check_xcode_cli; then
        log_success "$(msg ENVX_HEALTHY)"
        echo ""
        print_separator
        exit 0
    fi

    # Check if it's a corrupted state (path exists but tools are missing)
    local cli_path
    cli_path=$(xcode-select -p 2>/dev/null)
    if [[ -n "$cli_path" ]] && [[ -d "$cli_path" ]]; then
        log_warn "$(msgf ENVX_CORRUPT_AT "$cli_path")"
        if confirm_action "Do you want to delete it and perform a clean installation?" "Y"; then
            fix_corrupted_cli
            exit $?
        else
            log_info "$(msgf ENVX_ABORT "$cli_path")"
            exit 1
        fi
    fi

    # Trigger fresh installation
    trigger_installation
    
    # Final verification
    if check_xcode_cli; then
        echo ""
        print_separator
        log_success "$(msg ENVX_DONE)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
        echo "  $(msg ENVX_NEXT_1)"
        echo "  $(msg ENVX_NEXT_2)"
        echo "  ./env/install-homebrew.sh"
        echo ""
        print_separator
        exit 0
    else
        echo ""
        print_separator
        log_error "$(msg ENVX_FAILED)"
        echo ""
        echo -e "${COLOR_YELLOW}$(msg TROUBLESHOOT_LABEL)${COLOR_RESET}"
        echo "  $(msg ENVX_TS_1)"
        echo "  $(msg ENVX_TS_2)"
        echo "  $(msg ENVX_TS_3)"
        echo ""
        print_separator
        exit 1
    fi
}

# Execute main function
main "$@"
