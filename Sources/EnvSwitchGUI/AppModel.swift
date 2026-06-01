import Foundation
import EnvSwitchCore
import Combine
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var environmentNames: [String] = []
    @Published var activeName: String?
    @Published var selectedEnvironment: String?
    @Published var variables: [VariableRow] = []
    @Published var launchctlSync = false
    @Published var lastError: String?

    struct VariableRow: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    private let service = EnvSwitchService(paths: .resolved())

    func refresh() {
        do {
            let cfg = try service.loadConfig()
            environmentNames = cfg.environmentNames.sorted()
            activeName = cfg.active
            launchctlSync = cfg.launchctlSync
            if selectedEnvironment == nil { selectedEnvironment = cfg.active ?? environmentNames.first }
            loadVariables()
        } catch { lastError = "\(error)" }
    }

    func loadVariables() {
        guard let env = selectedEnvironment else { variables = []; return }
        do {
            let cfg = try service.loadConfig()
            let map = env == "base" ? cfg.base : (cfg.environments[env] ?? [:])
            variables = map.keys.sorted().map { key in
                VariableRow(key: key, value: map[key]!)
            }
        } catch { lastError = "\(error)" }
    }

    func activate(_ name: String) {
        do { try service.use(name); refresh() } catch { lastError = "\(error)" }
    }

    func addEnvironment(_ name: String) {
        do { try service.addEnvironment(name); selectedEnvironment = name; refresh() }
        catch { lastError = "\(error)" }
    }

    func removeEnvironment(_ name: String) {
        do { try service.removeEnvironment(name); selectedEnvironment = nil; refresh() }
        catch { lastError = "\(error)" }
    }

    func setVariable(key: String, value: String) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.setVariable(environment: target, key: key, value: value); loadVariables() }
        catch { lastError = "\(error)" }
    }

    func unsetVariable(key: String) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.unsetVariable(environment: target, key: key); loadVariables() }
        catch { lastError = "\(error)" }
    }

    /// Copy a variable's value to the clipboard.
    func copyValue(_ row: VariableRow) {
        copyString(row.value)
    }

    /// Copy any string to the clipboard.
    func copyString(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    /// Command the user can paste to apply the active environment to an already-open shell.
    var applyToShellCommand: String { "eval \"$(envswitch export)\"" }

    func setLaunchctlSync(_ on: Bool) {
        do { try service.setLaunchctlSync(on); launchctlSync = on } catch { lastError = "\(error)" }
    }

    /// Regenerate active.env from base + the active environment (no edit required).
    func reloadActive() {
        do { try service.reload() } catch { lastError = "\(error)" }
    }

    func installZshHook() {
        let zshrc = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
        do { try Installer.installZshHook(into: zshrc, paths: .resolved()) } catch { lastError = "\(error)" }
    }
    var needsHook: Bool {
        let zshrc = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
        return !Installer.hookInstalled(in: zshrc)
    }
    var cliSymlinkCommand: String {
        Installer.symlinkCommand(cliPath: Bundle.main.bundlePath + "/Contents/Resources/envswitch")
    }
}
