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
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Status: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Gather Status
    local status_info
    status_info=$(get_mlx_status)
    local check_exit=$?
    
    IFS='|' read -r status version device <<< "$status_info"

    # Step 2: Format and Print Output
    local info_items=()
    info_items+=("Component: ${COMPONENT_NAME}")
    info_items+=("Type: ${COMPONENT_TYPE}")
    info_items+=("Virtual Env: ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}")

    case "$status" in
        "READY")
            echo -e "  [${COLOR_GREEN}READY${COLOR_RESET}] MLX framework is installed and hardware acceleration is active."
            info_items+=("Version: ${COLOR_GREEN}v${version}${COLOR_RESET}")
            info_items+=("Active Device: ${COLOR_GREEN}${device} (Apple Silicon Optimized)${COLOR_RESET}")
            ;;
        "WARNING")
            echo -e "  [${COLOR_YELLOW}WARNING${COLOR_RESET}] MLX is installed, but hardware acceleration may not be active."
            info_items+=("Version: ${COLOR_YELLOW}v${version}${COLOR_RESET}")
            info_items+=("Active Device: ${COLOR_YELLOW}${device:-Unknown}${COLOR_RESET}")
            info_items+=("Note: Performance will be limited. This is expected on Intel Macs.")
            ;;
        "CORRUPTED")
            echo -e "  [${COLOR_RED}CORRUPTED${COLOR_RESET}] Virtual environment exists, but MLX cannot be imported."
            info_items+=("Version: ${COLOR_RED}Failed to load${COLOR_RESET}")
            info_items+=("Action: Re-installation is required.")
            ;;
        "NOT_INSTALLED")
            echo -e "  [${COLOR_RED}NOT INSTALLED${COLOR_RESET}]"
            echo ""
            echo "  The MLX framework has not been installed yet."
            echo "  Run: ${COLOR_CYAN}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}"
            echo ""
            print_separator
            exit 1
            ;;
    fi

    echo ""
    print_info_block "Environment Details" "${info_items[@]}"

    # Step 3: Provide Actionable Next Steps
    echo -e "${COLOR_BOLD}Next Steps & Usage:${COLOR_RESET}"
    if [[ "$status" == "READY" ]] || [[ "$status" == "WARNING" ]]; then
        echo "  • View usage guide:  ${COLOR_GRAY}./ai-studio.sh start ${COMPONENT_NAME}${COLOR_RESET}"
        echo "  • Download models:   ${COLOR_GRAY}./ai-studio.sh install model${COLOR_RESET}"
        echo "  • Update framework:  ${COLOR_GRAY}./ai-studio.sh update ${COMPONENT_NAME}${COLOR_RESET}"
        echo ""
        echo -e "  ${COLOR_GRAY}💡 Tip: To use MLX in your own scripts, activate the environment first:${COLOR_RESET}"
        echo -e "  ${COLOR_GRAY}   source ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate${COLOR_RESET}"
    else
        echo "  • Fix installation:  ${COLOR_GRAY}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}"
    fi
    echo ""
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
