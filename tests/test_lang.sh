#!/bin/bash
# ============================================================================
# tests/test_lang.sh - 消息层（lib/lang.sh）自检
# ============================================================================
# 校验内容：
#   1. 每个词条 KEY 在 msg_zh 与 msg_en 中都存在且非空（成对新增约束）
#   2. 默认语言为中文
#   3. --lang / lang_set 切换生效
#   4. 语言代码归一化（zh_CN / EN / Chinese 等写法）
#   5. 不支持的语言被拒绝
#   6. 未知 KEY 回退为 KEY 本身
#   7. msgf 变量插值正确
#
# 运行：bash tests/test_lang.sh   或   make test
# ============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export AI_STUDIO_ROOT="$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/lang.sh"

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  $(msgf TEST_PASS "$1")"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  $(msgf TEST_FAIL "$1")"
}

echo "========================================="
echo "$(msg TEST_LANG_SUITE)"
echo "========================================="

# --- 1. 词条成对且非空 -------------------------------------------------------
echo ""
echo "$(msg TEST_LANG_DICT)"
total=0
missing_zh=0
missing_en=0
for key in $(msg_keys); do
    total=$((total + 1))
    if [[ -z "$(msg_zh "$key")" ]]; then
        fail "中文词条缺失: $key"
        missing_zh=$((missing_zh + 1))
    fi
    if [[ -z "$(msg_en "$key")" ]]; then
        fail "英文词条缺失: $key"
        missing_en=$((missing_en + 1))
    fi
done
if [[ $missing_zh -eq 0 && $missing_en -eq 0 ]]; then
    pass "$total 个词条在中英文词条表中均存在且非空"
else
    fail "词条缺失：中文 $missing_zh 处，英文 $missing_en 处"
fi

# --- 2. 默认语言 -------------------------------------------------------------
echo ""
echo "$(msg TEST_LANG_DEFAULT)"
lang_set zh
if [[ "$(msg INSTALL_START)" == "开始安装" ]]; then
    pass "默认语言为中文"
else
    fail "默认语言不是中文，实际输出: $(msg INSTALL_START)"
fi

# --- 3. 语言切换 -------------------------------------------------------------
echo ""
echo "$(msg TEST_LANG_SWITCH)"
lang_set en
if [[ "$(msg INSTALL_START)" == "Installing" ]]; then
    pass "切换到英文生效"
else
    fail "切换英文失败，实际输出: $(msg INSTALL_START)"
fi

lang_set zh
if [[ "$(msg START_DONE)" == "启动完成" ]]; then
    pass "切换回中文生效"
else
    fail "切换回中文失败，实际输出: $(msg START_DONE)"
fi

# --- 4. 语言代码归一化 -------------------------------------------------------
echo ""
echo "$(msg TEST_LANG_NORMALIZE)"
_normalized_ok=1
for code in zh zh_CN zh-CN ZH Chinese cn; do
    if [[ "$(lang_normalize "$code")" != "zh" ]]; then
        fail "归一化失败: $code"
        _normalized_ok=0
    fi
done
for code in en en_US EN English; do
    if [[ "$(lang_normalize "$code")" != "en" ]]; then
        fail "归一化失败: $code"
        _normalized_ok=0
    fi
done
if [[ $_normalized_ok -eq 1 ]]; then
    pass "zh / en 的各种写法均能正确归一化"
fi

# --- 5. 不支持的语言被拒绝 ---------------------------------------------------
echo ""
echo "$(msg TEST_LANG_REJECT)"
if ! lang_set "klingon"; then
    pass "不支持的语言被拒绝"
else
    fail "不支持的语言未被拒绝"
fi
if [[ -z "$(lang_normalize "")" ]]; then
    pass "空语言代码返回空"
else
    fail "空语言代码未返回空"
fi

# --- 6. 未知 KEY 回退 --------------------------------------------------------
echo ""
echo "$(msg TEST_LANG_FALLBACK)"
lang_set zh
if [[ "$(msg THIS_KEY_DOES_NOT_EXIST)" == "THIS_KEY_DOES_NOT_EXIST" ]]; then
    pass "未知 KEY 回退为 KEY 本身"
else
    fail "未知 KEY 回退异常: $(msg THIS_KEY_DOES_NOT_EXIST)"
fi

# --- 7. msgf 插值 ------------------------------------------------------------
echo ""
echo "$(msg TEST_LANG_INTERP)"
lang_set zh
if [[ "$(msgf INSTALLING_COMPONENT "mlx")" == "正在安装 mlx" ]]; then
    pass "msgf 中文插值正确"
else
    fail "msgf 中文插值异常: $(msgf INSTALLING_COMPONENT "mlx")"
fi
lang_set en
if [[ "$(msgf INSTALLING_COMPONENT "mlx")" == "Installing mlx" ]]; then
    pass "msgf 英文插值正确"
else
    fail "msgf 英文插值异常: $(msgf INSTALLING_COMPONENT "mlx")"
fi

# --- 收尾 -------------------------------------------------------------------
lang_set zh

echo ""
echo "========================================="
echo "$(msgf TEST_RESULTS "$TESTS_PASSED" "$TESTS_FAILED")"
echo "========================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
