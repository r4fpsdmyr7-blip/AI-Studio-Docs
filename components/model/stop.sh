#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Stop Script
# File: components/model/stop.sh
# 
# Since models are static assets and not background services, this script 
# gracefully handles the "stop" command by explaining the component's nature 
# and guiding the user on how to actually free up system resources (VRAM/RAM).
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
    log_info "The '${COMPONENT_NAME}' component is a static asset repository."
    log_info "It does not run as a background service and does not consume CPU/GPU resources on its own."
    echo ""

    # Provide actionable advice on how to actually free up resources
    log_info "${COLOR_CYAN}To free up system resources (VRAM/RAM), you should stop the components that are currently loading these models:${COLOR_RESET}"
    echo ""
    
    local running_inference_components=()
    
    # Check common components that load MLX models
    if is_daemon_running "comfyui"; then
        running_inference_components+=("comfyui (Image/Video Generation)")
    fi
    
    if is_daemon_running "qwen3"; then
        running_inference_components+=("qwen3 (LLM Inference via Ollama)")
    fi
    
    if is_daemon_running "mlx-video"; then
        running_inference_components+=("mlx-video")
    fi

    if [[ ${#running_inference_components[@]} -gt 0 ]]; then
        echo -e "  ${COLOR_YELLOW}⚠️  The following components are currently running and may be holding models in memory:${COLOR_RESET}"
        for comp in "${running_inference_components[@]}"; do
            echo "    • ${comp}"
        done
        echo ""
        echo "  To stop them and free up resources, run:"
        for comp in "${running_inference_components[@]}"; do
            local comp_name="${comp%% *}" # Extract just the component name
            echo "    ${COLOR_GRAY}./ai-studio.sh stop ${comp_name}${COLOR_RESET}"
        done
    else
        echo -e "  ${COLOR_GREEN}✅ No inference components are currently running. Your system resources are fully available.${COLOR_RESET}"
    fi

    echo ""
    print_separator
    log_success "No action required for '${COMPONENT_NAME}'. Component state is preserved."
    echo ""
    print_separator
    
    # Always exit 0 to ensure this doesn't break batch operations like `./ai-studio.sh stop all`
    exit 0
}

# Execute main function
main "$@"
