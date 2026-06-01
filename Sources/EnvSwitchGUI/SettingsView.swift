import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Toggle("Sync to GUI apps (launchctl setenv)", isOn: Binding(
                get: { model.launchctlSync },
                set: { model.setLaunchctlSync($0) }))
            Text("New shells load the active environment automatically once the zsh hook is installed. Use the CLI `envswitch shell-init` to print the hook.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { model.refresh() }
    }
}
