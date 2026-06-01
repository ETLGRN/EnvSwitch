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
        var value: String      // plain value, or the revealed secret once `revealed` is true
        var isSecret: Bool
        var revealed: Bool = false   // for secrets: whether the real value is currently shown
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
                let v = map[key]!
                return VariableRow(key: key, value: v.literal ?? "", isSecret: v.isSecret)
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

    func setVariable(key: String, value: String, secret: Bool) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.setVariable(environment: target, key: key, value: value, secret: secret); loadVariables() }
        catch { lastError = "\(error)" }
    }

    func unsetVariable(key: String) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.unsetVariable(environment: target, key: key); loadVariables() }
        catch { lastError = "\(error)" }
    }

    private var targetLayer: String? {
        guard let env = selectedEnvironment else { return nil }
        return env == "base" ? nil : env
    }

    /// The actual value of a variable (resolving secrets from the Keychain).
    private func actualValue(forKey key: String) -> String? {
        do { return try service.revealValue(environment: targetLayer, key: key) }
        catch { lastError = "\(error)"; return nil }
    }

    /// Reveal a secret row in-place (fetches the real value from the Keychain).
    func reveal(_ row: VariableRow) {
        guard let value = actualValue(forKey: row.key),
              let idx = variables.firstIndex(where: { $0.id == row.id }) else { return }
        variables[idx].value = value
        variables[idx].revealed = true
    }

    func hide(_ row: VariableRow) {
        guard let idx = variables.firstIndex(where: { $0.id == row.id }) else { return }
        variables[idx].value = ""
        variables[idx].revealed = false
    }

    /// Copy a variable's actual value to the clipboard (works for plain and secret).
    func copyValue(_ row: VariableRow) {
        guard let value = actualValue(forKey: row.key) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
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
