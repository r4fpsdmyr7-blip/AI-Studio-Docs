#!/bin/bash

# ============================================================================
# AI Studio - Environment Install Library (lib/env-install.sh)
# Automates the installation of system dependencies and AI toolchains.
# ============================================================================

# ============================================================================
# 1. Installation Functions
# ============================================================================

install_homebrew() {
    if command_exists "brew"; then
        log_info "$(msg ENVINSTALL_HOMEBREW_EXISTS)"
        return 0
    fi
    log_info "$(msg ENVINSTALL_HOMEBREW_INSTALLING)"
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ $? -ne 0 ]; then
        log_error "$(msg ENVINSTALL_HOMEBREW_FAILED)"
        return 1
    fi

    if is_apple_silicon; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    log_success "$(msg ENVINSTALL_HOMEBREW_OK)"
    return 0
}

install_basic_tools() {
    log_info "$(msg ENVINSTALL_BASIC_CHECK)"
    local tools_to_install=""
    
    for tool in git curl wget; do
        if ! command_exists "$tool"; then
            tools_to_install="$tools_to_install $tool"
        fi
    done

    if [ -z "$tools_to_install" ]; then
        log_info "$(msg ENVINSTALL_BASIC_OK_EXISTS)"
        return 0
    fi

    log_info "$(msgf ENVINSTALL_BASIC_INSTALLING "$tools_to_install")"
    brew install $tools_to_install
    if [ $? -ne 0 ]; then
        log_error "$(msg ENVINSTALL_BASIC_FAILED)"
        return 1
    fi
    log_success "$(msg ENVINSTALL_BASIC_OK)"
    return 0
}

install_runtime_envs() {
    log_info "$(msg ENVINSTALL_RUNTIME_CHECK)"
    
    if ! command_exists "python3"; then
        log_info "$(msg ENVINSTALL_PYTHON_INSTALLING)"
        brew install python@3.11
        if [ $? -ne 0 ]; then
            log_error "$(msg ENVINSTALL_PYTHON_FAILED)"
            return 1
        fi
    else
        log_info "$(msg ENVINSTALL_PYTHON_EXISTS)"
    fi

    if ! command_exists "node"; then
        log_info "$(msg ENVINSTALL_NODE_INSTALLING)"
        brew install node
        if [ $? -ne 0 ]; then
            log_error "$(msg ENVINSTALL_NODE_FAILED)"
            return 1
        fi
    else
        log_info "$(msg ENVINSTALL_NODE_EXISTS)"
    fi
    log_success "$(msg ENVINSTALL_RUNTIME_OK)"
    return 0
}

install_ai_tools() {
    log_info "$(msg ENVINSTALL_AI_CHECK)"
    if ! command_exists "ollama"; then
        log_info "$(msg ENVINSTALL_OLLAMA_INSTALLING)"
        curl -fsSL https://ollama.com/install.sh | sh
        if [ $? -ne 0 ]; then
            log_error "$(msg ENVINSTALL_OLLAMA_FAILED)"
            return 1
        fi
        log_success "$(msg ENVINSTALL_OLLAMA_OK)"
    else
        log_info "$(msg ENVINSTALL_OLLAMA_EXISTS)"
    fi
    return 0
}

# ============================================================================
# 2. Aggregated Installation Function
# ============================================================================

install_all_dependencies() {
    print_separator
    log_info "$(msg ENVINSTALL_START)"
    log_warn "$(msg ENVINSTALL_NEED_PASSWORD)"
    print_separator

    local failed_steps=0

    install_homebrew
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi
    
    install_basic_tools
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi
    
    install_runtime_envs
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi
    
    install_ai_tools
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi

    print_separator
    if [ "$failed_steps" -eq 0 ]; then
        log_success "$(msg ENVINSTALL_DONE)"
        log_info "$(msg ENVINSTALL_READY)"
        return 0
    else
        log_error "$(msgf ENVINSTALL_FAILED_N "$failed_steps")"
        return 1
    fi
}

# ============================================================================
# 3. Helper for Specific Component Dependencies
# ============================================================================

install_component_deps() {
    local component="$1"
    shift
    local missing_deps=""

    log_info "$(msgf ENVINSTALL_DEPS_CHECK "$component")"

    for dep in "$@"; do
        if ! command_exists "$dep"; then
            missing_deps="$missing_deps $dep"
        fi
    done

    if [ -z "$missing_deps" ]; then
        log_info "$(msgf ENVINSTALL_DEPS_OK_EXISTS "$component")"
        return 0
    fi

    log_info "$(msgf ENVINSTALL_DEPS_INSTALLING "$component" "$missing_deps")"
    brew install $missing_deps
    if [ $? -ne 0 ]; then
        log_error "$(msgf ENVINSTALL_DEPS_FAILED "$component")"
        return 1
    fi

    log_success "$(msgf ENVINSTALL_DEPS_OK "$component")"
    return 0
}
