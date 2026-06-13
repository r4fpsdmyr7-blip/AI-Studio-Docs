#!/usr/bin/env bash
# =============================================================================
# AI-Studio 主入口脚本
# 用法: ./ai-studio.sh <command> [component] [options]
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
load_libs
load_all_components

show_help() {
    show_main_menu
    echo ""
    echo -e "${CLR_BOLD}命令详情:${CLR_RESET}"
    echo "  deploy [comp]     首次部署 (安装组件)"
    echo "  start [comp]      启动服务 (自动打开浏览器)"
    echo "  stop [comp]       停止服务"
    echo "  status [comp]     查看状态"
    echo "  update [comp]     更新组件"
    echo "  agent <action>    Agent 管理 (list/config/status)"
    echo "  model <action>    模型管理 (list/pull/download/architectures)"
    echo "  diagnose [fix]    自我诊断"
    echo "  uninstall [comp]  卸载组件"
    echo "  log [comp] [n]    查看日志"
    echo "  config [comp]     查看/编辑配置"
    echo "  help              显示帮助"
    echo ""
    echo -e "${CLR_BOLD}组件列表:${CLR_RESET}"
    for comp in "${REGISTERED_COMPONENTS[@]}"; do
        printf "  %-15s %s\n" "$comp" "$(get_comp_info "$comp" "DESC")"
    done
}

main() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        deploy)     source "$AI_STUDIO_COMMANDS_DIR/deploy.sh"; cmd_deploy "$@" ;;
        start)      source "$AI_STUDIO_COMMANDS_DIR/start.sh"; cmd_start "$@" ;;
        stop)       source "$AI_STUDIO_COMMANDS_DIR/stop.sh"; cmd_stop "$@" ;;
        status)     source "$AI_STUDIO_COMMANDS_DIR/status.sh"; cmd_status "$@" ;;
        update)     source "$AI_STUDIO_COMMANDS_DIR/update.sh"; cmd_update "$@" ;;
        agent)      source "$AI_STUDIO_COMMANDS_DIR/agent.sh"; cmd_agent "$@" ;;
        model)      source "$AI_STUDIO_COMMANDS_DIR/model.sh"; cmd_model "$@" ;;
        diagnose)   source "$AI_STUDIO_COMMANDS_DIR/diagnose.sh"; cmd_diagnose "$@" ;;
        uninstall)  source "$AI_STUDIO_COMMANDS_DIR/uninstall.sh"; cmd_uninstall "$@" ;;
        log)        show_log "${1:-}" "${2:-50}" ;;
        config)     show_config "${1:-}" ;;
        help|--help|-h|"") show_help ;;
        *)          log_error "未知命令: $cmd"; show_help; return 1 ;;
    esac
}

main "$@"
