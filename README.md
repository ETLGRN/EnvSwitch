# EnvSwitch

[English](README.en.md) | **中文**

一个用于在 macOS 上管理多套本地环境变量配置、并一键切换的工具 —— 类似 [SwitchHosts](https://github.com/oldj/SwitchHosts)，但管理的是环境变量。同时提供 **命令行工具**（`envswitch`）和 **图形界面**（菜单栏快速切换 + 编辑窗口）。

配置统一存放在用户主目录下的 `~/.config/envswitch/`，**绝不写进项目目录**。

## 功能特性

- base 公共层 + 多个环境覆盖，一键切换激活的环境。
- **GUI**（菜单栏快速切换 + 编辑窗口）与 **CLI**（`envswitch`）共用同一套核心逻辑。
- 单一 TOML 配置文件，位于 `~/.config/envswitch/`，不污染你的项目目录。
- 新开终端通过 zsh hook 自动加载当前环境；已打开的终端用一条命令即可应用。
- 可选的 **launchctl 同步**，让之后启动的 GUI 程序也能读到这些变量。
- 变量以明文存储，仅支持 **zsh**，需要 **macOS 14+**。

## 快速上手

1. **安装** —— 打开 `dist/EnvSwitch-0.1.0.dmg`，把 **EnvSwitch.app** 拖到「应用程序」（首次启动：右键 →「打开」）。或从源码构建（见 [安装](#安装)）。
2. **添加变量** —— 打开 EnvSwitch，选择 `base` 或新建一个环境，在底部填入 `KEY` / 值。点 **Activate** 把某个环境设为当前激活（放在 `base` 里的变量即使不激活也始终生效）。
3. **接入你的 shell** —— 接受首次启动的提示安装 zsh hook（或执行 `envswitch shell-init >> ~/.zshrc`）。
4. **开始使用** —— 新开一个终端，变量就已加载。对于已经打开的终端，运行 `eval "$(envswitch export)"`。

## 激活机制（请先阅读）

在 macOS 上，环境变量是进程**启动时**从父进程继承的。不像 `/etc/hosts`（每次查询都实时读取），没有办法对已经运行的进程全局修改变量。因此 EnvSwitch 这样激活一个环境：

1. 当你切换（或编辑）环境时，EnvSwitch 把 `base` + 当前激活环境合并，并将结果写入 `~/.config/envswitch/active.env`（一个由 `export KEY='VALUE'` 行组成、权限为 `600` 的文件）。编辑激活环境或 base 会立即重新生成该文件。
2. `~/.zshrc` 里的一行 hook 会 source 这个文件，于是**每个新开的终端都会自动加载当前激活环境**。
3. 对于**已经打开**的终端，运行 `eval "$(envswitch export)"` 把当前环境应用到该 shell。（`envswitch reload` 只会重新生成 `active.env`，无法改变一个已经在运行的进程。）
4. 可选：开启 **launchctl 同步**，让之后从 Dock/Spotlight 启动的 GUI 程序也能看到这些变量（`launchctl setenv`）。默认关闭，且需要重启目标程序。

未激活任何环境时，**base 层仍会单独导出** —— 所以那些到处都要用的变量可以直接放在 `base` 里。

只支持 **zsh**。

## 数据模型

一个位于 `~/.config/envswitch/config.toml` 的 TOML 文件，包含一个共享的 `base` 层和各环境的覆盖项。激活环境的最终变量 = `base` 合并该环境（环境的同名键优先）。

```toml
active = "dev"                 # 当前激活的环境
launchctl_sync = false         # 是否通过 launchctl setenv 同步给 GUI 程序

[base]                         # 始终生效
LANG = "zh_CN.UTF-8"
EDITOR = "vim"

[env.dev]
API_HOST = "dev.example.com"
TOKEN = "dev-token"

[env.prod]
API_HOST = "prod.example.com"
TOKEN = "prod-token"
```

所有值都以明文形式存储在 `config.toml` 中，生成的 `active.env`（权限 `600`）保存供 shell 读取的最终值。由于环境变量一旦 export 出去本质上就是明文，EnvSwitch 不尝试加密；如果在意保密，请不要把 `config.toml` 同步/提交到别处。

## 安装

### 方式一：使用预编译的 App（.dmg）

1. 打开 `dist/EnvSwitch-0.1.0.dmg`，把 **EnvSwitch.app** 拖到「应用程序」。
2. 仅首次启动：因为 App 是 ad-hoc 签名（未公证），需要右键 →「**打开**」，或执行：
   ```bash
   xattr -dr com.apple.quarantine /Applications/EnvSwitch.app
   ```
3. 首次启动时，App 会引导你安装 zsh hook，并显示把 CLI 加入 PATH 的命令。内嵌的 CLI 位于 `/Applications/EnvSwitch.app/Contents/Resources/envswitch`，用下面这条（无需 sudo）创建软链：
   ```bash
   mkdir -p ~/.local/bin && ln -sf "/Applications/EnvSwitch.app/Contents/Resources/envswitch" ~/.local/bin/envswitch
   ```
   （确保 `~/.local/bin` 在你的 `PATH` 中，然后新开一个终端。）

### 方式二：从源码构建

需要 Swift 5.9+ / macOS 14+。

```bash
git clone https://github.com/ETLGRN/EnvSwitch.git && cd EnvSwitch
swift build -c release

# 把 CLI 加入 PATH（无需 sudo）：
mkdir -p ~/.local/bin && ln -sf "$(pwd)/.build/release/envswitch" ~/.local/bin/envswitch

# 安装 zsh hook（或自己把输出粘到 ~/.zshrc）：
envswitch shell-init >> ~/.zshrc
exec zsh   # 重新加载你的 shell
```

## 命令行参考

```
envswitch list                 # 列出所有环境，激活的用 * 标记
envswitch use <env>            # 切换激活环境（新开的终端会自动加载）
envswitch reload               # 根据 base + 激活环境重新生成 active.env
envswitch current              # 显示当前激活环境及其导出内容
envswitch get KEY              # 打印某个变量解析后的值
envswitch set <env> KEY VALUE  # 设置变量（用 "base" 作为 <env> 表示 base 层）
envswitch unset <env> KEY      # 删除变量
envswitch add <env>            # 新建环境
envswitch rm <env>             # 删除环境
envswitch edit                 # 用 $EDITOR 打开 config.toml
envswitch export [<env>]       # 打印 export 语句（供 eval 使用）
envswitch import <env> <.env>  # 从 .env 文件导入 KEY=VALUE
envswitch shell-init           # 打印需要加入 ~/.zshrc 的 zsh hook
```

### 在已打开的 shell 中的典型用法

```bash
envswitch use dev      # 全局切换（影响新开的终端）
eval "$(envswitch export)"   # 立即应用到当前这个 shell
```

## 图形界面

- **菜单栏**（`switch.2` 图标）：列出所有环境，激活的那个带实心圆点 —— 点击即可立即切换。还提供「编辑环境…」和「使用说明…」（都会打开主窗口）。
- **主窗口**：左侧是 `base` + 你的各个环境，右侧是所选层的变量表。在底部用 `KEY` / 值字段添加变量；**双击**（或右键 → 复制，或点复制图标）即可复制 key 或值；垃圾桶图标删除变量。
  - **Activate** 把选中环境设为激活；**Reload** 按需重新生成 `active.env`。底部显示给已打开终端用的 `eval "$(envswitch export)"` 命令（带复制按钮）。
  - **?** 按钮打开应用内的中文使用说明，涵盖激活、应用到终端、安装 CLI。
- **设置**：开关 launchctl 同步。
- 首次启动会弹出引导，提示安装 zsh hook 并显示 CLI 软链命令。

## 架构

一个 SwiftPM 工作区，三个部分共用一个核心库：

- **EnvSwitchCore** —— TOML 配置读写（原子写入）、`base + 环境` 合并、`active.env` 生成（含 shell 转义）、zsh hook 片段、`launchctl` 同步。所有行为均有单元测试。
- **envswitch** —— CLI（基于 swift-argument-parser），是 Core 的薄封装。
- **EnvSwitchGUI** —— SwiftUI 应用：`MenuBarExtra` 负责快速切换，主窗口含环境列表与变量编辑器，外加设置页。

测试位于 `Tests/EnvSwitchCoreTests`，用 `swift test` 运行。（本项目统一使用 **Swift Testing** 框架，而非 XCTest。）

为便于隔离，CLI 支持通过 `ENVSWITCH_HOME` 环境变量指向另一个配置根目录（测试和安全试用时使用）。

## 打包成可安装的 App

运行内置脚本 —— 它会构建 release 二进制、组装签名后的 `.app`，并生成 `.dmg`：

```bash
scripts/package.sh
# 产物：
#   dist/EnvSwitch.app
#   dist/EnvSwitch-0.1.0.dmg
```

脚本对 bundle 进行 ad-hoc 签名（无需 Apple 开发者账号）。GUI 是 bundle 的主可执行文件（`Contents/MacOS/EnvSwitch`），`envswitch` CLI 内嵌在 `Contents/Resources/envswitch`（之所以不放 `MacOS/`，是因为 macOS 卷默认大小写不敏感，`EnvSwitch` 与 `envswitch` 会冲突）。首次启动时 App 会引导安装 zsh hook 并显示把内嵌 CLI 软链到 PATH 的命令。

> 由于 App 是 ad-hoc 签名（未公证），首次启动需要右键 →「**打开**」（或执行 `xattr -dr com.apple.quarantine EnvSwitch.app`）以通过 Gatekeeper。若要更广泛地分发，请使用 Developer ID 签名并进行公证。
