# AI Studio Manager for macOS

## 概述

`ai-studio.sh` 是一个功能完整的 macOS 脚本，用于管理以下 AI 工具的部署、运行、更新和维护：

- 🔗 **Open WebUI** - 开源的 LLM Web 界面 (端口: 8080)
- 🎭 **SillyTavern** - AI 角色扮演聊天界面 (端口: 8000)
- ⚡ **Continue.dev** - VSCode AI 编程助手 (端口: 3000)
- 🔄 **FaaS** - 函数即服务平台 (端口: 8081)
- 🌐 **Browser Use** - 浏览器自动化 Agent (端口: 8082)
- 🧠 **MLX** - Apple Silicon 机器学习框架 (本地库)
- 🎨 **ComfyUI** - SDXL/FLUX 工作流图像生成 (端口: 8188)
- 🎬 **MLX-Video** - Apple Silicon 视频生成框架 (本地库)

## 📋 系统要求

- macOS 13.0+ (Ventura 或更高版本)
- Apple Silicon (M1/M2/M3) 或 Intel Mac
- 至少 16GB RAM (推荐 32GB+)
- 至少 100GB 可用磁盘空间
- 稳定的互联网连接

## 🚀 快速开始

### 1. 下载并赋予执行权限

```bash
# 下载脚本
curl -o ~/ai-studio.sh https://raw.githubusercontent.com/your-repo/ai-studio.sh

# 赋予执行权限
chmod +x ~/ai-studio.sh
```

### 2. 运行脚本

```bash
# 交互式菜单模式（推荐）
~/ai-studio.sh

# 或命令行模式
~/ai-studio.sh --help
```

### 3. 首次部署

在菜单中选择 `1. 首次部署 (全部)`，脚本将：
- ✅ 自动检查并安装缺失依赖 (Homebrew, Git, Python, Node.js 等)
- ✅ 克隆所有组件的 GitHub 仓库
- ✅ 创建虚拟环境并安装依赖
- ✅ 生成启动脚本

## 📖 功能详解

### 🎛️ 菜单选项

| 选项 | 功能 | 说明 |
|------|------|------|
| 1 | 首次部署 (全部) | 一键部署所有 8 个组件 |
| 2 | 选择性部署 | 单独部署指定组件 |
| 3 | 启动所有服务 | 启动所有已部署的服务 |
| 4 | 停止所有服务 | 停止所有运行中的服务 |
| 5 | 启动单个服务 | 选择并启动单个组件 |
| 6 | 停止单个服务 | 选择并停止单个组件 |
| 7 | 查看状态 | 显示所有组件的运行状态 |
| 8 | 简单诊断 | 基础系统和依赖检查 |
| 9 | 深度诊断 | 详细系统、网络、环境诊断 |
| 10 | 更新全部 | 更新所有已安装的组件 |
| 11 | 更新前端 | 仅更新 WebUI 类组件 |
| 12 | 更新 Agent | 仅更新 Agent/服务类组件 |
| 13 | 更新架构及模型 | 仅更新 ML 框架和模型组件 |
| 14 | 版本回退 | 从备份恢复指定组件的旧版本 |
| 15 | 卸载单个组件 | 删除指定组件 |
| 16 | 完全卸载 | 删除所有组件和数据 ⚠️ |
| 0 | 退出 | 退出脚本 |

### 🌐 命令行参数

```bash
~/ai-studio.sh --deploy-all      # 部署所有组件
~/ai-studio.sh --start-all       # 启动所有服务
~/ai-studio.sh --stop-all        # 停止所有服务
~/ai-studio.sh --status          # 查看状态
~/ai-studio.sh --diagnose-simple # 简单诊断
~/ai-studio.sh --diagnose-deep   # 深度诊断
~/ai-studio.sh --help            # 显示帮助
```

### 🔍 诊断功能

#### 简单诊断 (`--diagnose-simple`)
- macOS 版本和芯片类型
- 内存和磁盘空间
- 基础依赖安装状态
- 组件安装状态
- 端口占用情况

#### 深度诊断 (`--diagnose-deep`)
- 包含简单诊断所有内容
- CPU/GPU 详细信息
- Python/Node.js 环境详情
- Git 仓库分支和提交信息
- 网络连通性测试 (GitHub, HuggingFace, PyPI)

### 🔄 更新与回退

#### 选择性更新
脚本支持按类别更新：
- **前端组件**: Open WebUI, SillyTavern, Continue.dev, ComfyUI
- **Agent 组件**: Browser Use, FaaS, MLX
- **模型组件**: MLX, MLX-Video, ComfyUI

#### 版本回退
1. 每次更新前自动创建备份 (`~/ai-studio/backups/`)
2. 选择 `14. 版本回退` → 选择组件 → 选择备份版本
3. 脚本自动停止服务并恢复备份

### 🌐 浏览器自动打开

启动带 Web 界面的服务时，脚本会自动：
1. 检查服务是否成功启动
2. 使用 macOS `open` 命令打开默认浏览器
3. 跳转到对应服务的本地地址

| 组件 | 自动打开的 URL |
|------|---------------|
| Open WebUI | http://localhost:8080 |
| SillyTavern | http://localhost:8000 |
| Continue.dev | http://localhost:3000 |
| FaaS | http://localhost:8081 |
| Browser Use | http://localhost:8082 |
| ComfyUI | http://localhost:8188 |

## 📁 目录结构

```
~/ai-studio/
├── open-webui/          # Open WebUI 源码和虚拟环境
├── sillytavern/         # SillyTavern 源码
├── continue-dev/        # Continue.dev 源码
├── faas/                # FaaS 配置
├── browser-use/         # Browser Use 源码
├── mlx/                 # MLX 框架
├── comfyui/             # ComfyUI 源码和模型
├── mlx-video/           # MLX-Video 框架
├── logs/                # 运行日志和 PID 文件
│   ├── open-webui.log
│   ├── open-webui.pid
│   └── ...
├── backups/             # 更新备份 (用于回退)
│   ├── open-webui_20260531_120000.tar.gz
│   └── ...
└── config.json          # 用户配置 (可选)
```

## ⚠️ 注意事项

### 首次部署
- 可能需要 30-60 分钟，取决于网络速度
- ComfyUI 模型下载可能需要额外时间
- 确保有足够磁盘空间 (建议 100GB+)

### 日常使用
- 服务以后台进程运行，关闭终端不影响
- 日志文件位于 `~/ai-studio/logs/`
- 使用 `--status` 或菜单选项 7 查看运行状态

### 更新建议
- 更新前建议先备份重要数据
- 大版本更新可能需手动调整配置
- 回退功能依赖更新时创建的备份

### 卸载警告
- `完全卸载` 会删除 `~/ai-studio/` 下所有内容
- 包括所有模型、配置和用户数据
- 操作前请确认已备份重要文件

## 🔧 故障排除

### 常见问题

**问题**: 依赖安装失败
```bash
# 手动安装 Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 然后重试
~/ai-studio.sh --deploy-all
```

**问题**: 端口被占用
```bash
# 查看占用端口的进程
lsof -i :8080

# 终止进程或修改组件端口配置
```

**问题**: Python 虚拟环境激活失败
```bash
# 手动激活并重新安装
cd ~/ai-studio/open-webui
source venv/bin/activate
pip install -e ".[docker]"
```

**问题**: 服务启动后浏览器未打开
```bash
# 检查服务日志
cat ~/ai-studio/logs/open-webui.log

# 手动打开
open http://localhost:8080
```

### 日志查看

```bash
# 实时查看日志
tail -f ~/ai-studio/logs/open-webui.log

# 查看错误日志
grep -i error ~/ai-studio/logs/*.log
```

## 🛠️ 自定义配置

编辑 `~/ai-studio.sh` 顶部的配置区：

```bash
# 修改安装目录
readonly INSTALL_DIR="${HOME}/my-ai-tools"

# 修改组件端口
[open-webui]="Open WebUI|https://...|9090|http://localhost:9090"

# 添加新组件
[my-tool]="My Tool|https://github.com/user/repo.git|9999|http://localhost:9999"
```

## 📝 许可证

本脚本采用 GNU GPL3 许可证。各组件遵循其各自的开源许可证。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 改进此脚本！

---

> 💡 **提示**: 建议定期运行 `简单诊断` 检查系统状态，并在重大更新前使用 `深度诊断` 确保环境健康。
