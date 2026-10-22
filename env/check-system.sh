#!/bin/bash

# ============================================================================
# AI Studio - System Environment Check Script (env/check-system.sh)
# Detects if the macOS system meets the requirements for AI Studio deployment.
# Can be run standalone or called by the main ai-studio.sh script.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine the root directory of the project
# This script is located in env/, so the root is one level up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 2. Source core libraries
# We source common.sh first, as it provides logging and utility functions.
# Then we source env-check.sh, which contains the actual check logic.
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/env-check.sh"

# 3. Main Execution Logic
main() {
    # Clear any previous temporary diagnosis reports
    rm -f "${AI_STUDIO_ROOT}/logs/diagnosis_report.tmp" 2>/dev/null

    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msg ENVC_BANNER)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  $(msg ENVC_SUBTITLE)${COLOR_RESET}"
    print_separator
    echo ""

    # Execute the comprehensive check function from lib/env-check.sh
    check_all_requirements
    local exit_code=$?

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "$(msg ENVC_PASSED)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
        echo "  $(msg ENVC_NEXT_1)"
        echo "     ./env/install-deps.sh"
        echo "  $(msg ENVC_NEXT_2)"
        echo "     ./ai-studio.sh install open-webui"
        echo ""
    else
        log_error "$(msg ENVC_FAILED)"
        echo ""
        echo -e "${COLOR_YELLOW}$(msg ENVC_RECOMMENDED_ACTION)${COLOR_RESET}"
        echo "  $(msg ENVC_RECOMMENDED_DESC)"
        echo "  ./env/install-deps.sh"
        echo ""
    fi

    print_separator

    # Exit with the same code as the check function
    exit $exit_code
}

# Execute main function
main "$@"
