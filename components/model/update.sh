#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Update Script
# File: components/model/update.sh
# 
# Handles granular updates for the MLX model repository. Since models are 
# static assets, "updating" means syncing with the latest weights on Hugging 
# Face or upgrading the underlying download toolchain (huggingface-cli).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Argument Parsing & Validation
# ============================================================================

TARGET="all" # Default update target

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        *)
            log_error "Unknown update argument: $1"
            log_info "Usage: ./ai-studio.sh update ${COMPONENT_NAME} [--target <models|architecture|all>]"
            exit 1
            ;;
    esac
done

# Validate target against metadata definition
if [[ ! " ${COMPONENT_UPDATE_TARGETS} " =~ " ${TARGET} " ]]; then
    log_error "Invalid update target: '${TARGET}'"
    log_info "Supported targets for ${COMPONENT_NAME} are: ${COMPONENT_UPDATE_TARGETS// /, }"
    exit 1
fi

# ============================================================================
# 4. Pre-flight Checks
# ============================================================================

check_installation() {
    if [[ ! -d "$COMPONENT_DATA_DIR" ]]; then
        log_error "Model directory does not exist: ${COMPONENT_DATA_DIR}"
        log_info "Please run './ai-studio.sh install ${COMPONENT_NAME}' first."
        return 1
    fi
    return 0
}

# ============================================================================
# 5. Core Update Logic
# ============================================================================

# Update the underlying toolchain (huggingface-cli, hf-transfer)
update_architecture() {
    log_info "Updating model management toolchain..."
    
    # Ensure dependencies are met (this is idempotent and will upgrade if needed)
    if install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_success "Model management toolchain is up to date."
        return 0
    else
        log_error "Failed to update model management dependencies."
        return 1
    fi
}

# Sync downloaded models with their remote Hugging Face repositories
update_models() {
    log_info "Checking for model weight updates on Hugging Face..."
    echo ""
    
    local update_failed=0
    local models_checked=0
    local models_updated=0

    # Iterate through all model directories
    for model_dir in "$COMPONENT_DATA_DIR"/*/; do
        [[ -d "$model_dir" ]] || continue
        ((models_checked++))
        
        local model_name
        model_name=$(basename "$model_dir")
        local repo_id_file="${model_dir}.repo_id"
        
        log_info "Checking: ${COLOR_CYAN}${model_name}${COLOR_RESET}"
        
        # Check if we know the source repository (recorded during install)
        if [[ ! -f "$repo_id_file" ]]; then
            log_warn "  -> Unknown source repository. Skipping automatic update."
            log_info "     (This model may have been added manually. To update, re-run install or update manually.)"
            continue
        fi
        
        local repo_id
        repo_id=$(cat "$repo_id_file" | tr -d '[:space:]')
        
        # Enable high-speed transfer
        export HF_HUB_ENABLE_HF_TRANSFER=1
        
        # huggingface-cli download is idempotent. 
        # If the remote has new files/commits, it downloads the diff. 
        # If it's already up to date, it returns instantly.
        if huggingface-cli download "$repo_id" --local-dir "$model_dir" --resume-download >/dev/null 2>&1; then
            # To determine if it actually updated, we can check the exit code or just report success
            # Since hf-cli doesn't have a built-in "updated" flag, we report the sync attempt as successful
            log_success "  -> Synced successfully. (Up to date or updated)"
            ((models_updated++))
        else
            log_error "  -> Failed to sync. Check network or Hugging Face access."
            ((update_failed++))
        fi
        echo ""
    done

    if [[ $models_checked -eq 0 ]]; then
        log_warn "No models found in ${COMPONENT_DATA_DIR}. Nothing to update."
    else
        log_info "Model sync complete: Checked ${models_checked}, Successfully synced ${models_updated}."
    fi

    return $update_failed
}

# ============================================================================
# 6. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Updating: ${COMPONENT_NAME} (Target: ${TARGET})${COLOR_RESET}"
    print_separator
    echo ""

    check_installation || exit 1

    local update_failed=0

    # Execute updates based on target
    case "$TARGET" in
        all)
            update_architecture || ((update_failed++))
            echo ""
            update_models || ((update_failed++))
            ;;
        architecture)
            update_architecture || ((update_failed++))
            ;;
        models)
            update_models || ((update_failed++))
            ;;
    esac

    echo ""
    print_separator

    if [[ $update_failed -gt 0 ]]; then
        log_error "Update completed with errors. Please check the logs above."
        log_info "Tip: Ensure you have accepted the model license on Hugging Face if it's a gated model."
        exit 1
    else
        log_success "${COMPONENT_NAME} has been successfully updated!"
        echo ""
        echo -e "${COLOR_CYAN}Note:${COLOR_RESET}"
        echo "  Running components (like ComfyUI or Ollama) may need to be restarted"
        echo "  to load the newly updated model weights into memory."
        echo ""
    fi
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
