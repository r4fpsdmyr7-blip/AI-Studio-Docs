#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Diagnosis Script
# File: components/model/diagnose.sh
# 
# Provides simple, deep, and auto-fix diagnostic capabilities specifically 
# tailored for the centralized MLX model repository. It focuses on file 
# integrity, disk space, and toolchain health rather than process status.
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

# Check 1: Model Directory Accessibility and Permissions
check_model_directory_access() {
    local data_dir="$COMPONENT_DATA_DIR"
    
    if [[ ! -d "$data_dir" ]]; then
        echo "$(msg MODEL_DIAG_DIR_MISSING)"
        echo "  $(msg MODEL_DIAG_HINT_INSTALL)"
        return 1
    fi
    
    if [[ ! -w "$data_dir" ]]; then
        echo "$(msg MODEL_DIAG_DIR_NOT_WRITABLE)"
        echo "  $(msg MODEL_DIAG_DIR_NOT_WRITABLE_HINT)"
        return 1
    fi
    
    echo "$(msg MODEL_DIAG_DIR_OK)"
    return 0
}

# Check 2: Model File Integrity (Deep Diagnosis)
check_model_integrity() {
    local data_dir="$COMPONENT_DATA_DIR"
    local issues=0
    local has_models=false
    
    # Iterate through immediate subdirectories
    for model_dir in "$data_dir"/*/; do
        [[ -d "$model_dir" ]] || continue
        has_models=true
        
        local model_name
        model_name=$(basename "$model_dir")
        local has_config=false
        local has_weights=false
        
        # Check for essential MLX model files
        if [[ -f "${model_dir}config.json" ]]; then
            has_config=true
        fi
        
        if ls "${model_dir}"*.safetensors 1>/dev/null 2>&1 || \
           ls "${model_dir}"*.npz 1>/dev/null 2>&1 || \
           [[ -f "${model_dir}model.safetensors" ]] || \
           [[ -f "${model_dir}model.npz" ]]; then
            has_weights=true
        fi

        if [[ "$has_config" == false ]] && [[ "$has_weights" == false ]]; then
            echo "$(msgf MODEL_DIAG_MODEL_EMPTY "$model_name")"
            echo "  $(msg MODEL_DIAG_MODEL_EMPTY_HINT)"
            ((issues++))
        elif [[ "$has_config" == false ]] || [[ "$has_weights" == false ]]; then
            echo "$(msgf MODEL_DIAG_MODEL_INCOMPLETE "$model_name")"
            echo "  $(msg MODEL_DIAG_MODEL_INCOMPLETE_HINT)"
            ((issues++))
        fi
    done
    
    if [[ "$has_models" == false ]]; then
        echo "$(msg MODEL_DIAG_NO_MODELS)"
    elif [[ $issues -eq 0 ]]; then
        echo "$(msg MODEL_DIAG_ALL_OK)"
    fi
    
    return $issues
}

# Check 3: Disk Space for Large Models (Deep Diagnosis)
check_model_disk_space() {
    local data_dir="$COMPONENT_DATA_DIR"
    local avail_gb
    avail_gb=$(df -g "$data_dir" 2>/dev/null | awk 'NR==2 {print $4}' | tr -dc '0-9')
    
    if [[ -z "$avail_gb" ]]; then
        echo "$(msg MODEL_DIAG_DISK_UNKNOWN)"
        return 0
    fi
    
    if [[ "$avail_gb" -lt 20 ]]; then
        echo "$(msg MODEL_DIAG_DISK_CRITICAL)"
        echo "  $(msg MODEL_DIAG_DISK_CRITICAL_HINT)"
        return 1
    elif [[ "$avail_gb" -lt 50 ]]; then
        echo "$(msg MODEL_DIAG_DISK_WARN)"
        echo "  $(msg MODEL_DIAG_DISK_WARN_HINT)"
        return 0 # Warning, not critical
    else
        echo "$(msgf MODEL_DIAG_DISK_OK "$avail_gb")"
        return 0
    fi
}

# Check 4: Download Toolchain Health
check_toolchain_health() {
    local issues=0
    
    if ! command_exists "huggingface-cli"; then
        echo "$(msg MODEL_DIAG_HF_MISSING)"
        echo "  $(msg MODEL_DIAG_HF_REQUIRED)"
        ((issues++))
    else
        # Quick version check to ensure it's not a broken symlink
        if ! huggingface-cli version >/dev/null 2>&1; then
            echo "$(msg MODEL_DIAG_HF_BROKEN)"
            ((issues++))
        fi
    fi
    
    # hf-transfer is optional but highly recommended
    if command_exists "python3"; then
        if ! python3 -c "import hf_transfer" >/dev/null 2>&1; then
            echo "$(msg MODEL_DIAG_HF_TRANSFER_MISSING)"
            echo "  $(msg MODEL_DIAG_HF_TRANSFER_HINT)"
            # Not a critical failure, but worth noting
        fi
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "$(msg MODEL_DIAG_TOOLCHAIN_OK)"
    fi
    
    return $issues
}

# ============================================================================
# 4. Component-Specific Auto-Fix Logic
# ============================================================================

attempt_model_fix() {
    local fixed=0
    
    # Fix 1: Repair directory permissions
    if [[ -d "$COMPONENT_DATA_DIR" ]] && [[ ! -w "$COMPONENT_DATA_DIR" ]]; then
        log_info "  $(msg MODEL_DIAG_FIX_PERMS)"
        if chmod u+w "$COMPONENT_DATA_DIR" 2>/dev/null; then
            log_success "    $(msg MODEL_DIAG_FIX_PERMS_OK)"
            ((fixed++))
        else
            log_error "    $(msg DIAG_FIX_PERMS_FAILED)"
        fi
    fi
    
    # Fix 2: Reinstall missing toolchain dependencies
    if ! command_exists "huggingface-cli" || ! python3 -c "import hf_transfer" >/dev/null 2>&1; then
        log_info "  $(msg MODEL_DIAG_FIX_TOOLCHAIN)"
        if install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
            log_success "    $(msg MODEL_DIAG_FIX_TOOLCHAIN_OK)"
            ((fixed++))
        else
            log_error "    $(msg MODEL_DIAG_FIX_TOOLCHAIN_FAILED)"
        fi
    fi
    
    # Note: We intentionally DO NOT auto-delete corrupted model files. 
    # Deleting multi-gigabyte files automatically is too risky. 
    # The user must manually delete them or re-run the install/update script.
    
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
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_DIAGNOSE "$COMPONENT_NAME") $(msg MODEL_REPO_SUFFIX)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  $(msg MODEL_DIAG_NOTE_STATIC)${COLOR_RESET}"
    print_separator
    echo ""

    local specific_issues=0
    local result

    # --- Component-Specific Checks ---
    log_info "$(msg MODEL_DIAG_RUNNING_CHECKS)"
    
    result=$(check_model_directory_access)
    echo -e "  [${COLOR_BLUE}DIRECTORY${COLOR_RESET}] $result"
    [[ $? -ne 0 ]] && ((specific_issues++))
    
    if [[ "$is_deep" == true ]]; then
        result=$(check_model_integrity)
        echo -e "  [${COLOR_BLUE}INTEGRITY${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
        
        result=$(check_model_disk_space)
        echo -e "  [${COLOR_BLUE}DISK_SPACE${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
        
        result=$(check_toolchain_health)
        echo -e "  [${COLOR_BLUE}TOOLCHAIN${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
    else
        echo -e "  [${COLOR_BLUE}INTEGRITY${COLOR_RESET}] ${COLOR_GRAY}$(msg MODEL_DIAG_SKIP_INTEGRITY)${COLOR_RESET}"
        echo -e "  [${COLOR_BLUE}DISK_SPACE${COLOR_RESET}] ${COLOR_GRAY}$(msg MODEL_DIAG_SKIP_DISK)${COLOR_RESET}"
        echo -e "  [${COLOR_BLUE}TOOLCHAIN${COLOR_RESET}] ${COLOR_GRAY}$(msg MODEL_DIAG_SKIP_TOOLCHAIN)${COLOR_RESET}"
    fi

    # --- Auto-Fix Execution ---
    if [[ $specific_issues -gt 0 ]] && [[ "$do_fix" == true ]]; then
        echo ""
        attempt_model_fix
        # Re-evaluate after fix (simplified: just report that fix was attempted)
    elif [[ $specific_issues -gt 0 ]] && [[ "$do_fix" != true ]]; then
        echo ""
        log_info "$(msg MODEL_DIAG_TIP_DEEP_FIX)"
        log_info "$(msg MODEL_DIAG_CORRUPT_MANUAL)"
    fi

    echo ""
    print_separator
    
    if [[ $specific_issues -gt 0 ]]; then
        log_warn "$(msgf DIAG_ISSUES_FOUND "$COMPONENT_NAME" "$specific_issues")"
        exit 1
    else
        if [[ "$is_deep" == true ]]; then
            log_success "$(msg MODEL_DIAG_DONE_DEEP_OK)"
        else
            log_success "$(msg MODEL_DIAG_DONE_BASIC_OK)"
        fi
        exit 0
    fi
}

# Execute main function
main "$@"
