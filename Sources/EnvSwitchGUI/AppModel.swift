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
    @Published var searchText = ""

    struct VariableRow: Identifiable {
        /// Stable identity by key (keys are unique within a layer).
        var id: String { key }
        var key: String
        var value: String
        var group: String?
        /// Position in the layer's full ordered list (for move operations).
        var index: Int
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
            let list = env == "base" ? cfg.base : (cfg.environments[env] ?? [])
            variables = list.enumerated().map { idx, entry in
                VariableRow(key: entry.key, value: entry.value, group: entry.group, index: idx)
            }
        } catch { lastError = "\(error)" }
    }

    /// Rows matching the search text (case-insensitive on key/value). Empty search = all.
    var filteredVariables: [VariableRow] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return variables }
        return variables.filter {
            $0.key.localizedCaseInsensitiveContains(q) || $0.value.localizedCaseInsensitiveContains(q)
        }
    }

    /// Existing group names in first-appearance order.
    var groupNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for row in variables {
            if let g = row.group, !g.isEmpty, seen.insert(g).inserted { names.append(g) }
        }
        return names
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

    func setVariable(key: String, value: String, group: String? = nil) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        let normalized = (group?.isEmpty == true) ? nil : group
        do {
            try service.setVariable(environment: target, key: key, value: value,
                                    group: normalized == nil ? nil : .some(normalized))
            loadVariables()
        } catch { lastError = "\(error)" }
    }

    /// Move a row to a new position in the layer's full ordered list.
    func moveVariable(fromIndex: Int, toIndex: Int) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.moveVariable(environment: target, fromIndex: fromIndex, toIndex: toIndex); loadVariables() }
        catch { lastError = "\(error)" }
    }

    /// Rename a group within the current layer.
    func renameGroup(from: String, to: String) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.renameGroup(environment: target, from: from, to: to); loadVariables() }
        catch { lastError = "\(error)" }
    }

    /// Assign or clear (nil) a row's group.
    func setGroup(key: String, group: String?) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.setGroup(environment: target, key: key, group: group); loadVariables() }
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
