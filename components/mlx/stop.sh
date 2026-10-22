#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Stop Script
# File: components/mlx/stop.sh
# 
# Since MLX is a foundational machine learning framework/library and not a 
# background service, this script gracefully handles the "stop" command by 
# explaining the component's nature and guiding the user on how to actually 
# free up system resources (VRAM/RAM) by stopping dependent components.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  $(msgf BANNER_STOP "$COMPONENT_NAME")${COLOR_RESET}"
    print_separator
    echo ""

    # Inform the user about the nature of this component
    log_info "$(msgf MLX_STOP_FOUNDATIONAL "$COMPONENT_NAME")"
    log_info "$(msg MLX_STOP_NO_DAEMON)"
    echo ""

    # Provide actionable advice on how to actually free up resources
    log_info "${COLOR_CYAN}$(msg MLX_STOP_FREE_HINT)${COLOR_RESET}"
    echo ""
    
    local running_inference_components=()
    
    # Check common components that rely on the MLX framework
    if is_daemon_running "comfyui"; then
        running_inference_components+=("comfyui (Image/Video Generation)")
    fi
    
    if is_daemon_running "mlx-video"; then
        running_inference_components+=("mlx-video")
    fi
    
    # Note: Ollama (qwen3) typically uses its own engine, but custom mlx-lm scripts might be running.
    # We keep the check focused on managed daemons.

    if [[ ${#running_inference_components[@]} -gt 0 ]]; then
        echo -e "  ${COLOR_YELLOW}[WARN] $(msg MLX_STOP_DEPS_RUNNING)${COLOR_RESET}"
        for comp in "${running_inference_components[@]}"; do
            echo "    - ${comp}"
        done
        echo ""
        echo "  $(msg STOP_DEPS_HINT)"
        for comp in "${running_inference_components[@]}"; do
            local comp_name="${comp%% *}" # Extract just the component name before the parenthesis
            echo "    ${COLOR_GRAY}$(msgf MLX_STOP_DEPS_CMD "$comp_name")${COLOR_RESET}"
        done
    else
        echo -e "  ${COLOR_GREEN}[OK] $(msg MLX_STOP_NONE_RUNNING)${COLOR_RESET}"
    fi

    echo ""
    print_separator
    log_success "$(msgf MLX_STOP_NO_ACTION "$COMPONENT_NAME")"
    echo ""
    print_separator
    
    # Always exit 0 to ensure this doesn't break batch operations like `./ai-studio.sh stop all`
    exit 0
}

# Execute main function
main "$@"
