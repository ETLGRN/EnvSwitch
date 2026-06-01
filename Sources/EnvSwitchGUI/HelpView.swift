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
                Text("How to use EnvSwitch").font(.title2.bold())
                Spacer()
                Button("Done", action: onClose).keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("What it does") {
                        Text("Manage several environment-variable profiles and switch between them. The active profile is written to ~/.config/envswitch/active.env, which your shell loads. The “base” layer always applies; each environment overrides/extends it.")
                    }

                    section("1. Edit variables") {
                        Text("Pick “base” or an environment on the left, then add KEY/value pairs at the bottom. Turn on “Secret” to store a value in the macOS Keychain instead of plain text. Use the eye icon to reveal a secret and the copy icon (or double-click a cell) to copy a key or value.")
                    }

                    section("2. Activate") {
                        Text("Click “Activate” on an environment to make it the active one. Editing the active environment (or base) updates active.env immediately. Use “Reload” to regenerate it on demand.")
                    }

                    section("3. Apply to your terminal") {
                        Text("New terminals load the active environment automatically once the zsh hook is installed. For a terminal that is already open, run:")
                        CommandRow(command: applyCommand)
                        Button(hookInstalled ? "zsh hook installed ✓" : "Install zsh hook into ~/.zshrc") {
                            onInstallHook(); hookInstalled = true
                        }
                        .disabled(hookInstalled)
                    }

                    section("4. Install the CLI (optional)") {
                        Text("To use the `envswitch` command in the terminal, run this once, then open a new terminal. (~/.local/bin must be on your PATH.)")
                        CommandRow(command: symlinkCommand)
                        Text("Common CLI commands:").font(.subheadline.bold()).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 3) {
                            mono("envswitch list                 # list environments")
                            mono("envswitch use <env>            # switch active environment")
                            mono("eval \"$(envswitch export)\"      # apply to the current shell")
                            mono("envswitch set <env> KEY VALUE  # set a variable")
                            mono("envswitch set <env> KEY --secret  # store in Keychain")
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
