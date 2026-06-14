#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Diagnosis Script
# File: components/open-webui/diagnose.sh
# 
# Provides simple, deep, and auto-fix diagnostic capabilities specifically 
# tailored for the Open WebUI component, building upon the core diagnosis library.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/diagnose.sh" # Core diagnosis logic
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Component-Specific Diagnostic Checks
# ============================================================================

# Check 1: Virtual Environment Integrity
check_venv_integrity() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    local venv_pip="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/pip"
    
    if [[ ! -x "$venv_python" ]] || [[ ! -x "$venv_pip" ]]; then
        echo "CRITICAL: Python virtual environment is missing or corrupted."
        echo "  -> The component may need to be reinstalled."
        return 1
    fi
    
    # Quick syntax check of the python binary
    if ! "$venv_python" -c "import sys" >/dev/null 2>&1; then
        echo "CRITICAL: Virtual environment Python binary is broken."
        return 1
    fi
    
    echo "OK: Virtual environment is intact and functional."
    return 0
}

# Check 2: Data Directory Permissions
check_data_directory() {
    local data_dir="${COMPONENT_DIR}/${COMPONENT_DATA_DIR}"
    
    if [[ ! -d "$data_dir" ]]; then
        echo "WARNING: Data directory does not exist. It will be created on first start."
        return 0
    fi
    
    if [[ ! -w "$data_dir" ]]; then
        echo "CRITICAL: Data directory exists but is not writable. Database saves will fail."
        return 1
    fi
    
    echo "OK: Data directory is present and writable."
    return 0
}

# Check 3: Ollama Connection Hint (Simple heuristic)
check_ollama_hint() {
    # If the component is running, check if it can reach the default Ollama port
    if is_daemon_running "$COMPONENT_NAME"; then
        if ! curl -s --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo "INFO: Cannot reach local Ollama instance at port 11434."
            echo "  -> If you intend to use local models, ensure Ollama is running: ./ai-studio.sh start qwen3"
        fi
    fi
    return 0 # This is informational, not a hard failure
}

# ============================================================================
# 4. Component-Specific Auto-Fix Logic
# ============================================================================

attempt_component_fix() {
    local fixed=0
    
    # Fix 1: Repair data directory permissions
    local data_dir="${COMPONENT_DIR}/${COMPONENT_DATA_DIR}"
    if [[ -d "$data_dir" ]] && [[ ! -w "$data_dir" ]]; then
        log_info "  -> Attempting to fix data directory permissions..."
        if chmod -R u+w "$data_dir" 2>/dev/null; then
            log_success "    Data directory permissions repaired."
            ((fixed++))
        else
            log_error "    Failed to repair permissions. Manual intervention required."
        fi
    fi
    
    # Fix 2: Stale virtual environment (Soft fix: just notify, hard fix requires reinstall)
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] && [[ ! -x "$venv_python" ]]; then
        log_warn "  -> Virtual environment is corrupted."
        log_info "    Auto-fix cannot repair a broken venv. Please run:"
        log_info "    ./ai-studio.sh uninstall ${COMPONENT_NAME} --keep-data"
        log_info "    ./ai-studio.sh install ${COMPONENT_NAME}"
    fi
    
    return $fixed
}

# ============================================================================
# 5. Main Execution Flow
# ============================================================================

main() {
    # Parse arguments: pass them to the core diagnosis library
    # The core library expects: execute_diagnosis "component_name" [--deep] [--fix]
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
    print_separator
    echo ""

    # Step 1: Run generic diagnosis (Process, Port, Logs, System Resources, Dependencies)
    execute_diagnosis "$COMPONENT_NAME" "$@"
    local generic_issues=$?

    # Step 2: Run component-specific checks (Only show if generic passed or during deep diagnosis)
    if [[ $generic_issues -eq 0 ]] || [[ "$is_deep" == true ]]; then
        echo ""
        log_info "Running ${COMPONENT_NAME}-specific checks..."
        local specific_issues=0
        
        local result
        result=$(check_venv_integrity)
        echo -e "  [${COLOR_BLUE}VENV${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
        
        result=$(check_data_directory)
        echo -e "  [${COLOR_BLUE}DATA_DIR${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
        
        # Informational check, doesn't increment specific_issues
        check_ollama_hint >/dev/null 
        
        # Step 3: Handle Auto-Fix for component-specific issues
        if [[ $specific_issues -gt 0 ]] && [[ "$do_fix" == true ]]; then
            echo ""
            attempt_component_fix
        fi
    fi

    echo ""
    print_separator
    
    local total_issues=$((generic_issues + specific_issues))
    if [[ $total_issues -gt 0 ]]; then
        log_warn "Diagnosis completed with $total_issues issue(s) detected for ${COMPONENT_NAME}."
        if [[ "$do_fix" != true ]]; then
            log_info "Tip: Run with '--deep --fix' to attempt automatic resolution of fixable issues."
        fi
        exit 1
    else
        log_success "Diagnosis completed. ${COMPONENT_NAME} is healthy and ready to use."
        exit 0
    fi
}

# Execute main function
main "$@"
