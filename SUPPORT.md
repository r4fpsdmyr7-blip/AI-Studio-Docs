# 获取支持 (Support)

使用 AI Studio 遇到问题？请按以下顺序寻求帮助。

---

## 1. 先自助排查（最快）

AI Studio 自带诊断能力，多数问题可以在这一步定位：

```bash
./ai-studio.sh env check          # 检查系统环境是否满足要求
./ai-studio.sh env status         # 查看系统环境概览
./ai-studio.sh diagnose <组件名>  # 诊断指定组件
./ai-studio.sh diagnose <组件名> --deep     # 深入诊断
./ai-studio.sh diagnose <组件名> --deep --fix  # 深入诊断并尝试自动修复
./ai-studio.sh status <组件名>    # 查看组件运行状态
```

运行日志位于 `logs/<组件名>.log`，诊断时请一并提供。

---

## 2. 查阅文档

| 文档 | 内容 |
| :--- | :--- |
| [`README.md`](./README.md) | 项目总览与快速开始（中英双语） |
| [`README_zh.md`](./README_zh.md) | 完整中文使用指南 |
| [`README_en.md`](./README_en.md) | 完整 English guide |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | 参与开发、新增组件、代码规范 |
| [`CHANGELOG.md`](./CHANGELOG.md) | 版本变更记录 |
| [`SECURITY.md`](./SECURITY.md) | 安全漏洞报告方式 |

---

## 3. 提问与讨论

- **Bug 报告 / 功能建议** → [GitHub Issues](https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs/issues)
  提交前请先搜索是否已有相同问题；请尽量使用 Issue 模板填写完整信息。
- **使用问题 / 经验交流** → [GitHub Discussions](https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs/discussions)

### 提问时请附上

1. macOS 版本（`sw_vers`）与芯片类型（`uname -m`）
2. Bash 版本（`bash --version`）
3. AI Studio 版本（`./ai-studio.sh version`）
4. 你执行的完整命令与完整输出
5. `logs/<组件名>.log` 中的相关片段

信息越完整，定位越快。

---

## 4. 安全问题 / 行为准则

**请勿在公开的 Issue 或 Discussions 中报告安全漏洞或行为准则问题。**
Please do not report security or Code-of-Conduct issues in public Issues or Discussions.

统一通过 GitHub Security Advisories 私密渠道提交：

提交地址：https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs/security/advisories/new

详见 [`SECURITY.md`](./SECURITY.md) 与 [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md)。

---

## 当前支持范围

| 项目 | 状态 |
| :--- | :--- |
| 版本 | `1.0.x` 支持 ｜ 更早版本 不支持 |
| 平台 | macOS 13+ 支持 ｜ Apple Silicon 推荐 ｜ Linux 实验性 |
| 组件 | Open WebUI、MLX、Model 支持 ｜ 其余组件 尚未实现，见 `CHANGELOG.md` 的 Known Issues |

> 正在寻找贡献方式？请看 [`CONTRIBUTING.md`](./CONTRIBUTING.md)，
> Issues 中带有 `good first issue` 标签的任务适合新手入门。
