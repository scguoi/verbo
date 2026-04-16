# Verbo

macOS 语音输入工具。按下快捷键说话，识别结果自动输入到当前应用。

支持纯听写、语音润色、中译英等多种场景，通过可视化 pipeline 自由组合 STT + LLM。

## 快速开始

### 1. 安装

从 [Releases](https://github.com/scguoi/verbo/releases) 下载最新版 `Verbo-x.y.z.zip`，解压后拖到 `/Applications`。

> 首次打开时 macOS 会提示未经验证的开发者。右键 Verbo.app → 打开 → 确认，或执行 `xattr -cr /Applications/Verbo.app`。

启动后会弹出两个权限请求，都需要允许：
- **麦克风** — 录音用
- **辅助功能** — 捕获 Fn 快捷键和模拟键盘输入用

### 2. 配置讯飞语音识别

Verbo 使用[讯飞开放平台](https://www.xfyun.cn)的语音识别服务，需要注册并获取 API Key：

1. 打开 [讯飞开放平台](https://www.xfyun.cn)，注册并登录
2. 进入 [控制台](https://console.xfyun.cn)，点击「创建新应用」，填写应用名称（随意）
3. 进入 [语音识别 → 中文识别大模型](https://console.xfyun.cn/services/bmc)，点击「购买」，选择**个人免费包**（2 万次免费调用）
4. 在应用详情页找到 **APPID**、**APIKey**、**APISecret** 三个值

然后在 Verbo 中：
- 点击菜单栏的 Verbo 图标 → **Settings** → **Providers** 标签
- 在 **Iflytek** 卡片中填入上面获取的三个值 → 点击 **保存**

### 3. 开始使用

默认配置了三个场景，每个绑定了不同快捷键：

| 场景 | 说明 | 默认快捷键 |
|------|------|-----------|
| 语音输入 | 说中文 → 直接输入文字 | `Fn` |
| 润色输入 | 说中文 → LLM 润色后输入 | `Alt+J` |
| 中译英 | 说中文 → LLM 翻译成英文输入 | `Alt+T` |

**基本操作**：按一次快捷键开始录音（胶囊显示音波），再按一次停止 → 识别结果自动输入到当前焦点窗口。

> 润色和中译英场景需要额外配置 LLM 服务商（Settings → Providers → OpenAI 卡片），填入 API Key 和 Base URL。支持任何 OpenAI 兼容的 API（OpenAI、Azure、ChatAnywhere、Ollama 等）。

## 功能特性

- **菜单栏常驻**，不占 Dock，不抢焦点
- **实时预览**：说话过程中胶囊下方实时显示识别文字（可在设置中关闭）
- **场景自定义**：可视化编辑 pipeline（添加/删除 STT+LLM 步骤），自定义 prompt 和快捷键
- **灵活快捷键**：支持 `Fn`、`Right Command`、`Fn+Alt`、`Cmd+Shift+H` 等各种组合
- **智能目标路由**：录音结束后文字准确输入到你开始录音时的那个窗口
- **AirPods 支持**：自动处理蓝牙设备协商，兼容 AirPods / AirPods Pro
- **虚拟设备过滤**：自动跳过 iFlyrec、BlackHole 等虚拟音频设备
- **端到端延迟统计**：状态栏菜单显示近 50 次平均耗时
- **暗色模式**，中英双语界面

## 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon（release 为 arm64；Intel 可从源码构建）

## 从源码构建

```bash
brew install xcodegen
git clone https://github.com/scguoi/verbo.git
cd verbo/Verbo
make build     # xcodegen generate + xcodebuild
make deploy    # 构建 → 复制到 /Applications → 启动
make test      # 运行测试
```

详见 [`CLAUDE.md`](CLAUDE.md)。

## License

[MIT](LICENSE) © 2026 scguoi
