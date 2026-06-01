import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @State private var newEnvName = ""
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var newSecret = false

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
                    if let env = model.selectedEnvironment, env != "base" {
                        Button("Activate") { model.activate(env) }
                            .disabled(env == model.activeName)
                    }
                }.padding(.horizontal)

                Table(model.variables) {
                    TableColumn("Key") { Text($0.key) }
                    TableColumn("Value") { row in
                        Text(row.isSecret ? "••••••" : row.value)
                    }
                    TableColumn("Secret") { Text($0.isSecret ? "🔒" : "") }
                    TableColumn("") { row in
                        Button(role: .destructive) { model.unsetVariable(key: row.key) } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

                HStack {
                    TextField("KEY", text: $newKey)
                    TextField("value", text: $newValue)
                    Toggle("Secret", isOn: $newSecret)
                    Button("Set") {
                        guard !newKey.isEmpty else { return }
                        model.setVariable(key: newKey, value: newValue, secret: newSecret)
                        newKey = ""; newValue = ""; newSecret = false
                    }
                }.padding()
            }
        }
        .alert("Error", isPresented: .constant(model.lastError != nil)) {
            Button("OK") { model.lastError = nil }
        } message: { Text(model.lastError ?? "") }
    }
}
