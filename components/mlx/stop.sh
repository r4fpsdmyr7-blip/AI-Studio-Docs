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
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  Stopping: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # Inform the user about the nature of this component
    log_info "The '${COMPONENT_NAME}' component is a foundational machine learning framework."
    log_info "It does not run as a background daemon service and does not consume CPU/GPU resources on its own."
    echo ""

    # Provide actionable advice on how to actually free up resources
    log_info "${COLOR_CYAN}To free up system resources (VRAM/RAM), you should stop the specific inference components or scripts that are currently utilizing MLX:${COLOR_RESET}"
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
        echo -e "  ${COLOR_YELLOW}⚠️  The following MLX-dependent components are currently running:${COLOR_RESET}"
        for comp in "${running_inference_components[@]}"; do
            echo "    • ${comp}"
        done
        echo ""
        echo "  To stop them and free up resources, run:"
        for comp in "${running_inference_components[@]}"; do
            local comp_name="${comp%% *}" # Extract just the component name before the parenthesis
            echo "    ${COLOR_GRAY}./ai-studio.sh stop ${comp_name}${COLOR_RESET}"
        done
    else
        echo -e "  ${COLOR_GREEN}✅ No MLX-dependent background services are currently running. Your system resources are fully available.${COLOR_RESET}"
    fi

    echo ""
    print_separator
    log_success "No action required for '${COMPONENT_NAME}'. Framework state is preserved."
    echo ""
    print_separator
    
    # Always exit 0 to ensure this doesn't break batch operations like `./ai-studio.sh stop all`
    exit 0
}

# Execute main function
main "$@"
