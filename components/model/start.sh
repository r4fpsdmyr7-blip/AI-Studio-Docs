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
        log_error "$(msgf MODEL_START_NO_DIR "$COMPONENT_DATA_DIR")"
        return 1
    fi

    # Check if there are any subdirectories or files (excluding hidden files)
    local file_count
    file_count=$(find "$COMPONENT_DATA_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$file_count" -eq 0 ]]; then
        log_error "$(msg MODEL_START_EMPTY)"
        return 1
    fi
    
    return 0
}

# List downloaded models with their sizes and status
list_downloaded_models() {
    echo ""
    echo -e "${COLOR_BOLD}$(msg MODEL_START_LIST_TITLE)${COLOR_RESET}"
    echo "--------------------------------------------------------------------------------"
    printf "  %-35s | %-10s | %s\n" "$(msg MODEL_TBL_NAME)" "$(msg MODEL_TBL_SIZE)" "$(msg MODEL_TBL_STATUS)"
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
        local status="${COLOR_GREEN}$(msg MODEL_STATUS_READY)${COLOR_RESET}"
        if [[ ! -f "${model_dir}config.json" ]] && [[ -z "$(ls -A "${model_dir}"/*.safetensors 2>/dev/null)" ]]; then
            status="${COLOR_YELLOW}$(msg MODEL_STATUS_INCOMPLETE_2)${COLOR_RESET}"
        fi
        
        printf "  %-35s | %-10s | %b\n" "$model_name" "$size" "$status"
    done

    if [[ "$has_models" == false ]]; then
        echo "  ${COLOR_GRAY}$(msg MODEL_START_NO_MODELS)${COLOR_RESET}"
    fi
    echo "--------------------------------------------------------------------------------"
    echo ""
}

# Provide actionable next steps based on available models
provide_usage_guide() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$(msg MODEL_START_TIP_TITLE)${COLOR_RESET}"
    echo ""
    echo "  $(msg MODEL_START_STATIC_1)"
    echo "  $(msg MODEL_START_STATIC_2)"
    echo ""
    
    # Check for specific model types and provide tailored advice
    if [[ -d "${COMPONENT_DATA_DIR}/qwen3-35b-uncensored" ]] || [[ -d "${COMPONENT_DATA_DIR}"/*qwen* ]]; then
        echo -e "  - ${COLOR_BOLD}$(msg MODEL_START_LLM_TITLE)${COLOR_RESET}"
        echo "    $(msg MODEL_START_LLM_DESC)"
        echo "    $(msgf MODEL_START_LLM_STEP1 "${COLOR_GRAY}./ai-studio.sh start qwen3${COLOR_RESET}")"
        echo "    $(msgf MODEL_START_LLM_STEP2 "${COLOR_GRAY}${COMPONENT_DATA_DIR}/qwen3-35b-uncensored${COLOR_RESET}")"
        echo ""
    fi

    if [[ -d "${COMPONENT_DATA_DIR}/stable-diffusion"* ]] || [[ -d "${COMPONENT_DATA_DIR}/flux"* ]]; then
        echo -e "  - ${COLOR_BOLD}$(msg MODEL_START_IMG_TITLE)${COLOR_RESET}"
        echo "    $(msgf MODEL_START_IMG_STEP1 "${COLOR_GRAY}./ai-studio.sh start comfyui${COLOR_RESET}")"
        echo "    $(msg MODEL_START_IMG_STEP2)"
        echo "       ${COLOR_GRAY}${COMPONENT_DATA_DIR}${COLOR_RESET}"
        echo "    $(msg MODEL_START_IMG_STEP3)"
        echo ""
    fi

    echo -e "  - ${COLOR_BOLD}$(msg MODEL_START_GLOBAL_TITLE)${COLOR_RESET}"
    echo "    $(msg MODEL_START_GLOBAL_DESC)"
    echo "    ${COLOR_GRAY}${COMPONENT_DATA_DIR}${COLOR_RESET}"
    echo ""
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_VERIFY "$COMPONENT_NAME") $(msg MODEL_REPO_SUFFIX)${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_models_exist; then
        echo ""
        print_separator
        log_error "$(msg MODEL_START_NONE_INSTALLED)"
        log_info "$(msg MODEL_START_DOWNLOAD_HINT)"
        log_info "  ${COLOR_CYAN}./ai-studio.sh install model${COLOR_RESET}"
        print_separator
        exit 1
    fi

    # Step 2: List models and their status
    list_downloaded_models

    # Step 3: Provide usage guide
    provide_usage_guide

    print_separator
    log_success "$(msg MODEL_START_VERIFY_OK)"
    echo ""
    echo -e "${COLOR_CYAN}$(msg NEXT_STEPS):${COLOR_RESET}"
    echo "  $(msg MODEL_START_ACTION_UPDATE)   ${COLOR_GRAY}./ai-studio.sh update model --target models${COLOR_RESET}"
    echo "  $(msg MODEL_START_ACTION_INTEGRITY) ${COLOR_GRAY}./ai-studio.sh diagnose model --deep${COLOR_RESET}"
    echo "  $(msg MODEL_START_ACTION_FREE)   ${COLOR_GRAY}./ai-studio.sh uninstall model --keep-data${COLOR_RESET} $(msg MODEL_START_ACTION_FREE_NOTE)"
    echo ""
    print_separator
    
    exit 0
}

# Execute main function
main "$@"
