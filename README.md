# 微记 · WeNote

<div align="center">
**一款类微信传输助手界面的桌面笔记应用**

用微信传输助手的方式做笔记，让记录像聊天一样自然。

目前仅测试windows桌面端。

[![Flutter](https://img.shields.io/badge/Flutter-3.41+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

## 简介

**微记（WeNote）** 是一个 Windows 桌面笔记应用，采用微信风格的聊天界面。你可以像聊天一样创建多个会话，在会话中记录文字、图片、文件等各种内容。每一次记录就是一条"消息"，按时间线排列，自然形成你的知识脉络。

### 为什么用聊天方式做笔记？

- **零学习成本** — 人人都会聊天，不需要学习任何新操作
- **时间线天然有序** — 消息按时间排列，你的笔记自动生成时间轴
- **多媒体融合** — 文字、截图、文件都在一条时间线上，不是割裂的富文本块
- **多会话隔离** — 每个主题一个"聊天窗口"，比文件夹更直观

## 特性

### 会话管理
- 创建、重命名、删除、置顶会话
- 全文搜索 — 同时搜索会话名称和消息内容
- 搜索结果高亮显示，支持上一个/下一个导航
- 展开式匹配列表，一键跳转到对应消息

### 消息编辑
- 文字消息 — 输入即发送，Enter 发送 / Ctrl+Enter 换行
- 图片消息 — 选择本地图片发送，行内预览，点击全屏查看并支持缩放
- 文件附件 — 发送任意类型文件，自动识别文件类型图标，显示文件名和大小
- 截图功能 — 一键调用 Windows 截图工具，截图后自动插入输入框
- 剪贴板粘贴 — Ctrl+V 粘贴文字，若剪贴板中有截图则自动粘贴图片

### 消息交互
- 文本选择 — 鼠标拖选文字，支持 Ctrl+C 复制
- 右键菜单 — 右键消息弹出菜单，支持复制文字/图片、删除消息
- 拖拽发送 — 从文件管理器拖拽图片或文件到聊天区域即可发送
- 时间分隔线 — 自动显示时间分割，点击切换相对时间/绝对时间

### 个性化设置
- 中英文切换 — 界面语言一键切换
- 主题颜色 — 10 种预设颜色 + RGB 自定义颜色选择器
- 深色/浅色模式 — 跟随系统或手动切换
- 媒体存储路径 — 自定义图片和附件的保存位置

### 拖拽与粘贴
- 文件拖拽到聊天区域自动弹出确认对话框
- 支持多文件同时拖拽
- 确认对话框中可添加说明文字
- 剪贴板图片自动识别并粘贴（Windows）

## 技术栈

| 模块 | 技术选型 |
|------|---------|
| 框架 | Flutter 3.41+ (Dart 3.11+) |
| 状态管理 | flutter_riverpod |
| 数据库 | sqflite_common_ffi (SQLite) |
| 文件选择 | file_picker |
| 窗口管理 | window_manager |
| 桌面拖拽 | desktop_drop |
| 唯一 ID | uuid |
| 国际化 | intl |

## 项目结构

```
lib/
├── main.dart                      # 应用入口，窗口配置，设置加载
├── database/
│   └── database.dart              # SQLite 数据库定义，数据模型，CRUD 操作
├── providers/
│   └── app_providers.dart         # Riverpod 状态管理（会话、消息、设置、主题）
├── l10n/
│   └── app_localizations.dart     # 中/英文国际化字符串
├── theme/
│   └── app_theme.dart             # Material 3 主题（亮色/暗色 + 自定义主色）
├── utils/
│   └── clipboard_utils.dart       # 剪贴板工具（图片检测与保存）
├── screens/
│   ├── home_screen.dart           # 主界面布局（桌面双栏 / 移动端单栏）
│   └── settings_screen.dart       # 设置页面（语言、颜色、存储、关于）
└── widgets/
    ├── session_list.dart          # 左侧会话列表（搜索、创建、重命名、删除）
    ├── session_tile.dart          # 会话列表项组件
    ├── chat_view.dart             # 主聊天区域（消息列表、搜索导航、匹配面板）
    ├── chat_input.dart            # 底部输入栏（文字、图片、文件、截图）
    ├── message_bubble.dart        # 消息气泡（文字、图片、文件附件渲染）
    └── drop_target_area.dart      # 文件拖拽目标区域 + 发送确认对话框
```

## 数据存储

- **数据库** — SQLite，存储在 `Documents/notechat/notechat.db`
- **媒体文件** — 图片和附件存储在 `Documents/notechat/media/`（可在设置中更改）
- **设置** — 语言、主题颜色、媒体路径等存储在 `settings` 表中

## 快速开始

### 环境要求

- Flutter 3.41+（需启用 Windows 桌面支持）
- Visual Studio 2022（需安装"使用 C++ 的桌面开发"工作负载）
- Windows 10/11

### 运行

```bash
git clone https://github.com/your-username/NoteChat.git
cd NoteChat
flutter pub get
flutter run -d windows
```

### 构建发布版本

```bash
flutter build windows --release
```

构建产物在 `build/windows/x64/runner/Release/` 目录下。

## 字体说明

应用默认使用 Windows 系统自带的 **微软雅黑**，提供中文和英文一致的渲染效果。

如需使用自定义字体（如 Noto Sans SC），请参考 `fonts/README.md` 中的说明。

## 开发日志

### 第一阶段 — 基础框架
- Flutter 项目脚手架搭建
- SQLite 数据库：Sessions 表 + Messages 表
- 会话列表：新建、重命名、删除、置顶
- 聊天界面：消息气泡、日期分隔线
- 深色/浅色主题切换
- 桌面窗口管理

### 第二阶段 — 核心功能
- 图片发送与行内预览、全屏查看
- 文件附件发送（自动识别文件类型图标）
- 设置页面：语言切换、主题颜色、存储路径
- 完整的中/英文国际化
- 消息回复数据模型

### 第三阶段 — 搜索与交互优化
- 全文搜索：同时搜索会话名称和消息内容
- 搜索结果导航：上一个/下一个 + 展开式匹配列表
- 文字选择与右键菜单（复制/删除）
- Windows 截图工具集成
- 剪贴板图片粘贴
- 文件拖拽发送
- 智能时间分隔线（点击切换相对/绝对时间）
- 字体渲染优化（中英文一致粗细）
- 紧凑复制提示

## 路线图

- [ ] 富文本编辑工具栏
- [ ] 全局快捷键（Ctrl+N 新建会话、Ctrl+F 搜索）
- [ ] 系统托盘快速创建笔记
- [ ] 导出 PDF / HTML / Markdown
- [ ] 云同步
- [ ] Android / iOS 移动端支持
- [ ] 本地存储端到端加密
- [ ] 定时提醒
- [ ] 简易绘图/涂鸦工具

## 贡献

欢迎提交 Issue 和 Pull Request。在提交 PR 前请确保代码通过 `flutter analyze` 检查。

## 开源协议

本项目采用 [MIT 协议](LICENSE)。你可以自由使用、修改和分发本项目代码。
