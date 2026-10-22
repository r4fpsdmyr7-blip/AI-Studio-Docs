#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$AI_STUDIO_ROOT/lib/common.sh"

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0

# 断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-$(msg TEST_ASSERT_FAILED)}"
    
    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "  $(msgf TEST_PASS "$message")"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "  $(msgf TEST_FAIL "$message")"
        echo "     $(msgf TEST_EXPECTED "$expected")"
        echo "     $(msgf TEST_ACTUAL "$actual")"
    fi
}

assert_command_exists() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "  $(msgf TEST_PASS "$(msgf TEST_CMD_EXISTS "$cmd")")"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "  $(msgf TEST_FAIL "$(msgf TEST_CMD_NOT_FOUND "$cmd")")"
    fi
}

# 测试用例
test_common_functions() {
    echo "$(msg TEST_COMMON_FUNCS)"
    
    # 测试 command_exists
    assert_command_exists "bash"
    
    # 测试 is_valid_component（需要 registry.sh）
    # ...
}

# 运行所有测试
echo "========================================="
echo "$(msg TEST_SUITE_TITLE)"
echo "========================================="

test_common_functions
# test_registry_functions
# test_process_functions

echo ""
echo "========================================="
echo "$(msgf TEST_RESULTS "$TESTS_PASSED" "$TESTS_FAILED")"
echo "========================================="

[[ $TESTS_FAILED -eq 0 ]]
