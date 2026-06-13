#!/usr/bin/env bash
# =============================================================================
# 配置管理 (兼容 Bash 3.2，不使用 declare -A)
# =============================================================================

# 用普通变量存储默认值
_cfg_default_GLOBAL_AUTO_OPEN_BROWSER="true"
_cfg_default_GLOBAL_LOG_LEVEL="1"
_cfg_default_GLOBAL_PROXY=""
_cfg_default_GLOBAL_HF_MIRROR="https://hf-mirror.com"
_cfg_default_GLOBAL_PIP_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
_cfg_default_GLOBAL_NPM_MIRROR="https://registry.npmmirror.com"
_cfg_default_GLOBAL_GH_PROXY=""
_cfg_default_OPEN_WEBUI_PORT="3000"
_cfg_default_SILLYTAVERN_PORT="8000"
_cfg_default_COMFYUI_PORT="8188"
_cfg_default_MLX_VIDEO_PORT="7860"
_cfg_default_BROWSER_USE_PORT="9222"
_cfg_default_FAZM_PORT="8501"
_cfg_default_OLLAMA_HOST="http://localhost:11434"

# 运行时配置存储（用 _cfg_VAL_<KEY> 变量）
_cfg_get_default() {
    local key="$1"
    local var="_cfg_default_${key}"
    echo "${!var:-}"
}

load_config() {
    local f="$AI_STUDIO_CONFIG_DIR/global.conf"
    [[ -f "$f" ]] || return 0
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# || -z "$k" ]] && continue
        k="$(echo "$k" | xargs)"
        v="$(echo "$v" | xargs | sed 's/^"//;s/"$//')"
        [[ -z "$k" ]] && continue
        # 存储到运行时变量
        eval "_cfg_VAL_${k}=\"\${v}\""
    done < "$f"
}

get_config() {
    local key="$1"
    local default_val="${2:-}"
    # 优先从运行时变量获取
    local var="_cfg_VAL_${key}"
    local val="${!var:-}"
    if [[ -n "$val" ]]; then
        echo "$val"
        return
    fi
    # 其次从默认值获取
    val="$(_cfg_get_default "$key")"
    if [[ -n "$val" ]]; then
        echo "$val"
        return
    fi
    echo "$default_val"
}

set_config() {
    local key="$1" value="$2"
    local f="$AI_STUDIO_CONFIG_DIR/global.conf"
    mkdir -p "$(dirname "$f")"
    # 更新运行时变量
    eval "_cfg_VAL_${key}=\"\${value}\""
    # 更新文件
    if [[ -f "$f" ]] && grep -q "^${key}=" "$f" 2>/dev/null; then
        # macOS 的 sed 需要 -i '' 格式
        sed -i '' "s|^${key}=.*|${key}=${value}|" "$f" 2>/dev/null || \
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$f" && rm -f "${f}.bak"
    else
        echo "${key}=${value}" >> "$f"
    fi
}

init_config() {
    local f="$AI_STUDIO_CONFIG_DIR/global.conf"
    mkdir -p "$(dirname "$f")"
    if [[ ! -f "$f" ]]; then
        {
            echo "# AI-Studio Config - $(date)"
            echo "# Generated automatically"
            echo ""
            for key in \
                GLOBAL_AUTO_OPEN_BROWSER GLOBAL_LOG_LEVEL GLOBAL_PROXY \
                GLOBAL_HF_MIRROR GLOBAL_PIP_MIRROR GLOBAL_NPM_MIRROR GLOBAL_GH_PROXY \
                OPEN_WEBUI_PORT SILLYTAVERN_PORT COMFYUI_PORT \
                MLX_VIDEO_PORT BROWSER_USE_PORT FAZM_PORT OLLAMA_HOST; do
                local val
                val="$(_cfg_get_default "$key")"
                echo "${key}=${val}"
            done
        } > "$f"
        log_info "已生成默认配置: $f"
    fi
    load_config
}

get_comp_config() {
    local comp="$1" key="$2" default_val="${3:-}"
    local f="$AI_STUDIO_CONFIG_DIR/${comp}.conf"
    if [[ -f "$f" ]]; then
        local v
        v="$(grep "^${key}=" "$f" 2>/dev/null | head -1 | cut -d= -f2-)"
        if [[ -n "$v" ]]; then
            echo "$v"
            return
        fi
    fi
    # 回退到全局配置
    get_config "${comp}_${key}" "$default_val"
}

set_comp_config() {
    local comp="$1" key="$2" value="$3"
    local f="$AI_STUDIO_CONFIG_DIR/${comp}.conf"
    mkdir -p "$(dirname "$f")"
    if [[ -f "$f" ]] && grep -q "^${key}=" "$f" 2>/dev/null; then
        sed -i '' "s|^${key}=.*|${key}=${value}|" "$f" 2>/dev/null || \
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$f" && rm -f "${f}.bak"
    else
        echo "${key}=${value}" >> "$f"
    fi
}

show_config() {
    local comp="${1:-}"
    local f="${comp:+$AI_STUDIO_CONFIG_DIR/${comp}.conf}"
    f="${f:-$AI_STUDIO_CONFIG_DIR/global.conf}"
    info_box "配置: ${comp:-global}"
    if [[ -f "$f" ]]; then
        cat "$f" | grep -v '^#' | grep '=' | while IFS='=' read -r k v; do
            [[ -n "$k" ]] && printf "    %-25s = %s\n" "$k" "$v"
        done
    else
        echo "    (配置文件不存在)"
    fi
}

reset_config() {
    local comp="${1:-global}"
    rm -f "$AI_STUDIO_CONFIG_DIR/${comp}.conf"
    [[ "$comp" == "global" ]] && init_config
    log_info "已重置配置: $comp"
}
