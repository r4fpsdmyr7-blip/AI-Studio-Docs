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
    log_info "Checking macOS version..."
    if ! is_macos; then
        log_error "Unsupported operating system. AI Studio requires macOS."
        return 1
    fi

    local os_version
    os_version=$(sw_vers -productVersion | cut -d. -f1)
    
    if [[ "$os_version" -lt "$MIN_MACOS_VERSION" ]]; then
        log_error "macOS version is too old. Found: $(sw_vers -productVersion), Required: ${MIN_MACOS_VERSION}.0 or later."
        return 1
    fi
    
    log_success "macOS version check passed ($(sw_vers -productVersion))."
    return 0
}

# Check hardware architecture
check_hardware() {
    log_info "Checking hardware architecture..."
    local arch
    arch=$(uname -m)
    
    if [[ "$arch" == "arm64" ]]; then
        log_success "Hardware check passed: Apple Silicon ($arch) detected. (Optimal for MLX/ComfyUI)"
    elif [[ "$arch" == "x86_64" ]]; then
        log_warn "Hardware check passed: Intel ($arch) detected. Note: MLX and MLX-Video components require Apple Silicon and will be disabled or run with limitations."
    else
        log_error "Unknown hardware architecture: $arch"
        return 1
    fi
    return 0
}

# Check available disk space
check_disk_space() {
    log_info "Checking available disk space..."
    # Get available space in GB on the root partition
    local available_gb
    available_gb=$(df -g / | awk 'NR==2 {print $4}')
    
    # Remove any non-numeric characters (just in case)
    available_gb=$(echo "$available_gb" | tr -dc '0-9')

    if [[ "$available_gb" -lt "$MIN_DISK_SPACE_GB" ]]; then
        log_error "Insufficient disk space. Found: ${available_gb}GB, Required: ${MIN_DISK_SPACE_GB}GB+."
        log_info "Please free up disk space before proceeding."
        return 1
    fi
    
    log_success "Disk space check passed (${available_gb}GB available)."
    return 0
}

# Check system memory (RAM)
check_memory() {
    log_info "Checking system memory..."
    # Get total memory in bytes, then convert to GB
    local mem_bytes
    mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    
    if [[ -z "$mem_bytes" ]]; then
        log_warn "Could not determine system memory. Skipping check."
        return 0
    fi

    # Calculate GB (bytes / 1024 / 1024 / 1024)
    local mem_gb=$((mem_bytes / 1073741824))

    if [[ "$mem_gb" -lt "$MIN_MEMORY_GB" ]]; then
        log_warn "System memory is below recommended minimum. Found: ${mem_gb}GB, Recommended: ${MIN_MEMORY_GB}GB+."
        log_info "Some large models (e.g., FLUX, large LLMs) may fail to load or run slowly."
        # Return 0 because it's a warning, not a hard failure for basic usage
    else
        log_success "System memory check passed (${mem_gb}GB)."
    fi
    return 0
}

# Check for required and recommended command-line tools
check_tools() {
    log_info "Checking required command-line tools..."
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
        log_error "Missing required tools: ${missing_required[*]}"
        log_info "Run './ai-studio.sh env install' to automatically install missing dependencies."
        return 1
    fi

    if [[ ${#missing_recommended[@]} -gt 0 ]]; then
        log_warn "Missing recommended tools: ${missing_recommended[*]}"
        log_info "It is highly recommended to run './ai-studio.sh env install' to install these for full functionality."
    else
        log_success "All required and recommended tools are present."
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
    log_info "Starting AI Studio Environment Check..."
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
        log_success "Environment check PASSED. Your system is ready for deployment."
        return 0
    else
        log_error "Environment check FAILED with $failed_checks critical issue(s)."
        log_info "Please resolve the issues above, or run './ai-studio.sh env install' to attempt automatic fixes."
        return 1
    fi
}

# ============================================================================
# 4. Helper for Status Command
# ============================================================================

# Show a brief summary of the environment status (for `ai-studio.sh env status`)
show_environment_status() {
    echo ""
    echo "=== AI Studio Environment Status ==="
    printf "%-25s : %s\n" "OS" "$(sw_vers -productName) $(sw_vers -productVersion)"
    printf "%-25s : %s\n" "Architecture" "$(uname -m)"
    
    local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    local mem_gb=$((mem_bytes / 1073741824))
    printf "%-25s : %s GB\n" "Total Memory" "$mem_gb"
    
    local available_gb=$(df -g / | awk 'NR==2 {print $4}')
    printf "%-25s : %s GB\n" "Available Disk" "$available_gb"
    
    echo ""
    echo "Core Tools Status:"
    for tool in "${REQUIRED_TOOLS[@]}" "${RECOMMENDED_TOOLS[@]}"; do
        if command_exists "$tool"; then
            printf "  ✅ %-15s : Installed\n" "$tool"
        else
            printf "  ❌ %-15s : Missing\n" "$tool"
        fi
    done
    echo "=================================="
    echo ""
}
