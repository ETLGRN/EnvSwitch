import SwiftUI

@main
struct EnvSwitchApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("EnvSwitch", id: "main") {
            MainWindowView().environmentObject(model).onAppear { model.refresh() }
        }
        .defaultSize(width: 720, height: 460)

        MenuBarExtra("EnvSwitch", systemImage: "switch.2") {
            MenuBarView().environmentObject(model)
        }
        .menuBarExtraStyle(.menu)

        Settings { SettingsView().environmentObject(model) }
    }
}
