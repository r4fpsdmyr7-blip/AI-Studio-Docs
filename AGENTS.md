# AGENTS.md

> 面向 AI 编码助手的项目指令。人类贡献者请看 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。
> Instructions for AI coding agents. Human contributors: see [`CONTRIBUTING.md`](./CONTRIBUTING.md).

> **与 [`README_FOR_AI.md`](./README_FOR_AI.md) 的分工**（两者都是给 AI 看的，请勿混淆）：
> - 本文件 = 仓库**已存在**时，如何在此工作（自检命令、硬性约束、什么不能碰）
> - `README_FOR_AI.md` = 仓库**不存在**时，如何从零重建（模块契约、文件清单、验收标准）
>
> 改动架构或文件清单时，两份都要同步更新。

AI Studio —— macOS 一站式 AI 工具自动化部署与管理平台。**纯 Bash 实现，无任何构建步骤。**

---

## 1. 先跑这个（自检命令）

改动任何 `.sh` 之后，**必须**运行：

```bash
make check       # 语法 + 可执行位 + Bash 3.2 兼容 + emoji + ShellCheck + 单元测试 + 语言策略门禁
make fix-perms   # 新增 .sh 后先跑这个，补上可执行位
```

单独检查：`make syntax` / `make perms` / `make compat` / `make emoji` / `make lint` / `make test` / `make lang`

`make lang` 含两道语言门禁：`tests/check-language.sh` 的 **L1 构成层非 ASCII 校验（阻断）**
与 **L2 消息层覆盖率统计（告警）**。新增 UI 文案必须走 `msg` / `msgf`，不得硬编码。

冒烟验证（不会触发真实安装）：

```bash
./ai-studio.sh version
./ai-studio.sh list
./ai-studio.sh status open-webui
```

---

## 2. 硬性约束（最容易踩的坑）

### 必须兼容 Bash 3.2

macOS 默认 shell 是 Bash 3.2，**不是** 5.x。以下写法会直接报 `bad substitution` 或静默失败：

| 禁用 | 改用 |
| :--- | :--- |
| `${var^^}` / `${var,,}` | `$(echo "$var" \| tr '[:lower:]' '[:upper:]')` |
| `${1^^}` | 同上 |
| `declare -A`（关联数组） | `case` 语句或普通变量 |
| `mapfile` / `readarray` | `while read` 循环 |

参考 `lib/config.sh` 的写法。CI 有专门的 grep 门禁拦截，本地用 `make compat`。

### 新增 `.sh` 必须有可执行位

主入口以**直接路径**调用组件脚本（如 `"$AI_STUDIO_ROOT/components/$comp/install.sh"`），
不是 `bash script.sh`。缺执行位 = `Permission denied`。

```bash
make fix-perms     # 或：git update-index --chmod=+x <file>
```

### 慎用 `((var++))`

`((x++))` 返回的是自增**前**的值。计数器为 0 时返回 0，在 `set -e` 下会**静默终止整个脚本**。
本项目 `tests/run_tests.sh` 曾因此从未跑完过。

```bash
# 错误示例：((TESTS_PASSED++))
# 正确写法：TESTS_PASSED=$((TESTS_PASSED + 1))
```

### 组件脚本的通用骨架

```bash
#!/bin/bash
set -u                                    # 用 set -u；谨慎使用 set -e
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$COMPONENT_DIR/metadata.sh"        # 必须 source，变量都在 metadata.sh 里
```

> 注意：`metadata.sh` 中定义的每个变量都要确认真的存在。
> `components/mlx/` 曾因 metadata 漏定义 `COMPONENT_VENV_DIR`，导致 7 个脚本全部 `unbound variable`。

---

## 3. 目录 30 秒导览

```
ai-studio.sh          主入口 / 命令调度器（install/start/stop/status/update/uninstall/diagnose/env/list）
lib/                  核心库：common(日志·系统) config env-check env-install process browser diagnose ui
components/registry.sh  组件注册表：组件清单、端口、描述的唯一来源
components/<name>/    每个组件 8 个脚本：metadata install start stop status update diagnose uninstall
env/                  环境安装脚本（Homebrew/Python/Node/Ollama/Xcode CLI）——仅可手工单独运行
tests/                run_tests.sh（单元）、run-spellcheck.sh（ShellCheck 入口）
config/               配置（见下方 Don't）
logs/                 运行日志（*.log 已 gitignore）
```

---

## 4. 新增组件的标准流程

1. `mkdir components/<name>`
2. 写 `metadata.sh`：`COMPONENT_NAME` / `DESCRIPTION` / `TYPE` / `PORT` / `REPO` / `BRANCH` / `REQUIRED_DEPS` / `VENV_DIR` / `DATA_DIR` / `LOG_FILE` / `UPDATE_TARGETS`，并逐个 `export`
3. 实现 7 个生命周期脚本
4. **同步修改 `components/registry.sh` 三处**：`SUPPORTED_COMPONENTS`、`get_component_port()`、`get_component_description()`
5. `make fix-perms && make check`
6. 更新 README / README_zh / README_en 的组件表与 `CHANGELOG.md`

漏掉第 4 步，组件将无法被命令行访问（`model` 组件就处于这个状态）。

---

## 5. Don't —— 不要做这些

### 不要碰 / 不要以为能用

- **孤儿代码，未接线**：`lib/component.sh`、`lib/network.sh`、`lib/logger.sh`、`commands/`（9 个文件）。
  这些从未被 `source` 或调用，且引用大量未定义符号（`load_libs`、`AI_STUDIO_OS`、`CLR_*`）。
  每个文件头部已带 `DEPRECATED - ORPHANED CODE` 警告块，保留仅作历史参考。
  **不要**基于它们写新逻辑，**不要**以为调用它们能工作，**不要**为其接入消息层（迁移后仍无法运行）。
- **`env/` 下 7 个脚本**：从未被主程序调用。主入口走的是 `lib/env-install.sh` 的内联函数。

### 不要改这三份配置文件并指望生效

- `config/ports.conf`、`config/ai-studio.conf`、`config/default.conf` —— **全部没有任何代码读取**。
  真实生效的是运行时由 `lib/config.sh:init_config()` 自动生成的 **`config/global.conf`**（仅 4 个键）。
- 三份文件之间的端口值还互相冲突（Browser Use `7788` vs `9222` 等）。改端口请改 `registry.sh`。

### 已知不可用的功能（不要试图「修好」再报告为 regression）

- `restart` 命令：主入口校验 `restart.sh` 是否存在，但无组件提供该文件
- `install/start/stop/update all`：9 个注册组件中 6 个只有 `metadata.sh`，`qwen3` 无目录
- `diagnose all` / `uninstall all`：路径被拼成 `components/all/*.sh`
- `model` 组件：已完整实现但未注册进 `SUPPORTED_COMPONENTS`

修复这些属于已排期工作，详见 `CHANGELOG.md` 的 Known Issues。

### 其它

- 不要提交运行产物：`run/`、`logs/*.log`、`config/global.conf`、组件 `data/` 与 `.venv/`（均已在 `.gitignore`）
- 不要提交 `.workbuddy/`（本地工作区）
- 不要引入 Bash 之外的运行时依赖；本项目刻意保持零依赖
- 不要放宽 CI 门禁（如给 ShellCheck 步骤加 `continue-on-error`）
- 提交信息遵循 Conventional Commits：`feat(scope): 描述`

---

## 6. 语言策略（三层模型 + 一条禁令）

| 层 | 内容 | 语言 |
| :-- | :--- | :--- |
| **L1 构成层** | 标识符、函数名、变量名、文件名、目录名、CLI 命令与选项、配置键、日志级别标签、commit type、错误码 | **英文 / ASCII** |
| **L2 UI 层** | 终端输出、`log_*` / `echo` 消息、交互提示、报错说明、表头 | **用户指定语言**（默认中文，可切换） |
| **L3 文档层** | README / CONTRIBUTING / 代码注释 / Issue 与 PR 模板 | **中文为主，英文为辅** |

**禁令（适用全部三层）：不得使用 emoji。**
替代写法一律用 ASCII 或文字：`[OK]`、`[FAIL]`、`[WARN]`、`Tip:`、`->`、`-`、`注意：`、`提示：`。

> 注意：`U+2713`（勾）与 `U+2717`（叉）虽属 Dingbats 而非彩色 emoji，
> 但同为非 ASCII 图形符号，同样禁止。

### 不改清单（L1 构成层，任何情况都不得中文化）

```
标识符 / 函数名 / 变量名     log_info  COMPONENT_NAME  SUPPORTED_COMPONENTS
文件名 / 目录名             ai-studio.sh  lib/  components/  metadata.sh
CLI 命令与选项              install start stop restart status update uninstall diagnose
                           --target --deep --fix --keep-data --force
配置键                     AUTO_OPEN_BROWSER  DEFAULT_PORT_OFFSET  LOG_LEVEL
日志级别标签               [INFO] [SUCCESS] [WARN] [ERROR] [DEBUG]
metadata 字段              COMPONENT_NAME / PORT / REPO / BRANCH / VENV_DIR ...
commit type                feat fix docs style refactor perf test chore
错误码 / 退出码             0 / 1 / 2 / 127
```

> 日志级别标签归 L1 而非 L2：它是机器可解析的，改成中文会破坏 `grep` 与日志分析。

### UI 文案必须走消息层

面向用户的消息一律通过 `lib/lang.sh`，**不得硬编码**：

```bash
# 正确
log_info "$(msg INSTALL_START)"
log_info "$(msgf INSTALL_DONE "$name")"

# 错误
log_info "Installing Open WebUI..."
```

新增词条时 `msg_zh` 与 `msg_en` **必须同时添加**，否则 `tests/test_lang.sh` 会失败。

### 切换 UI 语言

优先级：`--lang <code>` > 环境变量 `AI_STUDIO_LANG` > `config/global.conf` 的 `LANG` > 默认 `zh`。

```bash
./ai-studio.sh --lang en status mlx
AI_STUDIO_LANG=en ./ai-studio.sh status mlx
```

支持的语言代码见 `lib/lang.sh` 的 `LANG_SUPPORTED`。当前：`zh`、`en`。

---

## 7. 安全

- 漏洞与行为准则问题，统一通过 GitHub Security Advisories 私密渠道报告，
  **不要**开公开 Issue：`https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs/security/advisories/new`
- `env install` 会下载并执行远程脚本（Homebrew / Ollama）。改动这块时保持可见性，不要隐藏下载行为。
- 组件 `install.sh` 中的 `find ... -exec rm -rf {} +` 属于高风险操作，修改时保留路径守卫。
