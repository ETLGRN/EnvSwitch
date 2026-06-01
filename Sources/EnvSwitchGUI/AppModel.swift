import Foundation
import EnvSwitchCore
import Combine

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
        var value: String   // shown value; for secrets this is "" until revealed
        var isSecret: Bool
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

    func setLaunchctlSync(_ on: Bool) {
        do { try service.setLaunchctlSync(on); launchctlSync = on } catch { lastError = "\(error)" }
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
        Installer.symlinkCommand(cliPath: Bundle.main.bundlePath + "/Contents/MacOS/envswitch")
    }
}
