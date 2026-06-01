import SwiftUI
import EnvSwitchCore

struct FirstRunView: View {
    let onInstallHook: () -> Void
    let symlinkCommand: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Finish EnvSwitch setup").font(.title2.bold())
            Text("1. Add the zsh hook so new terminals load the active environment:")
            Button("Install zsh hook into ~/.zshrc", action: onInstallHook)
            Text("2. Put the CLI on your PATH by running this in Terminal:")
            Text(symlinkCommand).font(.system(.body, design: .monospaced))
                .textSelection(.enabled).padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(24)
        .frame(width: 520)
    }
}
