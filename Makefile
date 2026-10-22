# ============================================================================
# AI Studio - 开发入口 (Makefile)
# ============================================================================
# 用法：
# make 显示所有可用目标
# make check 本地跑一遍 CI 的全部检查（提交前必做）
# make fix-perms 批量修复脚本可执行位
#
# 注意：Makefile 的配方行必须使用 Tab 缩进，不能用空格。
# ============================================================================

SHELL := /bin/bash
DEFAULT_GOAL := help
.DEFAULT_GOAL := help

# 所有 shell 脚本（排除 .git）
SCRIPTS := $(shell find . -name '*.sh' -type f -not -path './.git/*')

.PHONY: help check syntax perms compat emoji lint test lang fix-perms clean

help: ## 显示帮助
	@echo "AI Studio - 可用目标"
	@echo ""
	@echo "  make check 运行全部检查（等价于 CI）：语法 + 执行位 + Bash3.2 + lint + 测试"
	@echo "  make syntax bash -n 语法检查"
	@echo "  make perms 检查所有脚本是否带可执行位"
	@echo "  make compat 检查是否误用 Bash 4.0+ 语法（macOS 默认 Bash 3.2）"
	@echo "  make emoji 检查全项目是否残留 emoji（CI 阻断项）"
	@echo "  make lint ShellCheck 静态分析"
	@echo "  make test 运行单元测试（含消息层自检）"
	@echo "  make lang 消息层自检 + 语言策略门禁（L1 阻断 / L2 告警）"
	@echo "  make fix-perms 批量为所有 .sh 补上可执行位"
	@echo "  make clean 清理运行期产物（run/、日志、config/global.conf）"
	@echo ""

syntax: ## bash -n 语法检查
	@echo "==> 语法检查 (bash -n)"
	@fail=0; \
	for f in $(SCRIPTS); do \
		bash -n "$$f" || { echo "  语法错误: $$f"; fail=1; }; \
	done; \
	[ $$fail -eq 0 ] && echo "  [OK] 通过" || { echo "  [FAIL] 失败"; exit 1; }

perms: ## 可执行位检查
	@echo "==> 可执行位检查"
	@bad=$$(find . -name '*.sh' -type f -not -path './.git/*' ! -perm -u+x); \
	if [ -n "$$bad" ]; then \
		echo "  [FAIL] 以下脚本缺少可执行位（可执行 make fix-perms）:"; \
		echo "$$bad" | sed 's/^/  /'; \
		exit 1; \
	else \
		echo "  [OK] 通过"; \
	fi

compat: ## Bash 3.2 兼容性检查
	@echo "==> Bash 3.2 兼容性检查"
	@if grep -rnE '\$$\{[A-Za-z0-9_]+(\^+|,+)\}' --include='*.sh' . ; then \
		echo "  [FAIL] 检测到 Bash 4.0+ 大小写转换语法，请改用 tr（参见 lib/config.sh）"; \
		exit 1; \
	else \
		echo "  [OK] 通过"; \
	fi

lint: ## ShellCheck
	@echo "==> ShellCheck"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name '*.sh' -type f -not -path './.git/*' -print0 | xargs -0 shellcheck; \
	else \
		echo "  [WARN] 未安装 shellcheck，跳过（macOS: brew install shellcheck）"; \
	fi

emoji: ## emoji 扫描（阻断）
	@bash ./tests/check-emoji.sh

test: ## 单元测试
	@echo "==> 单元测试"
	@bash ./tests/run_tests.sh

lang: ## 消息层自检 + 语言策略门禁
	@echo "==> 消息层自检 (lib/lang.sh)"
	@bash ./tests/test_lang.sh
	@bash ./tests/check-language.sh

check: syntax perms compat emoji lint test lang ## 运行全部检查（提交前必做）

fix-perms: ## 批量补可执行位
	@echo "==> 为所有 .sh 补上可执行位"
	@find . -name '*.sh' -type f -not -path './.git/*' -exec chmod +x {} +
	@echo "  [OK] 完成，请记得一并提交 mode 变更"

clean: ## 清理运行期产物
	@echo "==> 清理运行期产物"
	@rm -rf ./run
	@rm -f ./logs/*.log ./logs/diagnosis_report.tmp
	@rm -f ./config/global.conf
	@echo "  [OK] 完成（组件虚拟环境与数据目录未被删除）"
