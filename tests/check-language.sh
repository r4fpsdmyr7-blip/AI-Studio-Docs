#!/bin/bash
# ============================================================================
# tests/check-language.sh - 语言策略门禁（L1 阻断 + L2 告警）
# ============================================================================
# 依据三层语言模型：
#   L1 构成层 = 标识符 / 代码 / 配置键 -> 英文 ASCII（硬规则，命中即阻断）
#   L2 UI 层  = 终端输出               -> 用户指定语言，统一走 lib/lang.sh 消息层
#
# 本脚本做两件事：
#   1. L1 校验（阻断）：扫描 .sh 代码行（剔除整行注释与行尾注释），
#      命中非 ASCII 即退出 1。
#      豁免：lib/lang.sh（词典本身含中文词条）、tests/test_lang.sh（词典断言
#      必须含中文字面量）、已标记 DEPRECATED 的孤儿文件
#      （commands/、lib/component.sh、lib/network.sh、lib/logger.sh）。
#   2. L2 统计（告警）：统计 msg/msgf 调用数与 log_* 硬编码字面量残留数，
#      计算消息层覆盖率，低于 95% 打印 [WARN]，但不影响退出码。
#
# 已知近似：行尾注释按「空白 + #」切分，字符串字面量内含 " #" 时会被误认为
# 注释（漏报而非误报）。该启发式在注释规范（# 前必有空白）下对本项目足够可靠。
#
# 运行：bash tests/check-language.sh   或   make lang
# ============================================================================

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 加载消息层，使检查输出与项目 UI 语言一致
source "$ROOT/lib/lang.sh" 2>/dev/null || true

# 收集待扫描脚本：已跟踪 + 未跟踪但未忽略，排除词典与 DEPRECATED 孤儿文件
FILES=""
while IFS= read -r line; do
    case "$line" in
        lib/lang.sh|lib/component.sh|lib/network.sh|lib/logger.sh|commands/*|tests/test_lang.sh)
            continue ;;
    esac
    if [[ -f "$line" ]]; then
        FILES="${FILES}${line}\n"
    fi
done < <(
    {
        git ls-files '*.sh' 2>/dev/null || true
        git ls-files --others --exclude-standard '*.sh' 2>/dev/null || true
    } | sort -u
)

echo "$(msg TEST_LANGCHECK_TITLE)"

if [[ -z "$FILES" ]]; then
    echo "  $(msg TEST_LANGCHECK_NO_FILES)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Gate 1（阻断）：L1 构成层非 ASCII 检查
# 剔除整行注释与行尾注释后，代码部分不得含非 ASCII 字符
# ---------------------------------------------------------------------------
echo "  $(msg TEST_LANGCHECK_L1_TITLE)"

l1_hits=$(printf '%b' "$FILES" | tr '\n' '\0' | xargs -0 \
    perl -CSD -ne '
        my $code = $_;
        $code =~ s/^\s*#.*$//;        # 整行注释
        $code =~ s/[ \t]#.*$//;       # 行尾注释（# 前必有空白）
        print "$ARGV:$.: $_" if $code =~ /[^\x00-\x7F]/;
        close ARGV if eof' 2>/dev/null)

l1_failed=0
if [[ -n "$l1_hits" ]]; then
    echo "  $(msg TEST_LANGCHECK_L1_FOUND)"
    printf '%s\n' "$l1_hits" | sed 's/^/    /'
    l1_failed=1
else
    echo "  $(msg TEST_LANGCHECK_L1_OK)"
fi

# ---------------------------------------------------------------------------
# Gate 2（告警）：L2 UI 层消息层覆盖率统计
# 覆盖率 = msg/msgf 调用行 / (msg/msgf 调用行 + log_* 硬编码字面量行)
# ---------------------------------------------------------------------------
echo "  $(msg TEST_LANGCHECK_L2_TITLE)"

msg_calls=$(printf '%b' "$FILES" | tr '\n' '\0' | xargs -0 \
    grep -cE '\$\(msgf? ' 2>/dev/null | awk -F: '{s += $NF} END {print s + 0}')
hardcoded=$(printf '%b' "$FILES" | tr '\n' '\0' | xargs -0 \
    grep -E 'log_(info|success|warn|error|debug) "' 2>/dev/null \
    | grep -vE '\$\(msgf? ' | wc -l | tr -d '[:space:]')

total=$((msg_calls + hardcoded))
if [[ $total -gt 0 ]]; then
    coverage=$((msg_calls * 100 / total))
else
    coverage=100
fi

echo "  $(msgf TEST_LANGCHECK_L2_STAT "$msg_calls" "$hardcoded" "$coverage")"
if [[ $coverage -lt 95 ]]; then
    echo "  $(msg TEST_LANGCHECK_L2_WARN)"
else
    echo "  $(msg TEST_LANGCHECK_L2_OK)"
fi

# 只有 L1 是阻断项；L2 仅告警
exit $l1_failed
