#!/bin/bash

# ============================================================================
# AI Studio - Homebrew Installation Script (env/install-homebrew.sh)
# Automates the installation and configuration of Homebrew on macOS.
# Can be run standalone or sourced by other installation scripts.
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

install_homebrew() {
    log_info "$(msg ENVB_CHECKING)"

    # Check if brew is already available in the current PATH
    if command_exists "brew"; then
        log_success "$(msg ENVB_ALREADY)"
        
        # Optional: Run a quick update to ensure it's healthy
        log_info "$(msg ENVB_UPDATING)"
        brew update --quiet >/dev/null 2>&1
        return 0
    fi

    log_warn "$(msg ENVB_NOT_FOUND)"
    log_info "$(msg ENVB_INSTALLING)"
    log_info "${COLOR_GRAY}$(msg ENVB_PASSWORD_NOTE)${COLOR_RESET}"
    echo ""

    # Verify curl is available (required for the installation script)
    if ! command_exists "curl"; then
        log_error "$(msg ENVB_CURL_MISSING)"
        log_info "$(msg ENVB_CURL_HINT)"
        return 1
    fi

    # Execute the official Homebrew installation script
    # -f: fail silently on server errors, -s: silent mode, -S: show errors, -L: follow redirects
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    local install_status=$?

    if [[ $install_status -ne 0 ]]; then
        log_error "$(msgf ENVB_INSTALL_FAILED "$install_status")"
        log_info "$(msg ENVB_INSTALL_HINT)"
        return 1
    fi

    log_success "$(msg ENVB_INSTALL_OK)"
    echo ""

    # ========================================================================
    # 4. Post-Installation PATH Configuration
    # ========================================================================
    # Homebrew installs to different locations based on architecture.
    # We need to ensure the user's shell knows where to find it.
    
    local brew_path=""
    local shell_profile=""

    # Determine architecture and set paths
    if is_apple_silicon; then
        brew_path="/opt/homebrew/bin"
        log_info "$(msgf ENVB_APPLE_PATH "${COLOR_CYAN}${brew_path}${COLOR_RESET}")"
    else
        brew_path="/usr/local/bin"
        log_info "$(msgf ENVB_INTEL_PATH "${COLOR_CYAN}${brew_path}${COLOR_RESET}")"
    fi

    # Determine the user's default shell profile
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zprofile"
    else
        shell_profile="$HOME/.bash_profile"
    fi

    # Check if the path is already in the profile
    if ! grep -q "$brew_path" "$shell_profile" 2>/dev/null; then
        log_info "$(msgf ENVB_PROFILE_ADDING "$shell_profile")"
        echo "" >> "$shell_profile"
        echo "# Added by AI Studio: Homebrew PATH" >> "$shell_profile"
        echo "eval \"\$(${brew_path}/brew shellenv)\"" >> "$shell_profile"
        
        # Apply to the current session immediately
        eval "$(${brew_path}/brew shellenv)"
        
        log_success "$(msg ENVB_PROFILE_OK)"
    else
        log_info "$(msg ENVB_PROFILE_EXISTS)"
        # Still apply to current session just in case it wasn't loaded
        eval "$(${brew_path}/brew shellenv)"
    fi

    echo ""
    log_info "$(msg ENVB_VERIFY)"
    brew --version | head -n 1
    
    return 0
}

# ============================================================================
# 5. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msg ENVB_BANNER)${COLOR_RESET}"
    print_separator
    echo ""

    install_homebrew
    local exit_code=$?

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "$(msg ENVB_DONE)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
        echo "  $(msg ENVB_NEXT_INTRO)"
        echo "  ./env/install-deps.sh"
        echo ""
    else
        log_error "$(msg ENVB_FAILED)"
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
