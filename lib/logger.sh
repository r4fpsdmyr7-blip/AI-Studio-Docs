#!/usr/bin/env bash
_log_write() { local l="$1"; shift; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$l] $*" >> "${AI_STUDIO_LOG_DIR:-/tmp}/ai-studio.log" 2>/dev/null; }
comp_log() { local c="$1" l="$2"; shift 2; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$l] $*" >> "$AI_STUDIO_LOG_DIR/${c}.log" 2>/dev/null; }
show_log() {
    local comp="${1:-}" lines="${2:-50}" logfile="${comp:+$AI_STUDIO_LOG_DIR/${comp}.log}"
    logfile="${logfile:-$AI_STUDIO_LOG_DIR/ai-studio.log}"
    [[ -f "$logfile" ]] && { echo -e "${CLR_CYAN}=== $logfile (最近 $lines 行) ===${CLR_RESET}"; tail -n "$lines" "$logfile"; } || log_warn "日志不存在: $logfile"
}
clean_logs() { find "$AI_STUDIO_LOG_DIR" -name "*.log" -mtime "+${1:-7}" -delete 2>/dev/null; log_info "已清理旧日志"; }
