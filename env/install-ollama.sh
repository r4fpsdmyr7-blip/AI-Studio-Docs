#!/bin/bash

# ============================================================================
# AI Studio - Ollama Installation Script (env/install-ollama.sh)
# Automates the installation, configuration, and verification of Ollama 
# for local LLM execution on macOS.
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

# Check if Ollama is already installed and functional
check_ollama() {
    if ! command_exists "ollama"; then
        return 1
    fi

    # Verify it can actually respond (not just a broken symlink)
    if ollama --version >/dev/null 2>&1; then
        local version
        version=$(ollama --version | awk '{print $3}') # Extract version number
        log_info "$(msgf ENVO_VERSION_OK "$version")"
        return 0
    else
        log_warn "$(msg ENVO_NOT_RESPONDING)"
        return 1
    fi
}

# Install Ollama using the official macOS installation script
install_ollama() {
    log_info "$(msg ENVO_INSTALLING)"
    log_info "${COLOR_GRAY}$(msg ENVO_PASSWORD_NOTE)${COLOR_RESET}"
    echo ""

    # Verify curl is available
    if ! command_exists "curl"; then
        log_error "$(msg ENVO_CURL_MISSING)"
        return 1
    fi

    # Execute official installation script
    # The official script handles architecture detection (Apple Silicon vs Intel) automatically
    log_info "$(msg ENVO_DOWNLOADING)"
    if ! run_remote_installer "https://ollama.com/install.sh"; then
        log_error "$(msg ENVO_INSTALL_FAILED)"
        log_info "$(msg ENVO_INSTALL_HINT)"
        return 1
    fi

    log_success "$(msg ENVO_INSTALL_OK)"
    return 0
}

# Ensure the Ollama background service is running
ensure_ollama_running() {
    log_info "$(msg ENVO_SERVICE_CHECK)"

    # On macOS, Ollama runs as a LaunchAgent
    # Check if the service is loaded and running
    if launchctl list | grep -q "ai.ollama.ollama"; then
        log_success "$(msg ENVO_SERVICE_OK)"
        return 0
    else
        log_warn "$(msg ENVO_SERVICE_DOWN)"
        
        # Try to start the service
        if launchctl start ai.ollama.ollama 2>/dev/null; then
            # Give it a moment to initialize
            sleep 2
            if launchctl list | grep -q "ai.ollama.ollama"; then
                log_success "$(msg ENVO_SERVICE_STARTED)"
                return 0
            fi
        fi
        
        log_error "$(msg ENVO_SERVICE_FAILED)"
        log_info "$(msg ENVO_SERVICE_HINT)"
        return 1
    fi
}

# Perform a quick functional test
verify_ollama_functionality() {
    log_info "$(msg ENVO_FUNC_CHECK)"
    
    # Check if the default port (11434) is listening
    if is_port_in_use 11434; then
        log_success "$(msg ENVO_API_OK)"
    else
        log_warn "$(msg ENVO_API_DOWN)"
    fi

    # Try to list models (will be empty on fresh install, but proves API works)
    if ollama list >/dev/null 2>&1; then
        log_success "$(msg ENVO_CLI_OK)"
        return 0
    else
        log_error "$(msg ENVO_CLI_FAILED)"
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msg ENVO_BANNER)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  $(msg ENVO_SUBTITLE)${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_ollama; then
        log_success "$(msg ENVO_HEALTHY)"
    else
        install_ollama || exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        ensure_ollama_running || exit_code=1
        verify_ollama_functionality || exit_code=1
    fi

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "$(msg ENVO_DONE)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
        echo "  $(msg ENVO_NEXT_1)"
        echo "     ollama pull qwen2.5:7b  # (Example, adjust to your preferred model)"
        echo "  $(msg ENVO_NEXT_2)"
        echo "     ./ai-studio.sh install open-webui"
        echo ""
        echo -e "${COLOR_GRAY}$(msg ENVO_TIP_APPLE)${COLOR_RESET}"
        echo ""
    else
        log_error "$(msg ENVO_FAILED)"
        echo ""
        echo -e "${COLOR_YELLOW}$(msg TROUBLESHOOT_LABEL)${COLOR_RESET}"
        echo "  $(msg ENVP_TS_1)"
        echo "  $(msg ENVO_TS_2)"
        echo "  $(msg ENVO_TS_3)"
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
