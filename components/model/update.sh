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
            log_error "$(msgf UPDATE_UNKNOWN_ARG "$1")"
            log_info "$(msgf MODEL_UPDATE_USAGE "$COMPONENT_NAME")"
            exit 1
            ;;
    esac
done

# Validate target against metadata definition
if [[ ! " ${COMPONENT_UPDATE_TARGETS} " =~ " ${TARGET} " ]]; then
    log_error "$(msgf UPDATE_INVALID_TARGET "$TARGET")"
    log_info "$(msgf UPDATE_SUPPORTED_TARGETS "$COMPONENT_NAME" "${COMPONENT_UPDATE_TARGETS// /, }")"
    exit 1
fi

# ============================================================================
# 4. Pre-flight Checks
# ============================================================================

check_installation() {
    if [[ ! -d "$COMPONENT_DATA_DIR" ]]; then
        log_error "$(msgf MODEL_UPDATE_NO_DIR "$COMPONENT_DATA_DIR")"
        log_info "$(msgf UPDATE_HINT_INSTALL_FIRST "$COMPONENT_NAME")"
        return 1
    fi
    return 0
}

# ============================================================================
# 5. Core Update Logic
# ============================================================================

# Update the underlying toolchain (huggingface-cli, hf-transfer)
update_architecture() {
    log_info "$(msg MODEL_UPDATE_TOOLCHAIN)"
    
    # Ensure dependencies are met (this is idempotent and will upgrade if needed)
    if install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_success "$(msg MODEL_UPDATE_TOOLCHAIN_OK)"
        return 0
    else
        log_error "$(msg MODEL_UPDATE_TOOLCHAIN_FAILED)"
        return 1
    fi
}

# Sync downloaded models with their remote Hugging Face repositories
update_models() {
    log_info "$(msg MODEL_UPDATE_CHECKING_HF)"
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
        
        log_info "$(msgf MODEL_UPDATE_CHECKING "${COLOR_CYAN}${model_name}${COLOR_RESET}")"
        
        # Check if we know the source repository (recorded during install)
        if [[ ! -f "$repo_id_file" ]]; then
            log_warn "  $(msg MODEL_UPDATE_UNKNOWN_SRC)"
            log_info "     $(msg MODEL_UPDATE_MANUAL_NOTE)"
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
            log_success "  $(msg MODEL_UPDATE_SYNC_OK)"
            ((models_updated++))
        else
            log_error "  $(msg MODEL_UPDATE_SYNC_FAILED)"
            ((update_failed++))
        fi
        echo ""
    done

    if [[ $models_checked -eq 0 ]]; then
        log_warn "$(msgf MODEL_UPDATE_NO_MODELS "$COMPONENT_DATA_DIR")"
    else
        log_info "$(msgf MODEL_UPDATE_SYNC_SUMMARY "$models_checked" "$models_updated")"
    fi

    return $update_failed
}

# ============================================================================
# 6. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_UPDATE "$COMPONENT_NAME" "$TARGET")${COLOR_RESET}"
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
        log_error "$(msg UPDATE_ERRORS)"
        log_info "$(msg MODEL_UPDATE_TIP_LICENSE)"
        exit 1
    else
        log_success "$(msgf UPDATE_SUCCESS_COMPONENT "$COMPONENT_NAME")"
        echo ""
        echo -e "${COLOR_CYAN}$(msg LBL_NOTE):${COLOR_RESET}"
        echo "  $(msg MODEL_UPDATE_RESTART_1)"
        echo "  $(msg MODEL_UPDATE_RESTART_2)"
        echo ""
    fi
    
    print_separator
    exit 0
}

# Execute main function
main "$@"
