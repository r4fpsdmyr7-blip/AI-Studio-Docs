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
        echo "CRITICAL: Component directory missing."
        return $DIAGNOSIS_ISSUES_FOUND
    fi
    
    if [[ ! -f "$comp_dir/install.sh" ]] || [[ ! -x "$comp_dir/install.sh" ]]; then
        echo "WARNING: Installation scripts missing or not executable."
        return $DIAGNOSIS_ISSUES_FOUND
    fi
    
    echo "OK: Component files present."
    return $DIAGNOSIS_ALL_CLEAR
}

# Check 2: Process & Port Status
_check_process_status() {
    local component="$1"
    local port=$(get_component_port "$component")
    
    if is_daemon_running "$component"; then
        local info=$(get_daemon_info "$component")
        if [[ "$info" == "zombie_or_orphaned" ]]; then
            echo "WARNING: Process is running but appears orphaned/zombie."
            return $DIAGNOSIS_ISSUES_FOUND
        fi
        echo "OK: Process is running."
        
        # Check port if applicable
        if [[ -n "$port" ]] && ! is_port_in_use "$port"; then
            echo "WARNING: Process running, but port $port is not listening."
            return $DIAGNOSIS_ISSUES_FOUND
        fi
    else
        if [[ -n "$port" ]] && is_port_in_use "$port"; then
            echo "WARNING: Component is stopped, but port $port is occupied by another process."
            return $DIAGNOSIS_ISSUES_FOUND
        fi
        echo "INFO: Component is currently stopped."
    fi
    return $DIAGNOSIS_ALL_CLEAR
}

# Check 3: Recent Log Errors (Simple Diagnosis)
_check_recent_logs() {
    local component="$1"
    local log_file="${AI_STUDIO_ROOT}/logs/${component}.log"
    
    if [[ ! -f "$log_file" ]]; then
        echo "INFO: No log file found yet."
        return $DIAGNOSIS_ALL_CLEAR
    fi
    
    # Check last 50 lines for critical errors
    local errors
    errors=$(tail -n 50 "$log_file" | grep -iE "error|exception|fatal|traceback" | tail -n 3)
    
    if [[ -n "$errors" ]]; then
        echo "WARNING: Recent log contains potential errors:"
        echo "$errors" | sed 's/^/  -> /'
        return $DIAGNOSIS_ISSUES_FOUND
    fi
    
    echo "OK: No critical errors in recent logs."
    return $DIAGNOSIS_ALL_CLEAR
}

# Check 4: System Resources (Deep Diagnosis)
_check_system_resources() {
    local component="$1"
    local issues=0
    
    # Disk Space
    local avail_gb=$(df -g / | awk 'NR==2 {print $4}' | tr -dc '0-9')
    if [[ "$avail_gb" -lt 20 ]]; then
        echo "CRITICAL: Less than 20GB disk space remaining. Model downloads/operations may fail."
        ((issues++))
    fi
    
    # Memory Pressure (macOS specific)
    local mem_pressure=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    # Rough estimation: if free pages are very low (simplified check)
    # A more robust check uses `sysctl vm.swapusage` or `memory_pressure`
    local swap_usage=$(sysctl vm.swapusage 2>/dev/null | awk '{print $4}' | tr -d 'M')
    if [[ "${swap_usage:-0}" -gt 2048 ]]; then # > 2GB swap used
        echo "WARNING: High swap memory usage detected. System may be thrashing."
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "OK: System resources are adequate."
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
                    echo "CRITICAL: Missing required dependency: $dep"
                    ((issues++))
                fi
            done
        fi
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "OK: All declared dependencies are satisfied."
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
    
    log_info "Running simple diagnosis for ${COLOR_CYAN}${component}${COLOR_RESET}..."
    
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
    
    log_info "Running deep diagnosis for ${COLOR_CYAN}${component}${COLOR_RESET}..."
    
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
            echo -e "  [${COLOR_BLUE}CONFIG${COLOR_RESET}] OK: Configuration file syntax appears valid."
        else
            echo -e "  [${COLOR_BLUE}CONFIG${COLOR_RESET}] WARNING: Configuration file may be malformed."
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
    
    log_warn "Attempting automatic repairs for ${COLOR_CYAN}${component}${COLOR_RESET}..."
    
    # Fix 1: Clean stale PIDs
    local pid_file="${AI_STUDIO_ROOT}/run/pids/${component}.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ! _is_pid_alive "$pid"; then
            log_info "  -> Clearing stale PID file for $component..."
            _clear_pid "$component"
            ((fixed++))
        fi
    fi
    
    # Fix 2: Fix execution permissions
    local comp_dir="${AI_STUDIO_ROOT}/components/${component}"
    if [[ -d "$comp_dir" ]]; then
        local unexecuted=$(find "$comp_dir" -name "*.sh" ! -executable 2>/dev/null)
        if [[ -n "$unexecuted" ]]; then
            log_info "  -> Restoring execution permissions for component scripts..."
            chmod +x "$comp_dir"/*.sh
            ((fixed++))
        fi
    fi
    
    # Fix 3: Port conflict resolution (if component is supposed to be stopped but port is busy)
    local port=$(get_component_port "$component")
    if [[ -n "$port" ]] && ! is_daemon_running "$component" && is_port_in_use "$port"; then
        log_info "  -> Port $port is occupied. Attempting to free it..."
        if kill_process_on_port "$port"; then
            ((fixed++))
        fi
    fi
    
    if [[ $fixed -gt 0 ]]; then
        log_success "Applied $fixed automatic fix(es). Please run diagnosis again to verify."
    else
        log_info "No automatic fixes were applicable or necessary."
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
            *) log_error "Unknown diagnosis flag: $1"; return 1 ;;
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
        log_warn "Diagnosis completed with $issues issue(s) detected."
        if [[ "$do_fix" == true ]]; then
            echo ""
            attempt_auto_fix "$component"
        else
            log_info "Tip: Run with '--deep --fix' to attempt automatic resolution."
        fi
    else
        log_success "Diagnosis completed. No issues detected. ${component} is healthy."
    fi
    
    print_separator
    return $issues
}
