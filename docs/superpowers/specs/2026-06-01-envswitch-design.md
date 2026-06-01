# EnvSwitch 设计文档

- 日期：2026-06-01
- 状态：已通过头脑风暴评审，待实现计划
- 目标平台：macOS 14+

## 1. 目标与背景

在 macOS 上提供一个像 SwitchHosts 管理 hosts 那样、用来**管理本地环境变量**的工具，支持多套环境配置一键切换。要求：

- 同时提供 **CLI** 和 **GUI**。
- 支持多个可配置的环境（profile），可一键切换激活环境。
- 配置**不放在项目目录**，统一放在用户主目录下（`~/.config/envswitch/`）。
- 仅针对 **zsh**。

### 关键约束认知

macOS 上环境变量在进程**启动时从父进程继承**，无法像 `/etc/hosts` 那样被实时全局读取。因此「切换环境」不能真正影响已运行进程，必须通过明确的激活机制实现（见第 4 节）。

## 2. 总体架构

一个 SwiftPM 工作区，分三个模块，CLI 与 GUI 共用核心库以保证行为一致：

- **EnvSwitchCore**（共享库，纯 Swift，无 UI/CLI 依赖）
  - TOML 配置读写
  - `base + env` 合并逻辑（环境优先覆盖）
  - Keychain 存取（敏感值）
  - 生成 `active.env` 与 `export` 语句
  - launchctl 同步
  - 可单元测试（Keychain 通过协议抽象，便于 mock）
- **envswitch（CLI）**：基于 `swift-argument-parser`，是 Core 的薄包装。
- **EnvSwitch（GUI）**：SwiftUI，`MenuBarExtra`（菜单栏快速切换）+ 主窗口（编辑）。

三者都操作同一份 `~/.config/envswitch/config.toml`。

## 3. 数据模型与配置格式

单一 TOML 文件：`~/.config/envswitch/config.toml`。采用「公共层 base + 环境覆盖」模型。

```toml
active = "dev"                 # 当前激活的环境名
launchctl_sync = false         # 是否同步到 GUI 程序（launchctl setenv）

[base]                         # 始终生效的公共层
LANG = "zh_CN.UTF-8"
EDITOR = "vim"

[env.dev]
API_HOST = "dev.example.com"
TOKEN = { secret = true }      # 敏感值：真实内容在 Keychain，文件里只留标记

[env.prod]
API_HOST = "prod.example.com"
TOKEN = { secret = true }
```

- 普通变量：直接 `KEY = "VALUE"`。
- 敏感变量：`KEY = { secret = true }`，真实值存 Keychain，文件不落明文。
- 激活某环境时最终变量集 = `base` 合并该环境，环境同名键覆盖 base。
- base 同样允许标记敏感值。

## 4. 激活机制

支持三种生效方式，对应头脑风暴确认的 A+C 为核心、B 可选：

### 4.1 Shell 集成（核心 / 默认）
- Core 将「当前激活环境的合并结果」写到 `~/.config/envswitch/active.env`，内容为 `export KEY="VALUE"` 形式（值做 shell 转义）。
- `~/.zshrc` 中加入一行 hook：在每个新交互式 shell 启动时 `source` 该文件 → **新终端自动生效**。
- `envswitch shell-init` 输出该 hook 代码供用户粘贴；GUI 首启也可代为写入。

### 4.2 当前 shell 即时刷新
- `envswitch reload`（或 `eval "$(envswitch export)"`）刷新已打开终端为当前激活环境。
- `envswitch use <env>` 在切换全局激活的同时，亦可即时作用于当前 shell。

### 4.3 launchctl 同步（可选，默认关闭）
- 开启 `launchctl_sync` 后，切换激活环境时额外执行 `launchctl setenv KEY VALUE`，使之后从 Dock/Spotlight 启动的 GUI 程序读到这些变量（需重启目标程序）。

## 5. 敏感信息处理（Keychain）

- 变量标记 `secret = true` 时，真实值存入 macOS 钥匙串：service = `envswitch`，account = `<env>/<KEY>`（base 用 `base/<KEY>`）。
- TOML 中不落明文。
- 生成 `active.env` 时从 Keychain 取回真实值写入；`active.env` 文件权限设为 `600`。
- GUI 中敏感值默认显示为 `••••`，可点击「显示/编辑」。
- Core 通过 `KeychainStore` 协议访问钥匙串，测试时注入内存实现。

## 6. CLI 命令集（zsh）

```bash
envswitch list                 # 列出所有环境，标出当前激活的
envswitch use <env>            # 切换激活环境（重写 active.env），新终端自动生效
envswitch reload               # 在当前终端立即刷新为激活环境
envswitch current              # 显示当前激活环境名和生效变量
envswitch get KEY              # 查看某个变量的值
envswitch set <env> KEY VALUE  # 给指定环境设置变量
envswitch set <env> KEY --secret  # 设为敏感值，存入钥匙串
envswitch unset <env> KEY      # 删除变量
envswitch add <env>            # 新建环境
envswitch rm <env>             # 删除环境
envswitch edit                 # 用 $EDITOR 打开 config.toml
envswitch export [<env>]       # 输出 export 语句（供 eval 用）
envswitch import <env> <.env>  # 从现有 .env 文件导入
envswitch shell-init           # 输出 zshrc 里要加的 hook 代码
```

- CLI 非零退出码表示失败，并打印明确错误。

## 7. GUI

- **菜单栏（MenuBarExtra）**：图标下拉显示所有环境（单选圆点标当前激活），点击即切换激活；底部「编辑环境…」「设置」。
- **主窗口**：
  - 左侧：环境列表（含 base）、新建/删除。
  - 右侧：变量表格（增删改、敏感开关、显示/隐藏值），右上「激活此环境」。
  - 设置页：开机自启、launchctl 同步开关、重新链接 CLI、写入/更新 zsh hook。

## 8. 分发

- 单个 `.app`，内置 `envswitch` 二进制。
- 首次启动检测并提示将 CLI 软链到 `/usr/local/bin`（或 `~/.local/bin`），并提示一次性写入 zsh hook。
- 目标 macOS 14+（`MenuBarExtra` 需要）。

## 9. 错误处理与可靠性

- Core 对配置解析失败、Keychain 失败、文件权限问题定义明确错误类型。
- 写 `active.env` 和 `config.toml` 采用「写临时文件 + 原子替换」，避免半写损坏。
- shell 值转义：生成 `export` 时正确转义引号、空格、特殊字符。

## 10. 测试策略

- 单元测试集中在 EnvSwitchCore：
  - `base + env` 合并与覆盖
  - TOML 读写往返
  - `export` 语句的转义正确性
  - Keychain 经协议 mock 后的存取
- CLI 端到端冒烟测试若干（在临时 HOME 下运行）。

## 11. 明确不做（YAGNI / 未来）

- 暂不支持 bash / fish（仅 zsh）。
- 暂不做多层可叠加激活（采用单环境 + base 覆盖模型）。
- 暂不做云端/团队同步。
- 暂不做 Homebrew 分发（CLI 随 .app 内置）。
