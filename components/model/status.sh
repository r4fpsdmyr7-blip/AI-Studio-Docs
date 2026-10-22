#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Status Script
# File: components/model/status.sh
# 
# Provides a comprehensive inventory and integrity report of downloaded MLX 
# models. Since models are static assets, this replaces the traditional 
# "process status" check with a detailed "asset status" dashboard.
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
# 3. Core Status Logic
# ============================================================================

# Check if the model directory exists and is accessible
check_model_directory() {
    if [[ ! -d "$COMPONENT_DATA_DIR" ]]; then
        echo -e "  [${COLOR_RED}$(msg MODEL_STATUS_NOT_INIT_TAG)${COLOR_RESET}]"
        echo ""
        echo "  $(msg MODEL_STATUS_NO_DIR)"
        echo "  $(msgf STATUS_HINT_INSTALL "${COLOR_CYAN}./ai-studio.sh install model${COLOR_RESET}")"
        echo ""
        return 1
    fi
    return 0
}

# Generate and print the model inventory table
print_model_inventory() {
    echo -e "${COLOR_BOLD}$(msg MODEL_STATUS_INVENTORY)${COLOR_RESET}"
    echo "--------------------------------------------------------------------------------"
    # Use printf for aligned columns: Name (35 chars), Size (10 chars), Status
    printf "  %-35s | %-10s | %s\n" "$(msg MODEL_TBL_IDENTIFIER)" "$(msg MODEL_TBL_SIZE)" "$(msg MODEL_TBL_STATUS)"
    echo "--------------------------------------------------------------------------------"

    local has_models=false
    local total_size_bytes=0

    # Iterate through immediate subdirectories in the model data directory
    for model_dir in "$COMPONENT_DATA_DIR"/*/; do
        # Skip if no directories exist (glob didn't expand)
        [[ -d "$model_dir" ]] || continue
        has_models=true
        
        local model_name
        model_name=$(basename "$model_dir")
        
        # Get directory size in bytes for total calculation, and human-readable for display
        local size_bytes
        size_bytes=$(du -sk "$model_dir" 2>/dev/null | awk '{print $1 * 1024}')
        total_size_bytes=$((total_size_bytes + size_bytes))
        
        local size_human
        size_human=$(du -sh "$model_dir" 2>/dev/null | awk '{print $1}')
        
        # Integrity check: Look for essential MLX model files
        local status="${COLOR_GREEN}$(msg MODEL_STATUS_READY)${COLOR_RESET}"
        local has_config=false
        local has_weights=false
        
        if [[ -f "${model_dir}config.json" ]]; then
            has_config=true
        fi
        
        # Check for common MLX weight formats (.safetensors, .npz, or model.safetensors)
        if ls "${model_dir}"*.safetensors 1>/dev/null 2>&1 || \
           ls "${model_dir}"*.npz 1>/dev/null 2>&1 || \
           [[ -f "${model_dir}model.safetensors" ]] || \
           [[ -f "${model_dir}model.npz" ]]; then
            has_weights=true
        fi

        if [[ "$has_config" == false ]] && [[ "$has_weights" == false ]]; then
            status="${COLOR_RED}$(msg MODEL_STATUS_INCOMPLETE)${COLOR_RESET}"
        elif [[ "$has_config" == false ]] || [[ "$has_weights" == false ]]; then
            status="${COLOR_YELLOW}$(msg MODEL_STATUS_PARTIAL)${COLOR_YELLOW}"
        fi
        
        printf "  %-35s | %-10s | %b\n" "$model_name" "$size_human" "$status"
    done

    if [[ "$has_models" == false ]]; then
        echo -e "  ${COLOR_GRAY}$(msg MODEL_STATUS_EMPTY)${COLOR_RESET}"
    else
        echo "--------------------------------------------------------------------------------"
        # Convert total bytes to human-readable (GB)
        local total_gb
        total_gb=$(awk "BEGIN {printf \"%.2f\", $total_size_bytes / 1073741824}")
        echo -e "  ${COLOR_BOLD}$(msg MODEL_STATUS_TOTAL_USED)${COLOR_RESET} ${COLOR_CYAN}${total_gb} GB${COLOR_RESET}"
    fi
    echo ""
}

# Provide disk space context and actionable next steps
provide_context_and_actions() {
    # Check available space on the partition hosting the model directory
    local avail_gb
    avail_gb=$(df -g "$COMPONENT_DATA_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | tr -dc '0-9')
    
    echo -e "${COLOR_BOLD}$(msg MODEL_STATUS_STORAGE_CTX)${COLOR_RESET}"
    if [[ -n "$avail_gb" ]]; then
        if [[ "$avail_gb" -lt 20 ]]; then
            echo "  $(msgf MODEL_STATUS_SPACE_LOW "${COLOR_RED}${avail_gb} GB${COLOR_RESET}")"
        else
            echo "  $(msgf MODEL_STATUS_SPACE_OK "${COLOR_GREEN}${avail_gb} GB${COLOR_RESET}")"
        fi
    fi
    echo ""

    echo -e "${COLOR_BOLD}$(msg NEXT_STEPS) & $(msg LBL_MANAGEMENT):${COLOR_RESET}"
    echo "  $(msg MODEL_STATUS_ACTION_DL)  ${COLOR_GRAY}./ai-studio.sh install model${COLOR_RESET}"
    echo "  $(msg MODEL_STATUS_ACTION_UPDATE) ${COLOR_GRAY}./ai-studio.sh update model --target models${COLOR_RESET}"
    echo "  $(msg MODEL_STATUS_ACTION_VERIFY)     ${COLOR_GRAY}./ai-studio.sh diagnose model --deep${COLOR_RESET}"
    echo "  $(msg MODEL_STATUS_ACTION_REMOVE)${COLOR_GRAY} rm -rf ${COMPONENT_DATA_DIR}/<model_name>${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_GRAY}$(msg MODEL_STATUS_TIP_SHARED)${COLOR_RESET}"
    echo ""
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_STATUS "$COMPONENT_NAME") $(msg MODEL_REPO_SUFFIX)${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_model_directory; then
        print_separator
        exit 1
    fi

    # Step 2: Print Inventory
    print_model_inventory

    # Step 3: Provide Context and Actions
    provide_context_and_actions

    print_separator
    exit 0
}

# Execute main function
main "$@"
