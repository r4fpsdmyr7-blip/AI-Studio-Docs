#!/bin/bash
# ============================================================================
# lib/lang.sh - UI 消息层（i18n）
# ============================================================================
# 语言策略（详见 AGENTS.md §6）：
#   L1 构成层  标识符 / CLI / 配置键 / 日志级别标签  -> 永远英文 ASCII
#   L2 UI 层   终端输出                              -> 本文件词条，默认中文，可切换
#   L3 文档层  README / 注释                         -> 中文为主
#
# 三层一律禁止 emoji。
#
# 用法：
#   log_info "$(msg INSTALL_START)"
#   log_info "$(msgf INSTALL_DONE "$name")"
#
# 语言优先级（由高到低）：
#   1. --lang <code>      （调用 lang_set，见 ai-studio.sh）
#   2. AI_STUDIO_LANG     （环境变量）
#   3. config/global.conf 的 LANG
#   4. 默认 zh
#
# 新增词条时 msg_zh 与 msg_en 必须成对添加，tests/test_lang.sh 会校验。
# ============================================================================

set -u

# 幂等：common.sh 与其它脚本可能重复 source 本文件
if [[ -n "${AI_STUDIO_LANG_LOADED:-}" ]]; then
    return 0
fi
readonly AI_STUDIO_LANG_LOADED=1

readonly LANG_DEFAULT="zh"
readonly LANG_SUPPORTED="zh en"

# 语言代码归一化：把各种写法收敛到 LANG_SUPPORTED 里的值；不认识则返回空
lang_normalize() {
    local raw lower
    raw="${1:-}"
    lower="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' _-')"

    case "$lower" in
        zh|zhcn|zhhans|zhhant|zhtw|chinese|cn)           printf 'zh' ;;
        en|enus|engb|english)                            printf 'en' ;;
        *)                                               printf '' ;;
    esac
}

# 判断是否为受支持的语言
lang_is_supported() {
    local lang want
    lang="$1"
    for want in $LANG_SUPPORTED; do
        if [[ "$lang" == "$want" ]]; then
            return 0
        fi
    done
    return 1
}

# 显式设定语言（供 --lang 选项调用）。成功返回 0，不支持的语言返回 1
lang_set() {
    local code
    code="$(lang_normalize "${1:-}")"
    if [[ -z "$code" ]] || ! lang_is_supported "$code"; then
        return 1
    fi
    AI_STUDIO_LANG="$code"
    export AI_STUDIO_LANG
    return 0
}

# 把语言写入 config/global.conf（持久化）
lang_persist() {
    local code
    code="$(lang_normalize "${1:-}")"
    if [[ -z "$code" ]] || ! lang_is_supported "$code"; then
        return 1
    fi
    if command -v set_config >/dev/null 2>&1; then
        set_config "LANG" "$code"
    fi
    lang_set "$code"
}

# 当前生效语言
lang_current() {
    local code

    # 1. 运行时已显式设定（--lang 或环境变量）
    code="$(lang_normalize "${AI_STUDIO_LANG:-}")"
    if [[ -n "$code" ]] && lang_is_supported "$code"; then
        printf '%s' "$code"
        return 0
    fi

    # 2. 配置文件
    if [[ -n "${AI_STUDIO_GLOBAL_CONFIG:-}" && -f "${AI_STUDIO_GLOBAL_CONFIG}" ]]; then
        code="$(lang_normalize "$(grep -E '^LANG=' "$AI_STUDIO_GLOBAL_CONFIG" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '"')")"
        if [[ -n "$code" ]] && lang_is_supported "$code"; then
            printf '%s' "$code"
            return 0
        fi
    fi

    # 3. 默认值
    printf '%s' "$LANG_DEFAULT"
}

# 列出所有已定义词条 KEY（从本文件提取，自动与词条表保持同步）
msg_keys() {
    grep -oE '(^|[[:space:]])[A-Z][A-Z0-9_]*\)[[:space:]]' "${AI_STUDIO_ROOT:-.}/lib/lang.sh" \
        | tr -d ' )' | grep -vE '^(LANG|MSG)$' | sort -u
}

# ---------------------------------------------------------------------------
# 中文词条
# ---------------------------------------------------------------------------
msg_zh() {
    case "${1:-}" in
        # —— 通用 ——
        APP_TAGLINE)            printf '%s' 'macOS 一站式 AI 工具部署与管理平台' ;;
        UNKNOWN_COMMAND)        printf '%s' '未知命令' ;;
        USAGE_HINT)             printf '%s' '用法' ;;
        OPERATION_CANCELLED)    printf '%s' '操作已取消' ;;
        OPERATION_SUCCESS)      printf '%s' '操作成功' ;;
        OPERATION_FAILED)       printf '%s' '操作失败' ;;
        PRESS_ENTER)            printf '%s' '按回车键继续' ;;
        YES)                    printf '%s' '是' ;;
        NO)                     printf '%s' '否' ;;
        NOT_INSTALLED)          printf '%s' '未安装' ;;
        ALREADY_INSTALLED)      printf '%s' '已安装' ;;
        RUNNING)                printf '%s' '运行中' ;;
        STOPPED)                printf '%s' '已停止' ;;
        READY)                  printf '%s' '就绪' ;;
        SKIPPED)                printf '%s' '已跳过' ;;

        # —— 组件列表 ——
        LIST_HEADER)            printf '%s' '可用组件' ;;
        LIST_EMPTY)             printf '%s' '暂无可用组件' ;;
        COMPONENT_NOT_FOUND)    printf '%s' '未找到组件' ;;
        COMPONENT_UNKNOWN)      printf '%s' '未知组件' ;;

        # —— install ——
        INSTALL_START)          printf '%s' '开始安装' ;;
        INSTALL_DONE)           printf '%s' '安装完成' ;;
        INSTALL_FAILED)         printf '%s' '安装失败' ;;
        INSTALL_SKIPPED)        printf '%s' '已是最新，跳过安装' ;;

        # —— start ——
        START_START)            printf '%s' '正在启动' ;;
        START_DONE)             printf '%s' '启动完成' ;;
        START_FAILED)           printf '%s' '启动失败' ;;
        START_ALREADY)          printf '%s' '已在运行中' ;;

        # —— stop ——
        STOP_START)             printf '%s' '正在停止' ;;
        STOP_DONE)              printf '%s' '已停止' ;;
        STOP_NOT_RUNNING)       printf '%s' '当前未在运行' ;;

        # —— restart ——
        RESTART_START)          printf '%s' '正在重启' ;;
        RESTART_DONE)           printf '%s' '重启完成' ;;

        # —— update ——
        UPDATE_START)           printf '%s' '正在更新' ;;
        UPDATE_DONE)            printf '%s' '更新完成' ;;
        UPDATE_FAILED)          printf '%s' '更新失败' ;;
        UPDATE_NOTHING)         printf '%s' '无需更新' ;;

        # —— uninstall ——
        UNINSTALL_START)        printf '%s' '正在卸载' ;;
        UNINSTALL_DONE)         printf '%s' '卸载完成' ;;
        UNINSTALL_FAILED)       printf '%s' '卸载失败' ;;

        # —— status / diagnose ——
        STATUS_TITLE)           printf '%s' '组件状态' ;;
        DIAGNOSE_START)         printf '%s' '开始诊断' ;;
        DIAGNOSE_DONE)          printf '%s' '诊断完成' ;;
        DIAGNOSE_NO_ISSUE)      printf '%s' '未发现问题' ;;
        DIAGNOSE_ISSUE_FOUND)   printf '%s' '发现问题' ;;

        # —— env ——
        ENV_CHECK_START)        printf '%s' '正在检查系统环境' ;;
        ENV_CHECK_DONE)         printf '%s' '环境检查完成' ;;
        ENV_INSTALL_START)      printf '%s' '正在安装依赖' ;;
        ENV_INSTALL_DONE)       printf '%s' '依赖安装完成' ;;

        # —— 端口 ——
        PORT_IN_USE)            printf '%s' '端口被占用' ;;
        PORT_FREE)              printf '%s' '端口空闲' ;;

        # —— 主入口：帮助 ——
        HELP_CORE_COMMANDS)     printf '%s' '核心命令' ;;
        HELP_ENV_DESC)          printf '%s' '环境管理' ;;
        HELP_INSTALL_DESC)      printf '%s' '安装组件' ;;
        HELP_START_DESC)        printf '%s' '启动服务（自动打开浏览器）' ;;
        HELP_STOP_DESC)         printf '%s' '停止服务' ;;
        HELP_RESTART_DESC)      printf '%s' '重启服务' ;;
        HELP_STATUS_DESC)       printf '%s' '查看状态' ;;
        HELP_UPDATE_DESC)       printf '%s' '更新组件' ;;
        HELP_UPDATE_TARGET)     printf '%s' '更新目标' ;;
        HELP_UNINSTALL_DESC)    printf '%s' '卸载组件' ;;
        HELP_KEEP_DATA)         printf '%s' '保留用户数据' ;;
        HELP_FORCE)             printf '%s' '强制卸载' ;;
        HELP_DIAGNOSE_DESC)     printf '%s' '诊断组件' ;;
        HELP_DEEP)              printf '%s' '深度诊断' ;;
        HELP_FIX)               printf '%s' '诊断并自动修复' ;;
        HELP_LIST_DESC)         printf '%s' '列出所有可用组件' ;;
        HELP_HELP_DESC)         printf '%s' '显示本帮助' ;;
        HELP_VERSION_DESC)      printf '%s' '显示版本' ;;
        HELP_LANG_CMD)          printf '%s' '查看 / 列出 / 切换 UI 语言' ;;
        HELP_COMPONENTS)        printf '%s' '可用组件' ;;
        HELP_GLOBAL_OPTIONS)    printf '%s' '全局选项' ;;
        HELP_LANG_DESC)         printf '%s' '本次运行的 UI 语言（覆盖配置）' ;;
        HELP_EXAMPLES)          printf '%s' '示例' ;;

        # —— 主入口：批量操作 ——
        INSTALL_ALL)            printf '%s' '正在安装所有组件' ;;
        START_ALL)              printf '%s' '正在启动所有组件' ;;
        STOP_ALL)               printf '%s' '正在停止所有组件' ;;
        RESTART_ALL)            printf '%s' '正在重启所有组件' ;;
        UPDATE_ALL)             printf '%s' '正在更新所有组件' ;;
        INSTALLING_COMPONENT)   printf '%s' '正在安装 %s' ;;
        STARTING_COMPONENT)     printf '%s' '正在启动 %s' ;;
        STOPPING_COMPONENT)     printf '%s' '正在停止 %s' ;;
        RESTARTING_COMPONENT)   printf '%s' '正在重启 %s' ;;
        UPDATING_COMPONENT)     printf '%s' '正在更新 %s' ;;
        UNINSTALLING_COMPONENT) printf '%s' '正在卸载 %s' ;;
        DIAGNOSING_COMPONENT)   printf '%s' '正在诊断 %s' ;;

        # —— 主入口：提示与报错 ——
        ENV_STATUS_TITLE)       printf '%s' '环境状态' ;;
        ENV_SUBCOMMAND_UNKNOWN) printf '%s' '未知的 env 子命令' ;;
        SEE_COMPONENT_LIST)     printf '%s' "执行 '%s list' 查看所有可用组件" ;;
        COMPONENT_OP_UNSUPPORTED) printf '%s' '组件 %s 不支持 %s 操作' ;;
        MISSING_COMPONENT_ARG)  printf '%s' '缺少组件名参数' ;;

        # —— 列表图例 ——
        LIST_LEGEND)            printf '%s' '状态图例' ;;
        LEGEND_RUNNING)         printf '%s' '运行中' ;;
        LEGEND_INSTALLED)       printf '%s' '已安装但未运行' ;;
        LEGEND_NOT_INSTALLED)   printf '%s' '未安装' ;;
        LABEL_PORT)             printf '%s' '端口' ;;

        # —— 组件：通用横幅 ——
        BANNER_INSTALL)            printf '%s' '正在安装: %s' ;;
        BANNER_START)              printf '%s' '正在启动: %s' ;;
        BANNER_STOP)               printf '%s' '正在停止: %s' ;;
        BANNER_STATUS)             printf '%s' '状态: %s' ;;
        BANNER_DIAGNOSE)           printf '%s' '正在诊断: %s' ;;
        BANNER_UNINSTALL)          printf '%s' '正在卸载: %s' ;;
        BANNER_UPDATE)             printf '%s' '正在更新: %s (目标: %s)' ;;

        # —— 组件：mlx 专属 ——
        BANNER_VERIFY)             printf '%s' '正在校验: %s' ;;
        INSTALL_STEP_VENV_N)      printf '%s' '步骤 %s/4：建立独立 Python 虚拟环境...' ;;
        MLX_NOT_APPLE_SILICON)     printf '%s' 'MLX 面向 Apple Silicon (M1/M2/M3/M4) 设计，当前架构为 %s' ;;
        MLX_PERF_LIMITED)          printf '%s' '安装将继续，但性能会显著受限或不受支持' ;;
        MLX_INSTALL_ALREADY_OK)    printf '%s' '%s 似乎已安装且可用' ;;
        MLX_VENV_NOT_IMPORTABLE)   printf '%s' '虚拟环境存在但 MLX 无法导入，正在重新安装...' ;;
        MLX_FAILED_DEPS)           printf '%s' '依赖安装失败（python3、git、cmake），已中止' ;;
        MLX_STEP_VENV_CLEAN)       printf '%s' '正在移除已损坏或不完整的虚拟环境...' ;;
        MLX_STEP_FRAMEWORK)        printf '%s' '步骤 3/4：安装 MLX 框架与核心扩展...' ;;
        MLX_INSTALLING_PACKAGES)   printf '%s' '正在安装：%s ...' ;;
        MLX_FAILED_PACKAGES)       printf '%s' 'MLX Python 包安装失败' ;;
        MLX_MISSING_HEADERS)       printf '%s' '可能缺少系统头文件（请确认已安装 Xcode 命令行工具）' ;;
        MLX_PACKAGES_OK)           printf '%s' 'MLX 包安装成功' ;;
        MLX_STEP_VERIFY)           printf '%s' '步骤 4/4：校验安装...' ;;
        MLX_VERIFY_OK)             printf '%s' 'MLX v%s 安装并校验通过' ;;
        MLX_VERIFY_FAILED)         printf '%s' '安装校验失败，无法导入 MLX 模块' ;;
        MLX_CACHE_DIR_READY)       printf '%s' '已初始化 MLX 缓存目录：%s' ;;
        MLX_NEXT_TITLE)            printf '%s' '后续步骤与用法' ;;
        MLX_NEXT_NO_START)         printf '%s' '  MLX 是基础框架，通常不需要直接 '\''start'\''' ;;
        MLX_NEXT_USE_VIA)          printf '%s' '  而是通过以下方式使用：' ;;
        MLX_NEXT_1)                printf '%s' '  1. 用 '\''model'\'' 组件下载权重：./ai-studio.sh install model' ;;
        MLX_NEXT_2)                printf '%s' '  2. 自定义 Python 脚本激活此虚拟环境：source %s/bin/activate' ;;
        MLX_NEXT_3)                printf '%s' '  3. 其它依赖 MLX 的 AI Studio 组件' ;;
        MLX_START_NOT_IMPORTABLE)  printf '%s' 'MLX 已安装但无法导入，环境可能已损坏' ;;
        MLX_USAGE_TITLE)           printf '%s' '提示：如何使用 MLX 框架' ;;
        MLX_USAGE_DESC1)           printf '%s' '  MLX 是计算库，不是后台服务，不需要' ;;
        MLX_USAGE_DESC2)           printf '%s' '  启动。而是通过 Python 脚本或 CLI 工具与之交互。' ;;
        MLX_USAGE_STEP1)           printf '%s' '1. 激活独立环境：' ;;
        MLX_USAGE_STEP1_CMD)       printf '%s' 'source %s' ;;
        MLX_USAGE_STEP2)           printf '%s' '2. 确认 MLX 使用了 Apple Silicon 加速：' ;;
        MLX_USAGE_STEP2_CMD)       printf '%s' 'python3 -c "import mlx.core as mx; print('\''Device:'\'', mx.default_device())"' ;;
        MLX_USAGE_STEP2_EXPECT)    printf '%s' '     （预期输出：Device: mlx）' ;;
        MLX_USAGE_STEP3)           printf '%s' '3. 运行大语言模型（通过 mlx-lm）：' ;;
        MLX_USAGE_STEP3_CMD)       printf '%s' 'mlx_lm.generate --model mlx-community/Qwen2.5-7B-Instruct-4bit --prompt "Hello"' ;;
        MLX_USAGE_STEP4)           printf '%s' '4. 下载模型（集中管理）：' ;;
        MLX_USAGE_STEP4_CMD)       printf '%s' './ai-studio.sh install model' ;;
        MLX_START_NOT_PROPER)      printf '%s' 'MLX 未正确安装' ;;
        MLX_START_SETUP_HINT)      printf '%s' '执行以下命令搭建 MLX 框架及其扩展：' ;;
        MLX_START_INSTALL_CMD)     printf '%s' '  ./ai-studio.sh install %s' ;;
        MLX_START_READY)           printf '%s' 'MLX v%s 已安装，可以使用' ;;
        MLX_START_NO_SERVICE)      printf '%s' '无需启动后台服务，框架已就绪可供脚本调用' ;;
        MLX_STOP_FOUNDATIONAL)     printf '%s' ''\''%s'\'' 组件是基础机器学习框架' ;;
        MLX_STOP_NO_DAEMON)        printf '%s' '它不作为后台守护进程运行，自身不占用 CPU/GPU 资源' ;;
        MLX_STOP_FREE_HINT)        printf '%s' '如需释放系统资源（显存/内存），应停止当前正在使用 MLX 的具体推理组件或脚本：' ;;
        MLX_STOP_DEPS_RUNNING)     printf '%s' '以下依赖 MLX 的组件正在运行：' ;;
        STOP_DEPS_HINT)        printf '%s' '要停止它们并释放资源，执行：' ;;
        MLX_STOP_DEPS_CMD)         printf '%s' './ai-studio.sh stop %s' ;;
        MLX_STOP_NONE_RUNNING)     printf '%s' '当前没有依赖 MLX 的后台服务在运行，系统资源已完全释放' ;;
        MLX_STOP_NO_ACTION)        printf '%s' ''\''%s'\'' 无需任何操作，框架状态已保留' ;;
        NEXT_STEPS)                printf '%s' '后续步骤' ;;
        ACTIONS_LABEL)             printf '%s' '可执行操作' ;;

        # —— 组件：install ——
        INSTALL_ALREADY)           printf '%s' '%s 似乎已经安装' ;;
        INSTALL_SKIP_HINT)         printf '%s' '跳过安装。如需升级请执行 '\''./ai-studio.sh update %s'\''' ;;
        INSTALL_STEP_VERIFY_DEPS)  printf '%s' '步骤 1/4：校验系统依赖...' ;;
        INSTALL_FAILED_DEPS)       printf '%s' '依赖安装失败，已中止' ;;
        INSTALL_STEP_CLONE)        printf '%s' '步骤 2/4：从 %s 获取源码...' ;;
        INSTALL_DIR_NOT_GIT)       printf '%s' '目录非空且不是 git 仓库，正在清理...' ;;
        INSTALL_CLONE_OK)          printf '%s' '源码克隆成功' ;;
        INSTALL_SRC_EXISTS)        printf '%s' '源码已存在，正在确认分支正确...' ;;
        INSTALL_SRC_UPDATED)       printf '%s' '源码已更新' ;;
        INSTALL_STEP_VENV)         printf '%s' '步骤 3/4：建立独立 Python 虚拟环境...' ;;
        INSTALL_FAILED_VENV)       printf '%s' 'Python 虚拟环境创建失败' ;;
        INSTALL_VENV_OK)           printf '%s' '虚拟环境已创建并激活' ;;
        INSTALL_STEP_PYDEPS)       printf '%s' '步骤 4/4：安装 Python 依赖（可能需要几分钟）...' ;;
        INSTALL_FAILED_PYDEPS)     printf '%s' '从 requirements.txt 安装 Python 依赖失败' ;;
        INSTALL_NO_REQUIREMENTS)   printf '%s' '未找到 requirements.txt，改为直接安装 '\''open-webui'\'' 包...' ;;
        INSTALL_FAILED_PACKAGE)    printf '%s' 'open-webui 包安装失败' ;;
        INSTALL_PYDEPS_OK)         printf '%s' 'Python 依赖安装成功' ;;
        INSTALL_INIT_DATA_DIR)     printf '%s' '正在初始化组件数据目录...' ;;
        INSTALL_DATA_DIR_READY)    printf '%s' '数据目录就绪：%s' ;;
        INSTALL_SUCCESS_COMPONENT) printf '%s' '%s 安装成功！' ;;
        INSTALL_NEXT_START)        printf '%s' '1. 启动服务（会自动打开浏览器）：' ;;
        INSTALL_NEXT_START_CMD)    printf '%s' '   ./ai-studio.sh start %s' ;;
        INSTALL_NEXT_STATUS)       printf '%s' '2. 查看服务状态：' ;;
        INSTALL_NEXT_STATUS_CMD)   printf '%s' '   ./ai-studio.sh status %s' ;;

        # —— 组件：start ——
        START_NOT_INSTALLED)       printf '%s' '%s 似乎尚未安装' ;;
        START_ALREADY_RUNNING)     printf '%s' '%s 已在运行（PID: %s）' ;;
        START_INVALID_PORT_OFFSET) printf '%s' '配置中的 DEFAULT_PORT_OFFSET 无效，改用 0' ;;
        START_PORT_IN_USE)         printf '%s' '端口 %s 已被其它程序占用' ;;
        START_PORT_HINT)           printf '%s' '请修改 config/ai-studio.conf 中的 DEFAULT_PORT_OFFSET，或释放该端口' ;;
        START_LAUNCHING)           printf '%s' '正在端口 %s 启动 %s...' ;;
        START_FAILED_DAEMON)       printf '%s' '%s 守护进程启动失败' ;;
        START_SUCCESS_COMPONENT)   printf '%s' '%s 启动成功！' ;;
        START_ACCESS_URL)          printf '%s' '访问地址：%s' ;;
        START_HINT_STOP)           printf '%s' '停止服务请执行：./ai-studio.sh stop %s' ;;
        START_NOT_READY)           printf '%s' '%s 已启动，但端口 %s 未能就绪' ;;
        START_CHECK_LOGS)          printf '%s' '请查看日志了解详情：' ;;
        START_LOG_PATH)            printf '%s' '  %s/logs/%s.log' ;;

        # —— 组件：stop ——
        STOP_NOT_RUNNING)          printf '%s' '%s 当前未在运行' ;;
        STOP_SUCCESS_COMPONENT)    printf '%s' '%s 已成功停止' ;;
        STOP_PORT_RELEASED)        printf '%s' '端口 %s 已释放' ;;
        STOP_HINT_RESTART)         printf '%s' '• 重新启动：./ai-studio.sh start %s' ;;
        STOP_HINT_STATUS)          printf '%s' '• 查看详细状态：./ai-studio.sh status %s' ;;
        STOP_FAILED_CLEAN)         printf '%s' '%s 未能干净停止' ;;
        STOP_STUCK_HINT)           printf '%s' '进程可能卡住，你可以尝试：' ;;
        STOP_STUCK_LOG)            printf '%s' '1. 查看日志：%s/logs/%s.log' ;;
        STOP_STUCK_KILL)           printf '%s' '2. 手动强制结束端口进程：lsof -ti :%s | xargs kill -9' ;;
        STOP_STUCK_DIAGNOSE)       printf '%s' '3. 运行深度诊断：./ai-studio.sh diagnose %s --deep --fix' ;;

        # —— 组件：status ——
        STATUS_NOT_INSTALLED_TAG)  printf '%s' '未安装' ;;
        STATUS_NOT_INSTALLED_DESC) printf '%s' '组件尚未安装' ;;
        STATUS_HINT_INSTALL)       printf '%s' '执行：%s' ;;
        STATUS_RECENT_LOGS)        printf '%s' '最近的日志输出：' ;;
        STATUS_LOG_EMPTY)          printf '%s' '（日志文件为空或没有近期内容）' ;;
        STATUS_NO_LOG)             printf '%s' '（尚未生成日志文件）' ;;
        STATUS_ACTION_STOP)        printf '%s' '• 停止服务：' ;;
        STATUS_ACTION_LOGS)        printf '%s' '• 查看完整日志：' ;;
        STATUS_ACTION_BROWSER)     printf '%s' '• 打开浏览器：' ;;
        STATUS_ACTION_START)       printf '%s' '• 启动服务：' ;;
        STATUS_ACTION_DIAGNOSE)    printf '%s' '• 运行诊断：' ;;

        # —— 组件：diagnose ——
        DIAG_VENV_MISSING)         printf '%s' '严重：Python 虚拟环境缺失或损坏' ;;
        DIAG_HINT_REINSTALL)       printf '%s' '  -> 可能需要重新安装该组件' ;;
        DIAG_VENV_BROKEN)          printf '%s' '严重：虚拟环境的 Python 可执行文件损坏' ;;
        DIAG_VENV_OK)              printf '%s' '正常：虚拟环境完好可用' ;;
        DIAG_DATA_DIR_MISSING)     printf '%s' '警告：数据目录不存在，将在首次启动时创建' ;;
        DIAG_DATA_DIR_NOT_WRITABLE) printf '%s' '严重：数据目录存在但不可写，数据库保存会失败' ;;
        DIAG_DATA_DIR_OK)          printf '%s' '正常：数据目录存在且可写' ;;
        DIAG_OLLAMA_UNREACHABLE)   printf '%s' '提示：无法访问本地 Ollama 实例（端口 11434）' ;;
        DIAG_OLLAMA_HINT)          printf '%s' '  -> 如需使用本地模型，请确保 Ollama 在运行：./ai-studio.sh start qwen3' ;;
        DIAG_FIX_PERMS)            printf '%s' '  -> 正在修复数据目录权限...' ;;
        DIAG_FIX_PERMS_OK)         printf '%s' '    数据目录权限已修复' ;;
        DIAG_FIX_PERMS_FAILED)     printf '%s' '    权限修复失败，需要手工处理' ;;
        DIAG_VENV_CORRUPTED)       printf '%s' '  -> 虚拟环境已损坏' ;;
        DIAG_VENV_NO_AUTOFIX)      printf '%s' '    自动修复无法修复损坏的虚拟环境，请执行：' ;;
        DIAG_CMD_UNINSTALL_KEEP)   printf '%s' '    ./ai-studio.sh uninstall %s --keep-data' ;;
        DIAG_CMD_INSTALL)          printf '%s' '    ./ai-studio.sh install %s' ;;
        DIAG_SPECIFIC_CHECKS)      printf '%s' '正在运行 %s 专属检查...' ;;
        DIAG_ISSUES_FOUND)         printf '%s' '诊断完成，%s 共发现 %s 个问题' ;;
        DIAG_HINT_DEEP_FIX)        printf '%s' '提示：加 '\''--deep --fix'\'' 可尝试自动修复可修复的问题' ;;
        DIAG_HEALTHY)              printf '%s' '诊断完成，%s 状态健康，可以正常使用' ;;

        # —— 组件：uninstall ——
        UNINSTALL_UNKNOWN_ARG)     printf '%s' '未知的卸载参数：%s' ;;
        UNINSTALL_USAGE)           printf '%s' '用法：./ai-studio.sh uninstall %s [--keep-data] [--force]' ;;
        UNINSTALL_NOT_INSTALLED)   printf '%s' '%s 似乎尚未安装，无需卸载' ;;
        UNINSTALL_STOPPING)        printf '%s' '卸载前先停止 %s 服务...' ;;
        UNINSTALL_FORCE_KILL)      printf '%s' '优雅停止失败，因 --force 参数改为强制结束...' ;;
        UNINSTALL_STOP_FAILED)     printf '%s' '%s 未能优雅停止' ;;
        UNINSTALL_STOP_HINT)       printf '%s' '请手动停止服务，或使用 --force 参数' ;;
        UNINSTALL_CANCELLED)       printf '%s' '用户取消了卸载' ;;
        UNINSTALL_CLEANING)        printf '%s' '正在清理组件文件...' ;;
        UNINSTALL_KEEP_DATA)       printf '%s' '保留用户数据目录：%s' ;;
        UNINSTALL_DELETE_DATA)     printf '%s' '删除用户数据目录：%s' ;;
        UNINSTALL_REMOVED_OK)      printf '%s' '组件源码与依赖已移除' ;;
        UNINSTALL_CLEAN_FAILED)    printf '%s' '部分文件清理失败，可能需要手工删除' ;;
        UNINSTALL_LOG_CLEARED)     printf '%s' '已清除组件日志文件' ;;
        UNINSTALL_CONF_CLEARED)    printf '%s' '已清除组件配置文件' ;;
        UNINSTALL_SUCCESS_COMPONENT) printf '%s' '%s 已成功卸载！' ;;
        UNINSTALL_DATA_PRESERVED)  printf '%s' '你的数据与模型已保留在：%s' ;;
        UNINSTALL_REINSTALL_HINT)  printf '%s' '之后可以安全地重新安装该组件，数据不会丢失' ;;
        UNINSTALL_DATA_DELETED)    printf '%s' '该组件的全部本地数据、模型与配置已被永久删除' ;;
        UNINSTALL_HINT_LIST)       printf '%s' '• 查看剩余组件：./ai-studio.sh list' ;;
        UNINSTALL_HINT_INSTALL_OTHER) printf '%s' '• 安装其它组件：./ai-studio.sh install <component>' ;;

        # —— 组件：update ——
        UPDATE_UNKNOWN_ARG)        printf '%s' '未知的更新参数：%s' ;;
        UPDATE_USAGE)              printf '%s' '用法：./ai-studio.sh update %s [--target <frontend|backend|architecture|models|all>]' ;;
        UPDATE_INVALID_TARGET)     printf '%s' '无效的更新目标：'\''%s'\''' ;;
        UPDATE_SUPPORTED_TARGETS)  printf '%s' '%s 支持的目标为：%s' ;;
        UPDATE_NOT_INSTALLED)      printf '%s' '%s 尚未安装' ;;
        UPDATE_FETCHING)           printf '%s' '正在从 %s 拉取最新源码...' ;;
        UPDATE_SRC_OK)             printf '%s' '源码更新成功' ;;
        UPDATE_NO_UPDATES)         printf '%s' '没有可拉取的新更新，或 git pull 失败。继续执行依赖检查...' ;;
        UPDATE_PYDEPS)             printf '%s' '正在更新 Python 依赖（后端/架构）...' ;;
        UPDATE_PYDEPS_OK)          printf '%s' 'Python 依赖更新成功' ;;
        UPDATE_PYDEPS_FAILED)      printf '%s' 'Python 依赖更新失败' ;;
        UPDATE_NO_REQUIREMENTS)    printf '%s' '未找到 requirements.txt，改为直接升级 '\''open-webui'\'' 包...' ;;
        UPDATE_PACKAGE_OK)         printf '%s' 'Open WebUI 包升级成功' ;;
        UPDATE_PACKAGE_FAILED)     printf '%s' 'open-webui 包升级失败' ;;
        UPDATE_FRONTEND_CHECK)     printf '%s' '正在检查前端更新...' ;;
        UPDATE_NODE_DEPS)          printf '%s' '正在更新 Node.js 依赖...' ;;
        UPDATE_NODE_DEPS_OK)       printf '%s' '前端依赖已更新' ;;
        UPDATE_NODE_DEPS_FAILED)   printf '%s' '前端依赖更新失败。若后端已内置前端，这可能不影响使用' ;;
        UPDATE_NO_NODE)            printf '%s' '未找到 Node.js (npm)，跳过前端依赖更新' ;;
        UPDATE_NO_FRONTEND_DIR)    printf '%s' '未发现独立的前端构建目录，前端可能随后端更新一起打包' ;;
        UPDATE_MODELS)             printf '%s' '正在处理模型更新...' ;;
        UPDATE_MODELS_NOTE)        printf '%s' '说明：Open WebUI 通过 Web 界面或 Ollama 管理模型连接' ;;
        UPDATE_MODELS_CMD)         printf '%s' '更新本地模型请执行：ollama pull <model_name>' ;;
        UPDATE_MODELS_ADMIN)       printf '%s' '或在 Open WebUI 的管理设置中管理连接' ;;
        UPDATE_STOPPING_FOR_CLEAN) printf '%s' '%s 正在运行，为干净更新先停止它...' ;;
        UPDATE_RESTARTING)         printf '%s' '正在重启 %s...' ;;
        UPDATE_ERRORS)             printf '%s' '更新完成但存在错误，请查看日志' ;;
        UPDATE_HINT_DIAGNOSE)      printf '%s' '你可能需要执行：./ai-studio.sh diagnose %s --deep --fix' ;;
        UPDATE_SUCCESS_COMPONENT)  printf '%s' '%s 已成功更新到最新版本！' ;;
        UPDATE_AUTO_RESTARTED)     printf '%s' '服务已自动重启' ;;
        UPDATE_HINT_START)         printf '%s' '启动服务请执行：./ai-studio.sh start %s' ;;

        # —— 提示 ——
        TIP_HOW_TO_USE)         printf '%s' '提示：如何使用' ;;
        TIP_RUN_COMMAND)        printf '%s' '提示：可执行' ;;
        # —— 组件：mlx（第二批：状态 / 诊断 / 更新 / 卸载）与通用标签 ——
        LBL_COMPONENT)                printf '%s' '组件' ;;
        LBL_TYPE)                     printf '%s' '类型' ;;
        LBL_VIRTUAL_ENV)              printf '%s' '虚拟环境' ;;
        LBL_VERSION)                  printf '%s' '版本' ;;
        LBL_ACTIVE_DEVICE)            printf '%s' '活动设备' ;;
        LBL_NOTE)                     printf '%s' '说明' ;;
        LBL_ACTION)                   printf '%s' '处理建议' ;;
        LBL_STATUS)                   printf '%s' '状态' ;;
        LBL_USAGE)                    printf '%s' '用法' ;;
        LBL_PID)                      printf '%s' '进程 ID' ;;
        LBL_UPTIME)                   printf '%s' '运行时长' ;;
        LBL_RESOURCES)                printf '%s' '资源占用' ;;
        LBL_PORT_STATUS)              printf '%s' '端口状态' ;;
        LBL_TARGET_PORT)              printf '%s' '目标端口' ;;
        LBL_DATA_DIR)                 printf '%s' '数据目录' ;;
        MLX_STATUS_READY)             printf '%s' 'MLX 框架已安装，硬件加速已启用。' ;;
        MLX_STATUS_WARN)              printf '%s' 'MLX 已安装，但硬件加速可能未启用。' ;;
        MLX_STATUS_CORRUPTED)         printf '%s' '虚拟环境存在，但无法导入 MLX。' ;;
        MLX_STATUS_DEVICE_OPT)        printf '%s' '%s（Apple Silicon 优化）' ;;
        STATUS_LOAD_FAILED)           printf '%s' '加载失败' ;;
        ACTION_REINSTALL)             printf '%s' '需要重新安装。' ;;
        MLX_STATUS_PERF_NOTE)         printf '%s' '性能将受限。在 Intel Mac 上属于预期表现。' ;;
        STATUS_ENV_DETAILS)           printf '%s' '环境详情' ;;
        MLX_STATUS_ACTION_GUIDE)      printf '%s' '查看用法指南：' ;;
        MLX_STATUS_ACTION_MODELS)     printf '%s' '下载模型：' ;;
        MLX_STATUS_ACTION_UPDATE)     printf '%s' '更新框架：' ;;
        MLX_STATUS_ACTION_FIX)        printf '%s' '修复安装：' ;;
        MLX_STATUS_TIP_ACTIVATE)      printf '%s' '提示：若要在自己的脚本中使用 MLX，请先激活环境：' ;;
        MLX_DIAG_NOTE)                printf '%s' '注意：MLX 是基础框架，不是后台服务。' ;;
        MLX_DIAG_VENV_DIR_MISSING)    printf '%s' '严重：虚拟环境目录缺失。' ;;
        MLX_DIAG_HINT_SETUP)          printf '%s' '-> 执行 '\''./ai-studio.sh install %s'\'' 进行安装。' ;;
        MLX_DIAG_VENV_PY_MISSING)     printf '%s' '严重：虚拟环境的 Python 可执行文件缺失或不可执行。' ;;
        MLX_DIAG_HINT_REINSTALL)      printf '%s' '-> 环境已损坏，需要重新安装。' ;;
        MLX_DIAG_IMPORT_FAIL)         printf '%s' '严重：MLX 包已安装但无法导入。' ;;
        MLX_DIAG_PYENV_BROKEN)        printf '%s' '-> Python 环境已损坏，需要重新安装。' ;;
        MLX_DIAG_VENV_OK)             printf '%s' '正常：虚拟环境健康，MLX 可以导入。' ;;
        MLX_DIAG_HW_OK)               printf '%s' '正常：硬件加速已启用（设备：%s）。' ;;
        MLX_DIAG_HW_LIMITED)          printf '%s' '警告：MLX 可运行，但硬件加速可能受限（设备：%s）。' ;;
        MLX_DIAG_HW_LIMITED_NOTE)     printf '%s' '-> 在 Intel Mac 上属于预期表现，但在 Apple Silicon 上意味着性能未达最优。' ;;
        MLX_DIAG_HW_QUERY_FAIL)       printf '%s' '严重：无法查询 MLX 设备信息。' ;;
        MLX_DIAG_HW_BROKEN)           printf '%s' '-> MLX 安装可能已根本性损坏。' ;;
        MLX_DIAG_CMAKE_MISSING)       printf '%s' '警告：未安装 '\''cmake'\''。' ;;
        MLX_DIAG_CMAKE_NOTE)          printf '%s' '-> 构建部分 MLX 扩展或从源码编译时需要它。' ;;
        MLX_DIAG_SYS_PY_MISSING)      printf '%s' '严重：系统缺少 '\''python3'\''。' ;;
        MLX_DIAG_DEPS_OK)             printf '%s' '正常：所有必需的系统构建依赖均已就绪。' ;;
        MLX_DIAG_FIX_DEPS)            printf '%s' '-> 正在尝试修复系统构建依赖...' ;;
        MLX_DIAG_FIX_DEPS_OK)         printf '%s' '系统依赖已修复。' ;;
        MLX_DIAG_FIX_DEPS_FAILED)     printf '%s' '系统依赖修复失败，请手工安装。' ;;
        MLX_DIAG_FIX_VENV_PERMS)      printf '%s' '-> 正在尝试修复虚拟环境权限...' ;;
        MLX_DIAG_FIX_VENV_PERMS_OK)   printf '%s' '虚拟环境权限已修复。' ;;
        MLX_DIAG_SKIP_VENV_BROKEN)    printf '%s' '已跳过（虚拟环境已损坏）' ;;
        MLX_DIAG_SKIP_HW)             printf '%s' '已跳过（使用 --deep 可校验硬件加速）' ;;
        MLX_DIAG_SKIP_DEPS)           printf '%s' '已跳过（使用 --deep 可检查构建工具）' ;;
        MLX_DIAG_VENV_NO_AUTOFIX)     printf '%s' '虚拟环境已损坏且无法自动修复。' ;;
        MLX_DIAG_REBUILD_HINT)        printf '%s' '请执行以下命令安全地重建它：' ;;
        MLX_DIAG_DONE_DEEP_OK)        printf '%s' '深度诊断完成，MLX 框架健康且已优化。' ;;
        MLX_DIAG_DONE_BASIC_OK)       printf '%s' '基础诊断完成，MLX 框架可访问。' ;;
        MLX_VENV_NOT_FOUND)           printf '%s' '未找到 MLX 虚拟环境。' ;;
        MLX_UPDATE_USAGE)             printf '%s' '用法：./ai-studio.sh update %s [--target <architecture|all>]' ;;
        UPDATE_HINT_INSTALL_FIRST)        printf '%s' '请先执行 '\''./ai-studio.sh install %s'\''。' ;;
        MLX_UPDATE_CORRUPTED)         printf '%s' 'MLX 已安装但无法导入，环境已损坏。' ;;
        MLX_UPDATE_HINT_REPAIR)       printf '%s' '请执行 '\''./ai-studio.sh install %s'\'' 进行修复。' ;;
        MLX_UPDATE_START)             printf '%s' '正在更新 MLX 框架及核心依赖...' ;;
        MLX_UPDATE_VERIFY_DEPS)       printf '%s' '正在校验系统构建依赖（cmake 等）...' ;;
        MLX_UPDATE_UPGRADE_TOOLS)     printf '%s' '正在升级 pip、setuptools 与 wheel...' ;;
        MLX_UPDATE_TOOLS_FAILED)      printf '%s' '核心构建工具升级失败，谨慎继续...' ;;
        MLX_UPDATE_UPGRADE_PKGS)      printf '%s' '正在升级 Python 包：%s ...' ;;
        MLX_UPDATE_PKGS_OK)           printf '%s' 'MLX 包升级成功。' ;;
        MLX_UPDATE_VERSION)           printf '%s' '当前 MLX 版本：v%s' ;;
        MLX_UPDATE_PKGS_FAILED)       printf '%s' 'MLX 包升级失败。' ;;
        MLX_UPDATE_FAIL_REASON)       printf '%s' '可能是网络问题或依赖冲突导致。' ;;
        MLX_UPDATE_HINT_MANUAL)       printf '%s' '请查看上方日志。你可能需要手动激活虚拟环境并执行 '\''pip install --upgrade mlx'\''。' ;;
        MLX_UPDATE_NOTE_RESTART_1)    printf '%s' '当前正在使用 MLX 的 Python 脚本或终端会话应重新启动，' ;;
        MLX_UPDATE_NOTE_RESTART_2)    printf '%s' '以便将更新后的库加载进内存。' ;;
        MLX_UPDATE_ACTIVATE)          printf '%s' '激活环境请执行：%s' ;;
        MLX_UNINSTALL_CONFIRM)        printf '%s' '你确定要卸载 %s 框架吗？' ;;
        MLX_UNINSTALL_WILL_DELETE)    printf '%s' '这将删除独立的 Python 虚拟环境。' ;;
        MLX_UNINSTALL_WILL_KEEP)      printf '%s' '（虚拟环境将被保留）' ;;
        MLX_UNINSTALL_PRESERVE)       printf '%s' '保留虚拟环境目录：%s' ;;
        MLX_UNINSTALL_DELETE)         printf '%s' '删除虚拟环境目录：%s' ;;
        MLX_UNINSTALL_PRESERVED_AT)   printf '%s' '你的虚拟环境已保留在：%s' ;;
        MLX_UNINSTALL_REINSTALL_HINT) printf '%s' '之后可以安全地重新安装该组件，无需重新下载所有 Python 包。' ;;
        MLX_UNINSTALL_VENV_REMOVED)   printf '%s' '独立的 Python 环境已被完全移除。' ;;
        MLX_UNINSTALL_NO_IMPACT)      printf '%s' '这不会影响你系统级的 Python 安装或其它组件。' ;;


        # —— 组件：model（模型仓库：安装 / 启动 / 状态 / 停止 / 更新 / 卸载 / 诊断）与共享标签 ——
        MODEL_REPO_SUFFIX)                printf '%s' '（MLX 模型仓库）' ;;
        LBL_MANAGEMENT)                   printf '%s' '管理' ;;
        MODEL_TBL_NAME)                   printf '%s' '模型名称' ;;
        MODEL_TBL_IDENTIFIER)             printf '%s' '模型标识' ;;
        MODEL_TBL_SIZE)                   printf '%s' '大小' ;;
        MODEL_TBL_STATUS)                 printf '%s' '状态' ;;
        MODEL_INSTALL_DISK_LOW)           printf '%s' '磁盘空间不足：%s。' ;;
        MODEL_INSTALL_DISK_DETAIL)        printf '%s' '现有：%sGB，大型 MLX 模型需要：%sGB 以上。' ;;
        MODEL_INSTALL_DISK_OK)            printf '%s' '磁盘空间检查通过（可用 %sGB，路径 %s）。' ;;
        MODEL_INSTALL_CHECKING)           printf '%s' '正在检查模型：%s' ;;
        MODEL_INSTALL_EXISTS)             printf '%s' '模型 '\''%s'\'' 已存在，跳过下载。' ;;
        MODEL_INSTALL_DOWNLOADING)        printf '%s' '正在将 %s 下载到 %s...' ;;
        MODEL_INSTALL_LARGE_FILE)         printf '%s' '这是大文件，下载中断后支持断点续传。' ;;
        MODEL_INSTALL_DL_OK)              printf '%s' '已成功下载 %s。' ;;
        MODEL_INSTALL_DL_FAIL)            printf '%s' '%s 下载失败。' ;;
        TROUBLESHOOT_LABEL)       printf '%s' '排查建议：' ;;
        MODEL_INSTALL_TS_1)               printf '%s' '1. 检查网络连接。' ;;
        MODEL_INSTALL_TS_2)               printf '%s' '2. 若为受限模型，执行：huggingface-cli login' ;;
        MODEL_INSTALL_TS_3)               printf '%s' '3. 确保你已在 Hugging Face 上接受该模型的许可协议。' ;;
        MODEL_INSTALL_SUBTITLE)           printf '%s' '集中存储 Qwen3、SD 与 FLUX 的 MLX 模型' ;;
        MODEL_INSTALL_STEP1)              printf '%s' '步骤 1/3：正在校验大文件下载所需的系统依赖...' ;;
        MODEL_INSTALL_STEP2)              printf '%s' '步骤 2/3：正在校验模型存储所需的磁盘空间...' ;;
        MODEL_INSTALL_STEP3)              printf '%s' '步骤 3/3：正在下载 MLX 优化模型...' ;;
        MODEL_INSTALL_DONE_ERRORS)        printf '%s' '模型安装完成，但有 %s 个错误。' ;;
        MODEL_INSTALL_RETRY_HINT)         printf '%s' '请检查上方错误。重新执行本脚本可继续未完成的下载。' ;;
        MODEL_INSTALL_ALL_OK)             printf '%s' '所有指定的 MLX 模型均已成功下载！' ;;
        MODEL_INSTALL_INTEGRATION)        printf '%s' '集成指南：' ;;
        MODEL_INSTALL_STORED_AT)          printf '%s' '你的模型集中存储在：%s' ;;
        MODEL_INSTALL_USAGE_INTRO)        printf '%s' '在其它组件中使用这些模型：' ;;
        MODEL_INSTALL_USAGE_COMFYUI)      printf '%s' 'ComfyUI：将此路径加入 '\''extra_model_paths.yaml'\''' ;;
        MODEL_INSTALL_USAGE_MLX)          printf '%s' 'MLX-Video / 自定义脚本：把模型路径参数指向该目录' ;;
        MODEL_INSTALL_USAGE_OLLAMA)       printf '%s' 'Ollama（LLM）：可能需要转换或链接这些模型，或直接使用 ollama pull' ;;
        MODEL_INSTALL_TIP_UPDATE)         printf '%s' '提示：之后可执行 '\''./ai-studio.sh update model --target models'\'' 检查模型权重更新。' ;;
        MODEL_START_NO_DIR)               printf '%s' '模型目录不存在：%s' ;;
        MODEL_START_EMPTY)                printf '%s' '模型目录为空，尚未下载任何模型。' ;;
        MODEL_START_LIST_TITLE)           printf '%s' '已下载的 MLX 模型：' ;;
        MODEL_START_NO_MODELS)            printf '%s' '（未发现模型。执行 '\''./ai-studio.sh install model'\'' 进行下载。）' ;;
        MODEL_START_TIP_TITLE)            printf '%s' '提示：如何使用这些模型：' ;;
        MODEL_START_STATIC_1)             printf '%s' '模型是静态资源，不需要「启动」，而是由' ;;
        MODEL_START_STATIC_2)             printf '%s' '兼容的推理引擎或 UI 组件加载。' ;;
        MODEL_START_LLM_TITLE)            printf '%s' '用于 LLM（如 Qwen3）：' ;;
        MODEL_START_LLM_DESC)             printf '%s' '运行 MLX LLM 的推荐方式是 Ollama 或专用的 MLX-LM 脚本。' ;;
        MODEL_START_LLM_STEP1)            printf '%s' '1. 确保 Ollama 在运行：%s' ;;
        MODEL_START_LLM_STEP2)            printf '%s' '2. 或使用 Python 脚本指向：%s' ;;
        MODEL_START_IMG_TITLE)            printf '%s' '用于图像生成（SD / FLUX）：' ;;
        MODEL_START_IMG_STEP1)            printf '%s' '1. 启动 ComfyUI：%s' ;;
        MODEL_START_IMG_STEP2)            printf '%s' '2. 在 ComfyUI 中确保 '\''extra_model_paths.yaml'\'' 包含：' ;;
        MODEL_START_IMG_STEP3)            printf '%s' '3. 也可以直接使用 MLX-Video / MLX 图像生成脚本。' ;;
        MODEL_START_GLOBAL_TITLE)         printf '%s' '全局模型路径：' ;;
        MODEL_START_GLOBAL_DESC)          printf '%s' '你可以手动复制该目录或将其软链接到其它应用：' ;;
        MODEL_START_NONE_INSTALLED)       printf '%s' '当前没有安装任何模型。' ;;
        MODEL_START_DOWNLOAD_HINT)        printf '%s' '如需下载 Qwen3、Stable Diffusion 或 FLUX 的 MLX 模型，请执行：' ;;
        MODEL_START_VERIFY_OK)            printf '%s' '模型仓库校验完成。' ;;
        MODEL_START_ACTION_UPDATE)        printf '%s' '• 更新模型：' ;;
        MODEL_START_ACTION_INTEGRITY)     printf '%s' '• 校验完整性：' ;;
        MODEL_START_ACTION_FREE)          printf '%s' '• 释放空间：' ;;
        MODEL_START_ACTION_FREE_NOTE)     printf '%s' '（随后手动删除指定的模型目录）' ;;
        MODEL_STATUS_INCOMPLETE_2)        printf '%s' '不完整/校验中' ;;
        MODEL_STATUS_NOT_INIT_TAG)        printf '%s' '未初始化' ;;
        MODEL_STATUS_NO_DIR)              printf '%s' '集中式模型目录尚不存在。' ;;
        MODEL_STATUS_INVENTORY)           printf '%s' '已下载的 MLX 模型清单：' ;;
        MODEL_STATUS_EMPTY)               printf '%s' '（目录为空，尚未下载任何模型。）' ;;
        MODEL_STATUS_TOTAL_USED)          printf '%s' '已用存储总计：' ;;
        MODEL_STATUS_STORAGE_CTX)         printf '%s' '存储概况：' ;;
        MODEL_STATUS_SPACE_LOW)           printf '%s' '[WARN] 模型分区可用空间：%s（偏低！大型模型可能下载失败）' ;;
        MODEL_STATUS_SPACE_OK)            printf '%s' '[OK] 模型分区可用空间：%s' ;;
        MODEL_STATUS_ACTION_DL)           printf '%s' '• 下载新模型：' ;;
        MODEL_STATUS_ACTION_UPDATE)       printf '%s' '• 更新模型权重：' ;;
        MODEL_STATUS_ACTION_VERIFY)       printf '%s' '• 校验完整性：' ;;
        MODEL_STATUS_ACTION_REMOVE)       printf '%s' '• 删除指定模型：' ;;
        MODEL_STATUS_TIP_SHARED)          printf '%s' '提示：该目录由 ComfyUI、MLX-Video 与自定义脚本共享，以节省磁盘空间。' ;;
        MODEL_STATUS_READY)               printf '%s' '就绪' ;;
        MODEL_STATUS_INCOMPLETE)          printf '%s' '不完整/已损坏' ;;
        MODEL_STATUS_PARTIAL)             printf '%s' '部分/校验中' ;;
        MODEL_STOP_STATIC)                printf '%s' ''\''%s'\'' 组件是静态资源仓库。' ;;
        MODEL_STOP_NO_SERVICE)            printf '%s' '它不作为后台服务运行，自身不占用 CPU/GPU 资源。' ;;
        MODEL_STOP_FREE_HINT)             printf '%s' '如需释放系统资源（显存/内存），应停止当前正在加载这些模型的组件：' ;;
        MODEL_STOP_RUNNING_WARN)          printf '%s' '[WARN] 以下组件正在运行，可能在内存中持有模型：' ;;
        MODEL_STOP_ALL_FREE)              printf '%s' '当前没有推理组件在运行，系统资源完全可用。' ;;
        MODEL_STOP_NO_ACTION)             printf '%s' '无需对 '\''%s'\'' 执行任何操作，组件状态保持不变。' ;;
        MODEL_UPDATE_USAGE)               printf '%s' '用法：./ai-studio.sh update %s [--target <models|architecture|all>]' ;;
        MODEL_UPDATE_NO_DIR)              printf '%s' '模型目录不存在：%s' ;;
        MODEL_UPDATE_TOOLCHAIN)           printf '%s' '正在更新模型管理工具链...' ;;
        MODEL_UPDATE_TOOLCHAIN_OK)        printf '%s' '模型管理工具链已是最新。' ;;
        MODEL_UPDATE_TOOLCHAIN_FAILED)    printf '%s' '模型管理依赖更新失败。' ;;
        MODEL_UPDATE_CHECKING_HF)         printf '%s' '正在检查 Hugging Face 上的模型权重更新...' ;;
        MODEL_UPDATE_CHECKING)            printf '%s' '正在检查：%s' ;;
        MODEL_UPDATE_UNKNOWN_SRC)         printf '%s' '-> 源仓库未知，跳过自动更新。' ;;
        MODEL_UPDATE_MANUAL_NOTE)         printf '%s' '（该模型可能是手动添加的。如需更新，请重新执行 install 或手动更新。）' ;;
        MODEL_UPDATE_SYNC_OK)             printf '%s' '-> 同步成功。（已是最新或已更新）' ;;
        MODEL_UPDATE_SYNC_FAILED)         printf '%s' '-> 同步失败。请检查网络或 Hugging Face 访问。' ;;
        MODEL_UPDATE_NO_MODELS)           printf '%s' '%s 中未发现模型，无需更新。' ;;
        MODEL_UPDATE_SYNC_SUMMARY)        printf '%s' '模型同步完成：已检查 %s 个，成功同步 %s 个。' ;;
        MODEL_UPDATE_TIP_LICENSE)         printf '%s' '提示：若模型为受限模型，请确保已在 Hugging Face 上接受许可协议。' ;;
        MODEL_UPDATE_RESTART_1)           printf '%s' '正在运行的组件（如 ComfyUI 或 Ollama）可能需要重新启动，' ;;
        MODEL_UPDATE_RESTART_2)           printf '%s' '以便将更新后的模型权重加载进内存。' ;;
        MODEL_UNINSTALL_USAGE)            printf '%s' '用法：./ai-studio.sh uninstall %s [--keep-data] [--purge-models] [--force]' ;;
        MODEL_UNINSTALL_DEFAULT_NOTE)     printf '%s' '说明：默认情况下该命令只移除管理脚本，模型文件会安全保留。' ;;
        MODEL_UNINSTALL_NOTHING)          printf '%s' '%s 的管理文件似乎不存在，无需卸载。' ;;
        MODEL_UNINSTALL_WARN_BANNER)      printf '%s' '[WARN] 严重数据销毁警告 [WARN]' ;;
        MODEL_UNINSTALL_WARN_1)           printf '%s' '你即将永久删除所有已下载的 MLX 模型。' ;;
        MODEL_UNINSTALL_WARN_2)           printf '%s' '其中包括 Qwen3 35B、FLUX、Stable Diffusion 等大型资源。' ;;
        MODEL_UNINSTALL_TARGET_DIR)       printf '%s' '目标目录：%s' ;;
        MODEL_UNINSTALL_SPACE_FREED)      printf '%s' '将释放空间：%s' ;;
        MODEL_UNINSTALL_UNDOABLE)         printf '%s' '此操作无法撤销。' ;;
        MODEL_UNINSTALL_CONFIRM_PROMPT)   printf '%s' '输入 '\''DELETE ALL MODELS'\'' 以确认永久删除：' ;;
        MODEL_UNINSTALL_CONFIRMED)        printf '%s' '已收到确认，开始删除模型...' ;;
        MODEL_UNINSTALL_CANCELLED)        printf '%s' '已取消卸载，你的模型是安全的。' ;;
        MODEL_UNINSTALL_LOG_CLEARED)      printf '%s' '已清除模型管理器日志文件。' ;;
        MODEL_UNINSTALL_CONF_CLEARED)     printf '%s' '已清除模型配置文件。' ;;
        MODEL_UNINSTALL_PRESERVED_AT)     printf '%s' '模型资源已保留在：%s' ;;
        MODEL_UNINSTALL_ONLY_LOGS)        printf '%s' '仅移除了管理日志与配置，你可以随时重新安装管理器。' ;;
        MODEL_UNINSTALL_DELETING)         printf '%s' '正在永久删除模型目录：%s' ;;
        MODEL_UNINSTALL_DELETED)          printf '%s' '模型资源已成功删除，磁盘空间已释放。' ;;
        MODEL_UNINSTALL_DELETE_FAILED)    printf '%s' '模型目录删除失败，可能需要用 sudo 手动删除。' ;;
        MODEL_UNINSTALL_DEFAULT_MODE)     printf '%s' '默认模式：保留所有已下载的模型权重。' ;;
        MODEL_UNINSTALL_DEFAULT_MODE_2)   printf '%s' '这将只移除 AI Studio 的管理日志与配置。' ;;
        MODEL_UNINSTALL_DONE)             printf '%s' '%s 管理器已成功卸载！' ;;
        MODEL_UNINSTALL_STILL_INTACT)     printf '%s' '你的模型仍然完好，位于：%s' ;;
        MODEL_UNINSTALL_STILL_ACCESSIBLE) printf '%s' '其它组件（如 ComfyUI）若已配置，仍可访问它们。' ;;
        MODEL_UNINSTALL_ALL_DELETED)      printf '%s' '所有本地模型权重已被永久删除。' ;;
        MODEL_UNINSTALL_NEED_REDOWNLOAD)  printf '%s' '你需要重新下载它们才能使用图像/LLM 生成功能。' ;;
        MODEL_DIAG_DIR_MISSING)           printf '%s' '严重：模型目录不存在。' ;;
        MODEL_DIAG_HINT_INSTALL)          printf '%s' '-> 执行 '\''./ai-studio.sh install model'\'' 创建目录并下载模型。' ;;
        MODEL_DIAG_DIR_NOT_WRITABLE)      printf '%s' '严重：模型目录存在但不可写。' ;;
        MODEL_DIAG_DIR_NOT_WRITABLE_HINT) printf '%s' '-> 模型下载与更新将失败。' ;;
        MODEL_DIAG_DIR_OK)                printf '%s' '正常：模型目录可访问且可写。' ;;
        MODEL_DIAG_MODEL_EMPTY)           printf '%s' '严重：模型 '\''%s'\'' 似乎是空的或已损坏。' ;;
        MODEL_DIAG_MODEL_EMPTY_HINT)      printf '%s' '-> 缺少 config.json 与权重文件（.safetensors/.npz）。' ;;
        MODEL_DIAG_MODEL_INCOMPLETE)      printf '%s' '警告：模型 '\''%s'\'' 不完整。' ;;
        MODEL_DIAG_MODEL_INCOMPLETE_HINT) printf '%s' '-> 缺少 config.json 或权重文件，下载可能已中断。' ;;
        MODEL_DIAG_NO_MODELS)             printf '%s' '提示：目录中未发现模型。（不是错误，但也没有可校验的内容。）' ;;
        MODEL_DIAG_ALL_OK)                printf '%s' '正常：已发现的模型结构均完整。' ;;
        MODEL_DIAG_DISK_UNKNOWN)          printf '%s' '警告：无法确定可用磁盘空间。' ;;
        MODEL_DIAG_DISK_CRITICAL)         printf '%s' '严重：模型分区剩余空间不足 20GB。' ;;
        MODEL_DIAG_DISK_CRITICAL_HINT)    printf '%s' '-> 下载大型 MLX 模型（如 FLUX、35B LLM）很可能会失败。' ;;
        MODEL_DIAG_DISK_WARN)             printf '%s' '警告：剩余空间不足 50GB。' ;;
        MODEL_DIAG_DISK_WARN_HINT)        printf '%s' '-> 继续下载其它大型模型时可能空间不足。' ;;
        MODEL_DIAG_DISK_OK)               printf '%s' '正常：磁盘空间充足（%sGB）。' ;;
        MODEL_DIAG_HF_MISSING)            printf '%s' '严重：未安装 '\''huggingface-cli'\'' 或不在 PATH 中。' ;;
        MODEL_DIAG_HF_REQUIRED)           printf '%s' '-> 下载与更新模型需要它。' ;;
        MODEL_DIAG_HF_BROKEN)             printf '%s' '警告：'\''huggingface-cli'\'' 存在但执行失败。' ;;
        MODEL_DIAG_HF_TRANSFER_MISSING)   printf '%s' '警告：缺少 '\''hf-transfer'\'' Python 包。' ;;
        MODEL_DIAG_HF_TRANSFER_HINT)      printf '%s' '-> 模型下载会明显变慢。执行 '\''./ai-studio.sh install model'\'' 可修复。' ;;
        MODEL_DIAG_TOOLCHAIN_OK)          printf '%s' '正常：模型下载工具链健康。' ;;
        MODEL_DIAG_FIX_PERMS)             printf '%s' '-> 正在尝试修复模型目录权限...' ;;
        MODEL_DIAG_FIX_PERMS_OK)          printf '%s' '模型目录权限已修复。' ;;
        MODEL_DIAG_FIX_TOOLCHAIN)         printf '%s' '-> 正在尝试修复模型下载工具链...' ;;
        MODEL_DIAG_FIX_TOOLCHAIN_OK)      printf '%s' '工具链依赖已修复。' ;;
        MODEL_DIAG_FIX_TOOLCHAIN_FAILED)  printf '%s' '工具链修复失败，请手动执行 '\''./ai-studio.sh install model'\''。' ;;
        MODEL_DIAG_NOTE_STATIC)           printf '%s' '注意：模型是静态资源，不会作为后台服务运行。' ;;
        MODEL_DIAG_RUNNING_CHECKS)        printf '%s' '正在运行模型仓库专属检查...' ;;
        MODEL_DIAG_SKIP_INTEGRITY)        printf '%s' '已跳过（使用 --deep 可校验模型文件完整性）' ;;
        MODEL_DIAG_SKIP_DISK)             printf '%s' '已跳过（使用 --deep 可检查存储容量）' ;;
        MODEL_DIAG_SKIP_TOOLCHAIN)        printf '%s' '已跳过（使用 --deep 可检查下载工具）' ;;
        MODEL_DIAG_TIP_DEEP_FIX)          printf '%s' '提示：加 '\''--deep --fix'\'' 可尝试自动修复可修复的问题（例如权限、缺失工具）。' ;;
        MODEL_DIAG_CORRUPT_MANUAL)        printf '%s' '注意：损坏的模型文件必须手动删除或重新下载。' ;;
        MODEL_DIAG_DONE_DEEP_OK)          printf '%s' '深度诊断完成，模型仓库健康可用。' ;;
        MODEL_DIAG_DONE_BASIC_OK)         printf '%s' '基础诊断完成，模型仓库可访问。' ;;


        # —— 组件描述（registry.sh 的 list 与 metadata.sh 的 install 横幅共用同一真源） ——
        DESC_OPEN_WEBUI)                  printf '%s' '功能完善的本地 LLM Web 界面' ;;
        DESC_SILLYTAVERN)                 printf '%s' '高级 LLM 角色扮演与对话前端' ;;
        DESC_CONTINUE_DEV)                printf '%s' '开源的 VS Code / JetBrains AI 编程助手' ;;
        DESC_FAZM)                        printf '%s' '原生 macOS AI 桌面智能体' ;;
        DESC_BROWSER_USE)                 printf '%s' 'AI 驱动的浏览器自动化与网页抓取工具' ;;
        DESC_MLX)                         printf '%s' 'Apple 面向 Apple Silicon 优化的机器学习框架' ;;
        DESC_COMFYUI)                     printf '%s' '强大的节点式图像生成界面（支持 SDXL/FLUX）' ;;
        DESC_MLX_VIDEO)                   printf '%s' '基于 MLX 的高效本地视频生成工具' ;;
        DESC_QWEN3)                       printf '%s' '通过 Ollama 运行的 QWen3 大模型' ;;
        DESC_MODEL)                       printf '%s' '集中式 MLX 模型仓库管理器（LLM、SD、FLUX）' ;;
        DESC_UNKNOWN)                     printf '%s' '未知组件' ;;


        # —— lib：通用工具 / 配置 / 交互 UI / 浏览器 ——
        LIB_WAIT_PORT)                    printf '%s' '正在等待端口 %s 上的服务就绪（超时：%s 秒）...' ;;
        LIB_TIMEOUT_PORT)                 printf '%s' '等待端口 %s 打开超时。' ;;
        LIB_PORT_READY)                   printf '%s' '端口 %s 上的服务已就绪。' ;;
        LIB_NEED_SUDO)                    printf '%s' '此操作需要管理员权限。' ;;
        LIB_SUDO_HINT)                    printf '%s' '请使用 sudo 运行：sudo %s' ;;
        LIB_DIR_CREATED)                  printf '%s' '已创建目录：%s' ;;
        LIB_MACOS_OPTIMIZED)              printf '%s' 'AI Studio 目前针对 macOS 优化。' ;;
        LIB_DETECTED_OS)                  printf '%s' '检测到的系统：%s' ;;
        LIB_LINUX_EXPERIMENTAL)           printf '%s' 'Linux 支持为实验性，部分功能可能不可用。' ;;
        LIB_APPLE_SILICON_DISABLED)       printf '%s' 'Apple Silicon 专属组件（MLX、MLX-Video）将被禁用。' ;;
        LIB_UNSUPPORTED_PLATFORM)         printf '%s' '不支持的平台。请使用 macOS 13+ 以获得完整功能。' ;;
        CONFIG_INVALID_KEY)               printf '%s' '错误：无效的配置键：%s' ;;
        UI_INVALID_INPUT)                 printf '%s' '输入无效，请符合要求的格式。' ;;
        UI_NO_OPTIONS)                    printf '%s' '未提供任何选项给 select_from_list。' ;;
        UI_CANCEL_OPTION)                 printf '%s' '0) 取消' ;;
        UI_CHOICE_PROMPT)                 printf '%s' '请输入选择（0-%s）：' ;;
        UI_INVALID_SELECTION)             printf '%s' '选择无效，请输入 0 到 %s 之间的数字。' ;;
        UI_NO_TABLE_DATA)                 printf '%s' '未提供表格数据。' ;;
        BROWSER_AUTO_DISABLED)            printf '%s' '配置中已禁用自动打开浏览器，跳过打开：%s' ;;
        BROWSER_INVALID_URL)              printf '%s' '传给 open_browser 的 URL 无效：%s' ;;
        BROWSER_OPENING)                  printf '%s' '正在用浏览器打开：%s' ;;
        BROWSER_OPENED)                   printf '%s' '浏览器已成功打开。' ;;
        BROWSER_OPEN_FAILED)              printf '%s' '通过命令行自动打开浏览器失败。' ;;
        BROWSER_MANUAL_HINT)              printf '%s' '请手动打开浏览器并访问：%s' ;;
        BROWSER_WAITING_PORT)             printf '%s' '正在等待端口 %s 上的服务就绪后再打开浏览器...' ;;
        BROWSER_PORT_NOT_READY)           printf '%s' '端口 %s 上的服务在 %s 秒内未就绪。' ;;
        BROWSER_MAYBE_STARTING)           printf '%s' '服务可能仍在后台启动，也可能已启动失败。' ;;
        BROWSER_TRY_MANUAL)               printf '%s' '你可以手动尝试访问：%s' ;;
        BROWSER_CHECK_LOGS)               printf '%s' '或查看日志：%s（注意：应查看组件状态）' ;;
        BROWSER_FORCE_INVALID_URL)        printf '%s' '传给 force_open_browser 的 URL 无效：%s' ;;
        BROWSER_FORCE_OPENING)            printf '%s' '正在强制用浏览器打开：%s' ;;
        BROWSER_FORCE_FAILED)             printf '%s' '打开浏览器失败，请手动访问：%s' ;;


        # —— lib：诊断 / 进程管理 / 环境检查 / 环境安装 ——
        LIBDIAG_FILES_MISSING)        printf '%s' '严重：组件目录缺失。' ;;
        LIBDIAG_SCRIPTS_MISSING)      printf '%s' '警告：安装脚本缺失或不可执行。' ;;
        LIBDIAG_FILES_OK)             printf '%s' '正常：组件文件齐全。' ;;
        LIBDIAG_PROC_ORPHAN)          printf '%s' '警告：进程在运行但看起来是孤儿/僵尸进程。' ;;
        LIBDIAG_PROC_OK)              printf '%s' '正常：进程正在运行。' ;;
        LIBDIAG_PROC_PORT)            printf '%s' '警告：进程在运行，但端口 %s 未处于监听状态。' ;;
        LIBDIAG_STOPPED_PORT_BUSY)    printf '%s' '警告：组件已停止，但端口 %s 被其它进程占用。' ;;
        LIBDIAG_STOPPED)              printf '%s' '提示：组件当前已停止。' ;;
        LIBDIAG_NO_LOG)               printf '%s' '提示：尚未发现日志文件。' ;;
        LIBDIAG_LOG_ERRORS)           printf '%s' '警告：近期日志中可能存在错误：' ;;
        LIBDIAG_LOG_OK)               printf '%s' '正常：近期日志中没有严重错误。' ;;
        LIBDIAG_DISK_LOW)             printf '%s' '严重：磁盘剩余空间不足 20GB，模型下载/操作可能失败。' ;;
        LIBDIAG_SWAP_HIGH)            printf '%s' '警告：检测到 swap 使用率过高，系统可能在频繁换页。' ;;
        LIBDIAG_RESOURCES_OK)         printf '%s' '正常：系统资源充足。' ;;
        LIBDIAG_DEP_MISSING)          printf '%s' '严重：缺少必需依赖：%s' ;;
        LIBDIAG_DEP_OK)               printf '%s' '正常：声明的依赖均已满足。' ;;
        LIBDIAG_SIMPLE_RUNNING)       printf '%s' '正在对 %s 执行简单诊断...' ;;
        LIBDIAG_DEEP_RUNNING)         printf '%s' '正在对 %s 执行深度诊断...' ;;
        LIBDIAG_CONFIG_OK)            printf '%s' '正常：配置文件语法看起来有效。' ;;
        LIBDIAG_CONFIG_WARN)          printf '%s' '警告：配置文件可能格式有误。' ;;
        LIBDIAG_AUTOFIX)              printf '%s' '正在尝试对 %s 自动修复...' ;;
        LIBDIAG_FIX_PID)              printf '%s' '-> 正在清理 %s 的陈旧 PID 文件...' ;;
        LIBDIAG_FIX_PERMS2)           printf '%s' '-> 正在恢复组件脚本的可执行权限...' ;;
        LIBDIAG_FIX_PORT)             printf '%s' '-> 端口 %s 被占用，正在尝试释放...' ;;
        LIBDIAG_FIX_APPLIED)          printf '%s' '已应用 %s 项自动修复。请再次运行诊断以确认。' ;;
        LIBDIAG_FIX_NONE)             printf '%s' '没有适用或必要的自动修复。' ;;
        LIBDIAG_UNKNOWN_FLAG)         printf '%s' '未知的诊断参数：%s' ;;
        LIBDIAG_ISSUES)               printf '%s' '诊断完成，发现 %s 个问题。' ;;
        LIBDIAG_TIP_DEEP_FIX)         printf '%s' '提示：加 '\''--deep --fix'\'' 可尝试自动修复。' ;;
        LIBDIAG_HEALTHY)              printf '%s' '诊断完成，未发现问题。%s 状态健康。' ;;
        PROC_PID_SAVED)               printf '%s' '已保存 %s 的 PID：%s' ;;
        PROC_PID_CLEARED)             printf '%s' '已清除 %s 的 PID 文件' ;;
        PROC_ALREADY_RUNNING)         printf '%s' '%s 已在运行（PID：%s），跳过启动。' ;;
        PROC_STARTING)                printf '%s' '正在后台启动 %s...' ;;
        PROC_COMMAND)                 printf '%s' '命令：%s' ;;
        PROC_START_OK)                printf '%s' '%s 启动成功（PID：%s）。' ;;
        PROC_LOGS)                    printf '%s' '日志：%s' ;;
        PROC_START_FAIL)              printf '%s' '%s 启动失败，PID %s 立即退出。' ;;
        PROC_CHECK_LOGS)              printf '%s' '查看日志了解详情：%s' ;;
        PROC_NOT_RUNNING)             printf '%s' '%s 未在运行。' ;;
        PROC_STOPPING)                printf '%s' '正在优雅停止 %s（PID：%s）...' ;;
        PROC_SIGTERM_TIMEOUT)         printf '%s' '%s 在 %s 秒内未响应 SIGTERM，正在强制结束...' ;;
        PROC_STOP_OK)                 printf '%s' '%s 已成功停止。' ;;
        PROC_STALE_CLEANED)           printf '%s' '已清理 %s 的陈旧 PID' ;;
        PROC_STALE_FILES)             printf '%s' '已清理 %s 个陈旧 PID 文件。' ;;
        PROC_PORT_FREE)               printf '%s' '端口 %s 未被占用。' ;;
        PROC_PORT_FORCE_KILL)         printf '%s' '正在强制结束端口 %s 上的进程...' ;;
        PROC_PORT_KILLED)             printf '%s' '端口 %s 上的进程已终止。' ;;
        PROC_PORT_FREE_FAILED)        printf '%s' '释放端口 %s 失败，需要手工处理。' ;;
        PROC_PORT_NO_PID)             printf '%s' '无法确定端口 %s 对应的 PID。' ;;
        ENVCHECK_MACOS_START)         printf '%s' '正在检查 macOS 版本...' ;;
        ENVCHECK_UNSUPPORTED_OS)      printf '%s' '不支持的操作系统，AI Studio 需要 macOS。' ;;
        ENVCHECK_MACOS_OLD)           printf '%s' 'macOS 版本过旧。当前：%s，需要：%s.0 或更高。' ;;
        ENVCHECK_MACOS_OK)            printf '%s' 'macOS 版本检查通过（%s）。' ;;
        ENVCHECK_HW_START)            printf '%s' '正在检查硬件架构...' ;;
        ENVCHECK_HW_APPLE)            printf '%s' '硬件检查通过：检测到 Apple Silicon（%s）。（对 MLX/ComfyUI 最优）' ;;
        ENVCHECK_HW_INTEL)            printf '%s' '硬件检查通过：检测到 Intel（%s）。注意：MLX 与 MLX-Video 组件需要 Apple Silicon，将被禁用或受限运行。' ;;
        ENVCHECK_HW_UNKNOWN)          printf '%s' '未知的硬件架构：%s' ;;
        ENVCHECK_DISK_START)          printf '%s' '正在检查可用磁盘空间...' ;;
        ENVCHECK_DISK_LOW)            printf '%s' '磁盘空间不足。当前：%sGB，需要：%sGB 以上。' ;;
        ENVCHECK_DISK_HINT)           printf '%s' '请先释放磁盘空间再继续。' ;;
        ENVCHECK_DISK_OK)             printf '%s' '磁盘空间检查通过（可用 %sGB）。' ;;
        ENVCHECK_MEM_START)           printf '%s' '正在检查系统内存...' ;;
        ENVCHECK_MEM_UNKNOWN)         printf '%s' '无法确定系统内存，跳过检查。' ;;
        ENVCHECK_MEM_LOW)             printf '%s' '系统内存低于推荐下限。当前：%sGB，推荐：%sGB 以上。' ;;
        ENVCHECK_MEM_HINT)            printf '%s' '部分大型模型（如 FLUX、大语言模型）可能加载失败或运行缓慢。' ;;
        ENVCHECK_MEM_OK)              printf '%s' '系统内存检查通过（%sGB）。' ;;
        ENVCHECK_TOOLS_START)         printf '%s' '正在检查必需的命令行工具...' ;;
        ENVCHECK_MISSING_REQUIRED)    printf '%s' '缺少必需工具：%s' ;;
        ENVCHECK_INSTALL_HINT)        printf '%s' '执行 '\''./ai-studio.sh env install'\'' 可自动安装缺失依赖。' ;;
        ENVCHECK_MISSING_RECOMMENDED) printf '%s' '缺少推荐工具：%s' ;;
        ENVCHECK_INSTALL_REC_HINT)    printf '%s' '强烈建议执行 '\''./ai-studio.sh env install'\'' 安装它们以获得完整功能。' ;;
        ENVCHECK_TOOLS_OK)            printf '%s' '所有必需与推荐工具均已就绪。' ;;
        ENVCHECK_START)               printf '%s' '开始 AI Studio 环境检查...' ;;
        ENVCHECK_PASSED)              printf '%s' '环境检查通过。你的系统已可部署。' ;;
        ENVCHECK_FAILED)              printf '%s' '环境检查失败，存在 %s 个严重问题。' ;;
        ENVCHECK_FAILED_HINT)         printf '%s' '请解决上述问题，或执行 '\''./ai-studio.sh env install'\'' 尝试自动修复。' ;;
        ENVCHECK_STATUS_TITLE)        printf '%s' '=== AI Studio 环境状态 ===' ;;
        ENVCHECK_CORE_TOOLS)          printf '%s' '核心工具状态：' ;;
        ENVINSTALL_HOMEBREW_EXISTS)   printf '%s' 'Homebrew 已安装，跳过。' ;;
        ENVINSTALL_HOMEBREW_INSTALLING)printf '%s' '正在安装 Homebrew（可能会提示输入密码）...' ;;
        ENVINSTALL_HOMEBREW_FAILED)   printf '%s' 'Homebrew 安装失败。' ;;
        ENVINSTALL_HOMEBREW_OK)       printf '%s' 'Homebrew 已成功安装并配置。' ;;
        ENVINSTALL_BASIC_CHECK)       printf '%s' '正在检查基础命令行工具...' ;;
        ENVINSTALL_BASIC_OK_EXISTS)   printf '%s' '所有基础工具均已安装。' ;;
        ENVINSTALL_BASIC_INSTALLING)  printf '%s' '正在安装缺失的工具：%s ...' ;;
        ENVINSTALL_BASIC_FAILED)      printf '%s' '通过 Homebrew 安装基础工具失败。' ;;
        ENVINSTALL_BASIC_OK)          printf '%s' '基础工具安装成功。' ;;
        ENVINSTALL_RUNTIME_CHECK)     printf '%s' '正在检查运行时环境（Python、Node.js）...' ;;
        ENVINSTALL_PYTHON_INSTALLING) printf '%s' '正在安装 Python 3...' ;;
        ENVINSTALL_PYTHON_FAILED)     printf '%s' 'Python 3 安装失败。' ;;
        ENVINSTALL_PYTHON_EXISTS)     printf '%s' 'Python 3 已安装。' ;;
        ENVINSTALL_NODE_INSTALLING)   printf '%s' '正在安装 Node.js（LTS）...' ;;
        ENVINSTALL_NODE_FAILED)       printf '%s' 'Node.js 安装失败。' ;;
        ENVINSTALL_NODE_EXISTS)       printf '%s' 'Node.js 已安装。' ;;
        ENVINSTALL_RUNTIME_OK)        printf '%s' '运行时环境已就绪。' ;;
        ENVINSTALL_AI_CHECK)          printf '%s' '正在检查 AI 核心工具...' ;;
        ENVINSTALL_OLLAMA_INSTALLING) printf '%s' '正在安装 Ollama（本地 LLM 运行所需）...' ;;
        ENVINSTALL_OLLAMA_FAILED)     printf '%s' 'Ollama 安装失败。' ;;
        ENVINSTALL_OLLAMA_OK)         printf '%s' 'Ollama 安装成功。' ;;
        ENVINSTALL_OLLAMA_EXISTS)     printf '%s' 'Ollama 已安装。' ;;
        ENVINSTALL_START)             printf '%s' '开始 AI Studio 环境安装...' ;;
        ENVINSTALL_NEED_PASSWORD)     printf '%s' '该过程可能需要你的管理员密码。' ;;
        ENVINSTALL_DONE)              printf '%s' '环境安装成功完成！' ;;
        ENVINSTALL_READY)             printf '%s' '你的系统现已完全就绪，可以使用 AI Studio。' ;;
        ENVINSTALL_FAILED_N)          printf '%s' '环境安装过程中出现 %s 个错误。' ;;
        ENVINSTALL_DEPS_CHECK)        printf '%s' '正在检查 %s 的依赖...' ;;
        ENVINSTALL_DEPS_OK_EXISTS)    printf '%s' '%s 的依赖均已安装。' ;;
        ENVINSTALL_DEPS_INSTALLING)   printf '%s' '正在为 %s 安装缺失的依赖：%s ...' ;;
        ENVINSTALL_DEPS_FAILED)       printf '%s' '%s 的依赖安装失败。' ;;
        ENVINSTALL_DEPS_OK)           printf '%s' '%s 的依赖安装成功。' ;;


        # —— lib/env-check.sh：env status 的表格标签 ——
        ENVCHECK_LBL_OS)              printf '%s' '操作系统' ;;
        ENVCHECK_LBL_ARCH)            printf '%s' '架构' ;;
        ENVCHECK_LBL_MEM)             printf '%s' '内存总量' ;;
        ENVCHECK_LBL_DISK)            printf '%s' '可用磁盘' ;;
        ENVCHECK_INSTALLED)           printf '%s' '已安装' ;;
        ENVCHECK_MISSING)             printf '%s' '缺失' ;;


        # —— env/：Homebrew / Git LFS / 系统检查 ——
        ENVB_CHECKING)                printf '%s' '正在检查 Homebrew 安装状态...' ;;
        ENVB_ALREADY)                 printf '%s' 'Homebrew 已安装且可用。' ;;
        ENVB_UPDATING)                printf '%s' '正在执行一次快速 '\''brew update'\'' 以确保状态健康...' ;;
        ENVB_NOT_FOUND)               printf '%s' '未安装 Homebrew，或它不在系统 PATH 中。' ;;
        ENVB_INSTALLING)              printf '%s' '开始自动安装 Homebrew...' ;;
        ENVB_PASSWORD_NOTE)           printf '%s' '（注意：可能会提示输入 macOS 管理员密码）' ;;
        ENVB_CURL_MISSING)            printf '%s' '下载 Homebrew 安装脚本需要 '\''curl'\''，但未找到。' ;;
        ENVB_CURL_HINT)               printf '%s' '请手动安装 curl，或确保系统具备基础命令行工具。' ;;
        ENVB_INSTALL_FAILED)          printf '%s' 'Homebrew 安装失败，退出码 %s。' ;;
        ENVB_INSTALL_HINT)            printf '%s' '请检查网络连接，或从 https://brew.sh 手动安装。' ;;
        ENVB_INSTALL_OK)              printf '%s' 'Homebrew 安装成功！' ;;
        ENVB_APPLE_PATH)              printf '%s' '检测到 Apple Silicon。Homebrew 安装位置：%s' ;;
        ENVB_INTEL_PATH)              printf '%s' '检测到 Intel Mac。Homebrew 安装位置：%s' ;;
        ENVB_PROFILE_ADDING)          printf '%s' '正在把 Homebrew 写入你的 shell 配置文件（%s）...' ;;
        ENVB_PROFILE_OK)              printf '%s' '已为当前会话与后续登录配置好 Homebrew 的 PATH。' ;;
        ENVB_PROFILE_EXISTS)          printf '%s' '你的 shell 配置文件中已存在 Homebrew 的 PATH。' ;;
        ENVB_VERIFY)                  printf '%s' '校验：' ;;
        ENVB_BANNER)                  printf '%s' 'AI Studio - Homebrew 安装器' ;;
        ENVB_DONE)                    printf '%s' 'Homebrew 设置成功完成。' ;;
        ENVB_NEXT_INTRO)              printf '%s' '现在可以继续安装其它依赖：' ;;
        ENVB_FAILED)                  printf '%s' 'Homebrew 设置过程中出现错误。' ;;
        ENVL_VERSION_OK)              printf '%s' 'Git LFS v%s 已安装。' ;;
        ENVL_INSTALLING)              printf '%s' '正在通过 Homebrew 安装 Git LFS...' ;;
        ENVL_NEED_HOMEBREW)           printf '%s' '安装 Git LFS 需要 Homebrew，但未找到。' ;;
        ENVL_HOMEBREW_HINT)           printf '%s' '请先执行 '\''./env/install-homebrew.sh'\''。' ;;
        ENVL_GIT_MISSING)             printf '%s' '未检测到 Git，将连同 Git LFS 一起安装...' ;;
        ENVL_GIT_FAILED)              printf '%s' 'Git 安装失败。Git LFS 依赖 Git，无法使用。' ;;
        ENVL_RUNNING_CMD)             printf '%s' '正在执行：brew install git-lfs' ;;
        ENVL_INSTALL_FAILED)          printf '%s' '通过 Homebrew 安装 Git LFS 失败。' ;;
        ENVL_INSTALL_OK)              printf '%s' 'Git LFS 安装成功。' ;;
        ENVL_CONFIGURING)             printf '%s' '正在全局配置 Git LFS...' ;;
        ENVL_CONFIG_OK)               printf '%s' 'Git LFS 全局钩子与过滤器已配置。' ;;
        ENVL_CONFIG_DONE)             printf '%s' 'Git LFS 配置完成（可能此前已配置）。' ;;
        ENVL_VERIFYING)               printf '%s' '正在校验 Git LFS 功能...' ;;
        ENVL_VERIFY_OK)               printf '%s' 'Git LFS 功能完好，可用于大文件跟踪。' ;;
        ENVL_VERIFY_FAILED)           printf '%s' 'Git LFS 可执行文件校验失败。' ;;
        ENVL_BANNER)                  printf '%s' 'AI Studio - Git LFS 安装器' ;;
        ENVL_SUBTITLE)                printf '%s' '正在为 AI 模型与数据集配置大文件支持...' ;;
        ENVL_HEALTHY)                 printf '%s' 'Git LFS 已安装且状态健康。' ;;
        ENVL_DONE)                    printf '%s' 'Git LFS 设置成功完成。' ;;
        ENVL_NEXT_1)                  printf '%s' 'Git LFS 现已为你的用户账户全局配置。' ;;
        ENVL_NEXT_2)                  printf '%s' '克隆包含 AI 模型的仓库时，LFS 文件会自动下载。' ;;
        ENVL_MANUAL_TITLE)            printf '%s' '手动执行 LFS 操作（如需要）：' ;;
        ENVL_MANUAL_PULL)             printf '%s' '手动拉取大文件：git lfs pull' ;;
        ENVL_MANUAL_TRACK)            printf '%s' '跟踪新的文件类型：git lfs track '\''*.safetensors'\''' ;;
        ENVL_MANUAL_LIST)             printf '%s' '列出已跟踪的模式：git lfs track' ;;
        ENVL_FAILED)                  printf '%s' 'Git LFS 设置过程中出现错误。' ;;
        ENVL_TS_1)                    printf '%s' '1. 确保 Homebrew 已安装且为最新：brew doctor' ;;
        ENVL_TS_2)                    printf '%s' '2. 校验 Git 安装：git --version' ;;
        ENVL_TS_3)                    printf '%s' '3. 访问 https://git-lfs.com 查看手动安装说明。' ;;
        ENVC_BANNER)                  printf '%s' 'AI Studio - 系统环境检查' ;;
        ENVC_SUBTITLE)                printf '%s' '正在校验 macOS 兼容性与依赖项...' ;;
        ENVC_PASSED)                  printf '%s' '系统检查通过。你的环境已可部署。' ;;
        ENVC_NEXT_1)                  printf '%s' '1. 安装缺失的依赖（若上面有被标记为推荐的项）：' ;;
        ENVC_NEXT_2)                  printf '%s' '2. 安装你的第一个 AI 组件：' ;;
        ENVC_FAILED)                  printf '%s' '系统检查失败。请先解决上述问题再继续。' ;;
        ENVC_RECOMMENDED_ACTION)      printf '%s' '建议操作：' ;;
        ENVC_RECOMMENDED_DESC)        printf '%s' '运行自动化环境安装器以修复缺失的依赖：' ;;


        # —— env/：Python / Node.js / Ollama / Xcode CLI ——
        ENVP_VERSION_OK)              printf '%s' 'Python %s 已安装且满足最低要求（>= %s.%s）。' ;;
        ENVP_VERSION_LOW)             printf '%s' '发现 Python %s，但要求版本 >= %s.%s。' ;;
        ENVP_INSTALLING)              printf '%s' '正在通过 Homebrew 安装 Python %s...' ;;
        ENVP_NEED_HOMEBREW)           printf '%s' '安装 Python 需要 Homebrew，但未找到。' ;;
        ENVP_HOMEBREW_HINT)           printf '%s' '请先执行 '\''./env/install-homebrew.sh'\''。' ;;
        ENVP_RUNNING_CMD)             printf '%s' '正在执行：brew install python@%s' ;;
        ENVP_INSTALL_FAILED)          printf '%s' '通过 Homebrew 安装 Python %s 失败。' ;;
        ENVP_INSTALL_OK)              printf '%s' 'Python %s 安装成功。' ;;
        ENVP_PREFIX_UNKNOWN)          printf '%s' '无法确定 Homebrew 的 Python 前缀，你可能需要手动配置 PATH。' ;;
        ENVP_PATH_EXISTS)             printf '%s' '已在 %s 中配置过 Python PATH。' ;;
        ENVP_PATH_ADDING)             printf '%s' '正在把 Python %s 写入你的 shell 配置文件（%s）...' ;;
        ENVP_PATH_OK)                 printf '%s' '已为当前会话配置并启用 Python 环境。' ;;
        ENVP_PATH_OLD)                printf '%s' 'Python PATH 已更新，但版本检查仍显示旧版本，可能需要重启终端。' ;;
        ENVP_TOOLCHAIN)               printf '%s' '正在确保 Python 打包工具链为最新...' ;;
        ENVP_TOOLCHAIN_FAILED)        printf '%s' 'pip/setuptools/wheel 升级失败。部分组件安装可能需要手工处理。' ;;
        ENVP_TOOLCHAIN_OK)            printf '%s' 'Python 打包工具链（pip、setuptools、wheel）已就绪。' ;;
        ENVP_VENV_MISSING)            printf '%s' 'Python 缺少 '\''venv'\'' 模块，而组件隔离环境需要它。' ;;
        ENVP_VENV_OK)                 printf '%s' 'Python 虚拟环境（venv）支持已校验。' ;;
        ENVP_BANNER)                  printf '%s' 'AI Studio - Python 环境安装器' ;;
        ENVP_HEALTHY)                 printf '%s' 'Python 环境已健康。' ;;
        ENVP_DONE)                    printf '%s' 'Python 设置成功完成。' ;;
        ENVP_NEXT_INTRO)              printf '%s' '现在可以继续安装其它核心依赖：' ;;
        ENVP_FAILED)                  printf '%s' 'Python 设置过程中出现错误。' ;;
        ENVP_TS_1)                    printf '%s' '1. 确保网络连接稳定。' ;;
        ENVP_TS_2)                    printf '%s' '2. 检查是否已安装 Xcode Command Line Tools：xcode-select --install' ;;
        ENVN_VERSION_OK)              printf '%s' 'Node.js v%s 已安装且满足最低要求（>= v%s）。' ;;
        ENVN_VERSION_LOW)             printf '%s' '发现 Node.js v%s，但要求版本 >= v%s。' ;;
        ENVN_INSTALLING)              printf '%s' '正在通过 Homebrew 安装 Node.js（LTS）...' ;;
        ENVN_NEED_HOMEBREW)           printf '%s' '安装 Node.js 需要 Homebrew，但未找到。' ;;
        ENVN_RUNNING_CMD)             printf '%s' '正在执行：brew install %s' ;;
        ENVN_INSTALL_FAILED)          printf '%s' '通过 Homebrew 安装 Node.js 失败。' ;;
        ENVN_INSTALL_OK)              printf '%s' 'Node.js 安装成功。' ;;
        ENVN_TOOLCHAIN)               printf '%s' '正在确保 Node.js 打包工具链就绪...' ;;
        ENVN_NPM_UPDATING)            printf '%s' '正在更新 npm...' ;;
        ENVN_NPM_FAILED)              printf '%s' '全局更新 npm 失败。你可能需要加 sudo 运行或修复 npm 权限。' ;;
        ENVN_NPM_OK)                  printf '%s' 'npm 已更新到最新版本。' ;;
        ENVN_TOOLS_MISSING)           printf '%s' '安装完成后仍缺少核心 Node.js 工具：%s' ;;
        ENVN_TOOLS_HINT)              printf '%s' '你可能需要重启终端或手动配置 PATH。' ;;
        ENVN_TOOLS_OK)                printf '%s' 'Node.js 工具链（node、npm、npx）已校验并就绪。' ;;
        ENVN_NPM_CONFIG)              printf '%s' '正在配置 npm，使其无需 sudo 即可安装全局包...' ;;
        ENVN_NPM_PATH_ADDING)         printf '%s' '正在把 npm 全局 bin 写入你的 shell 配置文件（%s）...' ;;
        ENVN_NPM_PATH_OK)             printf '%s' '已在用户目录安全地配置好 npm 全局安装。' ;;
        ENVN_BANNER)                  printf '%s' 'AI Studio - Node.js 环境安装器' ;;
        ENVN_HEALTHY)                 printf '%s' 'Node.js 环境已健康。' ;;
        ENVN_DONE)                    printf '%s' 'Node.js 设置成功完成。' ;;
        ENVN_NEXT_1)                  printf '%s' '你的系统现已可部署基于 Web 的 AI 组件。' ;;
        ENVN_FAILED)                  printf '%s' 'Node.js 设置过程中出现错误。' ;;
        ENVN_TS_1)                    printf '%s' '1. 检查 Homebrew 状态：brew doctor' ;;
        ENVN_TS_2)                    printf '%s' '2. 确保网络连接稳定。' ;;
        ENVO_VERSION_OK)              printf '%s' 'Ollama v%s 已安装。' ;;
        ENVO_NOT_RESPONDING)          printf '%s' 'Ollama 命令存在，但响应不正确。' ;;
        ENVO_INSTALLING)              printf '%s' '开始安装 Ollama...' ;;
        ENVO_PASSWORD_NOTE)           printf '%s' '（注意：这将下载官方安装程序，可能会提示输入密码）' ;;
        ENVO_CURL_MISSING)            printf '%s' '下载 Ollama 安装程序需要 '\''curl'\''，但未找到。' ;;
        ENVO_DOWNLOADING)             printf '%s' '正在下载并执行官方 Ollama 安装程序...' ;;
        ENVO_INSTALL_FAILED)          printf '%s' 'Ollama 安装失败。' ;;
        ENVO_INSTALL_HINT)            printf '%s' '请检查网络连接，或从 https://ollama.com 手动安装。' ;;
        ENVO_INSTALL_OK)              printf '%s' 'Ollama 安装成功！' ;;
        ENVO_SERVICE_CHECK)           printf '%s' '正在校验 Ollama 后台服务状态...' ;;
        ENVO_SERVICE_OK)              printf '%s' 'Ollama 服务正在后台运行。' ;;
        ENVO_SERVICE_DOWN)            printf '%s' 'Ollama 服务未运行，正在尝试启动...' ;;
        ENVO_SERVICE_STARTED)         printf '%s' 'Ollama 服务启动成功。' ;;
        ENVO_SERVICE_FAILED)          printf '%s' '自动启动 Ollama 服务失败。' ;;
        ENVO_SERVICE_HINT)            printf '%s' '你可能需要重新登录，或通过 Spotlight 手动启动。' ;;
        ENVO_FUNC_CHECK)              printf '%s' '正在执行快速功能检查...' ;;
        ENVO_API_OK)                  printf '%s' 'Ollama API 正在端口 11434 监听。' ;;
        ENVO_API_DOWN)                printf '%s' 'Ollama 端口 11434 未监听，服务可能仍在启动中。' ;;
        ENVO_CLI_OK)                  printf '%s' 'Ollama CLI 功能完好。' ;;
        ENVO_CLI_FAILED)              printf '%s' 'Ollama CLI 执行 '\''ollama list'\'' 失败。' ;;
        ENVO_BANNER)                  printf '%s' 'AI Studio - Ollama 安装器' ;;
        ENVO_SUBTITLE)                printf '%s' '正在配置本地 LLM 执行引擎...' ;;
        ENVO_HEALTHY)                 printf '%s' 'Ollama 已安装且状态健康。' ;;
        ENVO_DONE)                    printf '%s' 'Ollama 设置成功完成。' ;;
        ENVO_NEXT_1)                  printf '%s' '1. 拉取你的第一个模型（例如 QWen3 或 Llama 3）：' ;;
        ENVO_NEXT_2)                  printf '%s' '2. 部署一个用于交互的界面：' ;;
        ENVO_TIP_APPLE)               printf '%s' '提示：Ollama 针对 Apple Silicon（M1/M2/M3/M4）做了原生优化' ;;
        ENVO_FAILED)                  printf '%s' 'Ollama 设置过程中出现错误。' ;;
        ENVO_TS_2)                    printf '%s' '2. 通过「活动监视器」或 Spotlight 检查 Ollama 是否在运行。' ;;
        ENVO_TS_3)                    printf '%s' '3. 访问 https://ollama.com 查看手动安装说明。' ;;
        ENVX_VERSION_OK)              printf '%s' 'Xcode Command Line Tools 已安装（Clang %s）。' ;;
        ENVX_BROKEN)                  printf '%s' 'Xcode CLI 路径存在，但核心工具（clang/make）缺失或损坏。' ;;
        ENVX_NOT_INSTALLED)           printf '%s' '尚未安装 Xcode Command Line Tools。' ;;
        ENVX_TRIGGERING)              printf '%s' '正在触发 macOS 系统的 Command Line Tools 安装程序...' ;;
        ENVX_DIALOG_NOTE)             printf '%s' '稍后会弹出系统对话框，请点击「安装」并接受许可协议。' ;;
        ENVX_PROMPT_ENTER)            printf '%s' '-> 当安装窗口显示「软件已安装」后，按 [Enter] 继续...' ;;
        ENVX_VERIFYING)               printf '%s' '正在校验安装结果...' ;;
        ENVX_RESETTING)               printf '%s' '正在尝试重置已损坏的 Command Line Tools 安装...' ;;
        ENVX_RESET_PRIVILEGE)         printf '%s' '该操作需要管理员权限，可能会提示输入密码。' ;;
        ENVX_OLD_REMOVED)             printf '%s' '已移除旧的 Command Line Tools 目录。' ;;
        ENVX_RERUN)                   printf '%s' '请再次运行本脚本以触发全新安装。' ;;
        ENVX_REMOVE_FAILED)           printf '%s' '移除旧的 Command Line Tools 失败，请通过 Finder 或终端手动删除。' ;;
        ENVX_BANNER)                  printf '%s' 'AI Studio - Xcode CLI 安装器' ;;
        ENVX_SUBTITLE)                printf '%s' '正在为 AI 依赖配置 macOS 编译工具...' ;;
        ENVX_HEALTHY)                 printf '%s' 'Xcode Command Line Tools 已安装且状态健康。' ;;
        ENVX_CORRUPT_AT)              printf '%s' '在 %s 检测到可能已损坏的安装' ;;
        ENVX_ABORT)                   printf '%s' '已中止。请手动修复 %s 处的安装。' ;;
        ENVX_DONE)                    printf '%s' 'Xcode Command Line Tools 设置成功完成！' ;;
        ENVX_NEXT_1)                  printf '%s' '你的 Mac 现已可以编译 AI 软件包。' ;;
        ENVX_NEXT_2)                  printf '%s' '继续安装 Homebrew 及其它依赖：' ;;
        ENVX_FAILED)                  printf '%s' '校验失败。安装可能已被取消或失败。' ;;
        ENVX_TS_1)                    printf '%s' '1. 若未弹出安装窗口，请检查「系统设置 > 软件更新」。' ;;
        ENVX_TS_2)                    printf '%s' '2. 若提示「无法安装软件」，尝试：sudo rm -rf /Library/Developer/CommandLineTools' ;;
        ENVX_TS_3)                    printf '%s' '3. 然后再次运行本脚本：./env/install-xcode-cli.sh' ;;


        # —— tests/：测试输出文案 ——
        TEST_PASS)                    printf '%s' 'PASS：%s' ;;
        TEST_FAIL)                    printf '%s' 'FAIL：%s' ;;
        TEST_EXPECTED)                printf '%s' '期望：%s' ;;
        TEST_ACTUAL)                  printf '%s' '实际：%s' ;;
        TEST_CMD_EXISTS)              printf '%s' '命令 '\''%s'\'' 存在' ;;
        TEST_CMD_NOT_FOUND)           printf '%s' '未找到命令 '\''%s'\''' ;;
        TEST_ASSERT_FAILED)           printf '%s' '断言失败' ;;
        TEST_COMMON_FUNCS)            printf '%s' '正在测试 common.sh 的函数...' ;;
        TEST_SUITE_TITLE)             printf '%s' 'AI Studio 测试套件' ;;
        TEST_RESULTS)                 printf '%s' '结果：通过 %s 项，失败 %s 项' ;;
        TEST_LANG_SUITE)              printf '%s' '消息层测试套件（lib/lang.sh）' ;;
        TEST_LANG_DICT)               printf '%s' '正在检查词条完整性...' ;;
        TEST_LANG_DEFAULT)            printf '%s' '正在检查默认语言...' ;;
        TEST_LANG_SWITCH)             printf '%s' '正在检查语言切换...' ;;
        TEST_LANG_NORMALIZE)          printf '%s' '正在检查语言代码归一化...' ;;
        TEST_LANG_REJECT)             printf '%s' '正在检查不支持语言的拒绝行为...' ;;
        TEST_LANG_FALLBACK)           printf '%s' '正在检查未知 KEY 的回退...' ;;
        TEST_LANG_INTERP)             printf '%s' '正在检查消息插值...' ;;
        TEST_SHELLCHECK_RUNNING)      printf '%s' '正在对 AI Studio 脚本运行 ShellCheck' ;;
        TEST_SHELLCHECK_OK)           printf '%s' '所有脚本均通过 ShellCheck！' ;;
        TEST_SHELLCHECK_FAILED)       printf '%s' '部分脚本未通过 ShellCheck，请修复上述问题。' ;;
        TEST_EMOJI_TITLE)             printf '%s' '==> emoji 检查' ;;
        TEST_EMOJI_NO_FILES)          printf '%s' '[WARN] 未找到待扫描文件，跳过' ;;
        TEST_EMOJI_FOUND)             printf '%s' '[FAIL] 检测到 emoji 或非 ASCII 修饰符，请改用 [OK] / [FAIL] / [WARN] / Tip: / -> 等 ASCII 替代：' ;;
        TEST_EMOJI_OK)                printf '%s' '[OK] 通过（全项目无 emoji）' ;;
        TEST_LANGCHECK_TITLE)         printf '%s' '==> 语言策略检查' ;;
        TEST_LANGCHECK_NO_FILES)      printf '%s' '[WARN] 未找到待扫描文件，跳过' ;;
        TEST_LANGCHECK_L1_TITLE)      printf '%s' '正在检查 L1 构成层（阻断）：注释与词典之外的代码不得含非 ASCII...' ;;
        TEST_LANGCHECK_L1_FOUND)      printf '%s' '[FAIL] 以下代码行含非 ASCII 字符（纯注释与行尾注释已排除，lib/lang.sh 与孤儿文件豁免）：' ;;
        TEST_LANGCHECK_L1_OK)         printf '%s' '[OK] 通过（构成层代码无非 ASCII 残留）' ;;
        TEST_LANGCHECK_L2_TITLE)      printf '%s' '正在统计 L2 UI 层消息层覆盖率（告警，不阻断）...' ;;
        TEST_LANGCHECK_L2_STAT)       printf '%s' 'msg/msgf 调用: %s 处；log_* 硬编码字面量残留: %s 处；消息层覆盖率: %s%%' ;;
        TEST_LANGCHECK_L2_WARN)       printf '%s' '[WARN] 消息层覆盖率低于 95%，请继续迁移存量 UI 文案' ;;
        TEST_LANGCHECK_L2_OK)         printf '%s' '[OK] 消息层覆盖率达标（>= 95%）' ;;

        *)                      printf '' ;;
    esac
}

# ---------------------------------------------------------------------------
# 英文词条（与 msg_zh 的 KEY 必须一一对应）
# ---------------------------------------------------------------------------
msg_en() {
    case "${1:-}" in
        # —— common ——
        APP_TAGLINE)            printf '%s' 'Unified AI tool deployment and management platform for macOS' ;;
        UNKNOWN_COMMAND)        printf '%s' 'Unknown command' ;;
        USAGE_HINT)             printf '%s' 'Usage' ;;
        OPERATION_CANCELLED)    printf '%s' 'Operation cancelled' ;;
        OPERATION_SUCCESS)      printf '%s' 'Operation succeeded' ;;
        OPERATION_FAILED)       printf '%s' 'Operation failed' ;;
        PRESS_ENTER)            printf '%s' 'Press Enter to continue' ;;
        YES)                    printf '%s' 'yes' ;;
        NO)                     printf '%s' 'no' ;;
        NOT_INSTALLED)          printf '%s' 'not installed' ;;
        ALREADY_INSTALLED)      printf '%s' 'already installed' ;;
        RUNNING)                printf '%s' 'running' ;;
        STOPPED)                printf '%s' 'stopped' ;;
        READY)                  printf '%s' 'ready' ;;
        SKIPPED)                printf '%s' 'skipped' ;;

        # —— list ——
        LIST_HEADER)            printf '%s' 'Available components' ;;
        LIST_EMPTY)             printf '%s' 'No components available' ;;
        COMPONENT_NOT_FOUND)    printf '%s' 'Component not found' ;;
        COMPONENT_UNKNOWN)      printf '%s' 'Unknown component' ;;

        # —— install ——
        INSTALL_START)          printf '%s' 'Installing' ;;
        INSTALL_DONE)           printf '%s' 'Installation complete' ;;
        INSTALL_FAILED)         printf '%s' 'Installation failed' ;;
        INSTALL_SKIPPED)        printf '%s' 'Already up to date, skipping installation' ;;

        # —— start ——
        START_START)            printf '%s' 'Starting' ;;
        START_DONE)             printf '%s' 'Started' ;;
        START_FAILED)           printf '%s' 'Failed to start' ;;
        START_ALREADY)          printf '%s' 'Already running' ;;

        # —— stop ——
        STOP_START)             printf '%s' 'Stopping' ;;
        STOP_DONE)              printf '%s' 'Stopped' ;;
        STOP_NOT_RUNNING)       printf '%s' 'Not currently running' ;;

        # —— restart ——
        RESTART_START)          printf '%s' 'Restarting' ;;
        RESTART_DONE)           printf '%s' 'Restart complete' ;;

        # —— update ——
        UPDATE_START)           printf '%s' 'Updating' ;;
        UPDATE_DONE)            printf '%s' 'Update complete' ;;
        UPDATE_FAILED)          printf '%s' 'Update failed' ;;
        UPDATE_NOTHING)         printf '%s' 'Nothing to update' ;;

        # —— uninstall ——
        UNINSTALL_START)        printf '%s' 'Uninstalling' ;;
        UNINSTALL_DONE)         printf '%s' 'Uninstall complete' ;;
        UNINSTALL_FAILED)       printf '%s' 'Uninstall failed' ;;

        # —— status / diagnose ——
        STATUS_TITLE)           printf '%s' 'Component status' ;;
        DIAGNOSE_START)         printf '%s' 'Starting diagnosis' ;;
        DIAGNOSE_DONE)          printf '%s' 'Diagnosis complete' ;;
        DIAGNOSE_NO_ISSUE)      printf '%s' 'No issues found' ;;
        DIAGNOSE_ISSUE_FOUND)   printf '%s' 'Issues found' ;;

        # —— env ——
        ENV_CHECK_START)        printf '%s' 'Checking system environment' ;;
        ENV_CHECK_DONE)         printf '%s' 'Environment check complete' ;;
        ENV_INSTALL_START)      printf '%s' 'Installing dependencies' ;;
        ENV_INSTALL_DONE)       printf '%s' 'Dependency installation complete' ;;

        # —— port ——
        PORT_IN_USE)            printf '%s' 'Port in use' ;;
        PORT_FREE)              printf '%s' 'Port free' ;;

        # —— main: help ——
        HELP_CORE_COMMANDS)     printf '%s' 'Core Commands' ;;
        HELP_ENV_DESC)          printf '%s' 'Environment management' ;;
        HELP_INSTALL_DESC)      printf '%s' 'Install component(s)' ;;
        HELP_START_DESC)        printf '%s' 'Start service(s) (auto-open browser)' ;;
        HELP_STOP_DESC)         printf '%s' 'Stop service(s)' ;;
        HELP_RESTART_DESC)      printf '%s' 'Restart service(s)' ;;
        HELP_STATUS_DESC)       printf '%s' 'View status' ;;
        HELP_UPDATE_DESC)       printf '%s' 'Update component(s)' ;;
        HELP_UPDATE_TARGET)     printf '%s' 'Update target' ;;
        HELP_UNINSTALL_DESC)    printf '%s' 'Uninstall component' ;;
        HELP_KEEP_DATA)         printf '%s' 'Keep user data' ;;
        HELP_FORCE)             printf '%s' 'Force uninstall' ;;
        HELP_DIAGNOSE_DESC)     printf '%s' 'Diagnose component' ;;
        HELP_DEEP)              printf '%s' 'Deep diagnosis' ;;
        HELP_FIX)               printf '%s' 'Diagnose and auto-fix' ;;
        HELP_LIST_DESC)         printf '%s' 'List all available components' ;;
        HELP_HELP_DESC)         printf '%s' 'Show this help' ;;
        HELP_VERSION_DESC)      printf '%s' 'Show version' ;;
        HELP_LANG_CMD)          printf '%s' 'Show / list / switch UI language' ;;
        HELP_COMPONENTS)        printf '%s' 'Available Components' ;;
        HELP_GLOBAL_OPTIONS)    printf '%s' 'Global Options' ;;
        HELP_LANG_DESC)         printf '%s' 'UI language for this run (overrides config)' ;;
        HELP_EXAMPLES)          printf '%s' 'Examples' ;;

        # —— main: batch operations ——
        INSTALL_ALL)            printf '%s' 'Installing all components' ;;
        START_ALL)              printf '%s' 'Starting all components' ;;
        STOP_ALL)               printf '%s' 'Stopping all components' ;;
        RESTART_ALL)            printf '%s' 'Restarting all components' ;;
        UPDATE_ALL)             printf '%s' 'Updating all components' ;;
        INSTALLING_COMPONENT)   printf '%s' 'Installing %s' ;;
        STARTING_COMPONENT)     printf '%s' 'Starting %s' ;;
        STOPPING_COMPONENT)     printf '%s' 'Stopping %s' ;;
        RESTARTING_COMPONENT)   printf '%s' 'Restarting %s' ;;
        UPDATING_COMPONENT)     printf '%s' 'Updating %s' ;;
        UNINSTALLING_COMPONENT) printf '%s' 'Uninstalling %s' ;;
        DIAGNOSING_COMPONENT)   printf '%s' 'Diagnosing %s' ;;

        # —— main: hints and errors ——
        ENV_STATUS_TITLE)       printf '%s' 'Environment status' ;;
        ENV_SUBCOMMAND_UNKNOWN) printf '%s' 'Unknown env subcommand' ;;
        SEE_COMPONENT_LIST)     printf '%s' "Run '%s list' to see all available components" ;;
        COMPONENT_OP_UNSUPPORTED) printf '%s' 'Component %s does not support %s operation' ;;
        MISSING_COMPONENT_ARG)  printf '%s' 'Missing component name argument' ;;

        # —— list legend ——
        LIST_LEGEND)            printf '%s' 'Status Legend' ;;
        LEGEND_RUNNING)         printf '%s' 'Running' ;;
        LEGEND_INSTALLED)       printf '%s' 'Installed but not running' ;;
        LEGEND_NOT_INSTALLED)   printf '%s' 'Not installed' ;;
        LABEL_PORT)             printf '%s' 'port' ;;

        # —— 组件：通用横幅 ——
        BANNER_INSTALL)            printf '%s' 'Installing: %s' ;;
        BANNER_START)              printf '%s' 'Starting: %s' ;;
        BANNER_STOP)               printf '%s' 'Stopping: %s' ;;
        BANNER_STATUS)             printf '%s' 'Status: %s' ;;
        BANNER_DIAGNOSE)           printf '%s' 'Diagnosing: %s' ;;
        BANNER_UNINSTALL)          printf '%s' 'Uninstalling: %s' ;;
        BANNER_UPDATE)             printf '%s' 'Updating: %s (Target: %s)' ;;

        # —— 组件：mlx 专属 ——
        BANNER_VERIFY)             printf '%s' 'Verifying: %s' ;;
        INSTALL_STEP_VENV_N)      printf '%s' 'Step %s/4: Setting up isolated Python virtual environment...' ;;
        MLX_NOT_APPLE_SILICON)     printf '%s' 'MLX is designed for Apple Silicon (M1/M2/M3/M4). You are on %s.' ;;
        MLX_PERF_LIMITED)          printf '%s' 'Installation will proceed, but performance will be significantly limited or unsupported.' ;;
        MLX_INSTALL_ALREADY_OK)    printf '%s' '%s appears to be already installed and functional.' ;;
        MLX_VENV_NOT_IMPORTABLE)   printf '%s' 'Virtual environment exists but MLX is not importable. Re-installing...' ;;
        MLX_FAILED_DEPS)           printf '%s' 'Failed to install required dependencies (python3, git, cmake). Aborting.' ;;
        MLX_STEP_VENV_CLEAN)       printf '%s' 'Removing existing corrupted or incomplete virtual environment...' ;;
        MLX_STEP_FRAMEWORK)        printf '%s' 'Step 3/4: Installing MLX framework and core extensions...' ;;
        MLX_INSTALLING_PACKAGES)   printf '%s' 'Installing: %s ...' ;;
        MLX_FAILED_PACKAGES)       printf '%s' 'Failed to install MLX Python packages.' ;;
        MLX_MISSING_HEADERS)       printf '%s' 'This may be due to missing system headers (ensure Xcode CLI tools are installed).' ;;
        MLX_PACKAGES_OK)           printf '%s' 'MLX packages installed successfully.' ;;
        MLX_STEP_VERIFY)           printf '%s' 'Step 4/4: Verifying installation...' ;;
        MLX_VERIFY_OK)             printf '%s' 'MLX v%s is successfully installed and verified.' ;;
        MLX_VERIFY_FAILED)         printf '%s' 'Installation verification failed. MLX module could not be imported.' ;;
        MLX_CACHE_DIR_READY)       printf '%s' 'Initialized MLX cache directory at: %s' ;;
        MLX_NEXT_TITLE)            printf '%s' 'Next Steps & Usage' ;;
        MLX_NEXT_NO_START)         printf '%s' '  MLX is a foundational framework. You typically don'\''t '\''start'\'' it directly.' ;;
        MLX_NEXT_USE_VIA)          printf '%s' '  Instead, use it via:' ;;
        MLX_NEXT_1)                printf '%s' '  1. The '\''model'\'' component to download weights: ./ai-studio.sh install model' ;;
        MLX_NEXT_2)                printf '%s' '  2. Custom Python scripts activating this venv: source %s/bin/activate' ;;
        MLX_NEXT_3)                printf '%s' '  3. Other AI Studio components that depend on MLX.' ;;
        MLX_START_NOT_IMPORTABLE)  printf '%s' 'MLX is installed but cannot be imported. The environment may be corrupted.' ;;
        MLX_USAGE_TITLE)           printf '%s' 'Tip: How to use the MLX Framework' ;;
        MLX_USAGE_DESC1)           printf '%s' '  MLX is a computational library, not a background service. It does not need' ;;
        MLX_USAGE_DESC2)           printf '%s' '  to be '\''started'\''. Instead, you interact with it via Python scripts or CLI tools.' ;;
        MLX_USAGE_STEP1)           printf '%s' '1. Activate the isolated environment:' ;;
        MLX_USAGE_STEP1_CMD)       printf '%s' 'source %s' ;;
        MLX_USAGE_STEP2)           printf '%s' '2. Verify MLX is using Apple Silicon acceleration:' ;;
        MLX_USAGE_STEP2_CMD)       printf '%s' 'python3 -c "import mlx.core as mx; print('\''Device:'\'', mx.default_device())"' ;;
        MLX_USAGE_STEP2_EXPECT)    printf '%s' '     (Expected output: Device: mlx)' ;;
        MLX_USAGE_STEP3)           printf '%s' '3. Run Large Language Models (via mlx-lm):' ;;
        MLX_USAGE_STEP3_CMD)       printf '%s' 'mlx_lm.generate --model mlx-community/Qwen2.5-7B-Instruct-4bit --prompt "Hello"' ;;
        MLX_USAGE_STEP4)           printf '%s' '4. Download models (Centralized Management):' ;;
        MLX_USAGE_STEP4_CMD)       printf '%s' './ai-studio.sh install model' ;;
        MLX_START_NOT_PROPER)      printf '%s' 'MLX is not properly installed.' ;;
        MLX_START_SETUP_HINT)      printf '%s' 'To set up the MLX framework and its extensions, run:' ;;
        MLX_START_INSTALL_CMD)     printf '%s' '  ./ai-studio.sh install %s' ;;
        MLX_START_READY)           printf '%s' 'MLX v%s is installed and ready to use.' ;;
        MLX_START_NO_SERVICE)      printf '%s' 'No background service to start. Framework is ready for your scripts.' ;;
        MLX_STOP_FOUNDATIONAL)     printf '%s' 'The '\''%s'\'' component is a foundational machine learning framework.' ;;
        MLX_STOP_NO_DAEMON)        printf '%s' 'It does not run as a background daemon service and does not consume CPU/GPU resources on its own.' ;;
        MLX_STOP_FREE_HINT)        printf '%s' 'To free up system resources (VRAM/RAM), you should stop the specific inference components or scripts that are currently utilizing MLX:' ;;
        MLX_STOP_DEPS_RUNNING)     printf '%s' 'The following MLX-dependent components are currently running:' ;;
        STOP_DEPS_HINT)        printf '%s' 'To stop them and free up resources, run:' ;;
        MLX_STOP_DEPS_CMD)         printf '%s' './ai-studio.sh stop %s' ;;
        MLX_STOP_NONE_RUNNING)     printf '%s' 'No MLX-dependent background services are currently running. Your system resources are fully available.' ;;
        MLX_STOP_NO_ACTION)        printf '%s' 'No action required for '\''%s'\''. Framework state is preserved.' ;;
        NEXT_STEPS)                printf '%s' 'Next Steps' ;;
        ACTIONS_LABEL)             printf '%s' 'Actions' ;;

        # —— 组件：install ——
        INSTALL_ALREADY)           printf '%s' '%s appears to be already installed' ;;
        INSTALL_SKIP_HINT)         printf '%s' 'Skipping installation. Use '\''./ai-studio.sh update %s'\'' to upgrade' ;;
        INSTALL_STEP_VERIFY_DEPS)  printf '%s' 'Step 1/4: Verifying system dependencies...' ;;
        INSTALL_FAILED_DEPS)       printf '%s' 'Failed to install required dependencies. Aborting.' ;;
        INSTALL_STEP_CLONE)        printf '%s' 'Step 2/4: Retrieving source code from %s...' ;;
        INSTALL_DIR_NOT_GIT)       printf '%s' 'Directory is not empty and not a git repository. Cleaning up...' ;;
        INSTALL_CLONE_OK)          printf '%s' 'Source code cloned successfully.' ;;
        INSTALL_SRC_EXISTS)        printf '%s' 'Source code already exists. Ensuring it'\''s on the correct branch...' ;;
        INSTALL_SRC_UPDATED)       printf '%s' 'Source code updated.' ;;
        INSTALL_STEP_VENV)         printf '%s' 'Step 3/4: Setting up isolated Python virtual environment...' ;;
        INSTALL_FAILED_VENV)       printf '%s' 'Failed to create Python virtual environment.' ;;
        INSTALL_VENV_OK)           printf '%s' 'Virtual environment created and activated.' ;;
        INSTALL_STEP_PYDEPS)       printf '%s' 'Step 4/4: Installing Python dependencies (this may take a few minutes)...' ;;
        INSTALL_FAILED_PYDEPS)     printf '%s' 'Failed to install Python dependencies from requirements.txt.' ;;
        INSTALL_NO_REQUIREMENTS)   printf '%s' 'requirements.txt not found. Attempting to install '\''open-webui'\'' package directly...' ;;
        INSTALL_FAILED_PACKAGE)    printf '%s' 'Failed to install open-webui package.' ;;
        INSTALL_PYDEPS_OK)         printf '%s' 'Python dependencies installed successfully.' ;;
        INSTALL_INIT_DATA_DIR)     printf '%s' 'Initializing component data directories...' ;;
        INSTALL_DATA_DIR_READY)    printf '%s' 'Data directory ready at %s' ;;
        INSTALL_SUCCESS_COMPONENT) printf '%s' '%s has been successfully installed!' ;;
        INSTALL_NEXT_START)        printf '%s' '1. Start the service (will auto-open browser):' ;;
        INSTALL_NEXT_START_CMD)    printf '%s' '   ./ai-studio.sh start %s' ;;
        INSTALL_NEXT_STATUS)       printf '%s' '2. View service status:' ;;
        INSTALL_NEXT_STATUS_CMD)   printf '%s' '   ./ai-studio.sh status %s' ;;

        # —— 组件：start ——
        START_NOT_INSTALLED)       printf '%s' '%s does not appear to be installed.' ;;
        START_ALREADY_RUNNING)     printf '%s' '%s is already running (PID: %s).' ;;
        START_INVALID_PORT_OFFSET) printf '%s' 'Invalid DEFAULT_PORT_OFFSET in config. Using 0.' ;;
        START_PORT_IN_USE)         printf '%s' 'Port %s is already in use by another application.' ;;
        START_PORT_HINT)           printf '%s' 'Please change the DEFAULT_PORT_OFFSET in config/ai-studio.conf or free up the port.' ;;
        START_LAUNCHING)           printf '%s' 'Launching on port %s: %s...' ;;
        START_FAILED_DAEMON)       printf '%s' 'Failed to start %s daemon.' ;;
        START_SUCCESS_COMPONENT)   printf '%s' '%s is running successfully!' ;;
        START_ACCESS_URL)          printf '%s' 'You can access it at: %s' ;;
        START_HINT_STOP)           printf '%s' 'To stop the service, run: ./ai-studio.sh stop %s' ;;
        START_NOT_READY)           printf '%s' '%s started but failed to become ready on port %s.' ;;
        START_CHECK_LOGS)          printf '%s' 'Please check the logs for details:' ;;
        START_LOG_PATH)            printf '%s' '  %s/logs/%s.log' ;;

        # —— 组件：stop ——
        STOP_NOT_RUNNING)          printf '%s' '%s is not currently running.' ;;
        STOP_SUCCESS_COMPONENT)    printf '%s' '%s has been stopped successfully.' ;;
        STOP_PORT_RELEASED)        printf '%s' 'Port %s is now released.' ;;
        STOP_HINT_RESTART)         printf '%s' '• To start it again: ./ai-studio.sh start %s' ;;
        STOP_HINT_STATUS)          printf '%s' '• To check detailed status: ./ai-studio.sh status %s' ;;
        STOP_FAILED_CLEAN)         printf '%s' 'Failed to stop %s cleanly.' ;;
        STOP_STUCK_HINT)           printf '%s' 'The process might be stuck. You can try:' ;;
        STOP_STUCK_LOG)            printf '%s' '1. Check the logs: %s/logs/%s.log' ;;
        STOP_STUCK_KILL)           printf '%s' '2. Force kill the port manually: lsof -ti :%s | xargs kill -9' ;;
        STOP_STUCK_DIAGNOSE)       printf '%s' '3. Run deep diagnosis: ./ai-studio.sh diagnose %s --deep --fix' ;;

        # —— 组件：status ——
        STATUS_NOT_INSTALLED_TAG)  printf '%s' 'NOT INSTALLED' ;;
        STATUS_NOT_INSTALLED_DESC) printf '%s' 'The component has not been installed yet.' ;;
        STATUS_HINT_INSTALL)       printf '%s' 'Run: %s' ;;
        STATUS_RECENT_LOGS)        printf '%s' 'Recent Log Activity:' ;;
        STATUS_LOG_EMPTY)          printf '%s' '(Log file is empty or contains no recent text)' ;;
        STATUS_NO_LOG)             printf '%s' '(No log file generated yet)' ;;
        STATUS_ACTION_STOP)        printf '%s' '• Stop service:' ;;
        STATUS_ACTION_LOGS)        printf '%s' '• View full logs:' ;;
        STATUS_ACTION_BROWSER)     printf '%s' '• Open browser:' ;;
        STATUS_ACTION_START)       printf '%s' '• Start service:' ;;
        STATUS_ACTION_DIAGNOSE)    printf '%s' '• Run diagnosis:' ;;

        # —— 组件：diagnose ——
        DIAG_VENV_MISSING)         printf '%s' 'CRITICAL: Python virtual environment is missing or corrupted.' ;;
        DIAG_HINT_REINSTALL)       printf '%s' '  -> The component may need to be reinstalled.' ;;
        DIAG_VENV_BROKEN)          printf '%s' 'CRITICAL: Virtual environment Python binary is broken.' ;;
        DIAG_VENV_OK)              printf '%s' 'OK: Virtual environment is intact and functional.' ;;
        DIAG_DATA_DIR_MISSING)     printf '%s' 'WARNING: Data directory does not exist. It will be created on first start.' ;;
        DIAG_DATA_DIR_NOT_WRITABLE) printf '%s' 'CRITICAL: Data directory exists but is not writable. Database saves will fail.' ;;
        DIAG_DATA_DIR_OK)          printf '%s' 'OK: Data directory is present and writable.' ;;
        DIAG_OLLAMA_UNREACHABLE)   printf '%s' 'INFO: Cannot reach local Ollama instance at port 11434.' ;;
        DIAG_OLLAMA_HINT)          printf '%s' '  -> If you intend to use local models, ensure Ollama is running: ./ai-studio.sh start qwen3' ;;
        DIAG_FIX_PERMS)            printf '%s' '  -> Attempting to fix data directory permissions...' ;;
        DIAG_FIX_PERMS_OK)         printf '%s' '    Data directory permissions repaired.' ;;
        DIAG_FIX_PERMS_FAILED)     printf '%s' '    Failed to repair permissions. Manual intervention required.' ;;
        DIAG_VENV_CORRUPTED)       printf '%s' '  -> Virtual environment is corrupted.' ;;
        DIAG_VENV_NO_AUTOFIX)      printf '%s' '    Auto-fix cannot repair a broken venv. Please run:' ;;
        DIAG_CMD_UNINSTALL_KEEP)   printf '%s' '    ./ai-studio.sh uninstall %s --keep-data' ;;
        DIAG_CMD_INSTALL)          printf '%s' '    ./ai-studio.sh install %s' ;;
        DIAG_SPECIFIC_CHECKS)      printf '%s' 'Running %s-specific checks...' ;;
        DIAG_ISSUES_FOUND)         printf '%s' 'Diagnosis completed for %s with %s issue(s) detected.' ;;
        DIAG_HINT_DEEP_FIX)        printf '%s' 'Tip: Run with '\''--deep --fix'\'' to attempt automatic resolution of fixable issues.' ;;
        DIAG_HEALTHY)              printf '%s' 'Diagnosis completed. %s is healthy and ready to use.' ;;

        # —— 组件：uninstall ——
        UNINSTALL_UNKNOWN_ARG)     printf '%s' 'Unknown uninstall argument: %s' ;;
        UNINSTALL_USAGE)           printf '%s' 'Usage: ./ai-studio.sh uninstall %s [--keep-data] [--force]' ;;
        UNINSTALL_NOT_INSTALLED)   printf '%s' '%s does not appear to be installed. Nothing to uninstall.' ;;
        UNINSTALL_STOPPING)        printf '%s' 'Stopping %s service before uninstallation...' ;;
        UNINSTALL_FORCE_KILL)      printf '%s' 'Failed to stop gracefully. Force killing due to --force flag...' ;;
        UNINSTALL_STOP_FAILED)     printf '%s' 'Failed to stop %s gracefully.' ;;
        UNINSTALL_STOP_HINT)       printf '%s' 'Please stop the service manually or use the --force flag.' ;;
        UNINSTALL_CANCELLED)       printf '%s' 'Uninstallation cancelled by user.' ;;
        UNINSTALL_CLEANING)        printf '%s' 'Cleaning up component files...' ;;
        UNINSTALL_KEEP_DATA)       printf '%s' 'Preserving user data directory: %s' ;;
        UNINSTALL_DELETE_DATA)     printf '%s' 'Deleting user data directory: %s' ;;
        UNINSTALL_REMOVED_OK)      printf '%s' 'Component source code and dependencies removed.' ;;
        UNINSTALL_CLEAN_FAILED)    printf '%s' 'Failed to clean up some files. You may need to remove them manually.' ;;
        UNINSTALL_LOG_CLEARED)     printf '%s' 'Cleared component log file.' ;;
        UNINSTALL_CONF_CLEARED)    printf '%s' 'Cleared component configuration file.' ;;
        UNINSTALL_SUCCESS_COMPONENT) printf '%s' '%s has been successfully uninstalled!' ;;
        UNINSTALL_DATA_PRESERVED)  printf '%s' 'Your data and models have been preserved in: %s' ;;
        UNINSTALL_REINSTALL_HINT)  printf '%s' 'You can safely reinstall the component later without losing your data.' ;;
        UNINSTALL_DATA_DELETED)    printf '%s' 'All local data, models, and configurations for this component have been permanently deleted.' ;;
        UNINSTALL_HINT_LIST)       printf '%s' '• View remaining components: ./ai-studio.sh list' ;;
        UNINSTALL_HINT_INSTALL_OTHER) printf '%s' '• Install a different component: ./ai-studio.sh install <component>' ;;

        # —— 组件：update ——
        UPDATE_UNKNOWN_ARG)        printf '%s' 'Unknown update argument: %s' ;;
        UPDATE_USAGE)              printf '%s' 'Usage: ./ai-studio.sh update %s [--target <frontend|backend|architecture|models|all>]' ;;
        UPDATE_INVALID_TARGET)     printf '%s' 'Invalid update target: '\''%s'\''' ;;
        UPDATE_SUPPORTED_TARGETS)  printf '%s' 'Supported targets for %s are: %s' ;;
        UPDATE_NOT_INSTALLED)      printf '%s' '%s is not installed.' ;;
        UPDATE_FETCHING)           printf '%s' 'Fetching latest source code from %s...' ;;
        UPDATE_SRC_OK)             printf '%s' 'Source code updated successfully.' ;;
        UPDATE_NO_UPDATES)         printf '%s' 'No new updates to pull, or git pull failed. Proceeding with dependency check...' ;;
        UPDATE_PYDEPS)             printf '%s' 'Updating Python dependencies (backend/architecture)...' ;;
        UPDATE_PYDEPS_OK)          printf '%s' 'Python dependencies updated successfully.' ;;
        UPDATE_PYDEPS_FAILED)      printf '%s' 'Failed to update Python dependencies.' ;;
        UPDATE_NO_REQUIREMENTS)    printf '%s' 'requirements.txt not found. Attempting to upgrade '\''open-webui'\'' package directly...' ;;
        UPDATE_PACKAGE_OK)         printf '%s' 'Open WebUI package upgraded successfully.' ;;
        UPDATE_PACKAGE_FAILED)     printf '%s' 'Failed to upgrade open-webui package.' ;;
        UPDATE_FRONTEND_CHECK)     printf '%s' 'Checking for frontend updates...' ;;
        UPDATE_NODE_DEPS)          printf '%s' 'Updating Node.js dependencies...' ;;
        UPDATE_NODE_DEPS_OK)       printf '%s' 'Frontend dependencies updated.' ;;
        UPDATE_NODE_DEPS_FAILED)   printf '%s' 'Failed to update frontend dependencies. This may not be critical if the backend is bundled.' ;;
        UPDATE_NO_NODE)            printf '%s' 'Node.js (npm) not found. Skipping frontend dependency update.' ;;
        UPDATE_NO_FRONTEND_DIR)    printf '%s' 'No separate frontend build directory found. Frontend is likely bundled with the backend update.' ;;
        UPDATE_MODELS)             printf '%s' 'Handling model updates...' ;;
        UPDATE_MODELS_NOTE)        printf '%s' 'Note: Open WebUI manages model connections via its Web UI or through Ollama.' ;;
        UPDATE_MODELS_CMD)         printf '%s' 'To update local models, please use: ollama pull <model_name>' ;;
        UPDATE_MODELS_ADMIN)       printf '%s' 'Or manage connections in the Open WebUI Admin Settings.' ;;
        UPDATE_STOPPING_FOR_CLEAN) printf '%s' '%s is currently running. Stopping it for a clean update...' ;;
        UPDATE_RESTARTING)         printf '%s' 'Restarting %s...' ;;
        UPDATE_ERRORS)             printf '%s' 'Update completed with errors. Please check the logs.' ;;
        UPDATE_HINT_DIAGNOSE)      printf '%s' 'You may need to run: ./ai-studio.sh diagnose %s --deep --fix' ;;
        UPDATE_SUCCESS_COMPONENT)  printf '%s' '%s has been successfully updated to the latest version!' ;;
        UPDATE_AUTO_RESTARTED)     printf '%s' 'The service has been automatically restarted.' ;;
        UPDATE_HINT_START)         printf '%s' 'You can start the service with: ./ai-studio.sh start %s' ;;

        # —— tips ——
        TIP_HOW_TO_USE)         printf '%s' 'Tip: how to use' ;;
        TIP_RUN_COMMAND)        printf '%s' 'Tip: run' ;;
        # —— 组件：mlx（第二批：状态 / 诊断 / 更新 / 卸载）与通用标签 ——
        LBL_COMPONENT)                printf '%s' 'Component' ;;
        LBL_TYPE)                     printf '%s' 'Type' ;;
        LBL_VIRTUAL_ENV)              printf '%s' 'Virtual Env' ;;
        LBL_VERSION)                  printf '%s' 'Version' ;;
        LBL_ACTIVE_DEVICE)            printf '%s' 'Active Device' ;;
        LBL_NOTE)                     printf '%s' 'Note' ;;
        LBL_ACTION)                   printf '%s' 'Action' ;;
        LBL_STATUS)                   printf '%s' 'Status' ;;
        LBL_USAGE)                    printf '%s' 'Usage' ;;
        LBL_PID)                      printf '%s' 'PID' ;;
        LBL_UPTIME)                   printf '%s' 'Uptime' ;;
        LBL_RESOURCES)                printf '%s' 'Resources' ;;
        LBL_PORT_STATUS)              printf '%s' 'Port Status' ;;
        LBL_TARGET_PORT)              printf '%s' 'Target Port' ;;
        LBL_DATA_DIR)                 printf '%s' 'Data Directory' ;;
        MLX_STATUS_READY)             printf '%s' 'MLX framework is installed and hardware acceleration is active.' ;;
        MLX_STATUS_WARN)              printf '%s' 'MLX is installed, but hardware acceleration may not be active.' ;;
        MLX_STATUS_CORRUPTED)         printf '%s' 'Virtual environment exists, but MLX cannot be imported.' ;;
        MLX_STATUS_DEVICE_OPT)        printf '%s' '%s (Apple Silicon Optimized)' ;;
        STATUS_LOAD_FAILED)           printf '%s' 'Failed to load' ;;
        ACTION_REINSTALL)             printf '%s' 'Re-installation is required.' ;;
        MLX_STATUS_PERF_NOTE)         printf '%s' 'Performance will be limited. This is expected on Intel Macs.' ;;
        STATUS_ENV_DETAILS)           printf '%s' 'Environment Details' ;;
        MLX_STATUS_ACTION_GUIDE)      printf '%s' 'View usage guide:' ;;
        MLX_STATUS_ACTION_MODELS)     printf '%s' 'Download models:' ;;
        MLX_STATUS_ACTION_UPDATE)     printf '%s' 'Update framework:' ;;
        MLX_STATUS_ACTION_FIX)        printf '%s' 'Fix installation:' ;;
        MLX_STATUS_TIP_ACTIVATE)      printf '%s' 'Tip: To use MLX in your own scripts, activate the environment first:' ;;
        MLX_DIAG_NOTE)                printf '%s' 'Note: MLX is a foundational framework, not a background service.' ;;
        MLX_DIAG_VENV_DIR_MISSING)    printf '%s' 'CRITICAL: Virtual environment directory is missing.' ;;
        MLX_DIAG_HINT_SETUP)          printf '%s' '-> Run '\''./ai-studio.sh install %s'\'' to set it up.' ;;
        MLX_DIAG_VENV_PY_MISSING)     printf '%s' 'CRITICAL: Virtual environment Python binary is missing or not executable.' ;;
        MLX_DIAG_HINT_REINSTALL)      printf '%s' '-> The environment is corrupted. Re-installation is required.' ;;
        MLX_DIAG_IMPORT_FAIL)         printf '%s' 'CRITICAL: MLX package is installed but cannot be imported.' ;;
        MLX_DIAG_PYENV_BROKEN)        printf '%s' '-> The Python environment is broken. Re-installation is required.' ;;
        MLX_DIAG_VENV_OK)             printf '%s' 'OK: Virtual environment is healthy and MLX is importable.' ;;
        MLX_DIAG_HW_OK)               printf '%s' 'OK: Hardware acceleration is active (Device: %s).' ;;
        MLX_DIAG_HW_LIMITED)          printf '%s' 'WARNING: MLX is running, but hardware acceleration may be limited (Device: %s).' ;;
        MLX_DIAG_HW_LIMITED_NOTE)     printf '%s' '-> This is expected on Intel Macs, but indicates suboptimal performance on Apple Silicon.' ;;
        MLX_DIAG_HW_QUERY_FAIL)       printf '%s' 'CRITICAL: Failed to query MLX device information.' ;;
        MLX_DIAG_HW_BROKEN)           printf '%s' '-> The MLX installation may be fundamentally broken.' ;;
        MLX_DIAG_CMAKE_MISSING)       printf '%s' 'WARNING: '\''cmake'\'' is not installed.' ;;
        MLX_DIAG_CMAKE_NOTE)          printf '%s' '-> Required for building certain MLX extensions or compiling from source.' ;;
        MLX_DIAG_SYS_PY_MISSING)      printf '%s' 'CRITICAL: System '\''python3'\'' is missing.' ;;
        MLX_DIAG_DEPS_OK)             printf '%s' 'OK: All required system build dependencies are present.' ;;
        MLX_DIAG_FIX_DEPS)            printf '%s' '-> Attempting to repair system build dependencies...' ;;
        MLX_DIAG_FIX_DEPS_OK)         printf '%s' 'System dependencies repaired.' ;;
        MLX_DIAG_FIX_DEPS_FAILED)     printf '%s' 'Failed to repair system dependencies. Please install manually.' ;;
        MLX_DIAG_FIX_VENV_PERMS)      printf '%s' '-> Attempting to fix virtual environment permissions...' ;;
        MLX_DIAG_FIX_VENV_PERMS_OK)   printf '%s' 'Virtual environment permissions repaired.' ;;
        MLX_DIAG_SKIP_VENV_BROKEN)    printf '%s' 'Skipped (Virtual environment is broken)' ;;
        MLX_DIAG_SKIP_HW)             printf '%s' 'Skipped (Use --deep to verify hardware acceleration)' ;;
        MLX_DIAG_SKIP_DEPS)           printf '%s' 'Skipped (Use --deep to check build tools)' ;;
        MLX_DIAG_VENV_NO_AUTOFIX)     printf '%s' 'The virtual environment is corrupted and cannot be auto-fixed.' ;;
        MLX_DIAG_REBUILD_HINT)        printf '%s' 'Please run the following commands to rebuild it safely:' ;;
        MLX_DIAG_DONE_DEEP_OK)        printf '%s' 'Deep diagnosis completed. The MLX framework is healthy and optimized.' ;;
        MLX_DIAG_DONE_BASIC_OK)       printf '%s' 'Basic diagnosis completed. The MLX framework is accessible.' ;;
        MLX_VENV_NOT_FOUND)           printf '%s' 'MLX virtual environment not found.' ;;
        MLX_UPDATE_USAGE)             printf '%s' 'Usage: ./ai-studio.sh update %s [--target <architecture|all>]' ;;
        UPDATE_HINT_INSTALL_FIRST)        printf '%s' 'Please run '\''./ai-studio.sh install %s'\'' first.' ;;
        MLX_UPDATE_CORRUPTED)         printf '%s' 'MLX is installed but cannot be imported. The environment is corrupted.' ;;
        MLX_UPDATE_HINT_REPAIR)       printf '%s' 'Please run '\''./ai-studio.sh install %s'\'' to repair it.' ;;
        MLX_UPDATE_START)             printf '%s' 'Updating MLX framework and core dependencies...' ;;
        MLX_UPDATE_VERIFY_DEPS)       printf '%s' 'Verifying system build dependencies (cmake, etc.)...' ;;
        MLX_UPDATE_UPGRADE_TOOLS)     printf '%s' 'Upgrading pip, setuptools, and wheel...' ;;
        MLX_UPDATE_TOOLS_FAILED)      printf '%s' 'Failed to upgrade core build tools. Proceeding with caution...' ;;
        MLX_UPDATE_UPGRADE_PKGS)      printf '%s' 'Upgrading Python packages: %s ...' ;;
        MLX_UPDATE_PKGS_OK)           printf '%s' 'MLX packages upgraded successfully.' ;;
        MLX_UPDATE_VERSION)           printf '%s' 'Current MLX version: v%s' ;;
        MLX_UPDATE_PKGS_FAILED)       printf '%s' 'Failed to upgrade MLX packages.' ;;
        MLX_UPDATE_FAIL_REASON)       printf '%s' 'This may be due to network issues or conflicting dependencies.' ;;
        MLX_UPDATE_HINT_MANUAL)       printf '%s' 'Please check the logs above. You may need to manually activate the venv and run '\''pip install --upgrade mlx'\''.' ;;
        MLX_UPDATE_NOTE_RESTART_1)    printf '%s' 'Any Python scripts or terminal sessions currently using MLX should be restarted' ;;
        MLX_UPDATE_NOTE_RESTART_2)    printf '%s' 'to load the newly updated library into memory.' ;;
        MLX_UPDATE_ACTIVATE)          printf '%s' 'Activate the environment with: %s' ;;
        MLX_UNINSTALL_CONFIRM)        printf '%s' 'Are you sure you want to uninstall the %s framework?' ;;
        MLX_UNINSTALL_WILL_DELETE)    printf '%s' 'This will delete the isolated Python virtual environment.' ;;
        MLX_UNINSTALL_WILL_KEEP)      printf '%s' '(The virtual environment will be preserved)' ;;
        MLX_UNINSTALL_PRESERVE)       printf '%s' 'Preserving virtual environment directory: %s' ;;
        MLX_UNINSTALL_DELETE)         printf '%s' 'Deleting virtual environment directory: %s' ;;
        MLX_UNINSTALL_PRESERVED_AT)   printf '%s' 'Your virtual environment has been preserved in: %s' ;;
        MLX_UNINSTALL_REINSTALL_HINT) printf '%s' 'You can safely reinstall the component later without re-downloading all Python packages.' ;;
        MLX_UNINSTALL_VENV_REMOVED)   printf '%s' 'The isolated Python environment has been completely removed.' ;;
        MLX_UNINSTALL_NO_IMPACT)      printf '%s' 'This does not affect your system-wide Python installation or other components.' ;;


        # —— 组件：model（模型仓库：安装 / 启动 / 状态 / 停止 / 更新 / 卸载 / 诊断）与共享标签 ——
        MODEL_REPO_SUFFIX)                printf '%s' '(MLX Model Repository)' ;;
        LBL_MANAGEMENT)                   printf '%s' 'Management' ;;
        MODEL_TBL_NAME)                   printf '%s' 'MODEL NAME' ;;
        MODEL_TBL_IDENTIFIER)             printf '%s' 'MODEL IDENTIFIER' ;;
        MODEL_TBL_SIZE)                   printf '%s' 'SIZE' ;;
        MODEL_TBL_STATUS)                 printf '%s' 'STATUS' ;;
        MODEL_INSTALL_DISK_LOW)           printf '%s' 'Insufficient disk space at %s.' ;;
        MODEL_INSTALL_DISK_DETAIL)        printf '%s' 'Found: %sGB, Required: %sGB+ for large MLX models.' ;;
        MODEL_INSTALL_DISK_OK)            printf '%s' 'Disk space check passed (%sGB available at %s).' ;;
        MODEL_INSTALL_CHECKING)           printf '%s' 'Checking model: %s' ;;
        MODEL_INSTALL_EXISTS)             printf '%s' 'Model '\''%s'\'' already exists. Skipping download.' ;;
        MODEL_INSTALL_DOWNLOADING)        printf '%s' 'Downloading %s to %s...' ;;
        MODEL_INSTALL_LARGE_FILE)         printf '%s' 'This is a large file. The download supports resuming if interrupted.' ;;
        MODEL_INSTALL_DL_OK)              printf '%s' 'Successfully downloaded %s.' ;;
        MODEL_INSTALL_DL_FAIL)            printf '%s' 'Failed to download %s.' ;;
        TROUBLESHOOT_LABEL)       printf '%s' 'Troubleshooting:' ;;
        MODEL_INSTALL_TS_1)               printf '%s' '1. Check your internet connection.' ;;
        MODEL_INSTALL_TS_2)               printf '%s' '2. If this is a gated model, run: huggingface-cli login' ;;
        MODEL_INSTALL_TS_3)               printf '%s' '3. Ensure you have accepted the model license on Hugging Face.' ;;
        MODEL_INSTALL_SUBTITLE)           printf '%s' 'Centralized storage for Qwen3, SD, and FLUX MLX models' ;;
        MODEL_INSTALL_STEP1)              printf '%s' 'Step 1/3: Verifying system dependencies for large file downloads...' ;;
        MODEL_INSTALL_STEP2)              printf '%s' 'Step 2/3: Verifying disk space for model storage...' ;;
        MODEL_INSTALL_STEP3)              printf '%s' 'Step 3/3: Downloading MLX-optimized models...' ;;
        MODEL_INSTALL_DONE_ERRORS)        printf '%s' 'Model installation completed with %s error(s).' ;;
        MODEL_INSTALL_RETRY_HINT)         printf '%s' 'Please review the errors above. You can re-run this script to resume failed downloads.' ;;
        MODEL_INSTALL_ALL_OK)             printf '%s' 'All specified MLX models have been successfully downloaded!' ;;
        MODEL_INSTALL_INTEGRATION)        printf '%s' 'Integration Guide:' ;;
        MODEL_INSTALL_STORED_AT)          printf '%s' 'Your models are centrally stored at: %s' ;;
        MODEL_INSTALL_USAGE_INTRO)        printf '%s' 'To use these models in other components:' ;;
        MODEL_INSTALL_USAGE_COMFYUI)      printf '%s' 'ComfyUI: Add this path to your '\''extra_model_paths.yaml'\''' ;;
        MODEL_INSTALL_USAGE_MLX)          printf '%s' 'MLX-Video / Custom Scripts: Set your model path argument to this directory' ;;
        MODEL_INSTALL_USAGE_OLLAMA)       printf '%s' 'Ollama (for LLMs): You may need to convert or link these, or use native Ollama pull' ;;
        MODEL_INSTALL_TIP_UPDATE)         printf '%s' 'Tip: Run '\''./ai-studio.sh update model --target models'\'' later to check for model weight updates.' ;;
        MODEL_START_NO_DIR)               printf '%s' 'Model directory does not exist: %s' ;;
        MODEL_START_EMPTY)                printf '%s' 'Model directory is empty. No models have been downloaded yet.' ;;
        MODEL_START_LIST_TITLE)           printf '%s' 'Downloaded MLX Models:' ;;
        MODEL_START_NO_MODELS)            printf '%s' '(No models found. Run '\''./ai-studio.sh install model'\'' to download.)' ;;
        MODEL_START_TIP_TITLE)            printf '%s' 'Tip: How to use these models:' ;;
        MODEL_START_STATIC_1)             printf '%s' 'Models are static assets and do not need to be '\''started'\''. Instead, they are' ;;
        MODEL_START_STATIC_2)             printf '%s' 'loaded by compatible inference engines or UI components.' ;;
        MODEL_START_LLM_TITLE)            printf '%s' 'For LLMs (e.g., Qwen3):' ;;
        MODEL_START_LLM_DESC)             printf '%s' 'The recommended way to run MLX LLMs is via Ollama or a dedicated MLX-LM script.' ;;
        MODEL_START_LLM_STEP1)            printf '%s' '1. Ensure Ollama is running: %s' ;;
        MODEL_START_LLM_STEP2)            printf '%s' '2. Or use a Python script pointing to: %s' ;;
        MODEL_START_IMG_TITLE)            printf '%s' 'For Image Generation (SD / FLUX):' ;;
        MODEL_START_IMG_STEP1)            printf '%s' '1. Start ComfyUI: %s' ;;
        MODEL_START_IMG_STEP2)            printf '%s' '2. In ComfyUI, ensure your '\''extra_model_paths.yaml'\'' includes:' ;;
        MODEL_START_IMG_STEP3)            printf '%s' '3. Alternatively, use MLX-Video/MLX image generation scripts directly.' ;;
        MODEL_START_GLOBAL_TITLE)         printf '%s' 'Global Model Path:' ;;
        MODEL_START_GLOBAL_DESC)          printf '%s' 'You can manually copy or symlink this directory to other applications:' ;;
        MODEL_START_NONE_INSTALLED)       printf '%s' 'No models are currently installed.' ;;
        MODEL_START_DOWNLOAD_HINT)        printf '%s' 'To download Qwen3, Stable Diffusion, or FLUX MLX models, run:' ;;
        MODEL_START_VERIFY_OK)            printf '%s' 'Model repository verification complete.' ;;
        MODEL_START_ACTION_UPDATE)        printf '%s' '• Update models:' ;;
        MODEL_START_ACTION_INTEGRITY)     printf '%s' '• Check integrity:' ;;
        MODEL_START_ACTION_FREE)          printf '%s' '• Free up space:' ;;
        MODEL_START_ACTION_FREE_NOTE)     printf '%s' '(then manually delete specific model folders)' ;;
        MODEL_STATUS_INCOMPLETE_2)        printf '%s' 'Incomplete/Verifying' ;;
        MODEL_STATUS_NOT_INIT_TAG)        printf '%s' 'NOT INITIALIZED' ;;
        MODEL_STATUS_NO_DIR)              printf '%s' 'The centralized model directory does not exist yet.' ;;
        MODEL_STATUS_INVENTORY)           printf '%s' 'Downloaded MLX Models Inventory:' ;;
        MODEL_STATUS_EMPTY)               printf '%s' '(Directory is empty. No models downloaded yet.)' ;;
        MODEL_STATUS_TOTAL_USED)          printf '%s' 'Total Storage Used:' ;;
        MODEL_STATUS_STORAGE_CTX)         printf '%s' 'Storage Context:' ;;
        MODEL_STATUS_SPACE_LOW)           printf '%s' '[WARN] Available space on model partition: %s (Low! Large models may fail to download)' ;;
        MODEL_STATUS_SPACE_OK)            printf '%s' '[OK] Available space on model partition: %s' ;;
        MODEL_STATUS_ACTION_DL)           printf '%s' '• Download new models:' ;;
        MODEL_STATUS_ACTION_UPDATE)       printf '%s' '• Update model weights:' ;;
        MODEL_STATUS_ACTION_VERIFY)       printf '%s' '• Verify integrity:' ;;
        MODEL_STATUS_ACTION_REMOVE)       printf '%s' '• Remove specific model:' ;;
        MODEL_STATUS_TIP_SHARED)          printf '%s' 'Tip: This directory is shared across ComfyUI, MLX-Video, and custom scripts to save disk space.' ;;
        MODEL_STATUS_READY)               printf '%s' 'Ready' ;;
        MODEL_STATUS_INCOMPLETE)          printf '%s' 'Incomplete/Corrupted' ;;
        MODEL_STATUS_PARTIAL)             printf '%s' 'Partial/Verifying' ;;
        MODEL_STOP_STATIC)                printf '%s' 'The '\''%s'\'' component is a static asset repository.' ;;
        MODEL_STOP_NO_SERVICE)            printf '%s' 'It does not run as a background service and does not consume CPU/GPU resources on its own.' ;;
        MODEL_STOP_FREE_HINT)             printf '%s' 'To free up system resources (VRAM/RAM), you should stop the components that are currently loading these models:' ;;
        MODEL_STOP_RUNNING_WARN)          printf '%s' '[WARN] The following components are currently running and may be holding models in memory:' ;;
        MODEL_STOP_ALL_FREE)              printf '%s' 'No inference components are currently running. Your system resources are fully available.' ;;
        MODEL_STOP_NO_ACTION)             printf '%s' 'No action required for '\''%s'\''. Component state is preserved.' ;;
        MODEL_UPDATE_USAGE)               printf '%s' 'Usage: ./ai-studio.sh update %s [--target <models|architecture|all>]' ;;
        MODEL_UPDATE_NO_DIR)              printf '%s' 'Model directory does not exist: %s' ;;
        MODEL_UPDATE_TOOLCHAIN)           printf '%s' 'Updating model management toolchain...' ;;
        MODEL_UPDATE_TOOLCHAIN_OK)        printf '%s' 'Model management toolchain is up to date.' ;;
        MODEL_UPDATE_TOOLCHAIN_FAILED)    printf '%s' 'Failed to update model management dependencies.' ;;
        MODEL_UPDATE_CHECKING_HF)         printf '%s' 'Checking for model weight updates on Hugging Face...' ;;
        MODEL_UPDATE_CHECKING)            printf '%s' 'Checking: %s' ;;
        MODEL_UPDATE_UNKNOWN_SRC)         printf '%s' '-> Unknown source repository. Skipping automatic update.' ;;
        MODEL_UPDATE_MANUAL_NOTE)         printf '%s' '(This model may have been added manually. To update, re-run install or update manually.)' ;;
        MODEL_UPDATE_SYNC_OK)             printf '%s' '-> Synced successfully. (Up to date or updated)' ;;
        MODEL_UPDATE_SYNC_FAILED)         printf '%s' '-> Failed to sync. Check network or Hugging Face access.' ;;
        MODEL_UPDATE_NO_MODELS)           printf '%s' 'No models found in %s. Nothing to update.' ;;
        MODEL_UPDATE_SYNC_SUMMARY)        printf '%s' 'Model sync complete: Checked %s, Successfully synced %s.' ;;
        MODEL_UPDATE_TIP_LICENSE)         printf '%s' 'Tip: Ensure you have accepted the model license on Hugging Face if it'\''s a gated model.' ;;
        MODEL_UPDATE_RESTART_1)           printf '%s' 'Running components (like ComfyUI or Ollama) may need to be restarted' ;;
        MODEL_UPDATE_RESTART_2)           printf '%s' 'to load the newly updated model weights into memory.' ;;
        MODEL_UNINSTALL_USAGE)            printf '%s' 'Usage: ./ai-studio.sh uninstall %s [--keep-data] [--purge-models] [--force]' ;;
        MODEL_UNINSTALL_DEFAULT_NOTE)     printf '%s' 'Note: By default, this command ONLY removes management scripts and keeps your models safe.' ;;
        MODEL_UNINSTALL_NOTHING)          printf '%s' '%s management files do not appear to exist. Nothing to uninstall.' ;;
        MODEL_UNINSTALL_WARN_BANNER)      printf '%s' '[WARN] CRITICAL DATA DESTRUCTION WARNING [WARN]' ;;
        MODEL_UNINSTALL_WARN_1)           printf '%s' 'You are about to permanently delete ALL downloaded MLX models.' ;;
        MODEL_UNINSTALL_WARN_2)           printf '%s' 'This includes large assets like Qwen3 35B, FLUX, and Stable Diffusion.' ;;
        MODEL_UNINSTALL_TARGET_DIR)       printf '%s' 'Target Directory: %s' ;;
        MODEL_UNINSTALL_SPACE_FREED)      printf '%s' 'Space to be freed: %s' ;;
        MODEL_UNINSTALL_UNDOABLE)         printf '%s' 'THIS ACTION CANNOT BE UNDONE.' ;;
        MODEL_UNINSTALL_CONFIRM_PROMPT)   printf '%s' 'Type '\''DELETE ALL MODELS'\'' to confirm permanent deletion:' ;;
        MODEL_UNINSTALL_CONFIRMED)        printf '%s' 'Confirmation received. Proceeding with model deletion...' ;;
        MODEL_UNINSTALL_CANCELLED)        printf '%s' 'Uninstallation cancelled. Your models are safe.' ;;
        MODEL_UNINSTALL_LOG_CLEARED)      printf '%s' 'Cleared model manager log file.' ;;
        MODEL_UNINSTALL_CONF_CLEARED)     printf '%s' 'Cleared model configuration file.' ;;
        MODEL_UNINSTALL_PRESERVED_AT)     printf '%s' 'Model assets preserved at: %s' ;;
        MODEL_UNINSTALL_ONLY_LOGS)        printf '%s' 'Only management logs and configs were removed. You can reinstall the manager anytime.' ;;
        MODEL_UNINSTALL_DELETING)         printf '%s' 'Permanently deleting model directory: %s' ;;
        MODEL_UNINSTALL_DELETED)          printf '%s' 'Model assets successfully deleted. Disk space has been freed.' ;;
        MODEL_UNINSTALL_DELETE_FAILED)    printf '%s' 'Failed to delete model directory. You may need to remove it manually with sudo.' ;;
        MODEL_UNINSTALL_DEFAULT_MODE)     printf '%s' 'Default mode: Preserving all downloaded model weights.' ;;
        MODEL_UNINSTALL_DEFAULT_MODE_2)   printf '%s' 'This will only remove AI Studio management logs and configurations.' ;;
        MODEL_UNINSTALL_DONE)             printf '%s' '%s management has been successfully uninstalled!' ;;
        MODEL_UNINSTALL_STILL_INTACT)     printf '%s' 'Your models are still intact at: %s' ;;
        MODEL_UNINSTALL_STILL_ACCESSIBLE) printf '%s' 'Other components (like ComfyUI) can still access them if configured.' ;;
        MODEL_UNINSTALL_ALL_DELETED)      printf '%s' 'All local model weights have been permanently deleted.' ;;
        MODEL_UNINSTALL_NEED_REDOWNLOAD)  printf '%s' 'You will need to re-download them to use image/LLM generation features.' ;;
        MODEL_DIAG_DIR_MISSING)           printf '%s' 'CRITICAL: Model directory does not exist.' ;;
        MODEL_DIAG_HINT_INSTALL)          printf '%s' '-> Run '\''./ai-studio.sh install model'\'' to create it and download models.' ;;
        MODEL_DIAG_DIR_NOT_WRITABLE)      printf '%s' 'CRITICAL: Model directory exists but is not writable.' ;;
        MODEL_DIAG_DIR_NOT_WRITABLE_HINT) printf '%s' '-> Model downloads and updates will fail.' ;;
        MODEL_DIAG_DIR_OK)                printf '%s' 'OK: Model directory is accessible and writable.' ;;
        MODEL_DIAG_MODEL_EMPTY)           printf '%s' 'CRITICAL: Model '\''%s'\'' appears empty or corrupted.' ;;
        MODEL_DIAG_MODEL_EMPTY_HINT)      printf '%s' '-> Missing both config.json and weight files (.safetensors/.npz).' ;;
        MODEL_DIAG_MODEL_INCOMPLETE)      printf '%s' 'WARNING: Model '\''%s'\'' is incomplete.' ;;
        MODEL_DIAG_MODEL_INCOMPLETE_HINT) printf '%s' '-> Missing either config.json or weight files. Download may have been interrupted.' ;;
        MODEL_DIAG_NO_MODELS)             printf '%s' 'INFO: No models found in directory. (Not an error, but nothing to verify.)' ;;
        MODEL_DIAG_ALL_OK)                printf '%s' 'OK: All discovered models appear structurally complete.' ;;
        MODEL_DIAG_DISK_UNKNOWN)          printf '%s' 'WARNING: Could not determine available disk space.' ;;
        MODEL_DIAG_DISK_CRITICAL)         printf '%s' 'CRITICAL: Less than 20GB of free space remaining on model partition.' ;;
        MODEL_DIAG_DISK_CRITICAL_HINT)    printf '%s' '-> Downloading large MLX models (e.g., FLUX, 35B LLMs) will likely fail.' ;;
        MODEL_DIAG_DISK_WARN)             printf '%s' 'WARNING: Less than 50GB of free space remaining.' ;;
        MODEL_DIAG_DISK_WARN_HINT)        printf '%s' '-> You may run out of space when downloading additional large models.' ;;
        MODEL_DIAG_DISK_OK)               printf '%s' 'OK: Sufficient disk space available (%sGB).' ;;
        MODEL_DIAG_HF_MISSING)            printf '%s' 'CRITICAL: '\''huggingface-cli'\'' is not installed or not in PATH.' ;;
        MODEL_DIAG_HF_REQUIRED)           printf '%s' '-> Required for downloading and updating models.' ;;
        MODEL_DIAG_HF_BROKEN)             printf '%s' 'WARNING: '\''huggingface-cli'\'' is present but fails to execute.' ;;
        MODEL_DIAG_HF_TRANSFER_MISSING)   printf '%s' 'WARNING: '\''hf-transfer'\'' Python package is missing.' ;;
        MODEL_DIAG_HF_TRANSFER_HINT)      printf '%s' '-> Model downloads will be significantly slower. Run '\''./ai-studio.sh install model'\'' to fix.' ;;
        MODEL_DIAG_TOOLCHAIN_OK)          printf '%s' 'OK: Model download toolchain is healthy.' ;;
        MODEL_DIAG_FIX_PERMS)             printf '%s' '-> Attempting to fix model directory permissions...' ;;
        MODEL_DIAG_FIX_PERMS_OK)          printf '%s' 'Model directory permissions repaired.' ;;
        MODEL_DIAG_FIX_TOOLCHAIN)         printf '%s' '-> Attempting to repair model download toolchain...' ;;
        MODEL_DIAG_FIX_TOOLCHAIN_OK)      printf '%s' 'Toolchain dependencies repaired.' ;;
        MODEL_DIAG_FIX_TOOLCHAIN_FAILED)  printf '%s' 'Failed to repair toolchain. Please run '\''./ai-studio.sh install model'\'' manually.' ;;
        MODEL_DIAG_NOTE_STATIC)           printf '%s' 'Note: Models are static assets and do not run as background services.' ;;
        MODEL_DIAG_RUNNING_CHECKS)        printf '%s' 'Running model repository specific checks...' ;;
        MODEL_DIAG_SKIP_INTEGRITY)        printf '%s' 'Skipped (Use --deep to check model file integrity)' ;;
        MODEL_DIAG_SKIP_DISK)             printf '%s' 'Skipped (Use --deep to check storage capacity)' ;;
        MODEL_DIAG_SKIP_TOOLCHAIN)        printf '%s' 'Skipped (Use --deep to check download tools)' ;;
        MODEL_DIAG_TIP_DEEP_FIX)          printf '%s' 'Tip: Run with '\''--deep --fix'\'' to attempt automatic resolution of fixable issues (e.g., permissions, missing tools).' ;;
        MODEL_DIAG_CORRUPT_MANUAL)        printf '%s' 'Note: Corrupted model files must be deleted manually or re-downloaded.' ;;
        MODEL_DIAG_DONE_DEEP_OK)          printf '%s' 'Deep diagnosis completed. The model repository is healthy and ready for use.' ;;
        MODEL_DIAG_DONE_BASIC_OK)         printf '%s' 'Basic diagnosis completed. The model repository is accessible.' ;;


        # —— 组件描述（registry.sh 的 list 与 metadata.sh 的 install 横幅共用同一真源） ——
        DESC_OPEN_WEBUI)                  printf '%s' 'Powerful and feature-rich local LLM Web UI' ;;
        DESC_SILLYTAVERN)                 printf '%s' 'Advanced LLM roleplay and chatting frontend' ;;
        DESC_CONTINUE_DEV)                printf '%s' 'Open-source AI coding assistant for VS Code / JetBrains' ;;
        DESC_FAZM)                        printf '%s' 'Native macOS AI Desktop Agent' ;;
        DESC_BROWSER_USE)                 printf '%s' 'AI-driven browser automation and web scraping tool' ;;
        DESC_MLX)                         printf '%s' 'Apple'\''s machine learning framework optimized for Apple Silicon' ;;
        DESC_COMFYUI)                     printf '%s' 'Powerful node-based image generation UI (SDXL/FLUX support)' ;;
        DESC_MLX_VIDEO)                   printf '%s' 'Efficient local video generation tool powered by MLX' ;;
        DESC_QWEN3)                       printf '%s' 'Uncensored QWen3 LLM via Ollama' ;;
        DESC_MODEL)                       printf '%s' 'Centralized MLX model repository manager (LLMs, SD, FLUX)' ;;
        DESC_UNKNOWN)                     printf '%s' 'Unknown component' ;;


        # —— lib：通用工具 / 配置 / 交互 UI / 浏览器 ——
        LIB_WAIT_PORT)                    printf '%s' 'Waiting for service on port %s to be ready (timeout: %ss)...' ;;
        LIB_TIMEOUT_PORT)                 printf '%s' 'Timeout waiting for port %s to open.' ;;
        LIB_PORT_READY)                   printf '%s' 'Service on port %s is ready.' ;;
        LIB_NEED_SUDO)                    printf '%s' 'This operation requires administrator privileges.' ;;
        LIB_SUDO_HINT)                    printf '%s' 'Please run with sudo: sudo %s' ;;
        LIB_DIR_CREATED)                  printf '%s' 'Created directory: %s' ;;
        LIB_MACOS_OPTIMIZED)              printf '%s' 'AI Studio is currently optimized for macOS.' ;;
        LIB_DETECTED_OS)                  printf '%s' 'Detected OS: %s' ;;
        LIB_LINUX_EXPERIMENTAL)           printf '%s' 'Linux support is experimental. Some features may not work.' ;;
        LIB_APPLE_SILICON_DISABLED)       printf '%s' 'Apple Silicon-specific components (MLX, MLX-Video) will be disabled.' ;;
        LIB_UNSUPPORTED_PLATFORM)         printf '%s' 'Unsupported platform. Please use macOS 13+ for full functionality.' ;;
        CONFIG_INVALID_KEY)               printf '%s' 'Error: Invalid configuration key: %s' ;;
        UI_INVALID_INPUT)                 printf '%s' 'Invalid input. Please match the required format.' ;;
        UI_NO_OPTIONS)                    printf '%s' 'No options provided to select_from_list.' ;;
        UI_CANCEL_OPTION)                 printf '%s' '0) Cancel' ;;
        UI_CHOICE_PROMPT)                 printf '%s' 'Enter your choice (0-%s):' ;;
        UI_INVALID_SELECTION)             printf '%s' 'Invalid selection. Please enter a number between 0 and %s.' ;;
        UI_NO_TABLE_DATA)                 printf '%s' 'No data provided for table.' ;;
        BROWSER_AUTO_DISABLED)            printf '%s' 'Auto-open browser is disabled in config. Skipping opening: %s' ;;
        BROWSER_INVALID_URL)              printf '%s' 'Invalid URL provided to open_browser: %s' ;;
        BROWSER_OPENING)                  printf '%s' 'Opening browser to: %s' ;;
        BROWSER_OPENED)                   printf '%s' 'Browser opened successfully.' ;;
        BROWSER_OPEN_FAILED)              printf '%s' 'Failed to automatically open the browser via command line.' ;;
        BROWSER_MANUAL_HINT)              printf '%s' 'Please manually open your browser and navigate to: %s' ;;
        BROWSER_WAITING_PORT)             printf '%s' 'Waiting for service on port %s before opening browser...' ;;
        BROWSER_PORT_NOT_READY)           printf '%s' 'Service on port %s did not become ready within %s seconds.' ;;
        BROWSER_MAYBE_STARTING)           printf '%s' 'The service might still be starting up in the background, or it may have failed.' ;;
        BROWSER_TRY_MANUAL)               printf '%s' 'You can manually try accessing: %s' ;;
        BROWSER_CHECK_LOGS)               printf '%s' 'Or check the logs: %s (Note: check component status instead)' ;;
        BROWSER_FORCE_INVALID_URL)        printf '%s' 'Invalid URL provided to force_open_browser: %s' ;;
        BROWSER_FORCE_OPENING)            printf '%s' 'Force opening browser to: %s' ;;
        BROWSER_FORCE_FAILED)             printf '%s' 'Failed to open browser. Please navigate manually to: %s' ;;


        # —— lib：诊断 / 进程管理 / 环境检查 / 环境安装 ——
        LIBDIAG_FILES_MISSING)        printf '%s' 'CRITICAL: Component directory missing.' ;;
        LIBDIAG_SCRIPTS_MISSING)      printf '%s' 'WARNING: Installation scripts missing or not executable.' ;;
        LIBDIAG_FILES_OK)             printf '%s' 'OK: Component files present.' ;;
        LIBDIAG_PROC_ORPHAN)          printf '%s' 'WARNING: Process is running but appears orphaned/zombie.' ;;
        LIBDIAG_PROC_OK)              printf '%s' 'OK: Process is running.' ;;
        LIBDIAG_PROC_PORT)            printf '%s' 'WARNING: Process running, but port %s is not listening.' ;;
        LIBDIAG_STOPPED_PORT_BUSY)    printf '%s' 'WARNING: Component is stopped, but port %s is occupied by another process.' ;;
        LIBDIAG_STOPPED)              printf '%s' 'INFO: Component is currently stopped.' ;;
        LIBDIAG_NO_LOG)               printf '%s' 'INFO: No log file found yet.' ;;
        LIBDIAG_LOG_ERRORS)           printf '%s' 'WARNING: Recent log contains potential errors:' ;;
        LIBDIAG_LOG_OK)               printf '%s' 'OK: No critical errors in recent logs.' ;;
        LIBDIAG_DISK_LOW)             printf '%s' 'CRITICAL: Less than 20GB disk space remaining. Model downloads/operations may fail.' ;;
        LIBDIAG_SWAP_HIGH)            printf '%s' 'WARNING: High swap memory usage detected. System may be thrashing.' ;;
        LIBDIAG_RESOURCES_OK)         printf '%s' 'OK: System resources are adequate.' ;;
        LIBDIAG_DEP_MISSING)          printf '%s' 'CRITICAL: Missing required dependency: %s' ;;
        LIBDIAG_DEP_OK)               printf '%s' 'OK: All declared dependencies are satisfied.' ;;
        LIBDIAG_SIMPLE_RUNNING)       printf '%s' 'Running simple diagnosis for %s...' ;;
        LIBDIAG_DEEP_RUNNING)         printf '%s' 'Running deep diagnosis for %s...' ;;
        LIBDIAG_CONFIG_OK)            printf '%s' 'OK: Configuration file syntax appears valid.' ;;
        LIBDIAG_CONFIG_WARN)          printf '%s' 'WARNING: Configuration file may be malformed.' ;;
        LIBDIAG_AUTOFIX)              printf '%s' 'Attempting automatic repairs for %s...' ;;
        LIBDIAG_FIX_PID)              printf '%s' '-> Clearing stale PID file for %s...' ;;
        LIBDIAG_FIX_PERMS2)           printf '%s' '-> Restoring execution permissions for component scripts...' ;;
        LIBDIAG_FIX_PORT)             printf '%s' '-> Port %s is occupied. Attempting to free it...' ;;
        LIBDIAG_FIX_APPLIED)          printf '%s' 'Applied %s automatic fix(es). Please run diagnosis again to verify.' ;;
        LIBDIAG_FIX_NONE)             printf '%s' 'No automatic fixes were applicable or necessary.' ;;
        LIBDIAG_UNKNOWN_FLAG)         printf '%s' 'Unknown diagnosis flag: %s' ;;
        LIBDIAG_ISSUES)               printf '%s' 'Diagnosis completed with %s issue(s) detected.' ;;
        LIBDIAG_TIP_DEEP_FIX)         printf '%s' 'Tip: Run with '\''--deep --fix'\'' to attempt automatic resolution.' ;;
        LIBDIAG_HEALTHY)              printf '%s' 'Diagnosis completed. No issues detected. %s is healthy.' ;;
        PROC_PID_SAVED)               printf '%s' 'Saved PID %s for %s' ;;
        PROC_PID_CLEARED)             printf '%s' 'Cleared PID file for %s' ;;
        PROC_ALREADY_RUNNING)         printf '%s' '%s is already running (PID: %s). Skipping start.' ;;
        PROC_STARTING)                printf '%s' 'Starting %s in background...' ;;
        PROC_COMMAND)                 printf '%s' 'Command: %s' ;;
        PROC_START_OK)                printf '%s' '%s started successfully (PID: %s).' ;;
        PROC_LOGS)                    printf '%s' 'Logs: %s' ;;
        PROC_START_FAIL)              printf '%s' '%s failed to start. PID %s exited immediately.' ;;
        PROC_CHECK_LOGS)              printf '%s' 'Check logs for details: %s' ;;
        PROC_NOT_RUNNING)             printf '%s' '%s is not running.' ;;
        PROC_STOPPING)                printf '%s' 'Stopping %s (PID: %s) gracefully...' ;;
        PROC_SIGTERM_TIMEOUT)         printf '%s' '%s did not respond to SIGTERM within %ss. Force killing...' ;;
        PROC_STOP_OK)                 printf '%s' '%s stopped successfully.' ;;
        PROC_STALE_CLEANED)           printf '%s' 'Cleaned stale PID for %s' ;;
        PROC_STALE_FILES)             printf '%s' 'Cleaned %s stale PID file(s).' ;;
        PROC_PORT_FREE)               printf '%s' 'Port %s is not in use.' ;;
        PROC_PORT_FORCE_KILL)         printf '%s' 'Force killing process on port %s...' ;;
        PROC_PORT_KILLED)             printf '%s' 'Process on port %s terminated.' ;;
        PROC_PORT_FREE_FAILED)        printf '%s' 'Failed to free port %s. Manual intervention required.' ;;
        PROC_PORT_NO_PID)             printf '%s' 'Could not identify PID for port %s.' ;;
        ENVCHECK_MACOS_START)         printf '%s' 'Checking macOS version...' ;;
        ENVCHECK_UNSUPPORTED_OS)      printf '%s' 'Unsupported operating system. AI Studio requires macOS.' ;;
        ENVCHECK_MACOS_OLD)           printf '%s' 'macOS version is too old. Found: %s, Required: %s.0 or later.' ;;
        ENVCHECK_MACOS_OK)            printf '%s' 'macOS version check passed (%s).' ;;
        ENVCHECK_HW_START)            printf '%s' 'Checking hardware architecture...' ;;
        ENVCHECK_HW_APPLE)            printf '%s' 'Hardware check passed: Apple Silicon (%s) detected. (Optimal for MLX/ComfyUI)' ;;
        ENVCHECK_HW_INTEL)            printf '%s' 'Hardware check passed: Intel (%s) detected. Note: MLX and MLX-Video components require Apple Silicon and will be disabled or run with limitations.' ;;
        ENVCHECK_HW_UNKNOWN)          printf '%s' 'Unknown hardware architecture: %s' ;;
        ENVCHECK_DISK_START)          printf '%s' 'Checking available disk space...' ;;
        ENVCHECK_DISK_LOW)            printf '%s' 'Insufficient disk space. Found: %sGB, Required: %sGB+.' ;;
        ENVCHECK_DISK_HINT)           printf '%s' 'Please free up disk space before proceeding.' ;;
        ENVCHECK_DISK_OK)             printf '%s' 'Disk space check passed (%sGB available).' ;;
        ENVCHECK_MEM_START)           printf '%s' 'Checking system memory...' ;;
        ENVCHECK_MEM_UNKNOWN)         printf '%s' 'Could not determine system memory. Skipping check.' ;;
        ENVCHECK_MEM_LOW)             printf '%s' 'System memory is below recommended minimum. Found: %sGB, Recommended: %sGB+.' ;;
        ENVCHECK_MEM_HINT)            printf '%s' 'Some large models (e.g., FLUX, large LLMs) may fail to load or run slowly.' ;;
        ENVCHECK_MEM_OK)              printf '%s' 'System memory check passed (%sGB).' ;;
        ENVCHECK_TOOLS_START)         printf '%s' 'Checking required command-line tools...' ;;
        ENVCHECK_MISSING_REQUIRED)    printf '%s' 'Missing required tools: %s' ;;
        ENVCHECK_INSTALL_HINT)        printf '%s' 'Run '\''./ai-studio.sh env install'\'' to automatically install missing dependencies.' ;;
        ENVCHECK_MISSING_RECOMMENDED) printf '%s' 'Missing recommended tools: %s' ;;
        ENVCHECK_INSTALL_REC_HINT)    printf '%s' 'It is highly recommended to run '\''./ai-studio.sh env install'\'' to install these for full functionality.' ;;
        ENVCHECK_TOOLS_OK)            printf '%s' 'All required and recommended tools are present.' ;;
        ENVCHECK_START)               printf '%s' 'Starting AI Studio Environment Check...' ;;
        ENVCHECK_PASSED)              printf '%s' 'Environment check PASSED. Your system is ready for deployment.' ;;
        ENVCHECK_FAILED)              printf '%s' 'Environment check FAILED with %s critical issue(s).' ;;
        ENVCHECK_FAILED_HINT)         printf '%s' 'Please resolve the issues above, or run '\''./ai-studio.sh env install'\'' to attempt automatic fixes.' ;;
        ENVCHECK_STATUS_TITLE)        printf '%s' '=== AI Studio Environment Status ===' ;;
        ENVCHECK_CORE_TOOLS)          printf '%s' 'Core Tools Status:' ;;
        ENVINSTALL_HOMEBREW_EXISTS)   printf '%s' 'Homebrew is already installed. Skipping.' ;;
        ENVINSTALL_HOMEBREW_INSTALLING)printf '%s' 'Installing Homebrew (this may prompt for your password)...' ;;
        ENVINSTALL_HOMEBREW_FAILED)   printf '%s' 'Failed to install Homebrew.' ;;
        ENVINSTALL_HOMEBREW_OK)       printf '%s' 'Homebrew installed and configured successfully.' ;;
        ENVINSTALL_BASIC_CHECK)       printf '%s' 'Checking basic command-line tools...' ;;
        ENVINSTALL_BASIC_OK_EXISTS)   printf '%s' 'All basic tools are already installed.' ;;
        ENVINSTALL_BASIC_INSTALLING)  printf '%s' 'Installing missing tools:%s ...' ;;
        ENVINSTALL_BASIC_FAILED)      printf '%s' 'Failed to install basic tools via Homebrew.' ;;
        ENVINSTALL_BASIC_OK)          printf '%s' 'Basic tools installed successfully.' ;;
        ENVINSTALL_RUNTIME_CHECK)     printf '%s' 'Checking runtime environments (Python, Node.js)...' ;;
        ENVINSTALL_PYTHON_INSTALLING) printf '%s' 'Installing Python 3...' ;;
        ENVINSTALL_PYTHON_FAILED)     printf '%s' 'Failed to install Python 3.' ;;
        ENVINSTALL_PYTHON_EXISTS)     printf '%s' 'Python 3 is already installed.' ;;
        ENVINSTALL_NODE_INSTALLING)   printf '%s' 'Installing Node.js (LTS)...' ;;
        ENVINSTALL_NODE_FAILED)       printf '%s' 'Failed to install Node.js.' ;;
        ENVINSTALL_NODE_EXISTS)       printf '%s' 'Node.js is already installed.' ;;
        ENVINSTALL_RUNTIME_OK)        printf '%s' 'Runtime environments are ready.' ;;
        ENVINSTALL_AI_CHECK)          printf '%s' 'Checking AI core tools...' ;;
        ENVINSTALL_OLLAMA_INSTALLING) printf '%s' 'Installing Ollama (required for local LLM execution)...' ;;
        ENVINSTALL_OLLAMA_FAILED)     printf '%s' 'Failed to install Ollama.' ;;
        ENVINSTALL_OLLAMA_OK)         printf '%s' 'Ollama installed successfully.' ;;
        ENVINSTALL_OLLAMA_EXISTS)     printf '%s' 'Ollama is already installed.' ;;
        ENVINSTALL_START)             printf '%s' 'Starting AI Studio Environment Installation...' ;;
        ENVINSTALL_NEED_PASSWORD)     printf '%s' 'This process may require your administrator password.' ;;
        ENVINSTALL_DONE)              printf '%s' 'Environment installation completed successfully!' ;;
        ENVINSTALL_READY)             printf '%s' 'Your system is now fully prepared for AI Studio.' ;;
        ENVINSTALL_FAILED_N)          printf '%s' 'Environment installation encountered %s error(s).' ;;
        ENVINSTALL_DEPS_CHECK)        printf '%s' 'Checking dependencies for %s...' ;;
        ENVINSTALL_DEPS_OK_EXISTS)    printf '%s' 'All dependencies for %s are already installed.' ;;
        ENVINSTALL_DEPS_INSTALLING)   printf '%s' 'Installing missing dependencies for %s:%s ...' ;;
        ENVINSTALL_DEPS_FAILED)       printf '%s' 'Failed to install dependencies for %s.' ;;
        ENVINSTALL_DEPS_OK)           printf '%s' 'Dependencies for %s installed successfully.' ;;


        # —— lib/env-check.sh：env status 的表格标签 ——
        ENVCHECK_LBL_OS)              printf '%s' 'OS' ;;
        ENVCHECK_LBL_ARCH)            printf '%s' 'Architecture' ;;
        ENVCHECK_LBL_MEM)             printf '%s' 'Total Memory' ;;
        ENVCHECK_LBL_DISK)            printf '%s' 'Available Disk' ;;
        ENVCHECK_INSTALLED)           printf '%s' 'Installed' ;;
        ENVCHECK_MISSING)             printf '%s' 'Missing' ;;


        # —— env/：Homebrew / Git LFS / 系统检查 ——
        ENVB_CHECKING)                printf '%s' 'Checking Homebrew installation status...' ;;
        ENVB_ALREADY)                 printf '%s' 'Homebrew is already installed and available.' ;;
        ENVB_UPDATING)                printf '%s' 'Running a quick '\''brew update'\'' to ensure everything is healthy...' ;;
        ENVB_NOT_FOUND)               printf '%s' 'Homebrew is not installed or not in the system PATH.' ;;
        ENVB_INSTALLING)              printf '%s' 'Starting automated Homebrew installation...' ;;
        ENVB_PASSWORD_NOTE)           printf '%s' '(Note: This may prompt for your macOS administrator password)' ;;
        ENVB_CURL_MISSING)            printf '%s' ''\''curl'\'' is required to download the Homebrew installer but is missing.' ;;
        ENVB_CURL_HINT)               printf '%s' 'Please install curl manually or ensure your system has basic command-line tools.' ;;
        ENVB_INSTALL_FAILED)          printf '%s' 'Homebrew installation failed with exit code %s.' ;;
        ENVB_INSTALL_HINT)            printf '%s' 'Please check your network connection or install manually from: https://brew.sh' ;;
        ENVB_INSTALL_OK)              printf '%s' 'Homebrew installed successfully!' ;;
        ENVB_APPLE_PATH)              printf '%s' 'Detected Apple Silicon. Homebrew installed to: %s' ;;
        ENVB_INTEL_PATH)              printf '%s' 'Detected Intel Mac. Homebrew installed to: %s' ;;
        ENVB_PROFILE_ADDING)          printf '%s' 'Adding Homebrew to your shell profile (%s)...' ;;
        ENVB_PROFILE_OK)              printf '%s' 'Homebrew PATH configured for current session and future logins.' ;;
        ENVB_PROFILE_EXISTS)          printf '%s' 'Homebrew PATH already exists in your shell profile.' ;;
        ENVB_VERIFY)                  printf '%s' 'Verification:' ;;
        ENVB_BANNER)                  printf '%s' 'AI Studio - Homebrew Installer' ;;
        ENVB_DONE)                    printf '%s' 'Homebrew setup completed successfully.' ;;
        ENVB_NEXT_INTRO)              printf '%s' 'You can now proceed to install other dependencies:' ;;
        ENVB_FAILED)                  printf '%s' 'Homebrew setup encountered an error.' ;;
        ENVL_VERSION_OK)              printf '%s' 'Git LFS v%s is already installed.' ;;
        ENVL_INSTALLING)              printf '%s' 'Installing Git LFS via Homebrew...' ;;
        ENVL_NEED_HOMEBREW)           printf '%s' 'Homebrew is required to install Git LFS, but it is not found.' ;;
        ENVL_HOMEBREW_HINT)           printf '%s' 'Please run '\''./env/install-homebrew.sh'\'' first.' ;;
        ENVL_GIT_MISSING)             printf '%s' 'Git is not detected. Installing Git alongside Git LFS...' ;;
        ENVL_GIT_FAILED)              printf '%s' 'Failed to install Git. Git LFS cannot function without it.' ;;
        ENVL_RUNNING_CMD)             printf '%s' 'Running: brew install git-lfs' ;;
        ENVL_INSTALL_FAILED)          printf '%s' 'Failed to install Git LFS via Homebrew.' ;;
        ENVL_INSTALL_OK)              printf '%s' 'Git LFS installed successfully.' ;;
        ENVL_CONFIGURING)             printf '%s' 'Configuring Git LFS globally...' ;;
        ENVL_CONFIG_OK)               printf '%s' 'Git LFS global hooks and filters configured.' ;;
        ENVL_CONFIG_DONE)             printf '%s' 'Git LFS configuration completed (may already be set up).' ;;
        ENVL_VERIFYING)               printf '%s' 'Verifying Git LFS functionality...' ;;
        ENVL_VERIFY_OK)               printf '%s' 'Git LFS is fully functional and ready for large file tracking.' ;;
        ENVL_VERIFY_FAILED)           printf '%s' 'Git LFS binary verification failed.' ;;
        ENVL_BANNER)                  printf '%s' 'AI Studio - Git LFS Installer' ;;
        ENVL_SUBTITLE)                printf '%s' 'Setting up large file support for AI models & datasets...' ;;
        ENVL_HEALTHY)                 printf '%s' 'Git LFS is already installed and healthy.' ;;
        ENVL_DONE)                    printf '%s' 'Git LFS setup completed successfully.' ;;
        ENVL_NEXT_1)                  printf '%s' 'Git LFS is now globally configured for your user account.' ;;
        ENVL_NEXT_2)                  printf '%s' 'When cloning repositories containing AI models, LFS files will download automatically.' ;;
        ENVL_MANUAL_TITLE)            printf '%s' 'Manual LFS operations (if needed):' ;;
        ENVL_MANUAL_PULL)             printf '%s' 'Pull large files manually: git lfs pull' ;;
        ENVL_MANUAL_TRACK)            printf '%s' 'Track a new file type: git lfs track '\''*.safetensors'\''' ;;
        ENVL_MANUAL_LIST)             printf '%s' 'List tracked patterns: git lfs track' ;;
        ENVL_FAILED)                  printf '%s' 'Git LFS setup encountered an error.' ;;
        ENVL_TS_1)                    printf '%s' '1. Ensure Homebrew is installed and up to date: brew doctor' ;;
        ENVL_TS_2)                    printf '%s' '2. Verify Git installation: git --version' ;;
        ENVL_TS_3)                    printf '%s' '3. Visit https://git-lfs.com for manual installation instructions.' ;;
        ENVC_BANNER)                  printf '%s' 'AI Studio - System Environment Check' ;;
        ENVC_SUBTITLE)                printf '%s' 'Verifying macOS compatibility and dependencies...' ;;
        ENVC_PASSED)                  printf '%s' 'System check PASSED. Your environment is ready for deployment.' ;;
        ENVC_NEXT_1)                  printf '%s' '1. Install missing dependencies (if any were flagged as recommended):' ;;
        ENVC_NEXT_2)                  printf '%s' '2. Install your first AI component:' ;;
        ENVC_FAILED)                  printf '%s' 'System check FAILED. Please resolve the issues above before proceeding.' ;;
        ENVC_RECOMMENDED_ACTION)      printf '%s' 'Recommended Action:' ;;
        ENVC_RECOMMENDED_DESC)        printf '%s' 'Run the automated environment installer to fix missing dependencies:' ;;


        # —— env/：Python / Node.js / Ollama / Xcode CLI ——
        ENVP_VERSION_OK)              printf '%s' 'Python %s is installed and meets the minimum requirement (>= %s.%s).' ;;
        ENVP_VERSION_LOW)             printf '%s' 'Found Python %s, but version >= %s.%s is required.' ;;
        ENVP_INSTALLING)              printf '%s' 'Installing Python %s via Homebrew...' ;;
        ENVP_NEED_HOMEBREW)           printf '%s' 'Homebrew is required to install Python, but it is not found.' ;;
        ENVP_HOMEBREW_HINT)           printf '%s' 'Please run '\''./env/install-homebrew.sh'\'' first.' ;;
        ENVP_RUNNING_CMD)             printf '%s' 'Running: brew install python@%s' ;;
        ENVP_INSTALL_FAILED)          printf '%s' 'Failed to install Python %s via Homebrew.' ;;
        ENVP_INSTALL_OK)              printf '%s' 'Python %s installed successfully.' ;;
        ENVP_PREFIX_UNKNOWN)          printf '%s' 'Could not determine Homebrew prefix for Python. You may need to configure PATH manually.' ;;
        ENVP_PATH_EXISTS)             printf '%s' 'Python PATH is already configured in %s.' ;;
        ENVP_PATH_ADDING)             printf '%s' 'Adding Python %s to your shell profile (%s)...' ;;
        ENVP_PATH_OK)                 printf '%s' 'Python environment configured and activated for the current session.' ;;
        ENVP_PATH_OLD)                printf '%s' 'Python PATH updated, but version check still shows old version. You may need to restart your terminal.' ;;
        ENVP_TOOLCHAIN)               printf '%s' 'Ensuring Python packaging toolchain is up to date...' ;;
        ENVP_TOOLCHAIN_FAILED)        printf '%s' 'Failed to upgrade pip/setuptools/wheel. Some component installations might require manual intervention.' ;;
        ENVP_TOOLCHAIN_OK)            printf '%s' 'Python packaging toolchain (pip, setuptools, wheel) is ready.' ;;
        ENVP_VENV_MISSING)            printf '%s' 'Python '\''venv'\'' module is missing. This is required for isolated component environments.' ;;
        ENVP_VENV_OK)                 printf '%s' 'Python virtual environment (venv) support is verified.' ;;
        ENVP_BANNER)                  printf '%s' 'AI Studio - Python Environment Installer' ;;
        ENVP_HEALTHY)                 printf '%s' 'Python environment is already healthy.' ;;
        ENVP_DONE)                    printf '%s' 'Python setup completed successfully.' ;;
        ENVP_NEXT_INTRO)              printf '%s' 'You can now proceed to install other core dependencies:' ;;
        ENVP_FAILED)                  printf '%s' 'Python setup encountered an error.' ;;
        ENVP_TS_1)                    printf '%s' '1. Ensure you have a stable internet connection.' ;;
        ENVP_TS_2)                    printf '%s' '2. Check if Xcode Command Line Tools are installed: xcode-select --install' ;;
        ENVN_VERSION_OK)              printf '%s' 'Node.js v%s is installed and meets the minimum requirement (>= v%s).' ;;
        ENVN_VERSION_LOW)             printf '%s' 'Found Node.js v%s, but version >= v%s is required.' ;;
        ENVN_INSTALLING)              printf '%s' 'Installing Node.js (LTS) via Homebrew...' ;;
        ENVN_NEED_HOMEBREW)           printf '%s' 'Homebrew is required to install Node.js, but it is not found.' ;;
        ENVN_RUNNING_CMD)             printf '%s' 'Running: brew install %s' ;;
        ENVN_INSTALL_FAILED)          printf '%s' 'Failed to install Node.js via Homebrew.' ;;
        ENVN_INSTALL_OK)              printf '%s' 'Node.js installed successfully.' ;;
        ENVN_TOOLCHAIN)               printf '%s' 'Ensuring Node.js packaging toolchain is ready...' ;;
        ENVN_NPM_UPDATING)            printf '%s' 'Updating npm...' ;;
        ENVN_NPM_FAILED)              printf '%s' 'Failed to update npm globally. You may need to run this with sudo or fix npm permissions.' ;;
        ENVN_NPM_OK)                  printf '%s' 'npm updated to latest version.' ;;
        ENVN_TOOLS_MISSING)           printf '%s' 'Core Node.js tools are missing after installation: %s' ;;
        ENVN_TOOLS_HINT)              printf '%s' 'You may need to restart your terminal or manually configure your PATH.' ;;
        ENVN_TOOLS_OK)                printf '%s' 'Node.js toolchain (node, npm, npx) is verified and ready.' ;;
        ENVN_NPM_CONFIG)              printf '%s' 'Configuring npm to install global packages without sudo...' ;;
        ENVN_NPM_PATH_ADDING)         printf '%s' 'Adding npm global bin to your shell profile (%s)...' ;;
        ENVN_NPM_PATH_OK)             printf '%s' 'npm global installation configured safely in user directory.' ;;
        ENVN_BANNER)                  printf '%s' 'AI Studio - Node.js Environment Installer' ;;
        ENVN_HEALTHY)                 printf '%s' 'Node.js environment is already healthy.' ;;
        ENVN_DONE)                    printf '%s' 'Node.js setup completed successfully.' ;;
        ENVN_NEXT_1)                  printf '%s' 'Your system is now ready to deploy Web-based AI components.' ;;
        ENVN_FAILED)                  printf '%s' 'Node.js setup encountered an error.' ;;
        ENVN_TS_1)                    printf '%s' '1. Check Homebrew status: brew doctor' ;;
        ENVN_TS_2)                    printf '%s' '2. Ensure you have a stable internet connection.' ;;
        ENVO_VERSION_OK)              printf '%s' 'Ollama v%s is already installed.' ;;
        ENVO_NOT_RESPONDING)          printf '%s' 'Ollama command exists but is not responding correctly.' ;;
        ENVO_INSTALLING)              printf '%s' 'Starting Ollama installation...' ;;
        ENVO_PASSWORD_NOTE)           printf '%s' '(Note: This will download the official installer and may prompt for your password)' ;;
        ENVO_CURL_MISSING)            printf '%s' ''\''curl'\'' is required to download the Ollama installer but is missing.' ;;
        ENVO_DOWNLOADING)             printf '%s' 'Downloading and executing official Ollama installer...' ;;
        ENVO_INSTALL_FAILED)          printf '%s' 'Ollama installation failed.' ;;
        ENVO_INSTALL_HINT)            printf '%s' 'Please check your network connection or install manually from: https://ollama.com' ;;
        ENVO_INSTALL_OK)              printf '%s' 'Ollama installed successfully!' ;;
        ENVO_SERVICE_CHECK)           printf '%s' 'Verifying Ollama background service status...' ;;
        ENVO_SERVICE_OK)              printf '%s' 'Ollama service is running in the background.' ;;
        ENVO_SERVICE_DOWN)            printf '%s' 'Ollama service is not running. Attempting to start it...' ;;
        ENVO_SERVICE_STARTED)         printf '%s' 'Ollama service started successfully.' ;;
        ENVO_SERVICE_FAILED)          printf '%s' 'Failed to start Ollama service automatically.' ;;
        ENVO_SERVICE_HINT)            printf '%s' 'You may need to log out and log back in, or start it manually via Spotlight.' ;;
        ENVO_FUNC_CHECK)              printf '%s' 'Performing quick functionality check...' ;;
        ENVO_API_OK)                  printf '%s' 'Ollama API is listening on port 11434.' ;;
        ENVO_API_DOWN)                printf '%s' 'Ollama port 11434 is not listening. The service might still be starting up.' ;;
        ENVO_CLI_OK)                  printf '%s' 'Ollama CLI is fully functional.' ;;
        ENVO_CLI_FAILED)              printf '%s' 'Ollama CLI failed to execute '\''ollama list'\''.' ;;
        ENVO_BANNER)                  printf '%s' 'AI Studio - Ollama Installer' ;;
        ENVO_SUBTITLE)                printf '%s' 'Setting up local LLM execution engine...' ;;
        ENVO_HEALTHY)                 printf '%s' 'Ollama is already installed and healthy.' ;;
        ENVO_DONE)                    printf '%s' 'Ollama setup completed successfully.' ;;
        ENVO_NEXT_1)                  printf '%s' '1. Pull your first model (e.g., QWen3 or Llama 3):' ;;
        ENVO_NEXT_2)                  printf '%s' '2. Deploy a UI to interact with it:' ;;
        ENVO_TIP_APPLE)               printf '%s' 'Tip: Ollama is natively optimized for Apple Silicon (M1/M2/M3/M4)' ;;
        ENVO_FAILED)                  printf '%s' 'Ollama setup encountered an error.' ;;
        ENVO_TS_2)                    printf '%s' '2. Check if Ollama is running via Activity Monitor or Spotlight.' ;;
        ENVO_TS_3)                    printf '%s' '3. Visit https://ollama.com for manual installation instructions.' ;;
        ENVX_VERSION_OK)              printf '%s' 'Xcode Command Line Tools are installed (Clang %s).' ;;
        ENVX_BROKEN)                  printf '%s' 'Xcode CLI path exists, but core tools (clang/make) are missing or broken.' ;;
        ENVX_NOT_INSTALLED)           printf '%s' 'Xcode Command Line Tools are not installed.' ;;
        ENVX_TRIGGERING)              printf '%s' 'Triggering macOS system installer for Command Line Tools...' ;;
        ENVX_DIALOG_NOTE)             printf '%s' 'A system dialog will appear shortly. Please click '\''Install'\'' and accept the license agreement.' ;;
        ENVX_PROMPT_ENTER)            printf '%s' '-> Press [Enter] once the installation window says '\''The software was installed'\''...' ;;
        ENVX_VERIFYING)               printf '%s' 'Verifying installation...' ;;
        ENVX_RESETTING)               printf '%s' 'Attempting to reset corrupted Command Line Tools installation...' ;;
        ENVX_RESET_PRIVILEGE)         printf '%s' 'This requires administrator privileges. You may be prompted for your password.' ;;
        ENVX_OLD_REMOVED)             printf '%s' 'Old Command Line Tools directory removed.' ;;
        ENVX_RERUN)                   printf '%s' 'Please run this script again to trigger a fresh installation.' ;;
        ENVX_REMOVE_FAILED)           printf '%s' 'Failed to remove old Command Line Tools. Please remove manually via Finder or Terminal.' ;;
        ENVX_BANNER)                  printf '%s' 'AI Studio - Xcode CLI Installer' ;;
        ENVX_SUBTITLE)                printf '%s' 'Setting up macOS compilation tools for AI dependencies...' ;;
        ENVX_HEALTHY)                 printf '%s' 'Xcode Command Line Tools are already installed and healthy.' ;;
        ENVX_CORRUPT_AT)              printf '%s' 'Detected a potentially corrupted installation at: %s' ;;
        ENVX_ABORT)                   printf '%s' 'Aborting. Please manually fix the installation at %s.' ;;
        ENVX_DONE)                    printf '%s' 'Xcode Command Line Tools setup completed successfully!' ;;
        ENVX_NEXT_1)                  printf '%s' 'Your Mac is now ready to compile AI packages.' ;;
        ENVX_NEXT_2)                  printf '%s' 'Proceed to install Homebrew and other dependencies:' ;;
        ENVX_FAILED)                  printf '%s' 'Verification failed. The installation may have been cancelled or failed.' ;;
        ENVX_TS_1)                    printf '%s' '1. If the popup didn'\''t appear, check System Settings > Software Update.' ;;
        ENVX_TS_2)                    printf '%s' '2. If it says '\''Cannot install software'\'', try: sudo rm -rf /Library/Developer/CommandLineTools' ;;
        ENVX_TS_3)                    printf '%s' '3. Then run this script again: ./env/install-xcode-cli.sh' ;;


        # —— tests/：测试输出文案 ——
        TEST_PASS)                    printf '%s' 'PASS: %s' ;;
        TEST_FAIL)                    printf '%s' 'FAIL: %s' ;;
        TEST_EXPECTED)                printf '%s' 'Expected: %s' ;;
        TEST_ACTUAL)                  printf '%s' 'Actual: %s' ;;
        TEST_CMD_EXISTS)              printf '%s' 'Command '\''%s'\'' exists' ;;
        TEST_CMD_NOT_FOUND)           printf '%s' 'Command '\''%s'\'' not found' ;;
        TEST_ASSERT_FAILED)           printf '%s' 'Assertion failed' ;;
        TEST_COMMON_FUNCS)            printf '%s' 'Testing common.sh functions...' ;;
        TEST_SUITE_TITLE)             printf '%s' 'AI Studio Test Suite' ;;
        TEST_RESULTS)                 printf '%s' 'Results: %s passed, %s failed' ;;
        TEST_LANG_SUITE)              printf '%s' 'Message Layer Test Suite (lib/lang.sh)' ;;
        TEST_LANG_DICT)               printf '%s' 'Checking dictionary integrity...' ;;
        TEST_LANG_DEFAULT)            printf '%s' 'Checking default language...' ;;
        TEST_LANG_SWITCH)             printf '%s' 'Checking language switching...' ;;
        TEST_LANG_NORMALIZE)          printf '%s' 'Checking language code normalization...' ;;
        TEST_LANG_REJECT)             printf '%s' 'Checking unsupported language rejection...' ;;
        TEST_LANG_FALLBACK)           printf '%s' 'Checking unknown key fallback...' ;;
        TEST_LANG_INTERP)             printf '%s' 'Checking message interpolation...' ;;
        TEST_SHELLCHECK_RUNNING)      printf '%s' 'Running ShellCheck on AI Studio scripts' ;;
        TEST_SHELLCHECK_OK)           printf '%s' 'All scripts passed ShellCheck!' ;;
        TEST_SHELLCHECK_FAILED)       printf '%s' 'Some scripts failed ShellCheck. Please fix the issues above.' ;;
        TEST_EMOJI_TITLE)             printf '%s' '==> Emoji check' ;;
        TEST_EMOJI_NO_FILES)          printf '%s' '[WARN] No files to scan. Skipping' ;;
        TEST_EMOJI_FOUND)             printf '%s' '[FAIL] Emoji or non-ASCII modifiers detected. Replace them with ASCII alternatives such as [OK] / [FAIL] / [WARN] / Tip: / ->:' ;;
        TEST_EMOJI_OK)                printf '%s' '[OK] Passed (no emoji found in the project)' ;;
        TEST_LANGCHECK_TITLE)         printf '%s' '==> Language policy check' ;;
        TEST_LANGCHECK_NO_FILES)      printf '%s' '[WARN] No files to scan. Skipping' ;;
        TEST_LANGCHECK_L1_TITLE)      printf '%s' 'Checking L1 composition layer (blocking): no non-ASCII in code outside comments and the dictionary...' ;;
        TEST_LANGCHECK_L1_FOUND)      printf '%s' '[FAIL] Non-ASCII characters found in code lines (whole-line and trailing comments excluded; lib/lang.sh and orphan files exempt):' ;;
        TEST_LANGCHECK_L1_OK)         printf '%s' '[OK] Passed (no non-ASCII left in composition-layer code)' ;;
        TEST_LANGCHECK_L2_TITLE)      printf '%s' 'Measuring L2 UI message-layer coverage (warning only, non-blocking)...' ;;
        TEST_LANGCHECK_L2_STAT)       printf '%s' 'msg/msgf calls: %s; hardcoded log_* literals remaining: %s; message-layer coverage: %s%%' ;;
        TEST_LANGCHECK_L2_WARN)       printf '%s' '[WARN] Message-layer coverage is below 95%. Continue migrating UI strings' ;;
        TEST_LANGCHECK_L2_OK)         printf '%s' '[OK] Message-layer coverage meets the target (>= 95%)' ;;

        *)                      printf '' ;;
    esac
}

# ---------------------------------------------------------------------------
# 对外接口
# ---------------------------------------------------------------------------

# msg KEY -> 输出当前语言词条（不带换行）
# 缺失时回退到另一语言，再缺失则输出 KEY 本身
msg() {
    local key out lang
    key="${1:-}"
    lang="$(lang_current)"

    if [[ "$lang" == "en" ]]; then
        out="$(msg_en "$key")"
        [[ -z "$out" ]] && out="$(msg_zh "$key")"
    else
        out="$(msg_zh "$key")"
        [[ -z "$out" ]] && out="$(msg_en "$key")"
    fi

    if [[ -z "$out" ]]; then
        out="$key"
    fi
    printf '%s' "$out"
}

# msgf KEY [args...] -> 词条作为 printf 格式串，支持变量插值，输出带换行
# shellcheck disable=SC2059
msgf() {
    local key fmt
    key="${1:-}"
    shift || true
    fmt="$(msg "$key")"
    # 注意：必须用 `--` 终止选项解析。部分词条以 `->` 开头（诊断提示类），
    # 若直接 `printf "${fmt}\n"`，printf 会把 `->` 当成命令行选项并报 invalid option。
    printf -- "${fmt}\n" "$@"
}

# ---------------------------------------------------------------------------
# CLI：lang 子命令
#   lang          显示当前语言
#   lang list     列出受支持的语言
#   lang set CODE 设定并持久化语言
# ---------------------------------------------------------------------------
lang_command() {
    local sub code
    sub="${1:-show}"

    case "$sub" in
        show|"")
            printf '%s\n' "$(lang_current)"
            ;;
        list)
            printf '%s\n' "$LANG_SUPPORTED"
            ;;
        set)
            code="${2:-}"
            if [[ -z "$code" ]]; then
                log_error "$(msg USAGE_HINT): ai-studio.sh lang set <zh|en>"
                return 1
            fi
            if lang_persist "$code"; then
                log_success "$(msg OPERATION_SUCCESS): $(lang_current)"
            else
                log_error "$(msg UNKNOWN_COMMAND): $code ($(msg USAGE_HINT): $(printf '%s' "$LANG_SUPPORTED" | tr ' ' '/'))"
                return 1
            fi
            ;;
        *)
            log_error "$(msg UNKNOWN_COMMAND): $sub"
            return 1
            ;;
    esac
}
