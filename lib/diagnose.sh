#!/bin/bash

# ============================================================================
# AI Studio - Diagnosis Library (lib/diagnose.sh)
# Provides simple, deep, and auto-fix diagnostic capabilities for components.
# ============================================================================

# Ensure required libraries are available
# This script expects to be sourced after lib/common.sh, lib/config.sh, and lib/process.sh

# ============================================================================
# 1. Diagnosis Constants & State
# ============================================================================
readonly DIAGNOSIS_ISSUES_FOUND=1
readonly DIAGNOSIS_ALL_CLEAR=0

# Temporary file for storing diagnosis results during a run
readonly DIAGNOSIS_REPORT_FILE="${AI_STUDIO_ROOT:-.}/logs/diagnosis_report.tmp"

# ============================================================================
# 2. Core Diagnostic Checks (Internal)
# ============================================================================

# Check 1: Installation Status
_check_installation() {
    local component="$1"
    local comp_dir="${AI_STUDIO_ROOT}/components/${component}"
    
    if [[ ! -d "$comp_dir" ]]; then
        echo "$(msg LIBDIAG_FILES_MISSING)"
        return $DIAGNOSIS_ISSUES_FOUND
    fi
    
    if [[ ! -f "$comp_dir/install.sh" ]] || [[ ! -x "$comp_dir/install.sh" ]]; then
        echo "$(msg LIBDIAG_SCRIPTS_MISSING)"
        return $DIAGNOSIS_ISSUES_FOUND
    fi
    
    echo "$(msg LIBDIAG_FILES_OK)"
    return $DIAGNOSIS_ALL_CLEAR
}

# Check 2: Process & Port Status
_check_process_status() {
    local component="$1"
    local port=$(get_component_port "$component")
    
    if is_daemon_running "$component"; then
        local info=$(get_daemon_info "$component")
        if [[ "$info" == "zombie_or_orphaned" ]]; then
            echo "$(msg LIBDIAG_PROC_ORPHAN)"
            return $DIAGNOSIS_ISSUES_FOUND
        fi
        echo "$(msg LIBDIAG_PROC_OK)"
        
        # Check port if applicable
        if [[ -n "$port" ]] && ! is_port_in_use "$port"; then
            echo "$(msgf LIBDIAG_PROC_PORT "$port")"
            return $DIAGNOSIS_ISSUES_FOUND
        fi
    else
        if [[ -n "$port" ]] && is_port_in_use "$port"; then
            echo "$(msgf LIBDIAG_STOPPED_PORT_BUSY "$port")"
            return $DIAGNOSIS_ISSUES_FOUND
        fi
        echo "$(msg LIBDIAG_STOPPED)"
    fi
    return $DIAGNOSIS_ALL_CLEAR
}

# Check 3: Recent Log Errors (Simple Diagnosis)
_check_recent_logs() {
    local component="$1"
    local log_file="${AI_STUDIO_ROOT}/logs/${component}.log"
    
    if [[ ! -f "$log_file" ]]; then
        echo "$(msg LIBDIAG_NO_LOG)"
        return $DIAGNOSIS_ALL_CLEAR
    fi
    
    # Check last 50 lines for critical errors
    local errors
    errors=$(tail -n 50 "$log_file" | grep -iE "error|exception|fatal|traceback" | tail -n 3)
    
    if [[ -n "$errors" ]]; then
        echo "$(msg LIBDIAG_LOG_ERRORS)"
        echo "$errors" | sed 's/^/  -> /'
        return $DIAGNOSIS_ISSUES_FOUND
    fi
    
    echo "$(msg LIBDIAG_LOG_OK)"
    return $DIAGNOSIS_ALL_CLEAR
}

# Check 4: System Resources (Deep Diagnosis)
_check_system_resources() {
    local component="$1"
    local issues=0
    
    # Disk Space
    local avail_gb=$(df -g / | awk 'NR==2 {print $4}' | tr -dc '0-9')
    if [[ "$avail_gb" -lt 20 ]]; then
        echo "$(msg LIBDIAG_DISK_LOW)"
        ((issues++))
    fi
    
    # Memory Pressure (macOS specific)
    local mem_pressure=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    # Rough estimation: if free pages are very low (simplified check)
    # A more robust check uses `sysctl vm.swapusage` or `memory_pressure`
    local swap_usage=$(sysctl vm.swapusage 2>/dev/null | awk '{print $4}' | tr -d 'M')
    if [[ "${swap_usage:-0}" -gt 2048 ]]; then # > 2GB swap used
        echo "$(msg LIBDIAG_SWAP_HIGH)"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "$(msg LIBDIAG_RESOURCES_OK)"
    fi
    return $issues
}

# Check 5: Dependency Integrity (Deep Diagnosis)
_check_dependencies() {
    local component="$1"
    local comp_dir="${AI_STUDIO_ROOT}/components/${component}"
    local meta_file="$comp_dir/metadata.sh"
    local issues=0
    
    if [[ -f "$meta_file" ]]; then
        # shellcheck disable=SC1090
        source "$meta_file"
        if [[ -n "${REQUIRED_DEPS:-}" ]]; then
            for dep in $REQUIRED_DEPS; do
                if ! command_exists "$dep"; then
                    echo "$(msgf LIBDIAG_DEP_MISSING "$dep")"
                    ((issues++))
                fi
            done
        fi
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "$(msg LIBDIAG_DEP_OK)"
    fi
    return $issues
}

# ============================================================================
# 3. Public Diagnostic Functions
# ============================================================================

# Run Simple Diagnosis
# Usage: run_simple_diagnosis "open-webui"
run_simple_diagnosis() {
    local component="$1"
    local total_issues=0
    
    log_info "$(msgf LIBDIAG_SIMPLE_RUNNING "${COLOR_CYAN}${component}${COLOR_RESET}")"
    
    local result
    result=$(_check_installation "$component")
    echo -e "  [${COLOR_BLUE}FILES${COLOR_RESET}] $result"
    [[ $? -ne 0 ]] && ((total_issues++))
    
    result=$(_check_process_status "$component")
    echo -e "  [${COLOR_BLUE}PROCESS${COLOR_RESET}] $result"
    [[ $? -ne 0 ]] && ((total_issues++))
    
    result=$(_check_recent_logs "$component")
    echo -e "  [${COLOR_BLUE}LOGS${COLOR_RESET}] $result"
    [[ $? -ne 0 ]] && ((total_issues++))
    
    return $total_issues
}

# Run Deep Diagnosis
# Usage: run_deep_diagnosis "comfyui"
run_deep_diagnosis() {
    local component="$1"
    local total_issues=0
    
    log_info "$(msgf LIBDIAG_DEEP_RUNNING "${COLOR_CYAN}${component}${COLOR_RESET}")"
    
    # Run simple checks first
    run_simple_diagnosis "$component"
    total_issues=$?
    
    echo ""
    local result
    result=$(_check_system_resources)
    echo -e "  [${COLOR_BLUE}RESOURCES${COLOR_RESET}] $result"
    [[ $? -ne 0 ]] && ((total_issues++))
    
    result=$(_check_dependencies "$component")
    echo -e "  [${COLOR_BLUE}DEPENDENCIES${COLOR_RESET}] $result"
    [[ $? -ne 0 ]] && ((total_issues++))
    
    # Check configuration file syntax
    local conf_file="${AI_STUDIO_ROOT}/config/${component}.conf"
    if [[ -f "$conf_file" ]]; then
        if grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*=' "$conf_file"; then
            echo -e "  [${COLOR_BLUE}CONFIG${COLOR_RESET}] $(msg LIBDIAG_CONFIG_OK)"
        else
            echo -e "  [${COLOR_BLUE}CONFIG${COLOR_RESET}] $(msg LIBDIAG_CONFIG_WARN)"
            ((total_issues++))
        fi
    fi
    
    return $total_issues
}

# ============================================================================
# 4. Auto-Fix Mechanism
# ============================================================================

# Attempt to automatically fix common issues
# Usage: attempt_auto_fix "sillytavern"
attempt_auto_fix() {
    local component="$1"
    local fixed=0
    
    log_warn "$(msgf LIBDIAG_AUTOFIX "${COLOR_CYAN}${component}${COLOR_RESET}")"
    
    # Fix 1: Clean stale PIDs
    local pid_file="${AI_STUDIO_ROOT}/run/pids/${component}.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ! _is_pid_alive "$pid"; then
            log_info "  $(msgf LIBDIAG_FIX_PID "$component")"
            _clear_pid "$component"
            ((fixed++))
        fi
    fi
    
    # Fix 2: Fix execution permissions
    local comp_dir="${AI_STUDIO_ROOT}/components/${component}"
    if [[ -d "$comp_dir" ]]; then
        local unexecuted=$(find "$comp_dir" -name "*.sh" ! -executable 2>/dev/null)
        if [[ -n "$unexecuted" ]]; then
            log_info "  $(msg LIBDIAG_FIX_PERMS2)"
            chmod +x "$comp_dir"/*.sh
            ((fixed++))
        fi
    fi
    
    # Fix 3: Port conflict resolution (if component is supposed to be stopped but port is busy)
    local port=$(get_component_port "$component")
    if [[ -n "$port" ]] && ! is_daemon_running "$component" && is_port_in_use "$port"; then
        log_info "  $(msgf LIBDIAG_FIX_PORT "$port")"
        if kill_process_on_port "$port"; then
            ((fixed++))
        fi
    fi
    
    if [[ $fixed -gt 0 ]]; then
        log_success "$(msgf LIBDIAG_FIX_APPLIED "$fixed")"
    else
        log_info "$(msg LIBDIAG_FIX_NONE)"
    fi
    
    return 0
}

# ============================================================================
# 5. Main Dispatcher
# ============================================================================

# Main entry point for diagnosis commands
# Usage: execute_diagnosis "component" [--deep] [--fix]
execute_diagnosis() {
    local component="$1"
    shift
    local is_deep=false
    local do_fix=false
    
    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --deep) is_deep=true; shift ;;
            --fix) do_fix=true; shift ;;
            *) log_error "$(msgf LIBDIAG_UNKNOWN_FLAG "$1")"; return 1 ;;
        esac
    done
    
    print_separator
    
    if [[ "$is_deep" == true ]]; then
        run_deep_diagnosis "$component"
        local issues=$?
    else
        run_simple_diagnosis "$component"
        local issues=$?
    fi
    
    if [[ $issues -gt 0 ]]; then
        log_warn "$(msgf LIBDIAG_ISSUES "$issues")"
        if [[ "$do_fix" == true ]]; then
            echo ""
            attempt_auto_fix "$component"
        else
            log_info "$(msg LIBDIAG_TIP_DEEP_FIX)"
        fi
    else
        log_success "$(msgf LIBDIAG_HEALTHY "$component")"
    fi
    
    print_separator
    return $issues
}
