# Security Policy / 安全策略

## Supported Versions / 受支持的版本

| Version / 版本 | Supported / 是否支持 |
| :--- | :---: |
| 1.0.x | 是 |
| < 1.0 | 否 |

## Reporting a Vulnerability / 报告漏洞

**请勿在公开的 Issue 或 Discussions 中报告安全漏洞。**
Please **do not** report security vulnerabilities in public Issues or Discussions.

本项目**唯一的**漏洞接收渠道是 GitHub Security Advisories 私密通道。
The **only** accepted channel for reporting vulnerabilities is GitHub Security Advisories.

**[提交安全漏洞报告 / Report a vulnerability](https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs/security/advisories/new)**

（也可在仓库页面进入 Security → Report a vulnerability；该通道提交的报告仅维护者可见。）
(Alternatively: Security → Report a vulnerability in the repository. Reports filed there are visible only to maintainers.)

### 响应时限 / Response SLA

| 阶段 / Stage | 时限 / Target |
| :--- | :--- |
| 确认收到 / Acknowledgement | 48 小时内 / within 48 hours |
| 初步评估 / Initial assessment | 7 天内 / within 7 days |
| 修复发布 / Fix released | 30 天内 / within 30 days |

### 披露窗口 / Disclosure Policy

- 我们将与你协调公开时间，默认在修复版本发布 **14 天后**公开披露。
- We will coordinate the disclosure timeline with you; the default embargo is **14 days** after the fix is released.
- 若你希望署名，我们会在 Release Notes 与 Advisory 中致谢。
- We are happy to credit you in the release notes and advisory, if you wish.

## Scope / 适用范围

以下属于本项目的安全关注范围：

- `ai-studio.sh` 主入口的参数处理与命令派发
- `components/*/` 下各组件的安装、启停、卸载脚本
- `env/` 与 `lib/env-install.sh` 中的依赖安装流程（含远程脚本下载）
- 配置文件中密钥或令牌的处理

不属于本项目范围的问题（请上报给上游）：

- Open WebUI、MLX、ComfyUI 等**上游组件自身**的漏洞
- Homebrew、Python、Node.js、Ollama 等**系统依赖**的漏洞

## Security Best Practices / 安全建议

使用本项目时请注意：

- **验证脚本完整性**：`env install` 会从网络下载并执行 Homebrew / Ollama 的安装脚本。
  执行前请先查看 `lib/env-install.sh` 与 `env/install-ollama.sh` 的实际内容。
- **审阅安装脚本**：组件安装脚本会在本地创建虚拟环境、克隆仓库并安装包，
  建议在运行 `install` 前浏览对应组件目录下的 `install.sh`。
- **谨慎使用卸载**：测试卸载时请加 `--keep-data`，避免误删模型与用户数据。
- **不要提交密钥**：`.env`、令牌、私钥均已列入 `.gitignore`；如不慎入库，
  仅删除文件无效，需用 `git-filter-repo` 或 BFG 清洗历史。
