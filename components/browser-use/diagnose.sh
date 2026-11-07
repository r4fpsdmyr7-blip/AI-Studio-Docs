#!/bin/bash

# ============================================================================
# AI Studio - Browser Use Diagnosis Script (library-type component)
# File: components/browser-use/diagnose.sh
#
# Component-specific diagnostics for browser-use: virtualenv health, package
# import, Python version (>= 3.11) and the Playwright Chromium browser cache.
# There is no port/daemon, so the generic service checks do not apply.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Component-Specific Diagnostic Checks
# ============================================================================

# Check 1: Virtual Environment Health (Basic)
check_venv_health() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"

    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        echo "$(msg MLX_DIAG_VENV_DIR_MISSING)"
        echo "  $(msgf MLX_DIAG_HINT_SETUP "$COMPONENT_NAME")"
        return 1
    fi

    if [[ ! -x "$venv_python" ]]; then
        echo "$(msg MLX_DIAG_VENV_PY_MISSING)"
        echo "  $(msg MLX_DIAG_HINT_REINSTALL)"
        return 1
    fi

    if ! "$venv_python" -c "import browser_use" >/dev/null 2>&1; then
        echo "$(msg BU_DIAG_IMPORT_FAIL)"
        echo "  $(msg MLX_DIAG_PYENV_BROKEN)"
        return 1
    fi

    echo "$(msg BU_DIAG_VENV_OK)"
    return 0
}

# Check 2: Python Version >= 3.11 (Deep)
check_python_version() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    local pyver major minor
    pyver=$("$venv_python" -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>/dev/null)
    major="${pyver%%.*}"
    minor="${pyver##*.}"

    if [[ -z "$pyver" ]]; then
        echo "$(msg BU_DIAG_IMPORT_FAIL)"
        return 1
    fi

    if [[ "$major" -lt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -lt 11 ]]; }; then
        echo "$(msgf BU_DIAG_PYVER_WARN "$pyver")"
        return 1
    fi

    echo "$(msgf BU_DIAG_PYVER_OK "$pyver")"
    return 0
}

# Check 3: Playwright Chromium Browser Cache (Deep)
check_playwright_browser() {
    if ls "$HOME/Library/Caches/ms-playwright/"chromium* >/dev/null 2>&1; then
        echo "$(msg BU_DIAG_PW_OK)"
        return 0
    fi

    echo "$(msg BU_DIAG_PW_MISSING)"
    echo "  $(msg BU_DIAG_PW_HINT)"
    return 1
}

# ============================================================================
# 4. Component-Specific Auto-Fix Logic
# ============================================================================

attempt_bu_fix() {
    local fixed=0
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"

    # Fix 1: Install the Playwright Chromium browser if missing
    if ! ls "$HOME/Library/Caches/ms-playwright/"chromium* >/dev/null 2>&1 \
        && [[ -x "$venv_python" ]]; then
        log_info "  $(msg BU_DIAG_FIX_PW)"
        if "$venv_python" -m playwright install chromium --no-shell; then
            log_success "    $(msg BU_DIAG_FIX_PW_OK)"
            fixed=$((fixed + 1))
        else
            log_error "    $(msg BU_DIAG_FIX_PW_FAILED)"
        fi
    fi

    # Fix 2: Fix directory permissions (common issue if run with sudo accidentally)
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] && [[ ! -w "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        log_info "  $(msg MLX_DIAG_FIX_VENV_PERMS)"
        if chmod -R u+w "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" 2>/dev/null; then
            log_success "    $(msg MLX_DIAG_FIX_VENV_PERMS_OK)"
            fixed=$((fixed + 1))
        else
            log_error "    $(msg DIAG_FIX_PERMS_FAILED)"
        fi
    fi

    # Note: We intentionally DO NOT auto-delete and recreate the virtual environment.
    # Doing so automatically is too risky and might destroy user configurations.

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
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_DIAGNOSE "$COMPONENT_NAME")${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  $(msg BU_DIAG_NOTE)${COLOR_RESET}"
    print_separator
    echo ""

    local specific_issues=0
    local result

    # --- Component-Specific Checks ---
    log_info "$(msgf DIAG_SPECIFIC_CHECKS "$COMPONENT_NAME")"

    result=$(check_venv_health)
    local venv_status=$?
    echo -e "  [${COLOR_BLUE}VENV_HEALTH${COLOR_RESET}] $result"
    [[ $venv_status -ne 0 ]] && specific_issues=$((specific_issues + 1))

    if [[ "$is_deep" == true ]]; then
        # Only run deep checks if basic venv health passed (otherwise python commands will fail)
        if [[ $venv_status -eq 0 ]]; then
            result=$(check_python_version)
            [[ $? -ne 0 ]] && specific_issues=$((specific_issues + 1))
            echo -e "  [${COLOR_BLUE}PY_VERSION${COLOR_RESET}] $result"

            result=$(check_playwright_browser)
            [[ $? -ne 0 ]] && specific_issues=$((specific_issues + 1))
            echo -e "  [${COLOR_BLUE}BROWSER${COLOR_RESET}] $result"
        else
            echo -e "  [${COLOR_BLUE}PY_VERSION${COLOR_RESET}] ${COLOR_GRAY}$(msg MLX_DIAG_SKIP_VENV_BROKEN)${COLOR_RESET}"
            echo -e "  [${COLOR_BLUE}BROWSER${COLOR_RESET}] ${COLOR_GRAY}$(msg MLX_DIAG_SKIP_VENV_BROKEN)${COLOR_RESET}"
        fi
    else
        echo -e "  [${COLOR_BLUE}PY_VERSION${COLOR_RESET}] ${COLOR_GRAY}$(msg BU_DIAG_SKIP_DEEP)${COLOR_RESET}"
        echo -e "  [${COLOR_BLUE}BROWSER${COLOR_RESET}] ${COLOR_GRAY}$(msg BU_DIAG_SKIP_DEEP)${COLOR_RESET}"
    fi

    # --- Auto-Fix Execution ---
    if [[ $specific_issues -gt 0 ]] && [[ "$do_fix" == true ]]; then
        echo ""
        attempt_bu_fix

        # If venv was broken and we couldn't fix it via permissions, give explicit advice
        if [[ $venv_status -ne 0 ]]; then
            echo ""
            log_warn "$(msg MLX_DIAG_VENV_NO_AUTOFIX)"
            log_info "$(msg MLX_DIAG_REBUILD_HINT)"
            log_info "  ${COLOR_GRAY}rm -rf ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}${COLOR_RESET}"
            log_info "  ${COLOR_GRAY}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}"
        fi
    elif [[ $specific_issues -gt 0 ]] && [[ "$do_fix" != true ]]; then
        echo ""
        log_info "$(msg DIAG_HINT_DEEP_FIX)"
    fi

    echo ""
    print_separator

    if [[ $specific_issues -gt 0 ]]; then
        log_warn "$(msgf DIAG_ISSUES_FOUND "$COMPONENT_NAME" "$specific_issues")"
        exit 1
    else
        if [[ "$is_deep" == true ]]; then
            log_success "$(msg BU_DIAG_DONE_DEEP_OK)"
        else
            log_success "$(msg BU_DIAG_DONE_BASIC_OK)"
        fi
        exit 0
    fi
}

# Execute main function
main "$@"
