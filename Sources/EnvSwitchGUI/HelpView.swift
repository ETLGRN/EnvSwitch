import SwiftUI
import AppKit

struct HelpView: View {
    let symlinkCommand: String
    let applyCommand: String
    let onInstallHook: () -> Void
    let onClose: () -> Void

    @State private var hookInstalled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("使用说明").font(.title2.bold())
                Spacer()
                Button("完成", action: onClose).keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("这是什么") {
                        Text("管理多套环境变量配置并一键切换。当前激活的配置会写入 ~/.config/envswitch/active.env，由终端加载。“base” 公共层始终生效，各环境在其上覆盖或新增。")
                    }

                    section("① 编辑变量") {
                        Text("在左侧选择 “base” 或某个环境，然后在底部添加 KEY / 值。打开 “Secret” 开关可把值存入 macOS 钥匙串而非明文。点眼睛图标可显示 secret，点复制图标（或双击单元格）可复制 key 或值。")
                    }

                    section("② 激活") {
                        Text("点环境上的 “Activate” 将其设为当前激活环境。编辑激活环境（或 base）会立即更新 active.env。也可点 “Reload” 手动重新生成。")
                    }

                    section("③ 应用到终端") {
                        Text("装好 zsh hook 后，新开的终端会自动加载当前激活环境。对于已经打开的终端，执行：")
                        CommandRow(command: applyCommand)
                        Button(hookInstalled ? "zsh hook 已安装 ✓" : "把 zsh hook 写入 ~/.zshrc") {
                            onInstallHook(); hookInstalled = true
                        }
                        .disabled(hookInstalled)
                    }

                    section("④ 安装命令行工具 CLI（可选）") {
                        Text("想在终端使用 `envswitch` 命令，执行下面这条（一次即可），然后新开一个终端。（需保证 ~/.local/bin 在你的 PATH 中。）")
                        CommandRow(command: symlinkCommand)
                        Text("常用 CLI 命令：").font(.subheadline.bold()).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 3) {
                            mono("envswitch list                 # 列出所有环境")
                            mono("envswitch use <env>            # 切换激活环境")
                            mono("eval \"$(envswitch export)\"      # 应用到当前终端")
                            mono("envswitch set <env> KEY VALUE  # 设置变量")
                            mono("envswitch set <env> KEY --secret  # 存入钥匙串")
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 560, height: 560)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }

    private func mono(_ s: String) -> some View {
        Text(s).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
    }
}

/// A monospaced command line with a copy button.
private struct CommandRow: View {
    let command: String

    var body: some View {
        HStack {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless)
                .help("Copy")
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}
