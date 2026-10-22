# 贡献指南 (Contributing Guidelines)

感谢您对 **AI Studio** 的兴趣！我们欢迎任何形式的贡献，无论是修复 Bug、添加新组件、改进文档，还是提出新功能建议。

为了确保项目保持**标准化、模块化和通用化**的设计原则，请在提交代码前仔细阅读本指南。

> **如果你使用 AI 编码助手（Codex / Cursor / Copilot / Claude Code 等），
> 请先读 [`AGENTS.md`](./AGENTS.md)** —— 那里列出了本项目的硬性约束
> （Bash 3.2 兼容、脚本可执行位、`((x++))` 陷阱、哪些代码不可碰）。

---

## 如何添加新组件

AI Studio 的核心优势在于其高度模块化的架构。添加一个新组件（例如 `my-new-ai`）只需遵循以下标准化步骤：

### 1. 创建组件目录
在 `components/` 目录下创建以组件名命名的新文件夹：
```bash
mkdir components/my-new-ai
cd components/my-new-ai
```

### 2. 定义元数据 (`metadata.sh`)
创建 `metadata.sh` 文件，定义组件的静态属性。这是其他脚本读取配置的“单一事实来源”。
```bash
#!/bin/bash
readonly COMPONENT_NAME="my-new-ai"
readonly COMPONENT_DESCRIPTION="My awesome new AI tool"
readonly COMPONENT_TYPE="python" # python, node, binary, etc.
readonly COMPONENT_PORT="9000"   # Leave empty ("") if no network port
readonly COMPONENT_REQUIRED_DEPS="python3 git"
# ... (请参考 components/open-webui/metadata.sh 作为完整模板)
```

### 3. 实现 8 个标准生命周期脚本
在组件目录下创建以下脚本（可参考 `open-webui` 的实现）：
- `install.sh`: 处理依赖检查、源码克隆和环境配置。
- `start.sh`: 启动服务，处理端口偏移，并调用 `lib/browser.sh` 自动打开浏览器。
- `stop.sh`: 优雅停止后台守护进程。
- `status.sh`: 报告进程、端口和日志状态。
- `update.sh`: 支持细粒度更新（如 `--target backend`）。
- `diagnose.sh`: 集成 `lib/diagnose.sh`，提供组件特定的健康检查和自动修复。
- `uninstall.sh`: 清理文件，支持 `--keep-data` 保留用户资产。
- *(注：`metadata.sh` 本身也算作核心定义文件)*

### 4. 注册新组件
打开 `components/registry.sh`，将您的组件名称添加到 `SUPPORTED_COMPONENTS` 列表中，并在 `get_component_port` 和 `get_component_description` 的 `case` 语句中添加对应的映射。

### 5. 本地测试
在提交前，务必运行本地检查，确保代码符合规范。项目根目录提供了 `Makefile`：

```bash
make check      # 全部检查：语法 + 可执行位 + Bash 3.2 兼容 + ShellCheck + 单元测试
make lint       # 只跑 ShellCheck
make syntax     # 只跑 bash -n 语法检查
make perms      # 只检查脚本可执行位
make fix-perms  # 批量补上可执行位
```

等价于 CI 中运行的全部检查。也可以单独调用脚本：`./tests/run-spellcheck.sh`。

> 注意：新增 `.sh` 文件后请务必执行 `make fix-perms`。主入口通过**直接路径**调用组件脚本，
> 缺少可执行位会导致运行时 `Permission denied`。

---

## 代码规范

为了保持代码库的一致性和可维护性，请遵循以下规范：

1. **Shell 解释器**: 所有脚本必须以 `#!/bin/bash` 开头。我们依赖 Bash 的特性，不使用纯 POSIX `sh`。
2. **严格模式**: 脚本顶部应包含 `set -u`（防止未定义变量）。谨慎使用 `set -e`，在需要优雅处理错误的场景下，请显式检查命令的返回值 (`if ! command; then ...`)。
3. **变量命名**:
   - 全局常量和导出的元数据变量使用**全大写**（如 `COMPONENT_PORT`, `AI_STUDIO_ROOT`）。
   - 局部变量使用**小写**（如 `local port_offset`）。
4. **日志输出**: 严禁直接使用 `echo` 输出重要信息。必须使用 `lib/common.sh` 提供的标准化日志函数：`log_info`, `log_success`, `log_warn`, `log_error`, `log_debug`。
5. **ShellCheck 兼容**: 代码必须通过 `shellcheck` 检查。项目根目录的 `.shellcheckrc` 已配置了合理的规则排除（如动态 `source` 的 SC1090/SC1091），请勿随意修改该文件。如果引入新的警告，请先评估是否合理。
6. **渐进式披露**: 在编写 CLI 输出时，优先展示核心信息。高级排错信息应通过 `--deep` 或 `--fix` 等标志触发，或通过 `log_debug` 隐藏。
7. **语言策略**: 详见下方「语言策略」一节。构成层用英文、UI 层走消息层、全项目不用 emoji。

---

## 语言策略

项目采用**三层模型**，改动任何文本前请先判断它属于哪一层：

| 层 | 内容 | 语言 |
| :-- | :--- | :--- |
| **L1 构成层** | 标识符、函数名、变量名、文件名、目录名、CLI 命令与选项、配置键、日志级别标签、commit type、错误码 | **英文 / ASCII** |
| **L2 UI 层** | 终端输出、`log_*` 消息、交互提示、报错说明 | **用户指定语言**（默认中文，可切换） |
| **L3 文档层** | README / CONTRIBUTING / 注释 / 模板 | **中文为主，英文为辅** |

### 构成层不得中文化

以下内容**任何时候都保持英文**，包括新增代码时：

```
CLI：install start stop restart status update uninstall diagnose
选项：--target --deep --fix --keep-data --force
配置键：AUTO_OPEN_BROWSER  DEFAULT_PORT_OFFSET  LOG_LEVEL
日志级别标签：[INFO] [SUCCESS] [WARN] [ERROR] [DEBUG]
metadata 字段：COMPONENT_NAME / PORT / REPO / BRANCH / VENV_DIR
commit type：feat fix docs style refactor perf test chore
```

### UI 文案必须走消息层

```bash
# 正确
log_info "$(msg INSTALL_START)"
log_info "$(msgf INSTALL_DONE "$name")"

# 错误
log_info "Installing Open WebUI..."
```

新增词条时，`lib/lang.sh` 里的 `msg_zh` 与 `msg_en` **必须同时添加**，`tests/test_lang.sh` 会校验这一点。

### 不使用 emoji

全部三层禁用。替代写法：`[OK]`、`[FAIL]`、`[WARN]`、`Tip:`、`->`、`-`，或直接用文字（`注意：`、`提示：`）。

提交前可自查：

```bash
make emoji          # 全量扫描 emoji / keycap / 孤立修饰符
```

---

## 提交流程 (Workflow)

我们采用 **Conventional Commits** 规范来管理提交历史，这有助于自动生成 Changelog 和版本发布。

### 1. Fork 并克隆
Fork 本仓库，并将其克隆到本地：
```bash
git clone https://github.com/YOUR_USERNAME/AI-Studio-Docs.git
cd AI-Studio-Docs
git remote add upstream https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs.git
```

### 2. 创建特性分支
从最新的 `main` 分支创建您的工作分支。分支命名应具有描述性：
```bash
git checkout -b feat/add-llama3-component
# 或
git checkout -b fix/port-conflict-handling
```

### 3. 提交代码 (Commit)
提交信息必须遵循以下格式：
```text
<type>(<scope>): <subject>

<body>

<footer>
```
**常用 Type**:
- `feat`: 新功能（如添加新组件、新命令）
- `fix`: 修复 Bug
- `docs`: 仅文档更改
- `style`: 代码格式调整（不影响逻辑）
- `refactor`: 代码重构（既不修复 Bug 也不添加功能）
- `test`: 添加或修改测试
- `chore`: 构建过程或辅助工具的变动

**示例**:
```text
feat(comfyui): 添加 FLUX 模型自动下载支持

- 在 install.sh 中集成 huggingface-cli
- 更新 metadata.sh 的依赖列表
- 添加对应的 diagnose 检查项
```

### 4. 推送并创建 Pull Request (PR)
```bash
git push origin feat/add-llama3-component
```
前往 GitHub 创建 Pull Request。请在 PR 描述中清晰说明：
- 这个 PR 解决了什么问题或添加了什么功能？
- 如何测试这些更改？
- 是否更新了相关文档？

### 5. Code Review 与 CI
- GitHub Actions 会自动运行 `shellcheck`。请确保 CI 状态为绿色。
- 维护者将对您的代码进行 Review。请保持耐心，并根据反馈进行相应的修改 (Push 新的 commit 或 force push 整理后的 commit)。

---

## 需要帮助？

如果您在贡献过程中遇到任何问题，或者不确定某个设计决策，请随时：
1. 查阅现有的 [Issues](https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs/issues)。
2. 在 [Discussions](https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs/discussions) 或新建 Issue 中讨论。
3. 在 PR 中 @ 维护者寻求指导。
4. 完整的求助渠道见 [`SUPPORT.md`](./SUPPORT.md)。

再次感谢您让 AI Studio 变得更好！
