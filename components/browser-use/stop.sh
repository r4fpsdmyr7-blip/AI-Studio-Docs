#!/bin/bash

# ============================================================================
# AI Studio - Browser Use Stop Script (library-type component)
# File: components/browser-use/stop.sh
#
# browser-use is a Python library with no daemon; nothing to stop.
# Always exits 0 so batch operations (stop all) stay green.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$COMPONENT_DIR/metadata.sh"

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  $(msgf BANNER_STOP "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    log_info "$(msg BU_STOP_NO_DAEMON)"
    echo ""
    print_separator

    exit 0
}

# Execute main function
main "$@"
