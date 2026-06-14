#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Start Script
# File: components/model/start.sh
# 
# Since models are static assets and not background services, this script 
# acts as a "Model Verification and Usage Guide". It checks the integrity 
# of downloaded MLX models, lists their status, and provides clear instructions 
# on how to load them into compatible inference engines (e.g., ComfyUI, Ollama).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Logic
# ============================================================================

# Check if the model directory exists and contains data
check_models_exist() {
    if [[ ! -d "$COMPONENT_DATA_DIR" ]]; then
        log_error "Model directory does not exist: ${COMPONENT_DATA_DIR}"
        return 1
    fi

    # Check if there are any subdirectories or files (excluding hidden files)
    local file_count
    file_count=$(find "$COMPONENT_DATA_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$file_count" -eq 0 ]]; then
        log_error "Model directory is empty. No models have been downloaded yet."
        return 1
    fi
    
    return 0
}

# List downloaded models with their sizes and status
list_downloaded_models() {
    echo ""
    echo -e "${COLOR_BOLD}Downloaded MLX Models:${COLOR_RESET}"
    echo "--------------------------------------------------------------------------------"
    printf "  %-35s | %-10s | %s\n" "MODEL NAME" "SIZE" "STATUS"
    echo "--------------------------------------------------------------------------------"

    local has_models=false
    
    # Iterate through subdirectories in the model data directory
    for model_dir in "$COMPONENT_DATA_DIR"/*/; do
        [[ -d "$model_dir" ]] || continue
        has_models=true
        
        local model_name
        model_name=$(basename "$model_dir")
        
        # Get directory size in human-readable format (macOS compatible)
        local size
        size=$(du -sh "$model_dir" 2>/dev/null | awk '{print $1}')
        
        # Basic integrity check: look for config.json or .safetensors
        local status="${COLOR_GREEN}Ready${COLOR_RESET}"
        if [[ ! -f "${model_dir}config.json" ]] && [[ -z "$(ls -A "${model_dir}"/*.safetensors 2>/dev/null)" ]]; then
            status="${COLOR_YELLOW}Incomplete/Verifying${COLOR_RESET}"
        fi
        
        printf "  %-35s | %-10s | %b\n" "$model_name" "$size" "$status"
    done

    if [[ "$has_models" == false ]]; then
        echo "  ${COLOR_GRAY}(No models found. Run './ai-studio.sh install model' to download.)${COLOR_RESET}"
    fi
    echo "--------------------------------------------------------------------------------"
    echo ""
}

# Provide actionable next steps based on available models
provide_usage_guide() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}💡 How to use these models:${COLOR_RESET}"
    echo ""
    echo "  Models are static assets and do not need to be 'started'. Instead, they are"
    echo "  loaded by compatible inference engines or UI components."
    echo ""
    
    # Check for specific model types and provide tailored advice
    if [[ -d "${COMPONENT_DATA_DIR}/qwen3-35b-uncensored" ]] || [[ -d "${COMPONENT_DATA_DIR}"/*qwen* ]]; then
        echo -e "  🧠 ${COLOR_BOLD}For LLMs (e.g., Qwen3):${COLOR_RESET}"
        echo "    The recommended way to run MLX LLMs is via Ollama or a dedicated MLX-LM script."
        echo "    1. Ensure Ollama is running: ${COLOR_GRAY}./ai-studio.sh start qwen3${COLOR_RESET}"
        echo "    2. Or use a Python script pointing to: ${COLOR_GRAY}${COMPONENT_DATA_DIR}/qwen3-35b-uncensored${COLOR_RESET}"
        echo ""
    fi

    if [[ -d "${COMPONENT_DATA_DIR}/stable-diffusion"* ]] || [[ -d "${COMPONENT_DATA_DIR}/flux"* ]]; then
        echo -e "  🎨 ${COLOR_BOLD}For Image Generation (SD / FLUX):${COLOR_RESET}"
        echo "    1. Start ComfyUI: ${COLOR_GRAY}./ai-studio.sh start comfyui${COLOR_RESET}"
        echo "    2. In ComfyUI, ensure your 'extra_model_paths.yaml' includes:"
        echo "       ${COLOR_GRAY}${COMPONENT_DATA_DIR}${COLOR_RESET}"
        echo "    3. Alternatively, use MLX-Video/MLX image generation scripts directly."
        echo ""
    fi

    echo -e "  📂 ${COLOR_BOLD}Global Model Path:${COLOR_RESET}"
    echo "    You can manually copy or symlink this directory to other applications:"
    echo "    ${COLOR_GRAY}${COMPONENT_DATA_DIR}${COLOR_RESET}"
    echo ""
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Verifying: ${COMPONENT_NAME} (MLX Model Repository)${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_models_exist; then
        echo ""
        print_separator
        log_error "No models are currently installed."
        log_info "To download Qwen3, Stable Diffusion, or FLUX MLX models, run:"
        log_info "  ${COLOR_CYAN}./ai-studio.sh install model${COLOR_RESET}"
        print_separator
        exit 1
    fi

    # Step 2: List models and their status
    list_downloaded_models

    # Step 3: Provide usage guide
    provide_usage_guide

    print_separator
    log_success "Model repository verification complete."
    echo ""
    echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
    echo "  • Update models:   ${COLOR_GRAY}./ai-studio.sh update model --target models${COLOR_RESET}"
    echo "  • Check integrity: ${COLOR_GRAY}./ai-studio.sh diagnose model --deep${COLOR_RESET}"
    echo "  • Free up space:   ${COLOR_GRAY}./ai-studio.sh uninstall model --keep-data${COLOR_RESET} (then manually delete specific model folders)"
    echo ""
    print_separator
    
    exit 0
}

# Execute main function
main "$@"
