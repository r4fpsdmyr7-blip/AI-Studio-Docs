#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_diagnose() {
    log_info "===== AI-Studio 自我诊断 ====="; echo ""
    local issues=0
    info_box "1. 系统环境"
    detect_platform
    echo -e "  OS:   $AI_STUDIO_OS / $AI_STUDIO_ARCH"
    is_apple_silicon && echo -e "  芯片: ${CLR_GREEN}Apple Silicon (Metal 加速)${CLR_RESET}" || echo -e "  芯片: Intel"
    echo -e "  内存: $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GB\n", $1/1024/1024/1024}' || echo 'N/A')"
    echo -e "  磁盘: $(df -h "$AI_STUDIO_HOME" 2>/dev/null | tail -1 | awk '{print $4 " 可用"}' || echo 'N/A')"
    echo ""; info_box "2. 依赖检查"
    for dep in git curl python3 node npm pip3 brew ollama docker; do
        if check_command "$dep"; then echo -e "  ${CLR_GREEN}✓${CLR_RESET} $dep: $($dep --version 2>&1 | head -1)"
        else echo -e "  ${CLR_RED}✗${CLR_RESET} $dep: 未安装"; ((issues++)); fi
    done
    echo ""; info_box "3. Python 环境"
    if check_command python3; then
        echo -e "  版本: $(python3 --version 2>&1)"; echo -e "  路径: $(which python3)"
        python3 -c "import mlx" 2>/dev/null && echo -e "  MLX:  ${CLR_GREEN}已安装${CLR_RESET}" || echo -e "  MLX:  ${CLR_YELLOW}未安装${CLR_RESET}"
        python3 -c "import torch" 2>/dev/null && echo -e "  PyTorch: ${CLR_GREEN}已安装$(python3 -c 'import torch; print(" (MPS)" if torch.backends.mps.is_available() else "")' 2>/dev/null)${CLR_RESET}" || echo -e "  PyTorch: ${CLR_YELLOW}未安装${CLR_RESET}"
    fi
    echo ""; info_box "4. 网络连通性"
    check_internet "https://github.com" && echo -e "  GitHub: ${CLR_GREEN}可达${CLR_RESET}" || { echo -e "  GitHub: ${CLR_RED}不可达${CLR_RESET}"; ((issues++)); }
    check_internet "https://huggingface.co" && echo -e "  HuggingFace: ${CLR_GREEN}可达${CLR_RESET}" || { echo -e "  HuggingFace: ${CLR_RED}不可达${CLR_RESET}"; ((issues++)); }
    check_internet "$(get_config OLLAMA_HOST http://localhost:11434)" && echo -e "  Ollama: ${CLR_GREEN}运行中${CLR_RESET}" || echo -e "  Ollama: ${CLR_YELLOW}未运行${CLR_RESET}"
    echo ""; info_box "5. 组件状态"
    for comp in "${REGISTERED_COMPONENTS[@]}"; do
        if is_comp_installed "$comp"; then
            is_running "$comp" && echo -e "  ${CLR_GREEN}✓${CLR_RESET} $comp: 已安装, 运行中" || echo -e "  ${CLR_YELLOW}○${CLR_RESET} $comp: 已安装, 已停止"
        else echo -e "  ${CLR_DIM}○${CLR_RESET} $comp: 未安装"; fi
    done
    echo ""; info_box "6. 端口检查"
    for comp in "${REGISTERED_COMPONENTS[@]}"; do
        local port; port="$(get_comp_info "$comp" "PORT")"; [[ -z "$port" ]] && continue
        is_port_free "$port" && echo -e "  ${CLR_GREEN}✓${CLR_RESET} $port ($comp): 空闲" || { echo -e "  ${CLR_RED}✗${CLR_RESET} $port ($comp): 被占用"; ((issues++)); }
    done
    echo ""
    ((issues == 0)) && success_box "诊断完成: 无问题" || log_warn "发现 $issues 个问题"
    [[ "${2:-}" == "fix" ]] && { echo ""; log_info "===== 自动修复 ====="
        check_command python3 || { [[ "$AI_STUDIO_OS" == "macos" ]] && brew install python; }
        check_command node || { [[ "$AI_STUDIO_OS" == "macos" ]] && brew install node; }
        success_box "修复完成"
    }
}
cmd_diagnose "$@"
