# 智能翻译助手

一个基于 Flutter 开发的现代化桌面翻译工具，支持多平台运行。

## 功能特性

- 🚀 快速翻译：支持实时翻译功能
- 🌐 多平台支持：Windows、macOS 和 Linux
- ⌨️ 全局快捷键：使用 Alt + L 快速唤起翻译
- 📋 剪贴板集成：自动获取剪贴板内容
- 🔄 系统托盘：最小化到系统托盘继续运行
- ⚙️ 自定义配置：支持配置多种 API 参数
- 🎨 现代化界面：简洁优雅的用户界面

## 快速开始

### 系统要求

- Flutter 3.0 或更高版本
- Windows 10/11, macOS 10.14+, 或 Linux 系统
- 支持 x64 架构

### 安装步骤

1. 克隆项目到本地：

```bash
git clone https://github.com/your-repo/flutter_demo.git
cd flutter_demo
```

2. 获取依赖：

```bash
flutter pub get
```

3. 运行项目：

```bash
flutter run
```

## 打包说明

### Windows 静态打包

要生成单个 EXE 文件（包含所有 DLL），请按以下步骤操作：

1. 使用 Release 模式构建：

```bash
flutter build windows --release
```

2. 在 `build/windows/runner/Release` 目录下找到生成的 EXE 文件。

注意：生成的 EXE 文件已包含所有依赖，可以直接分发使用。
