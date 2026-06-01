import SwiftUI
import AppKit

struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @State private var newEnvName = ""
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var showFirstRun = false
    @State private var showError = false
    @State private var showHelp = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                List(selection: $model.selectedEnvironment) {
                    Section("Layers") { Text("base").tag("base") }
                    Section("Environments") {
                        ForEach(model.environmentNames, id: \.self) { name in
                            HStack {
                                Text(name)
                                if name == model.activeName {
                                    Spacer(); Image(systemName: "largecircle.fill.circle")
                                }
                            }.tag(name)
                        }
                    }
                }
                .onChange(of: model.selectedEnvironment) { _, _ in model.loadVariables() }

                HStack {
                    TextField("New environment", text: $newEnvName)
                    Button("Add") {
                        guard !newEnvName.isEmpty else { return }
                        model.addEnvironment(newEnvName); newEnvName = ""
                    }
                }.padding(8)
            }
            .frame(minWidth: 200)
        } detail: {
            VStack(alignment: .leading) {
                HStack {
                    Text(model.selectedEnvironment ?? "—").font(.title2)
                    Spacer()
                    Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
                        .help("使用说明 / 安装 CLI")
                    Button("Reload") { model.reloadActive() }
                        .help("Regenerate active.env now (base + active environment)")
                    if let env = model.selectedEnvironment, env != "base" {
                        Button("Activate") { model.activate(env) }
                            .disabled(env == model.activeName)
                    }
                }.padding(.horizontal)

                Table(model.variables) {
                    TableColumn("Key") { row in
                        Text(row.key)
                            .textSelection(.enabled)
                            .onTapGesture(count: 2) { model.copyString(row.key) }
                            .contextMenu { Button("Copy key") { model.copyString(row.key) } }
                            .help("Double-click or right-click to copy the key")
                    }
                    TableColumn("Value") { row in
                        Text(row.value)
                            .textSelection(.enabled)
                            .onTapGesture(count: 2) { model.copyValue(row) }
                            .contextMenu { Button("Copy value") { model.copyValue(row) } }
                            .help("Double-click or right-click to copy the value")
                    }
                    TableColumn("Actions") { row in
                        HStack(spacing: 10) {
                            Button { model.copyValue(row) } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy value")
                            Button(role: .destructive) { model.unsetVariable(key: row.key) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete")
                        }
                    }
                    .width(80)
                }

                HStack {
                    TextField("KEY", text: $newKey)
                    TextField("value", text: $newValue)
                    Button("Set") {
                        guard !newKey.isEmpty else { return }
                        model.setVariable(key: newKey, value: newValue)
                        newKey = ""; newValue = ""
                    }
                }.padding(.horizontal)

                HStack(spacing: 8) {
                    Text("To apply to an already-open terminal, run:")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(model.applyToShellCommand)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.applyToShellCommand, forType: .string)
                    } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless)
                        .help("Copy command")
                }.padding([.horizontal, .bottom])
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { model.lastError = nil }
        } message: { Text(model.lastError ?? "") }
        .sheet(isPresented: $showFirstRun) {
            FirstRunView(onInstallHook: { model.installZshHook(); showFirstRun = false },
                         symlinkCommand: model.cliSymlinkCommand)
        }
        .sheet(isPresented: $showHelp) {
            HelpView(symlinkCommand: model.cliSymlinkCommand,
                     applyCommand: model.applyToShellCommand,
                     onInstallHook: { model.installZshHook() },
                     onClose: { showHelp = false })
        }
        .onChange(of: model.lastError) { _, newValue in showError = (newValue != nil) }
        .onAppear { showFirstRun = model.needsHook }
    }
}
