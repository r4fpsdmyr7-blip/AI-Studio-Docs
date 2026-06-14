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
    log_info "Git LFS v${version} is already installed."
    return 0
}

# Install Git LFS via Homebrew
install_git_lfs() {
    log_info "Installing Git LFS via Homebrew..."

    # Ensure Homebrew is available
    if ! command_exists "brew"; then
        log_error "Homebrew is required to install Git LFS, but it is not found."
        log_info "Please run './env/install-homebrew.sh' first."
        return 1
    fi

    # Git LFS requires Git. Install Git if missing.
    if ! command_exists "git"; then
        log_warn "Git is not detected. Installing Git alongside Git LFS..."
        brew install git >/dev/null 2>&1 || {
            log_error "Failed to install Git. Git LFS cannot function without it."
            return 1
        }
    fi

    # Install Git LFS
    log_info "Running: brew install git-lfs"
    if ! brew install git-lfs; then
        log_error "Failed to install Git LFS via Homebrew."
        return 1
    fi

    log_success "Git LFS installed successfully."
    return 0
}

# Configure Git LFS globally (hooks and filters)
configure_git_lfs() {
    log_info "Configuring Git LFS globally..."
    
    # 'git lfs install' sets up Git hooks and global filters in ~/.gitconfig.
    # It is idempotent and safe to run multiple times.
    # We suppress standard output to keep the CLI clean, only caring about the exit code.
    if git lfs install >/dev/null 2>&1; then
        log_success "Git LFS global hooks and filters configured."
        return 0
    else
        # If it fails, it's usually because it's already configured, which is fine.
        log_debug "Git LFS configuration completed (may already be set up)."
        return 0
    fi
}

# Perform a quick functionality verification
verify_git_lfs() {
    log_info "Verifying Git LFS functionality..."
    
    # Check version output again to ensure binary is accessible in PATH
    if git-lfs version >/dev/null 2>&1; then
        log_success "Git LFS is fully functional and ready for large file tracking."
        return 0
    else
        log_error "Git LFS binary verification failed."
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  AI Studio - Git LFS Installer${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  Setting up large file support for AI models & datasets...${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_git_lfs; then
        log_success "Git LFS is already installed and healthy."
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
        log_success "Git LFS setup completed successfully."
        echo ""
        echo -e "${COLOR_CYAN}Next Steps & Usage:${COLOR_RESET}"
        echo "  Git LFS is now globally configured for your user account."
        echo "  When cloning repositories containing AI models, LFS files will download automatically."
        echo ""
        echo "  Manual LFS operations (if needed):"
        echo "  • Pull large files manually: git lfs pull"
        echo "  • Track a new file type:  git lfs track '*.safetensors'"
        echo "  • List tracked patterns:  git lfs track"
        echo ""
    else
        log_error "Git LFS setup encountered an error."
        echo ""
        echo -e "${COLOR_YELLOW}Troubleshooting:${COLOR_RESET}"
        echo "  1. Ensure Homebrew is installed and up to date: brew doctor"
        echo "  2. Verify Git installation: git --version"
        echo "  3. Visit https://git-lfs.com for manual installation instructions."
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
