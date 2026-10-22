#!/bin/bash

# ============================================================================
# AI Studio - Git LFS Installation Script (env/install-git-lfs.sh)
# Automates the installation and global configuration of Git LFS (Large File Storage)
# for handling large AI model weights, checkpoints, and datasets on macOS.
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

# Check if Git LFS is already installed and functional
check_git_lfs() {
    if ! command_exists "git-lfs"; then
        return 1
    fi

    local version
    version=$(git-lfs --version 2>/dev/null | awk '{print $3}')
    log_info "$(msgf ENVL_VERSION_OK "$version")"
    return 0
}

# Install Git LFS via Homebrew
install_git_lfs() {
    log_info "$(msg ENVL_INSTALLING)"

    # Ensure Homebrew is available
    if ! command_exists "brew"; then
        log_error "$(msg ENVL_NEED_HOMEBREW)"
        log_info "$(msg ENVL_HOMEBREW_HINT)"
        return 1
    fi

    # Git LFS requires Git. Install Git if missing.
    if ! command_exists "git"; then
        log_warn "$(msg ENVL_GIT_MISSING)"
        brew install git >/dev/null 2>&1 || {
            log_error "$(msg ENVL_GIT_FAILED)"
            return 1
        }
    fi

    # Install Git LFS
    log_info "$(msg ENVL_RUNNING_CMD)"
    if ! brew install git-lfs; then
        log_error "$(msg ENVL_INSTALL_FAILED)"
        return 1
    fi

    log_success "$(msg ENVL_INSTALL_OK)"
    return 0
}

# Configure Git LFS globally (hooks and filters)
configure_git_lfs() {
    log_info "$(msg ENVL_CONFIGURING)"
    
    # 'git lfs install' sets up Git hooks and global filters in ~/.gitconfig.
    # It is idempotent and safe to run multiple times.
    # We suppress standard output to keep the CLI clean, only caring about the exit code.
    if git lfs install >/dev/null 2>&1; then
        log_success "$(msg ENVL_CONFIG_OK)"
        return 0
    else
        # If it fails, it's usually because it's already configured, which is fine.
        log_debug "$(msg ENVL_CONFIG_DONE)"
        return 0
    fi
}

# Perform a quick functionality verification
verify_git_lfs() {
    log_info "$(msg ENVL_VERIFYING)"
    
    # Check version output again to ensure binary is accessible in PATH
    if git-lfs version >/dev/null 2>&1; then
        log_success "$(msg ENVL_VERIFY_OK)"
        return 0
    else
        log_error "$(msg ENVL_VERIFY_FAILED)"
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msg ENVL_BANNER)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  $(msg ENVL_SUBTITLE)${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_git_lfs; then
        log_success "$(msg ENVL_HEALTHY)"
    else
        install_git_lfs || exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        configure_git_lfs || exit_code=1
        verify_git_lfs || exit_code=1
    fi

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "$(msg ENVL_DONE)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS) & $(msg LBL_USAGE):${COLOR_RESET}"
        echo "  $(msg ENVL_NEXT_1)"
        echo "  $(msg ENVL_NEXT_2)"
        echo ""
        echo "  $(msg ENVL_MANUAL_TITLE)"
        echo "  - $(msg ENVL_MANUAL_PULL)"
        echo "  - $(msg ENVL_MANUAL_TRACK)"
        echo "  - $(msg ENVL_MANUAL_LIST)"
        echo ""
    else
        log_error "$(msg ENVL_FAILED)"
        echo ""
        echo -e "${COLOR_YELLOW}$(msg TROUBLESHOOT_LABEL)${COLOR_RESET}"
        echo "  $(msg ENVL_TS_1)"
        echo "  $(msg ENVL_TS_2)"
        echo "  $(msg ENVL_TS_3)"
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
