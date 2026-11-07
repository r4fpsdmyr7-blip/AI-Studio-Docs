#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Installation Script
# File: components/model/install.sh
# 
# Handles the centralized downloading and management of large MLX-optimized 
# models (LLMs, SD, FLUX). It uses hf-transfer for high-speed, resumable 
# downloads and stores all models in a shared global directory to save disk space.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Installation Logic
# ============================================================================

# Check available disk space specifically for the model directory
check_model_disk_space() {
    local target_dir="$1"
    local required_gb="${2:-50}" # Default require 50GB for large models
    
    # Get available space in GB on the partition containing the target directory
    local avail_gb
    avail_gb=$(df -g "$target_dir" | awk 'NR==2 {print $4}' | tr -dc '0-9')
    
    if [[ "$avail_gb" -lt "$required_gb" ]]; then
        log_error "$(msgf MODEL_INSTALL_DISK_LOW "$target_dir")"
        log_info "$(msgf MODEL_INSTALL_DISK_DETAIL "$avail_gb" "$required_gb")"
        return 1
    fi
    log_success "$(msgf MODEL_INSTALL_DISK_OK "$avail_gb" "$target_dir")"
    return 0
}

# Download a specific MLX model from Hugging Face
# Usage: download_mlx_model "mlx-community/Qwen3-35B-Uncensored-MLX" "qwen3-35b-uncensored"
download_mlx_model() {
    local repo_id="$1"
    local model_dir_name="$2"
    local target_path="${COMPONENT_DATA_DIR}/${model_dir_name}"
    
    log_info "$(msgf MODEL_INSTALL_CHECKING "${COLOR_CYAN}${model_dir_name}${COLOR_RESET}")"
    
    # Idempotency check: If config.json or a .safetensors file exists, assume it's downloaded
    if [[ -f "${target_path}/config.json" ]] || [[ -n "$(ls -A "${target_path}"/*.safetensors 2>/dev/null)" ]]; then
        log_success "$(msgf MODEL_INSTALL_EXISTS "$model_dir_name")"
        return 0
    fi

    log_info "$(msgf MODEL_INSTALL_DOWNLOADING "$repo_id" "$target_path")"
    log_warn "${COLOR_YELLOW}$(msg MODEL_INSTALL_LARGE_FILE)${COLOR_RESET}"
    
    # Ensure parent directory exists
    ensure_dir "$(dirname "$target_path")"

    # Enable hf-transfer for massive speedup (Rust-based, multi-threaded)
    # HUGGING_FACE_HUB_TOKEN can be set by user if downloading gated/private models
    export HF_HUB_ENABLE_HF_TRANSFER=1
    
    # Use huggingface-cli to download. 
    # --resume-download is critical for large models over unstable connections
    if huggingface-cli download "$repo_id" --local-dir "$target_path" --resume-download; then
        log_success "$(msgf MODEL_INSTALL_DL_OK "$model_dir_name")"
        return 0
    else
        log_error "$(msgf MODEL_INSTALL_DL_FAIL "$model_dir_name")"
        log_info "$(msg TROUBLESHOOT_LABEL)"
        log_info "  $(msg MODEL_INSTALL_TS_1)"
        log_info "  $(msg MODEL_INSTALL_TS_2)"
        log_info "  $(msg MODEL_INSTALL_TS_3)"
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  $(msgf BANNER_INSTALL "$COMPONENT_NAME") $(msg MODEL_REPO_SUFFIX)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  $(msg MODEL_INSTALL_SUBTITLE)${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Dependency Verification & Installation
    log_info "$(msg MODEL_INSTALL_STEP1)"
    if ! install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_error "$(msg INSTALL_FAILED_DEPS)"
        exit 1
    fi

    # Step 2: Disk Space Verification
    log_info "$(msg MODEL_INSTALL_STEP2)"
    # FLUX and 35B LLMs can easily exceed 30-40GB. We require at least 50GB free.
    if ! check_model_disk_space "$COMPONENT_DATA_DIR" 50; then
        exit 1
    fi

    # Step 3: Model Download Execution
    log_info "$(msg MODEL_INSTALL_STEP3)"
    echo ""
    
    local download_failed=0

    # 1. Qwen3 35B Uncensored (Aggressive variant)
    # Note: Replace repo_id with the actual mlx-community converted repository name
    download_mlx_model "mlx-community/Qwen3-35B-A3B-Uncensored-HauHauCS-Aggressive" "qwen3-35b-uncensored" || download_failed=$((download_failed + 1))
    
    echo ""
    
    # 2. Stable Diffusion (e.g., SD 3.5 Large or SDXL)
    download_mlx_model "mlx-community/stable-diffusion-3.5-large" "stable-diffusion-3.5-large" || download_failed=$((download_failed + 1))
    
    echo ""
    
    # 3. FLUX.1 (Dev or Schnell)
    download_mlx_model "mlx-community/FLUX.1-dev" "flux.1-dev" || download_failed=$((download_failed + 1))

    echo ""
    print_separator

    if [[ $download_failed -gt 0 ]]; then
        log_error "$(msgf MODEL_INSTALL_DONE_ERRORS "$download_failed")"
        log_info "$(msg MODEL_INSTALL_RETRY_HINT)"
        exit 1
    else
        touch "${COMPONENT_DIR}/.installed"
        log_success "$(msg MODEL_INSTALL_ALL_OK)"
        echo ""
        echo -e "${COLOR_CYAN}$(msg MODEL_INSTALL_INTEGRATION)${COLOR_RESET}"
        echo "  $(msgf MODEL_INSTALL_STORED_AT "${COLOR_BOLD}${COMPONENT_DATA_DIR}${COLOR_RESET}")"
        echo ""
        echo "  $(msg MODEL_INSTALL_USAGE_INTRO)"
        echo "  - $(msg MODEL_INSTALL_USAGE_COMFYUI)"
        echo "  - $(msg MODEL_INSTALL_USAGE_MLX)"
        echo "  - $(msg MODEL_INSTALL_USAGE_OLLAMA)"
        echo ""
        echo -e "${COLOR_GRAY}$(msg MODEL_INSTALL_TIP_UPDATE)${COLOR_RESET}"
        echo ""
    fi

    print_separator
    exit 0
}

# Execute main function
main "$@"
