#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Status Script
# File: components/mlx/status.sh
# 
# Provides a comprehensive health and configuration report for the MLX 
# framework. Since MLX is a library and not a background service, this 
# replaces the traditional "process status" check with an "environment 
# and hardware acceleration verification" dashboard.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Status Logic
# ============================================================================

# Check installation and gather detailed environment info
get_mlx_status() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    local status="NOT INSTALLED"
    local version="N/A"
    local device="N/A"
    local exit_code=1

    if [[ ! -x "$venv_python" ]]; then
        echo "NOT_INSTALLED|$version|$device"
        return 1
    fi

    # Try to import mlx and get version
    version=$("$venv_python" -c "import mlx; print(mlx.__version__)" 2>/dev/null)
    
    if [[ -z "$version" ]]; then
        echo "CORRUPTED|$version|$device"
        return 1
    fi

    # Try to check hardware acceleration device
    device=$("$venv_python" -c "import mlx.core as mx; print(str(mx.default_device()).split('.')[-1])" 2>/dev/null)
    
    if [[ "$device" == "mlx" ]] || [[ "$device" == "gpu" ]]; then
        status="READY"
        exit_code=0
    else
        status="WARNING" # Installed, but hardware acceleration might not be active (e.g., on Intel Mac or broken install)
        exit_code=0
    fi

    echo "${status}|${version}|${device}"
    return $exit_code
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_STATUS "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Gather Status
    local status_info
    status_info=$(get_mlx_status)
    local check_exit=$?
    
    IFS='|' read -r status version device <<< "$status_info"

    # Step 2: Format and Print Output
    local info_items=()
    info_items+=("$(msg LBL_COMPONENT): ${COMPONENT_NAME}")
    info_items+=("$(msg LBL_TYPE): ${COMPONENT_TYPE}")
    info_items+=("$(msg LBL_VIRTUAL_ENV): ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}")

    case "$status" in
        "READY")
            echo -e "  [${COLOR_GREEN}READY${COLOR_RESET}] $(msg MLX_STATUS_READY)"
            info_items+=("$(msg LBL_VERSION): ${COLOR_GREEN}v${version}${COLOR_RESET}")
            info_items+=("$(msg LBL_ACTIVE_DEVICE): ${COLOR_GREEN}$(msgf MLX_STATUS_DEVICE_OPT "$device")${COLOR_RESET}")
            ;;
        "WARNING")
            echo -e "  [${COLOR_YELLOW}WARNING${COLOR_RESET}] $(msg MLX_STATUS_WARN)"
            info_items+=("$(msg LBL_VERSION): ${COLOR_YELLOW}v${version}${COLOR_RESET}")
            info_items+=("$(msg LBL_ACTIVE_DEVICE): ${COLOR_YELLOW}${device:-Unknown}${COLOR_RESET}")
            info_items+=("$(msg LBL_NOTE): $(msg MLX_STATUS_PERF_NOTE)")
            ;;
        "CORRUPTED")
            echo -e "  [${COLOR_RED}CORRUPTED${COLOR_RESET}] $(msg MLX_STATUS_CORRUPTED)"
            info_items+=("$(msg LBL_VERSION): ${COLOR_RED}$(msg STATUS_LOAD_FAILED)${COLOR_RESET}")
            info_items+=("$(msg LBL_ACTION): $(msg ACTION_REINSTALL)")
            ;;
        "NOT_INSTALLED")
            echo -e "  [${COLOR_RED}$(msg STATUS_NOT_INSTALLED_TAG)${COLOR_RESET}]"
            echo ""
            echo "  $(msg STATUS_NOT_INSTALLED_DESC)"
            echo "  $(msgf STATUS_HINT_INSTALL "${COLOR_CYAN}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}")"
            echo ""
            print_separator
            exit 1
            ;;
    esac

    echo ""
    print_info_block "$(msg STATUS_ENV_DETAILS)" "${info_items[@]}"

    # Step 3: Provide Actionable Next Steps
    echo -e "${COLOR_BOLD}$(msg NEXT_STEPS) & $(msg LBL_USAGE):${COLOR_RESET}"
    if [[ "$status" == "READY" ]] || [[ "$status" == "WARNING" ]]; then
        echo "  - $(msg MLX_STATUS_ACTION_GUIDE)  ${COLOR_GRAY}./ai-studio.sh start ${COMPONENT_NAME}${COLOR_RESET}"
        echo "  - $(msg MLX_STATUS_ACTION_MODELS)   ${COLOR_GRAY}./ai-studio.sh install model${COLOR_RESET}"
        echo "  - $(msg MLX_STATUS_ACTION_UPDATE)  ${COLOR_GRAY}./ai-studio.sh update ${COMPONENT_NAME}${COLOR_RESET}"
        echo ""
        echo -e "  ${COLOR_GRAY}$(msg MLX_STATUS_TIP_ACTIVATE)${COLOR_RESET}"
        echo -e "  ${COLOR_GRAY}   source ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate${COLOR_RESET}"
    else
        echo "  - $(msg MLX_STATUS_ACTION_FIX)  ${COLOR_GRAY}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}"
    fi
    echo ""
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
