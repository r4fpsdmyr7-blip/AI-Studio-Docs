# README_FOR_AI

> **给 AI 看的重建规格**：本文件描述 AI Studio 的完整设计，目标是让 AI 能据此**从零重建**本项目。
> 若你是要**修改**已有仓库，请改读 [`AGENTS.md`](./AGENTS.md)（工作约定）与 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。

| | |
| :--- | :--- |
| **规格版本** | 对应 `v1.0.0`（`ai-studio.sh` 中 `VERSION="1.0.0"`） |
| **最后校验** | 2026-10-22，对照 commit `9e98160` |
| **规模** | 61 个 `.sh` / 约 7,478 行，**纯 Bash，零第三方运行时依赖** |
| **平台** | macOS 13+（含 Apple Silicon 优化；Linux 实验性） |
| **许可证** | GNU GPL v3 |

> 注意：**本文件的每条声明均以代码实际状态为准**，不沿用 README 中的描述性文字。
> 生成前请先读「§7 实现状态」与「§8 已知缺陷」，避免把本项目的缺陷当成需求复现。

---

## 1. 一句话定位

macOS 一站式 AI 工具自动化部署与管理平台：统一 CLI 管理多个本地 AI 组件
（安装 / 启动 / 停止 / 状态 / 更新 / 卸载 / 诊断），组件之间互不影响。

## 2. 设计原则（决定后续所有取舍）

1. **标准化**：每个组件目录含同一套生命周期脚本，主入口以统一接口调用
2. **模块化**：`lib/`（通用能力）+ `registry.sh`（元数据）+ `components/<name>/`（业务隔离），删除任一组件不影响其他
3. **通用化**：无论组件是 Python / Node / Ollama，对外 CLI 体验一致
4. **渐进式披露**：L0 `start/stop/status` → L1 `install/update/diagnose` → L2 `--target/--deep/--keep-data` → L3 改配置
5. **零依赖**：只用 Bash + 系统自带命令，不引入 Python/Node 包管理器之外的运行时

## 3. 硬性技术约束（违反即不可用）

| 约束 | 说明 |
| :--- | :--- |
| **Bash 3.2 兼容** | macOS 默认 shell。禁用 `${var^^}`、`${var,,}`、`declare -A`、`mapfile`；大写转换用 `tr`，键值映射用 `case` |
| **脚本必须带可执行位** | 主入口以**直接路径**调用组件脚本（非 `bash xxx.sh`），缺位即 `Permission denied` |
| **`set -u` 为主** | 库文件统一 `set -u`；`set -e` 谨慎使用并显式检查返回值 |
| **慎用 `((x++))`** | 返回自增**前**的值，计数器为 0 时返回 0，在 `set -e` 下静默终止脚本。用 `X=$((X + 1))` |
| **CI 门禁** | `bash -n` 语法 / 可执行位 / Bash 3.2 grep 检查 / ShellCheck / 单元测试 / emoji 扫描，见 `Makefile` 的 `make check` |
| **三层语言模型** | L1 构成层（标识符 / CLI / 配置键 / 日志级别标签 / commit type）**必须英文 ASCII**；L2 UI 层（终端输出）走 `lib/lang.sh` 消息层，默认中文、可切换；L3 文档层中文为主 |
| **禁止 emoji** | 全部三层不得使用 emoji。替代：`[OK]`、`[FAIL]`、`[WARN]`、`Tip:`、`->`、`-` |
| **UI 文案不得硬编码** | 一律 `msg KEY` / `msgf KEY arg`；`lib/lang.sh` 的 `msg_zh` 与 `msg_en` 必须成对新增 |

## 4. 目录结构与文件契约

```
ai-studio.sh              主入口：命令解析与派发
lib/                      核心库（被 source，不直接执行）
components/registry.sh    组件注册表：组件清单、端口、描述的唯一来源
components/<name>/        每个组件一套生命周期脚本
env/                      环境安装脚本（可独立手工运行，主入口不调用）
tests/                    run_tests.sh（单元）、run-spellcheck.sh（ShellCheck 入口）
config/                   配置（注意 §6 的真相说明）
logs/                     运行日志
```

### 4.1 `ai-studio.sh`（主入口，约 268 行）

必须完成：定位 `AI_STUDIO_ROOT` → `source` 全部 lib 与 registry → 按 `$1` 派发。

派发的命令（12 个）：`help` / `version` / `env` / `list` / `install` / `start` / `stop` /
`restart` / `status` / `update` / `uninstall` / `diagnose`。
其中 `env` 有三个子命令：`check` / `install` / `status`。

关键函数：`show_help()`、`show_version()`、`handle_env_command()`、
`handle_component_command()`、`list_components()`、`main()`。

> 注意：`--help/-h`、`--version/-v` 需与 `help` / `version` 等价。

### 4.2 `lib/` 各库契约

| 文件 | 必须提供 |
| :--- | :--- |
| `common.sh` | `log_info` `log_success` `log_warn` `log_error` `log_debug`（`AI_STUDIO_DEBUG=1` 才输出）；`is_macos` `is_apple_silicon` `command_exists` `is_port_in_use` `wait_for_port` `require_sudo` `ensure_dir` `print_separator` `check_platform_compatibility`。顶部 `set -u` |
| `config.sh` | `get_default_config_value` `init_config` `get_config` `set_config` `delete_config` `is_config_true`。**Bash 3.2 实现**，禁止关联数组 |
| `env-check.sh` | `check_os_version` `check_hardware` `check_disk_space` `check_memory` `check_tools` `check_all_requirements` `show_environment_status`。常量：`MIN_MACOS_VERSION=13`、`MIN_DISK_SPACE_GB=50`、`MIN_MEMORY_GB=16`、`REQUIRED_TOOLS=(git curl python3 node npm)`、`RECOMMENDED_TOOLS=(brew ollama)` |
| `env-install.sh` | `install_homebrew` `install_basic_tools` `install_runtime_envs` `install_ai_tools` `install_all_dependencies` `install_component_deps` |
| `process.sh` | PID 生命周期：`start_daemon`（`nohup` + 写 PID + 启动后存活校验）`stop_daemon`（SIGTERM → 超时 → SIGKILL）`restart_daemon` `is_daemon_running` `get_daemon_info` `wait_for_daemon_exit` `clean_stale_pids` `kill_process_on_port`；内部 `_get_pid_file` `_save_pid` `_read_pid` `_clear_pid` `_is_pid_alive`。运行时目录：`run/pids/` |
| `browser.sh` | `open_browser`（受 `AUTO_OPEN_BROWSER` 控制）`open_browser_when_ready` `is_browser_installed` `get_available_browsers` `force_open_browser` |
| `diagnose.sh` | `run_simple_diagnosis` `run_deep_diagnosis` `attempt_auto_fix` `execute_diagnosis` + 内部 5 个 `_check_*` |
| `ui.sh` | `show_progress` `show_spinner` `confirm_action` `user_input` `select_from_list` `print_table` `print_info_block` `pause_for_user` `clear_screen` |

### 4.3 `components/registry.sh`（唯一元数据来源）

```bash
readonly SUPPORTED_COMPONENTS="open-webui sillytavern continue-dev fazm browser-use mlx comfyui mlx-video qwen3"
```

必须提供的函数：`get_component_port` `get_component_description` `get_component_dir`
`is_valid_component` `get_all_components` `is_component_installed` `is_component_running` `discover_components`。

默认端口：`open-webui 3000`、`sillytavern 8000`、`browser-use 7788`、`comfyui 8188`、`qwen3 11434`；
`continue-dev / fazm / mlx / mlx-video` 无独立端口，返回空串。

### 4.4 组件契约：`components/<name>/`

标准 8 个脚本：`metadata.sh` + `install.sh` `start.sh` `stop.sh` `status.sh` `update.sh` `diagnose.sh` `uninstall.sh`。

`metadata.sh` 必须 `readonly` 定义并 `export` 这些字段（以 open-webui 为模板）：

```
COMPONENT_NAME  COMPONENT_DESCRIPTION  COMPONENT_TYPE  COMPONENT_PORT
COMPONENT_REPO  COMPONENT_BRANCH  COMPONENT_REQUIRED_DEPS
COMPONENT_VENV_DIR  COMPONENT_DATA_DIR  COMPONENT_LOG_FILE  COMPONENT_UPDATE_TARGETS
```

> 注意：**每个被生命周期脚本引用的字段都必须在 metadata.sh 中定义**，否则 `set -u` 下报
> `unbound variable`（本项目 `mlx` 曾漏定义 `COMPONENT_VENV_DIR`，导致 7 个脚本全废）。
> 无虚拟环境的组件（如 `model`）可不定义 `COMPONENT_VENV_DIR`，但前提是没有任何脚本引用它。

通用骨架：

```bash
#!/bin/bash
set -u
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$COMPONENT_DIR/metadata.sh"
```

`install.sh` 需幂等（检测到已安装则跳过）；`start.sh` 需处理端口占用并调用浏览器自动打开；
`uninstall.sh` 需支持 `--keep-data`；`diagnose.sh` 需支持 `--deep` / `--fix`；
`update.sh` 需支持 `--target`。

### 4.5 `env/`（7 个可独立运行的脚本）

`check-system.sh`、`install-homebrew.sh`、`install-xcode-cli.sh`、`install-python.sh`、
`install-node.sh`、`install-ollama.sh`、`install-git-lfs.sh`。

## 5. 命令行契约

```bash
./ai-studio.sh env check|install|status
./ai-studio.sh install|start|stop|restart|update|uninstall|diagnose <component|all>
./ai-studio.sh status [component]
./ai-studio.sh list
./ai-studio.sh help|version
```

选项：`--target frontend|agent|architecture|models`（update）、
`--keep-data` / `--force`（uninstall）、`--deep` / `--fix`（diagnose）。

## 6. 配置真相（容易搞错，务必按此实现）

- **真正生效的配置**：运行时由 `lib/config.sh:init_config()` 自动生成的 `config/global.conf`，
  仅含 4 个键：`AUTO_OPEN_BROWSER="true"`、`DEFAULT_PORT_OFFSET="0"`、`LOG_LEVEL="info"`、`MAX_DIAGNOSE_DEPTH="1"`
- **仓库内 `config/ports.conf`、`config/ai-studio.conf`、`config/default.conf` 三份均无任何代码读取**，
  且端口值互相冲突（如 Browser Use `7788` vs `9222`）。**不要**按它们实现读取逻辑
- 改端口的正确位置：`registry.sh:get_component_port()`

## 7. 实现状态（生成时务必区分）

| 组件 | 状态 | 说明 |
| :--- | :--- | :--- |
| `open-webui` | 已实现 | 8 个脚本齐全 |
| `mlx` | 已实现 | 8 个脚本齐全 |
| `model` | 已实现，但**未注册** | 8 个脚本齐全，却不在 `SUPPORTED_COMPONENTS` 中，命令行无法访问 |
| `sillytavern` / `continue-dev` / `fazm` / `browser-use` / `comfyui` / `mlx-video` | 仅声明 | **只有 `metadata.sh`**，无任何生命周期脚本 |
| `qwen3` | 未创建 | 在 `SUPPORTED_COMPONENTS` 中声明，但目录不存在 |

> 重建时建议：**先完整实现 3 个已实现组件**，其余组件从 `SUPPORTED_COMPONENTS` 中移除
> 或补齐全套脚本，**不要**保留「已声明但无实现」的状态——那会让 `install all` 大面积失败。

## 8. 已知缺陷（不要复现）

| 缺陷 | 根因 |
| :--- | :--- |
| `restart` 100% 失败 | 主入口校验 `restart.sh` 是否存在，但无组件提供该文件 |
| `install/start/stop/update all` 大面积失败 | 派发时直接拼接 `components/<name>/install.sh`，而多数组件只有 `metadata.sh` |
| `diagnose all` / `uninstall all` 失败 | 未处理 `all`，路径被拼成 `components/all/*.sh` |
| 批量操作不汇总失败 | 循环中不检查返回码，也不统计失败数 |
| `status`（无参数）被拦截 | `main()` 统一要求至少一个参数，导致「列出全部」分支不可达 |
| `is_component_installed` 语义错误 | 以「是否存在 install.sh」判定，实际反映的是「是否已实现」而非「是否已安装」 |
| 孤儿代码 | `lib/component.sh`、`lib/network.sh`、`lib/logger.sh`、`commands/`（9 文件）从未被 source/调用，且引用未定义符号 |
| `env/` 未被主程序调用 | 主入口走 `lib/env-install.sh` 的内联函数 |
| 部分 `echo` 缺 `-e` | 颜色转义序列被原样打印（如字面量 `\033[36m`） |

## 9. 验收标准（生成后逐项自校验）

```bash
chmod +x ai-studio.sh $(find . -name '*.sh')   # 必须：全部脚本带可执行位

# A. 冒烟（不应报错）
./ai-studio.sh version
./ai-studio.sh help
./ai-studio.sh list                 # 组件全部列出，端口正确
./ai-studio.sh status open-webui    # 提示未安装，但不崩溃
./ai-studio.sh env check            # 在 macOS 上应输出检查结果

# B. 质量门禁（若提供 Makefile）
make check       # bash -n + 可执行位 + Bash 3.2 兼容 + ShellCheck + 单元测试

# C. 手工核对
grep -c '' $(find . -name '*.sh')          # 规模量级一致
ls components/open-webui/                  # 8 个脚本齐全
grep -n 'SUPPORTED_COMPONENTS' components/registry.sh
```

**必须通过的判定**：A 全部返回 0 且无 `Permission denied` / `syntax error` / `unbound variable`；
B 若提供则全绿；C 中 `SUPPORTED_COMPONENTS` 的每个名字**都必须有对应目录且含 `install.sh`**。

**若某条不通过**：不要静默跳过，请在最终报告中列出未通过项——
本文件的 §7/§8 已列出当前版本的已知差距，生成方应说明自己消除了哪几条、保留了哪几条。

## 10. 推荐重建顺序

1. `lib/common.sh`（日志与系统工具，其它库都依赖它）
2. `lib/config.sh` → `lib/process.sh` → `lib/browser.sh`
3. `lib/env-check.sh` + `lib/env-install.sh` → `lib/diagnose.sh` → `lib/ui.sh`
4. `components/registry.sh`
5. `ai-studio.sh` 主入口与派发
6. 三个组件：`open-webui`（Python Web 服务）→ `mlx`（Python 库，无端口）→ `model`（模型管理）
7. `tests/` + `Makefile` + CI
8. 文档：README / CONTRIBUTING / CHANGELOG / SECURITY / CODE_OF_CONDUCT / SUPPORT / AGENTS.md

---

## 附：如何使用本文件

把本文件与下面这段提示词一起交给 AI：

```text
请阅读 README_FOR_AI.md，按其规格从零生成完整项目。
要求：
1. 严格遵守「§3 硬性技术约束」，尤其是 Bash 3.2 兼容与脚本可执行位；
2. 按「§10 推荐重建顺序」逐步生成；
3. 不要复现「§8 已知缺陷」中列出的任何一条；
4. 生成后逐项执行「§9 验收标准」，并如实报告未通过项。
```
