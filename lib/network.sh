#!/usr/bin/env bash
setup_proxy() { local p="${AI_STUDIO_PROXY:-}"; [[ -n "$p" ]] && { export http_proxy="$p" https_proxy="$p" HTTP_PROXY="$p" HTTPS_PROXY="$p"; log_debug "代理: $p"; }; }
setup_hf_mirror() { export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"; }
setup_pip_mirror() { export PIP_INDEX_URL="${PIP_MIRROR:-https://pypi.tuna.tsinghua.edu.cn/simple}"; export PIP_TRUSTED_HOST="$(echo "$PIP_INDEX_URL" | sed 's|https\?://||;s|/.*||')"; }
setup_npm_mirror() { check_command npm && npm config set registry "${NPM_MIRROR:-https://registry.npmmirror.com}" 2>/dev/null; }
setup_gh_mirror() { export GH_PROXY_PREFIX="${GH_PROXY:-}"; }
gh_url() { [[ -n "${GH_PROXY_PREFIX:-}" ]] && echo "${GH_PROXY_PREFIX}$1" || echo "$1"; }
check_internet() { curl -sf --connect-timeout 5 "${1:-https://github.com}" &>/dev/null; }
get_local_ip() { [[ "$AI_STUDIO_OS" == "macos" ]] && { ipconfig getifaddr en0 2>/dev/null || echo "127.0.0.1"; } || { hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"; }; }
