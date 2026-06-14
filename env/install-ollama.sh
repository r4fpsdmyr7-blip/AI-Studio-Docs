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
        log_info "Ollama v${version} is already installed."
        return 0
    else
        log_warn "Ollama command exists but is not responding correctly."
        return 1
    fi
}

# Install Ollama using the official macOS installation script
install_ollama() {
    log_info "Starting Ollama installation..."
    log_info "${COLOR_GRAY}(Note: This will download the official installer and may prompt for your password)${COLOR_RESET}"
    echo ""

    # Verify curl is available
    if ! command_exists "curl"; then
        log_error "'curl' is required to download the Ollama installer but is missing."
        return 1
    fi

    # Execute official installation script
    # The official script handles architecture detection (Apple Silicon vs Intel) automatically
    log_info "Downloading and executing official Ollama installer..."
    if ! curl -fsSL https://ollama.com/install.sh | sh; then
        log_error "Ollama installation failed."
        log_info "Please check your network connection or install manually from: https://ollama.com"
        return 1
    fi

    log_success "Ollama installed successfully!"
    return 0
}

# Ensure the Ollama background service is running
ensure_ollama_running() {
    log_info "Verifying Ollama background service status..."

    # On macOS, Ollama runs as a LaunchAgent
    # Check if the service is loaded and running
    if launchctl list | grep -q "ai.ollama.ollama"; then
        log_success "Ollama service is running in the background."
        return 0
    else
        log_warn "Ollama service is not running. Attempting to start it..."
        
        # Try to start the service
        if launchctl start ai.ollama.ollama 2>/dev/null; then
            # Give it a moment to initialize
            sleep 2
            if launchctl list | grep -q "ai.ollama.ollama"; then
                log_success "Ollama service started successfully."
                return 0
            fi
        fi
        
        log_error "Failed to start Ollama service automatically."
        log_info "You may need to log out and log back in, or start it manually via Spotlight."
        return 1
    fi
}

# Perform a quick functional test
verify_ollama_functionality() {
    log_info "Performing quick functionality check..."
    
    # Check if the default port (11434) is listening
    if is_port_in_use 11434; then
        log_success "Ollama API is listening on port 11434."
    else
        log_warn "Ollama port 11434 is not listening. The service might still be starting up."
    fi

    # Try to list models (will be empty on fresh install, but proves API works)
    if ollama list >/dev/null 2>&1; then
        log_success "Ollama CLI is fully functional."
        return 0
    else
        log_error "Ollama CLI failed to execute 'ollama list'."
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  AI Studio - Ollama Installer${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  Setting up local LLM execution engine...${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_ollama; then
        log_success "Ollama is already installed and healthy."
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
        log_success "Ollama setup completed successfully."
        echo ""
        echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
        echo "  1. Pull your first model (e.g., QWen3 or Llama 3):"
        echo "     ollama pull qwen2.5:7b  # (Example, adjust to your preferred model)"
        echo "  2. Deploy a UI to interact with it:"
        echo "     ./ai-studio.sh install open-webui"
        echo ""
        echo -e "${COLOR_GRAY}💡 Tip: Ollama is natively optimized for Apple Silicon (M1/M2/M3/M4)${COLOR_RESET}"
        echo ""
    else
        log_error "Ollama setup encountered an error."
        echo ""
        echo -e "${COLOR_YELLOW}Troubleshooting:${COLOR_RESET}"
        echo "  1. Ensure you have a stable internet connection."
        echo "  2. Check if Ollama is running via Activity Monitor or Spotlight."
        echo "  3. Visit https://ollama.com for manual installation instructions."
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
