#!/usr/bin/env bash
# ============================================================================
# DEPRECATED - ORPHANED CODE (not wired into the main program)
#
# This file belongs to an abandoned command-dispatch layer. It is NOT
# referenced by ai-studio.sh or any active lib/ module, and it references
# symbols that do not exist (load_libs, REGISTERED_COMPONENTS, CLR_*,
# AI_STUDIO_DATA_DIR, ...), so it cannot run as-is.
# Kept for historical reference only.
#
# The active architecture is:
#   ai-studio.sh -> lib/*.sh -> components/registry.sh -> components/<name>/
#
# Do NOT build new features on top of this file. See AGENTS.md for details.
# ============================================================================
_log_write() { local l="$1"; shift; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$l] $*" >> "${AI_STUDIO_LOG_DIR:-/tmp}/ai-studio.log" 2>/dev/null; }
comp_log() { local c="$1" l="$2"; shift 2; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$l] $*" >> "$AI_STUDIO_LOG_DIR/${c}.log" 2>/dev/null; }
show_log() {
    local comp="${1:-}" lines="${2:-50}" logfile="${comp:+$AI_STUDIO_LOG_DIR/${comp}.log}"
    logfile="${logfile:-$AI_STUDIO_LOG_DIR/ai-studio.log}"
    [[ -f "$logfile" ]] && { echo -e "${CLR_CYAN}=== $logfile (最近 $lines 行) ===${CLR_RESET}"; tail -n "$lines" "$logfile"; } || log_warn "日志不存在: $logfile"
}
clean_logs() { find "$AI_STUDIO_LOG_DIR" -name "*.log" -mtime "+${1:-7}" -delete 2>/dev/null; log_info "已清理旧日志"; }
