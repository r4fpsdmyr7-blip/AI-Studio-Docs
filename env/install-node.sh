#!/bin/bash

# ============================================================================
# AI Studio - Node.js Environment Installation Script (env/install-node.sh)
# Automates the installation and configuration of a compatible Node.js 
# environment for Web-based AI components on macOS.
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
readonly MIN_NODE_MAJOR="18" # Node 18 is the current minimum LTS requirement for most modern AI Web UIs
readonly TARGET_NODE_VERSION="node" # Installing default 'node' from brew ensures the latest stable LTS

# ============================================================================
# 4. Core Installation Logic
# ============================================================================

# Check if the current node meets the minimum version requirement
check_node_version() {
    if ! command_exists "node"; then
        return 1
    fi

    # Extract major version (e.g., "v20.11.1" -> "20")
    local version_str
    version_str=$(node --version 2>&1 | tr -d 'v')
    local major
    major=$(echo "$version_str" | cut -d. -f1)

    if [[ "$major" -ge "$MIN_NODE_MAJOR" ]]; then
        log_info "$(msgf ENVN_VERSION_OK "$version_str" "$MIN_NODE_MAJOR")"
        return 0
    else
        log_warn "$(msgf ENVN_VERSION_LOW "$version_str" "$MIN_NODE_MAJOR")"
        return 1
    fi
}

# Install Node.js via Homebrew
install_node_via_brew() {
    log_info "$(msg ENVN_INSTALLING)"

    # Ensure brew is available
    if ! command_exists "brew"; then
        log_error "$(msg ENVN_NEED_HOMEBREW)"
        log_info "$(msg ENVP_HOMEBREW_HINT)"
        return 1
    fi

    # Install node
    log_info "$(msgf ENVN_RUNNING_CMD "$TARGET_NODE_VERSION")"
    if ! brew install "${TARGET_NODE_VERSION}"; then
        log_error "$(msg ENVN_INSTALL_FAILED)"
        return 1
    fi

    log_success "$(msg ENVN_INSTALL_OK)"
    return 0
}

# Ensure essential Node.js packaging tools are up to date and configured
setup_npm_toolchain() {
    log_info "$(msg ENVN_TOOLCHAIN)"
    
    # 1. Update npm to the latest version compatible with the installed Node
    log_info "$(msg ENVN_NPM_UPDATING)"
    if ! npm install -g npm@latest >/dev/null 2>&1; then
        log_warn "$(msg ENVN_NPM_FAILED)"
    else
        log_success "$(msg ENVN_NPM_OK)"
    fi

    # 2. Verify core tools
    local tools_to_check=("node" "npm" "npx")
    local missing_tools=()

    for tool in "${tools_to_check[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "$(msgf ENVN_TOOLS_MISSING "${missing_tools[*]}")"
        log_info "$(msg ENVN_TOOLS_HINT)"
        return 1
    fi

    log_success "$(msg ENVN_TOOLS_OK)"
    return 0
}

# Optional: Configure npm to install global packages in user directory to avoid sudo
# This is a best practice for macOS to prevent permission errors.
configure_npm_global_prefix() {
    log_info "$(msg ENVN_NPM_CONFIG)"
    
    local npm_global_dir="$HOME/.npm-global"
    
    # Create directory if it doesn't exist
    mkdir -p "$npm_global_dir"

    # Set npm config
    npm config set prefix "$npm_global_dir" >/dev/null 2>&1

    local shell_profile=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zprofile"
    else
        shell_profile="$HOME/.bash_profile"
    fi

    # Add to PATH if not already present
    if ! grep -q "$npm_global_dir/bin" "$shell_profile" 2>/dev/null; then
        log_info "$(msgf ENVN_NPM_PATH_ADDING "$shell_profile")"
        echo "" >> "$shell_profile"
        echo "# Added by AI Studio: npm global packages PATH" >> "$shell_profile"
        echo "export PATH=\"${npm_global_dir}/bin:\$PATH\"" >> "$shell_profile"
        
        # Apply to current session
        export PATH="${npm_global_dir}/bin:${PATH}"
    fi
    
    log_success "$(msg ENVN_NPM_PATH_OK)"
}

# ============================================================================
# 5. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msg ENVN_BANNER)${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_node_version; then
        log_success "$(msg ENVN_HEALTHY)"
    else
        install_node_via_brew || exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        # Even if node was already installed, we still want to ensure the toolchain and permissions are correct
        setup_npm_toolchain || exit_code=1
        configure_npm_global_prefix || exit_code=1
    fi

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "$(msg ENVN_DONE)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
        echo "  $(msg ENVN_NEXT_1)"
        echo "  Run: ./ai-studio.sh install open-webui"
        echo ""
    else
        log_error "$(msg ENVN_FAILED)"
        echo ""
        echo -e "${COLOR_YELLOW}$(msg TROUBLESHOOT_LABEL)${COLOR_RESET}"
        echo "  $(msg ENVN_TS_1)"
        echo "  $(msg ENVN_TS_2)"
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
