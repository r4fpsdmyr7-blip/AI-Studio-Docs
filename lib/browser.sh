#!/bin/bash

# ============================================================================
# AI Studio - Browser Control Library (lib/browser.sh)
# Handles automatic browser opening after service startup with robust fallbacks.
# ============================================================================

# Ensure common and config functions are available
# This script expects to be sourced after lib/common.sh and lib/config.sh

# ============================================================================
# 1. Core Browser Functions
# ============================================================================

# Open a URL in the system's default browser (or a specified browser)
# Usage: open_browser "http://localhost:3000" ["Google Chrome"]
open_browser() {
    local url="$1"
    local browser="${2:-}" # Optional: specific browser application name

    # 1. Respect user configuration (Progressive Disclosure: can be disabled)
    if ! is_config_true "AUTO_OPEN_BROWSER" "global"; then
        log_debug "Auto-open browser is disabled in config. Skipping opening: $url"
        return 0
    fi

    # 2. Basic URL validation
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Invalid URL provided to open_browser: $url"
        return 1
    fi

    # 3. Execute the open command
    log_info "Opening browser to: ${COLOR_CYAN}${url}${COLOR_RESET}"
    
    local open_cmd
    if [[ -n "$browser" ]]; then
        # Open in a specific application (e.g., "Google Chrome", "Safari", "Firefox")
        open_cmd=(open -a "$browser" "$url")
    else
        # Open in the system default browser
        open_cmd=(open "$url")
    fi

    # Execute and capture output/errors silently, checking exit status
    if "${open_cmd[@]}" 2>/dev/null; then
        log_success "Browser opened successfully."
        return 0
    else
        log_warn "Failed to automatically open the browser via command line."
        log_info "Please manually open your browser and navigate to: ${COLOR_CYAN}${url}${COLOR_RESET}"
        return 1
    fi
}

# Wait for a service port to be ready, then automatically open the browser
# This is the recommended function for component `start.sh` scripts.
# Usage: open_browser_when_ready "http://localhost:8188" 8188 15
open_browser_when_ready() {
    local url="$1"
    local port="$2"
    local timeout="${3:-15}" # Default 15 seconds timeout
    local browser="${4:-}"   # Optional specific browser

    log_info "Waiting for service on port $port before opening browser..."
    
    # Reuse the robust wait_for_port function from common.sh
    if wait_for_port "$port" "$timeout"; then
        # Give the web server a tiny extra moment to fully initialize its UI
        sleep 1
        open_browser "$url" "$browser"
    else
        log_warn "Service on port $port did not become ready within ${timeout} seconds."
        log_info "The service might still be starting up in the background, or it may have failed."
        log_info "You can manually try accessing: ${COLOR_CYAN}${url}${COLOR_RESET}"
        log_info "Or check the logs: ${COLOR_GRAY}./ai-studio.sh status $port${COLOR_RESET} (Note: check component status instead)"
        return 1
    fi
}

# ============================================================================
# 2. Advanced / Utility Functions
# ============================================================================

# Check if a specific browser application is installed on macOS
# Usage: if is_browser_installed "Google Chrome"; then ...
is_browser_installed() {
    local app_name="$1"
    # Check common installation paths for macOS applications
    if [[ -d "/Applications/$app_name.app" ]] || [[ -d "$HOME/Applications/$app_name.app" ]]; then
        return 0
    fi
    return 1
}

# Get a list of commonly installed browsers on the system
# Usage: browsers=$(get_available_browsers)
get_available_browsers() {
    local browsers=()
    local common_browsers=("Safari" "Google Chrome" "Firefox" "Microsoft Edge" "Arc" "Brave Browser")
    
    for browser in "${common_browsers[@]}"; do
        if is_browser_installed "$browser"; then
            browsers+=("$browser")
        fi
    done
    
    echo "${browsers[@]}"
}

# Force open a URL, bypassing the AUTO_OPEN_BROWSER config check
# Useful for explicit user commands like `./ai-studio.sh open <component>` (if implemented later)
force_open_browser() {
    local url="$1"
    local browser="${2:-}"
    
    # Temporarily override the config check by directly calling the core logic
    # We duplicate the validation and execution here for safety and clarity
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Invalid URL provided to force_open_browser: $url"
        return 1
    fi

    log_info "Force opening browser to: ${COLOR_CYAN}${url}${COLOR_RESET}"
    
    if [[ -n "$browser" ]]; then
        open -a "$browser" "$url" 2>/dev/null
    else
        open "$url" 2>/dev/null
    fi

    if [[ $? -eq 0 ]]; then
        return 0
    else
        log_warn "Failed to open browser. Please navigate manually to: $url"
        return 1
    fi
}
