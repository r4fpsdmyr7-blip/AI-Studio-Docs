#!/bin/bash

# ============================================================================
# AI Studio - Environment Check Library (lib/env-check.sh)
# Detects system requirements and reports missing dependencies.
# ============================================================================

# Ensure common functions are available
# This script expects to be sourced after lib/common.sh

# ============================================================================
# 1. System Requirement Constants
# ============================================================================
readonly MIN_MACOS_VERSION="13"      # macOS 13.0 (Ventura) minimum
readonly MIN_DISK_SPACE_GB="50"      # Minimum 50GB free space
readonly MIN_MEMORY_GB="16"          # Minimum 16GB RAM

# Core tools required for basic operations
readonly REQUIRED_TOOLS=("git" "curl" "python3" "node" "npm")
# Recommended tools (warn if missing, but don't fail hard)
readonly RECOMMENDED_TOOLS=("brew" "ollama")

# ============================================================================
# 2. Individual Check Functions
# ============================================================================

# Check macOS version
check_os_version() {
    log_info "$(msg ENVCHECK_MACOS_START)"
    if ! is_macos; then
        log_error "$(msg ENVCHECK_UNSUPPORTED_OS)"
        return 1
    fi

    local os_version
    os_version=$(sw_vers -productVersion | cut -d. -f1)
    
    if [[ "$os_version" -lt "$MIN_MACOS_VERSION" ]]; then
        log_error "$(msgf ENVCHECK_MACOS_OLD "$(sw_vers -productVersion)" "$MIN_MACOS_VERSION")"
        return 1
    fi
    
    log_success "$(msgf ENVCHECK_MACOS_OK "$(sw_vers -productVersion)")"
    return 0
}

# Check hardware architecture
check_hardware() {
    log_info "$(msg ENVCHECK_HW_START)"
    local arch
    arch=$(uname -m)
    
    if [[ "$arch" == "arm64" ]]; then
        log_success "$(msgf ENVCHECK_HW_APPLE "$arch")"
    elif [[ "$arch" == "x86_64" ]]; then
        log_warn "$(msgf ENVCHECK_HW_INTEL "$arch")"
    else
        log_error "$(msgf ENVCHECK_HW_UNKNOWN "$arch")"
        return 1
    fi
    return 0
}

# Check available disk space
check_disk_space() {
    log_info "$(msg ENVCHECK_DISK_START)"
    # Get available space in GB on the root partition
    local available_gb
    available_gb=$(df -g / | awk 'NR==2 {print $4}')
    
    # Remove any non-numeric characters (just in case)
    available_gb=$(echo "$available_gb" | tr -dc '0-9')

    if [[ "$available_gb" -lt "$MIN_DISK_SPACE_GB" ]]; then
        log_error "$(msgf ENVCHECK_DISK_LOW "$available_gb" "$MIN_DISK_SPACE_GB")"
        log_info "$(msg ENVCHECK_DISK_HINT)"
        return 1
    fi
    
    log_success "$(msgf ENVCHECK_DISK_OK "$available_gb")"
    return 0
}

# Check system memory (RAM)
check_memory() {
    log_info "$(msg ENVCHECK_MEM_START)"
    # Get total memory in bytes, then convert to GB
    local mem_bytes
    mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    
    if [[ -z "$mem_bytes" ]]; then
        log_warn "$(msg ENVCHECK_MEM_UNKNOWN)"
        return 0
    fi

    # Calculate GB (bytes / 1024 / 1024 / 1024)
    local mem_gb=$((mem_bytes / 1073741824))

    if [[ "$mem_gb" -lt "$MIN_MEMORY_GB" ]]; then
        log_warn "$(msgf ENVCHECK_MEM_LOW "$mem_gb" "$MIN_MEMORY_GB")"
        log_info "$(msg ENVCHECK_MEM_HINT)"
        # Return 0 because it's a warning, not a hard failure for basic usage
    else
        log_success "$(msgf ENVCHECK_MEM_OK "$mem_gb")"
    fi
    return 0
}

# Check for required and recommended command-line tools
check_tools() {
    log_info "$(msg ENVCHECK_TOOLS_START)"
    local missing_required=()
    local missing_recommended=()

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command_exists "$tool"; then
            missing_required+=("$tool")
        fi
    done

    for tool in "${RECOMMENDED_TOOLS[@]}"; do
        if ! command_exists "$tool"; then
            missing_recommended+=("$tool")
        fi
    done

    # Report results
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        log_error "$(msgf ENVCHECK_MISSING_REQUIRED "${missing_required[*]}")"
        log_info "$(msg ENVCHECK_INSTALL_HINT)"
        return 1
    fi

    if [[ ${#missing_recommended[@]} -gt 0 ]]; then
        log_warn "$(msgf ENVCHECK_MISSING_RECOMMENDED "${missing_recommended[*]}")"
        log_info "$(msg ENVCHECK_INSTALL_REC_HINT)"
    else
        log_success "$(msg ENVCHECK_TOOLS_OK)"
    fi
    
    return 0
}

# ============================================================================
# 3. Aggregated Check Function
# ============================================================================

# Run all environment checks and provide a summary
# Usage: check_all_requirements
# Returns: 0 if all critical checks pass, 1 if any critical check fails
check_all_requirements() {
    print_separator
    log_info "$(msg ENVCHECK_START)"
    print_separator

    local failed_checks=0

    # Run checks and count failures
    check_os_version || ((failed_checks++))
    check_hardware || ((failed_checks++))
    check_disk_space || ((failed_checks++))
    check_memory    # Memory is a warning, doesn't increment failed_checks
    check_tools || ((failed_checks++))

    print_separator
    
    if [[ $failed_checks -eq 0 ]]; then
        log_success "$(msg ENVCHECK_PASSED)"
        return 0
    else
        log_error "$(msgf ENVCHECK_FAILED "$failed_checks")"
        log_info "$(msg ENVCHECK_FAILED_HINT)"
        return 1
    fi
}

# ============================================================================
# 4. Helper for Status Command
# ============================================================================

# Show a brief summary of the environment status (for `ai-studio.sh env status`)
show_environment_status() {
    echo ""
    echo "$(msg ENVCHECK_STATUS_TITLE)"
    printf "%s : %s\n" "$(pad_display "$(msg ENVCHECK_LBL_OS)" 25)" "$(sw_vers -productName) $(sw_vers -productVersion)"
    printf "%s : %s\n" "$(pad_display "$(msg ENVCHECK_LBL_ARCH)" 25)" "$(uname -m)"
    
    local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    local mem_gb=$((mem_bytes / 1073741824))
    printf "%s : %s GB\n" "$(pad_display "$(msg ENVCHECK_LBL_MEM)" 25)" "$mem_gb"
    
    local available_gb=$(df -g / | awk 'NR==2 {print $4}')
    printf "%s : %s GB\n" "$(pad_display "$(msg ENVCHECK_LBL_DISK)" 25)" "$available_gb"
    
    echo ""
    echo "$(msg ENVCHECK_CORE_TOOLS)"
    for tool in "${REQUIRED_TOOLS[@]}" "${RECOMMENDED_TOOLS[@]}"; do
        if command_exists "$tool"; then
            printf "  [OK] %-15s : %s\n" "$tool" "$(msg ENVCHECK_INSTALLED)"
        else
            printf "  [FAIL] %-15s : %s\n" "$tool" "$(msg ENVCHECK_MISSING)"
        fi
    done
    echo "=================================="
    echo ""
}
