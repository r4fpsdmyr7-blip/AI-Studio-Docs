#!/bin/bash
# ============================================================================
# tests/check-emoji.sh - 全项目 emoji 扫描（CI 阻断项）
# ============================================================================
# 语言策略要求：构成层、UI 层、文档层一律不使用 emoji。
# 本脚本扫描全部入库文件（含未跟踪但未忽略的新文件），命中即返回非 0。
#
# 检测范围：
#   - emoji 主字符区      U+1F000-1FAFF / U+2600-27BF / U+2B00-2BFF
#   - 组合修饰符（残留）  U+FE0F 变体选择符 / U+20E3 键帽符 / U+200D 连接符
#   - keycap 序列         数字或 # * + FE0F? + 20E3（如 1 键帽）
#
# 两个已实测的坑：
#   1. 不要用 \p{Emoji_Presentation}：perl 5.34 会漏掉 text-default emoji
#      （实测漏 U+1F6E0 与 U+1F3D7 共 10 行）。必须用显式码点区间。
#   2. 多文件扫描必须加 `close ARGV if eof`，否则 $. 跨文件累加，行号全错。
#
# 运行：bash tests/check-emoji.sh   或   make emoji
# ============================================================================

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 加载消息层，使测试输出与项目 UI 语言一致
source "$ROOT/lib/lang.sh" 2>/dev/null || true

# 收集待扫描文件：已跟踪 + 未跟踪但未忽略
mapfile_compat() { :; }  # Bash 3.2 无 mapfile，改用逐行读取
FILES=""
while IFS= read -r line; do
    if [[ -f "$line" ]]; then
        FILES="${FILES}${line}\n"
    fi
done < <(
    {
        git ls-files 2>/dev/null || true
        git ls-files --others --exclude-standard 2>/dev/null || true
    } | sort -u
)

if [[ -z "$FILES" ]]; then
    echo "$(msg TEST_EMOJI_TITLE)"
    echo "  $(msg TEST_EMOJI_NO_FILES)"
    exit 0
fi

echo "$(msg TEST_EMOJI_TITLE)"

hits=$(printf '%b' "$FILES" | tr '\n' '\0' | xargs -0 \
    perl -CSD -ne 'print "$ARGV:$.: $_" if /[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}\x{20E3}\x{200D}]|[0-9#*]\x{FE0F}?\x{20E3}/; close ARGV if eof' 2>/dev/null)

if [[ -n "$hits" ]]; then
    echo "  $(msg TEST_EMOJI_FOUND)"
    printf '%s\n' "$hits" | sed 's/^/    /'
    exit 1
fi

echo "  $(msg TEST_EMOJI_OK)"
exit 0
