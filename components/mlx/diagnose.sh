#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Diagnosis Script
# File: components/mlx/diagnose.sh
# 
# Provides simple, deep, and auto-fix diagnostic capabilities specifically 
# tailored for the MLX framework. It focuses on virtual environment health, 
# hardware acceleration verification, and system dependency integrity.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/diagnose.sh" # Core diagnosis logic
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Component-Specific Diagnostic Checks
# ============================================================================

# Check 1: Virtual Environment Health (Basic)
check_venv_health() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    
    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        echo "CRITICAL: Virtual environment directory is missing."
        echo "  -> Run './ai-studio.sh install ${COMPONENT_NAME}' to set it up."
        return 1
    fi
    
    if [[ ! -x "$venv_python" ]]; then
        echo "CRITICAL: Virtual environment Python binary is missing or not executable."
        echo "  -> The environment is corrupted. Re-installation is required."
        return 1
    fi
    
    if ! "$venv_python" -c "import mlx" >/dev/null 2>&1; then
        echo "CRITICAL: MLX package is installed but cannot be imported."
        echo "  -> The Python environment is broken. Re-installation is required."
        return 1
    fi
    
    echo "OK: Virtual environment is healthy and MLX is importable."
    return 0
}

# Check 2: Hardware Acceleration Verification (Deep)
check_hardware_acceleration() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    
    # Run a micro-benchmark to check the default device
    local device_info
    device_info=$("$venv_python" -c "import mlx.core as mx; print(str(mx.default_device()).split('.')[-1])" 2>/dev/null)
    
    if [[ "$device_info" == "mlx" ]] || [[ "$device_info" == "gpu" ]]; then
        echo "OK: Hardware acceleration is active (Device: ${device_info})."
        return 0
    elif [[ -n "$device_info" ]]; then
        echo "WARNING: MLX is running, but hardware acceleration may be limited (Device: ${device_info})."
        echo "  -> This is expected on Intel Macs, but indicates suboptimal performance on Apple Silicon."
        return 0
    else
        echo "CRITICAL: Failed to query MLX device information."
        echo "  -> The MLX installation may be fundamentally broken."
        return 1
    fi
}

# Check 3: System Build Dependencies (Deep)
check_system_deps() {
    local issues=0
    
    # MLX often requires cmake for building custom extensions or from source
    if ! command_exists "cmake"; then
        echo "WARNING: 'cmake' is not installed."
        echo "  -> Required for building certain MLX extensions or compiling from source."
        ((issues++))
    fi
    
    if ! command_exists "python3"; then
        echo "CRITICAL: System 'python3' is missing."
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "OK: All required system build dependencies are present."
    fi
    
    return $issues
}

# ============================================================================
# 4. Component-Specific Auto-Fix Logic
# ============================================================================

attempt_mlx_fix() {
    local fixed=0
    
    # Fix 1: Repair system dependencies
    if ! command_exists "cmake" || ! command_exists "python3"; then
        log_info "  -> Attempting to repair system build dependencies..."
        if install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
            log_success "    System dependencies repaired."
            ((fixed++))
        else
            log_error "    Failed to repair system dependencies. Please install manually."
        fi
    fi
    
    # Fix 2: Fix directory permissions (common issue if run with sudo accidentally)
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] && [[ ! -w "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        log_info "  -> Attempting to fix virtual environment permissions..."
        if chmod -R u+w "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" 2>/dev/null; then
            log_success "    Virtual environment permissions repaired."
            ((fixed++))
        else
            log_error "    Failed to repair permissions. Manual intervention required."
        fi
    fi
    
    # Note: We intentionally DO NOT auto-delete and recreate the virtual environment.
    # Doing so automatically is too risky and might destroy user configurations.
    # We will advise the user to run the install script if the venv is truly broken.
    
    return $fixed
}

# ============================================================================
# 5. Main Execution Flow
# ============================================================================

main() {
    # Parse arguments
    local is_deep=false
    local do_fix=false
    
    for arg in "$@"; do
        case "$arg" in
            --deep) is_deep=true ;;
            --fix) do_fix=true ;;
        esac
    done

    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Diagnosing: ${COMPONENT_NAME}${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  Note: MLX is a foundational framework, not a background service.${COLOR_RESET}"
    print_separator
    echo ""

    local specific_issues=0
    local result

    # --- Component-Specific Checks ---
    log_info "Running MLX framework specific checks..."
    
    result=$(check_venv_health)
    echo -e "  [${COLOR_BLUE}VENV_HEALTH${COLOR_RESET}] $result"
    local venv_status=$?
    [[ $venv_status -ne 0 ]] && ((specific_issues++))
    
    if [[ "$is_deep" == true ]]; then
        # Only run deep checks if basic venv health passed (otherwise python commands will fail)
        if [[ $venv_status -eq 0 ]]; then
            result=$(check_hardware_acceleration)
            echo -e "  [${COLOR_BLUE}HW_ACCEL${COLOR_RESET}] $result"
            [[ $? -ne 0 ]] && ((specific_issues++))
        else
            echo -e "  [${COLOR_BLUE}HW_ACCEL${COLOR_RESET}] ${COLOR_GRAY}Skipped (Virtual environment is broken)${COLOR_RESET}"
        fi
        
        result=$(check_system_deps)
        echo -e "  [${COLOR_BLUE}SYS_DEPS${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
    else
        echo -e "  [${COLOR_BLUE}HW_ACCEL${COLOR_RESET}] ${COLOR_GRAY}Skipped (Use --deep to verify hardware acceleration)${COLOR_RESET}"
        echo -e "  [${COLOR_BLUE}SYS_DEPS${COLOR_RESET}] ${COLOR_GRAY}Skipped (Use --deep to check build tools)${COLOR_RESET}"
    fi

    # --- Auto-Fix Execution ---
    if [[ $specific_issues -gt 0 ]] && [[ "$do_fix" == true ]]; then
        echo ""
        attempt_mlx_fix
        
        # If venv was broken and we couldn't fix it via permissions, give explicit advice
        if [[ $venv_status -ne 0 ]]; then
            echo ""
            log_warn "The virtual environment is corrupted and cannot be auto-fixed."
            log_info "Please run the following commands to rebuild it safely:"
            log_info "  ${COLOR_GRAY}rm -rf ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}${COLOR_RESET}"
            log_info "  ${COLOR_GRAY}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}"
        fi
    elif [[ $specific_issues -gt 0 ]] && [[ "$do_fix" != true ]]; then
        echo ""
        log_info "Tip: Run with '--deep --fix' to attempt automatic resolution of fixable issues (e.g., missing cmake, permissions)."
    fi

    echo ""
    print_separator
    
    if [[ $specific_issues -gt 0 ]]; then
        log_warn "Diagnosis completed with $specific_issues issue(s) detected."
        exit 1
    else
        if [[ "$is_deep" == true ]]; then
            log_success "Deep diagnosis completed. The MLX framework is healthy and optimized."
        else
            log_success "Basic diagnosis completed. The MLX framework is accessible."
        fi
        exit 0
    fi
}

# Execute main function
main "$@"
