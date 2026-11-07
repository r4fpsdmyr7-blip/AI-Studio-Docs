#!/bin/bash

# ============================================================================
# AI Studio - MLX-Video Status Script (library-type component)
# File: components/mlx-video/status.sh
#
# Reports installation state: virtualenv, mlx-video package, ffmpeg and the
# outputs data directory.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_STATUS "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # --- Check 1: Installation Status ---
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    if [[ ! -x "$venv_python" ]]; then
        echo -e "  [${COLOR_RED}$(msg STATUS_NOT_INSTALLED_TAG)${COLOR_RESET}]"
        echo ""
        echo "  $(msg STATUS_NOT_INSTALLED_DESC)"
        echo -e "  $(msgf STATUS_HINT_INSTALL "${COLOR_CYAN}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}")"
        echo ""
        print_separator
        exit 1
    fi

    local info_items=()
    info_items+=("Component: ${COMPONENT_NAME}")
    info_items+=("Virtual Env: ${COMPONENT_VENV_DIR}")
    info_items+=("Data Directory: ${COMPONENT_DATA_DIR}")

    if "$venv_python" -m pip show mlx-video >/dev/null 2>&1; then
        local mlxv_version
        mlxv_version=$("$venv_python" -m pip show mlx-video 2>/dev/null | awk '/^Version:/ {print $2}')
        echo -e "  ${COLOR_GREEN}[READY]${COLOR_RESET} mlx-video ${mlxv_version:-unknown}"
        info_items+=("mlx-video: ${COLOR_GREEN}${mlxv_version:-unknown}${COLOR_RESET}")
    else
        echo -e "  ${COLOR_YELLOW}[INCOMPLETE]${COLOR_RESET}"
        info_items+=("mlx-video: ${COLOR_RED}not installed${COLOR_RESET}")
    fi

    # ffmpeg is required for video encoding/decoding
    if command_exists "ffmpeg"; then
        info_items+=("ffmpeg: ${COLOR_GREEN}Installed${COLOR_RESET}")
    else
        info_items+=("ffmpeg: ${COLOR_YELLOW}$(msg MLXV_STATUS_FFMPEG_MISSING)${COLOR_RESET}")
    fi

    echo ""
    print_info_block "Configuration & State" "${info_items[@]}"

    echo ""
    print_separator
    echo -e "  ${COLOR_CYAN}$(msg ACTIONS_LABEL):${COLOR_RESET}"
    echo "    $(msg STATUS_ACTION_DIAGNOSE)  ${COLOR_GRAY}./ai-studio.sh diagnose ${COMPONENT_NAME}${COLOR_RESET}"
    echo ""
    print_separator

    exit 0
}

# Execute main function
main "$@"
