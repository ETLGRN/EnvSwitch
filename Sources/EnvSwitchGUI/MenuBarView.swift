import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            ForEach(model.environmentNames, id: \.self) { name in
                Button {
                    model.activate(name)
                } label: {
                    Label(name, systemImage: name == model.activeName ? "largecircle.fill.circle" : "circle")
                }
            }
            Divider()
            Button("Edit Environments…") { openWindow(id: "main") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .onAppear { model.refresh() }
    }
}
