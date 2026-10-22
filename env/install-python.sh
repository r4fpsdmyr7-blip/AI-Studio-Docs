#!/bin/bash

# ============================================================================
# AI Studio - Python Environment Installation Script (env/install-python.sh)
# Automates the installation and configuration of a compatible Python 3 
# environment for AI components on macOS.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 2. Source core libraries
source "$AI_STUDIO_ROOT/lib/common.sh"

# ============================================================================
# 3. Configuration Constants
# ============================================================================
readonly MIN_PYTHON_MAJOR="3"
readonly MIN_PYTHON_MINOR="10"
readonly TARGET_PYTHON_VERSION="3.11" # 3.11 offers the best compatibility for current AI tools (MLX, ComfyUI, etc.)

# ============================================================================
# 4. Core Installation Logic
# ============================================================================

# Check if the current python3 meets the minimum version requirement
check_python_version() {
    if ! command_exists "python3"; then
        return 1
    fi

    # Extract major and minor version (e.g., "3.11.4" -> "3" and "11")
    local version_str
    version_str=$(python3 --version 2>&1 | awk '{print $2}')
    local major minor
    major=$(echo "$version_str" | cut -d. -f1)
    minor=$(echo "$version_str" | cut -d. -f2)

    if [[ "$major" -gt "$MIN_PYTHON_MAJOR" ]] || \
       { [[ "$major" -eq "$MIN_PYTHON_MAJOR" ]] && [[ "$minor" -ge "$MIN_PYTHON_MINOR" ]]; }; then
        log_info "$(msgf ENVP_VERSION_OK "$version_str" "$MIN_PYTHON_MAJOR" "$MIN_PYTHON_MINOR")"
        return 0
    else
        log_warn "$(msgf ENVP_VERSION_LOW "$version_str" "$MIN_PYTHON_MAJOR" "$MIN_PYTHON_MINOR")"
        return 1
    fi
}

# Install Python via Homebrew
install_python_via_brew() {
    log_info "$(msgf ENVP_INSTALLING "$TARGET_PYTHON_VERSION")"

    # Ensure brew is available
    if ! command_exists "brew"; then
        log_error "$(msg ENVP_NEED_HOMEBREW)"
        log_info "$(msg ENVP_HOMEBREW_HINT)"
        return 1
    fi

    # Install specific Python version
    log_info "$(msgf ENVP_RUNNING_CMD "$TARGET_PYTHON_VERSION")"
    if ! brew install "python@${TARGET_PYTHON_VERSION}"; then
        log_error "$(msgf ENVP_INSTALL_FAILED "$TARGET_PYTHON_VERSION")"
        return 1
    fi

    log_success "$(msgf ENVP_INSTALL_OK "$TARGET_PYTHON_VERSION")"
    
    # Handle Homebrew's keg-only nature for python@3.11
    # We need to ensure it's accessible as 'python3' in the current session and future sessions
    configure_python_path
}

# Configure PATH to ensure the newly installed Python is prioritized
configure_python_path() {
    local brew_prefix
    brew_prefix=$(brew --prefix "python@${TARGET_PYTHON_VERSION}" 2>/dev/null)
    
    if [[ -z "$brew_prefix" ]] || [[ ! -d "$brew_prefix" ]]; then
        log_warn "$(msg ENVP_PREFIX_UNKNOWN)"
        return 1
    fi

    local python_bin_dir="${brew_prefix}/libexec/bin"
    local shell_profile=""

    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zprofile"
    else
        shell_profile="$HOME/.bash_profile"
    fi

    # Check if already configured
    if grep -q "$python_bin_dir" "$shell_profile" 2>/dev/null; then
        log_info "$(msgf ENVP_PATH_EXISTS "$shell_profile")"
    else
        log_info "$(msgf ENVP_PATH_ADDING "$TARGET_PYTHON_VERSION" "$shell_profile")"
        echo "" >> "$shell_profile"
        echo "# Added by AI Studio: Python ${TARGET_PYTHON_VERSION} PATH" >> "$shell_profile"
        echo "export PATH=\"${python_bin_dir}:\$PATH\"" >> "$shell_profile"
    fi

    # Apply to current session immediately
    export PATH="${python_bin_dir}:${PATH}"
    
    # Verify the active python3 is now the correct one
    if check_python_version; then
        log_success "$(msg ENVP_PATH_OK)"
    else
        log_warn "$(msg ENVP_PATH_OLD)"
    fi
}

# Ensure essential Python packaging tools are up to date
setup_python_toolchain() {
    log_info "$(msg ENVP_TOOLCHAIN)"
    
    # Upgrade pip, setuptools, and wheel (essential for building AI dependencies)
    if ! python3 -m pip install --upgrade --quiet pip setuptools wheel; then
        log_warn "$(msg ENVP_TOOLCHAIN_FAILED)"
    else
        log_success "$(msg ENVP_TOOLCHAIN_OK)"
    fi

    # Verify venv module is available (critical for component isolation)
    if ! python3 -m venv --help >/dev/null 2>&1; then
        log_error "$(msg ENVP_VENV_MISSING)"
        return 1
    fi
    log_success "$(msg ENVP_VENV_OK)"
    
    return 0
}

# ============================================================================
# 5. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msg ENVP_BANNER)${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_python_version; then
        log_success "$(msg ENVP_HEALTHY)"
        # Still ensure toolchain is ready even if version is OK
        setup_python_toolchain || exit_code=1
    else
        install_python_via_brew || exit_code=1
        
        if [[ $exit_code -eq 0 ]]; then
            setup_python_toolchain || exit_code=1
        fi
    fi

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "$(msg ENVP_DONE)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
        echo "  $(msg ENVP_NEXT_INTRO)"
        echo "  ./env/install-nodejs.sh  (if needed for Web UIs)"
        echo "  ./env/install-ollama.sh  (for local LLM execution)"
        echo ""
    else
        log_error "$(msg ENVP_FAILED)"
        echo ""
        echo -e "${COLOR_YELLOW}$(msg TROUBLESHOOT_LABEL)${COLOR_RESET}"
        echo "  $(msg ENVP_TS_1)"
        echo "  $(msg ENVP_TS_2)"
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
