# 变更日志 (Changelog)

本项目所有值得注意的变更都会记录在此文件。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。
变更类别：`Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security`。

> **说明**：本文件于 2026-10-22 的工程规范审核中补建。1.0.0 条目依据仓库实际内容
> 整理，并非逐条还原 129 个历史提交；后续版本请随 PR 同步更新本文件。

---

## [Unreleased]

### Fixed

- **阻断级**：`components/mlx/status.sh` 的 `case` 语句误以 `fi` 结尾（应为 `esac`），导致该文件无法被解析，`ai-studio.sh status mlx` 直接报语法错误
- **阻断级**：全部 61 个 `.sh` 脚本缺少可执行位，主入口以直接路径调用组件脚本，导致所有组件操作 `Permission denied`
- `components/mlx/metadata.sh` 未定义 `COMPONENT_VENV_DIR`，而 mlx 的 7 个生命周期脚本共 26 处引用它，在 `set -u` 下触发 `unbound variable`
- `lib/ui.sh` 与 `lib/component.sh` 使用了 Bash 4.0+ 的参数展开大小写转换，与项目声明的「macOS 默认 Bash 3.2 兼容」目标冲突，已改为 `tr` 实现
- **配置写入失效**：`lib/config.sh` 的 `set_config` / `delete_config` 使用 `sed -i '' script file`，
  BSD sed 会把紧跟的空后缀参数吃掉、把脚本当成文件名，报 `No such file or directory` 且**不修改文件**。
  已改为「临时文件 + mv」，跨平台可靠且不产生 `.bak` 残留（该缺陷由 `lang set` 持久化首次暴露）
- **消息层插值失败**：`lib/lang.sh` 的 `msgf` 以 `printf "${fmt}\n"` 输出，当词条以 `->` 开头
  （诊断提示类文案）时，printf 会把它解析成命令行选项并报 `printf: ->: invalid option`，该行输出丢失。
  已改为 `printf -- "${fmt}\n" "$@"`，用 `--` 终止选项解析
- **中文标签列错位**：Bash 的 `printf "%-25s"` 按**字节**补齐，中文字符占 3 字节却只占 2 个显示列，
  导致 `ai-studio.sh env status` 的中文标签列宽参差不齐（实测 21 / 23 / 21 列）。
  新增 `pad_display`（`lib/common.sh`）按显示宽度补齐，中文与英文均稳定对齐到 25 列

### Added

- **UI 消息层 `lib/lang.sh`（i18n）**：新增 `msg KEY` / `msgf KEY arg...` 接口与中英两套词条表，
  语言优先级为 `--lang <code>` > 环境变量 `AI_STUDIO_LANG` > `config/global.conf` 的 `LANG` > 默认 `zh`
- **`lang` 子命令**：`lang`（查看）/ `lang list`（列出支持的语言）/ `lang set zh|en`（切换并持久化）
- **`--lang <zh|en>` 全局选项**：只对本次运行生效，覆盖配置
- `tests/test_lang.sh`：消息层自检（词条成对、语言切换、归一化、插值、未知 KEY 回退）
- `tests/check-emoji.sh` 与 `make emoji`：全项目 emoji 扫描，**CI 阻断项**
- `tests/check-language.sh` 与 `make lang` 扩展：语言策略门禁（新增 9 条中英词条）——
  **L1 构成层校验（阻断）**：剔除注释后 .sh 代码不得含非 ASCII；
  **L2 消息层覆盖率统计（告警）**：`msg/msgf` 调用占比低于 95% 时提示
- `AGENTS.md` §6 / `CONTRIBUTING.md` / `README_FOR_AI.md` §3 写入语言策略（三层模型、不改清单、emoji 禁令）
- `.github/ISSUE_TEMPLATE/`（`bug_report.yml`、`feature_request.yml`、`config.yml`）、`.github/PULL_REQUEST_TEMPLATE.md`、`.github/CODEOWNERS`、`.github/dependabot.yml`
- CI 新增三项门禁：语法检查（`bash -n`）、可执行位检查、Bash 3.2 兼容性检查
- `AGENTS.md`：面向 AI 编码助手的项目指令（Bash 3.2 约束、可执行位、`((x++))` 陷阱、孤儿代码与失效配置清单、Don't 一节）
- `CLAUDE.md`：仅 2 行的薄壳，通过 `@AGENTS.md` 导入，用于覆盖不原生读取 AGENTS.md 的 Claude Code
- `README_FOR_AI.md`：面向 AI 的**完整重建规格**（模块契约、文件清单、硬性约束、实现状态表、已知缺陷、验收标准、推荐重建顺序）。
  规格**逐项从代码采集**而非沿用 README 描述，并显式标注 9 个组件中仅 3 个已完整实现
- 三份 README 新增「用 AI 重建本项目」小节，含可直接复制的提示词

### Changed

- `SECURITY.md`：移除邮件渠道，**漏洞与行为准则报告统一收敛为 GitHub Security Advisories 私密通道**，并作为全仓库唯一联系方式（同步更新 `CODE_OF_CONDUCT.md`、`SUPPORT.md`、`ISSUE_TEMPLATE/config.yml`）
- CI 工作流重写：原配置引用了不存在的 `tests/run-shellcheck.sh`，每次构建必然失败
- `CONTRIBUTING.md` 中的占位仓库地址（`ORIGINAL_OWNER` / `YOUR_USERNAME` / `ai-studio.git`）替换为真实仓库地址
- `README_zh.md` 的克隆地址大小写统一为 `AI-Studio-Docs`
- **全项目 emoji 清零（157 处 / 29 文件）**：统一替换为 ASCII —— `U+2705`→`[OK]`、`U+274C`→`[FAIL]`、
  `U+26A0`→`[WARN]`、`U+1F4A1`→`Tip:`、`U+1F449`→`->`、`U+2713`/`U+2717`→`[OK]`/`[FAIL]`、标题装饰直接删除
- `README_en.md` 的 8 个目录锚点重写：原锚点由标题中的 emoji 参与生成，删除 emoji 后会全部失效
- `ai-studio.sh` 主入口的 33 处 UI 文案迁移到消息层，终端输出改为中文（可用 `--lang en` 切回英文）
- `components/open-webui/` 8 个脚本共 145 处 UI 文案迁移到消息层（新增 141 条中英词条），
  作为其余组件的迁移范本；`lib/common.sh` 现自动加载 `lib/lang.sh`，凡 source 它的脚本即具备 `msg` / `msgf`
- `components/mlx/` 8 个脚本共 163 处 UI 文案迁移到消息层（新增 84 条中英词条），
  并把 `MLX_START_NO_VENV` 收敛为 `MLX_VENV_NOT_FOUND`、`MLX_STOP_DEPS_HINT` 收敛为 `STOP_DEPS_HINT`（供 model 复用）
- `components/model/` 8 个脚本共 177 处 UI 文案迁移到消息层（新增 159 条中英词条），
  含表格表头（`MODEL NAME` / `SIZE` / `STATUS`）与模型状态词（`Ready` / `Incomplete/Corrupted` / `Partial/Verifying`）；
  同时把 `MLX_UPDATE_HINT_FIRST` 收敛为共享的 `UPDATE_HINT_INSTALL_FIRST`
- **组件描述收敛为单一真源（新增 11 条 `DESC_*` 词条）**：此前同一组件存在两套英文描述且措辞不一致 ——
  `ai-studio.sh list` 读 `components/registry.sh` 的 `get_component_description()`，
  而 install 横幅读 `components/<name>/metadata.sh` 的 `COMPONENT_DESCRIPTION`
  （如 open-webui 分别是 "Powerful local LLM Web UI" 与 "Powerful and feature-rich local LLM Web UI"）。
  现两者共用同一批 `DESC_*` 词条，`list` 与 install 横幅均随 `--lang` 切换；
  `metadata.sh` / `registry.sh` 被独立 source 时会回退到英文原文
- `lib/` 全部 8 个在用脚本共 149 处 UI 文案迁移到消息层（新增 149 条中英词条）：
  `common.sh`（11）、`config.sh`（1）、`ui.sh`（6）、`browser.sh`（14）、
  `diagnose.sh`（30）、`process.sh`（20）、`env-check.sh`（35）、`env-install.sh`（32）。
  孤儿文件 `lib/component.sh` / `lib/network.sh` / `lib/logger.sh` 不在本批范围（见下方 Deprecated）
- `env/` 7 个脚本共 170 处 UI 文案迁移到消息层（新增 161 条中英词条）；写入用户 shell
  配置文件的标记注释（`# Added by AI Studio: ...`）**刻意保留英文**——该内容进入用户
  `~/.zshrc` 等文件，非 ASCII 字符可能影响部分 shell 解析
- `tests/` 4 个脚本共 28 处输出文案迁移到消息层（新增 25 条中英词条）；`run_tests.sh` 把
  `lib/common.sh` 的加载从函数内提到文件顶部（否则标题输出时 `msg` 尚未定义，且重复
  source 会因 `readonly` 变量报错）
- 共享键收敛：`MODEL_INSTALL_TROUBLESHOOT` → `TROUBLESHOOT_LABEL`（供 model 与 5 个 env 脚本复用）
- **三份 README 明确分工**：`README.md` = 中英双语摘要 + 顶部语言索引（指向完整版）；
  `README_zh.md` = 中文完整版；`README_en.md` = 英文完整版。三份顶部均新增语言切换互链，
  `README_zh.md` 补齐与英文版对等的目录

### Deprecated

- **12 个孤儿文件正式标记废弃**：`commands/`（9 个文件）与 `lib/component.sh` / `lib/network.sh` / `lib/logger.sh`
  头部统一加入 `DEPRECATED - ORPHANED CODE` 警告块。这些文件从未被主程序 `source` 或调用，
  且引用未定义符号（`load_libs`、`REGISTERED_COMPONENTS`、`CLR_*` 等），**无法运行**，
  故不迁移到消息层，仅保留作历史参考；`AGENTS.md` 已同步说明
- `lib/common.sh` 内残留的中文注释（i18n 加载说明、`pad_display` 说明、平台警告返回值注释）
  统一改为英文，与文件其余注释风格一致（构成层语言约定）
- **UI 列表符号 `U+2022`（`•`）替换为 ASCII `-`**：`components/mlx/`、`components/model/`、
  `env/install-git-lfs.sh` 共 12 处 echo 行。词典 `lib/lang.sh` 词条中的 `•` 属 UI 层内容，保留
- `.github/PULL_REQUEST_TEMPLATE.md` 自检清单新增「无 emoji」与「遵循语言策略」勾选项

### Security

- CI 增加可执行位与语法门禁，避免「脚本带语法错误 / 无执行权限」被合入主干

---

## [1.0.0] - 2026-06-13

首个对外发布版本。

### Added

- **主入口** `ai-studio.sh`：统一 CLI 调度器，支持 `env` / `install` / `start` / `stop` / `restart` / `status` / `update` / `uninstall` / `diagnose` / `list`
- **核心库** `lib/`：`common.sh`（日志与系统工具）、`config.sh`（配置读写）、`env-check.sh`（环境检测）、`env-install.sh`（依赖安装）、`process.sh`（守护进程与 PID 管理）、`browser.sh`（自动唤起浏览器）、`diagnose.sh`（诊断引擎）、`ui.sh`（终端 UI）
- **组件注册表** `components/registry.sh`：集中管理组件元数据、端口与描述
- **组件**：Open WebUI、MLX、Model 三套完整生命周期脚本（`metadata` / `install` / `start` / `stop` / `status` / `update` / `diagnose` / `uninstall`）
- **环境安装脚本** `env/`：Homebrew、Xcode CLI、Python、Node.js、Ollama、Git LFS、系统检测
- **配置** `config/`：`ai-studio.conf`、`ports.conf`、`default.conf`
- **文档**：`README.md`（中英双语）、`README_en.md`、`README_zh.md`、`CONTRIBUTING.md`、`CODE_OF_CONDUCT.md`、`SECURITY.md`
- **测试**：`tests/run_tests.sh`、`tests/run-spellcheck.sh`（ShellCheck 本地入口）
- **CI**：`.github/workflows/ci.yml`，运行 ShellCheck

### Known Issues

> 以下内容在 2026-10-22 的工程审核中被确认，尚未修复，将在后续版本中处理：

- `restart` 命令不可用：主入口校验 `restart.sh` 是否存在，但没有任何组件提供该文件
- `install` / `start` / `stop` / `update all` 对多数组件失败：注册表中声明的 9 个组件里，6 个仅有 `metadata.sh`，`qwen3` 目录不存在
- `diagnose all` / `uninstall all` 未实现，路径被拼成 `components/all/*.sh`
- `model` 组件已完整实现但未注册进 `SUPPORTED_COMPONENTS`，无法被命令行访问
- `config/` 下三份配置文件均未被任何代码读取，且端口值互相冲突
- 部分 `echo` 未使用 `-e`，颜色转义序列 `\033[36m` 被原样打印而非渲染
- `lib/diagnose.sh:46` 调用了未定义的 `get_component_port`（`components/registry.sh` 未被加载），
  每次诊断都输出 `command not found`
- `components/mlx/diagnose.sh:166` 的 `local venv_status=$?` 取到的是上一行 `echo` 的退出码
  （中间隔了一次 `echo`，`$?` 已被覆盖），`venv_status` 恒为 0，虚拟环境损坏时不会计入问题数、也不会触发修复建议

---

> **关于版本链接 / About version links**
>
> 本文件目前**不添加**任何版本链接引用。Keep a Changelog 惯例会在文末为每
> 个版本附上 Release / compare 链接，但那些链接只有在仓库里存在同名 Git tag
> 时才有效。当前仓库 **尚无任何 tag 或 Release**，提前写入只会产生死链。
>
> 因此遵循一条规则：**版本链接只指向真实存在的 Release**。
> 待你为 `1.0.0` 打上 tag 后，再按上述惯例补上对应链接即可。
