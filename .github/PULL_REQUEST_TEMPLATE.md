# Pull Request

感谢你的贡献！请填写以下内容，帮助维护者快速理解与 review。

## 关联 Issue

<!-- 例如：Closes #123 -->

Closes #

## 变更说明

<!-- 这个 PR 解决了什么问题？做了什么改动？ -->

## 变更类型

<!-- 请勾选适用的项 -->

- [ ] `fix` — 修复 Bug
- [ ] `feat` — 新功能（新组件 / 新命令 / 新参数）
- [ ] `docs` — 仅文档变更
- [ ] `style` — 格式调整，不影响逻辑
- [ ] `refactor` — 重构，既不修 Bug 也不加功能
- [ ] `test` — 新增或修改测试
- [ ] `chore` — 构建过程或辅助工具变动

## 如何测试

<!-- 请给出 reviewers 可以直接跑的验证步骤 -->

```bash
# 例如：
./ai-studio.sh install open-webui
./ai-studio.sh start open-webui
./ai-studio.sh status open-webui
```

## Breaking Changes

<!-- 是否破坏了向后兼容？如果有，请说明影响范围与迁移方式；没有就填「无」 -->

无

## 影响范围

<!-- 影响哪些组件 / 库 / 命令？ -->

- [ ] 主入口 `ai-studio.sh`
- [ ] 核心库 `lib/`
- [ ] 组件注册表 `components/registry.sh`
- [ ] 具体组件：
- [ ] 环境安装脚本 `env/`
- [ ] 文档
- [ ] CI / 测试

## 提交前自检

<!-- 请确认已逐项完成，CI 会重复检查其中大部分 -->

- [ ] 已运行 `make check` 且全部通过（语法 / 可执行位 / Bash 3.2 兼容 / ShellCheck / 单元测试）
- [ ] 未引入 emoji（三层一律禁用，`make emoji` 为 CI 阻断项）
- [ ] 遵循语言策略：构成层（标识符 / 代码 / 配置键）保持英文 ASCII；
      UI 文案走消息层 `msg` / `msgf`，不新增硬编码字面量（`make lang` 校验）
- [ ] 新增的 `.sh` 文件已具备可执行位（可执行 `make fix-perms`）
- [ ] 未使用 Bash 4.0+ 语法（macOS 默认 Bash 为 3.2）
- [ ] 提交信息遵循 Conventional Commits：`feat(scope): 描述`
- [ ] 如新增组件：已同步更新 `registry.sh` 的 `SUPPORTED_COMPONENTS` / `get_component_port` / `get_component_description`
- [ ] 已同步更新相关文档（README / README_zh / README_en）
- [ ] 已更新 `CHANGELOG.md` 的 `Unreleased` 段落
- [ ] 若改动了架构、目录结构或文件清单：已同步更新 `README_FOR_AI.md`（重建规格）
      并复核 `AGENTS.md` 中的约束与 Don't 清单是否仍然成立

---

> 代码规范详见 [`CONTRIBUTING.md`](../CONTRIBUTING.md)。
> 本地一键检查：`make check`
