import Foundation

public final class EnvSwitchService {
    private let paths: EnvPaths
    private let store: ConfigStore
    private let keychain: KeychainStore
    private let runner: CommandRunner

    public init(paths: EnvPaths = .default(),
                keychain: KeychainStore = SecurityKeychainStore(),
                runner: CommandRunner = ProcessRunner()) {
        self.paths = paths
        self.store = ConfigStore(paths: paths)
        self.keychain = keychain
        self.runner = runner
    }

    // MARK: Config access
    public func loadConfig() throws -> EnvConfig { try store.load() }
    public func environmentNames() throws -> [String] { try store.load().environmentNames.sorted() }
    public func currentEnvironmentName() throws -> String? { try store.load().active }

    // MARK: Mutations
    public func addEnvironment(_ name: String) throws {
        var cfg = try store.load()
        if cfg.environments[name] == nil { cfg.environments[name] = [:] }
        try store.save(cfg)
    }

    public func removeEnvironment(_ name: String) throws {
        var cfg = try store.load()
        guard cfg.environments[name] != nil else { throw EnvSwitchError.environmentNotFound(name) }
        for key in cfg.environments[name]!.keys where cfg.environments[name]![key] == .secret {
            try keychain.delete(account: KeychainAccount.key(env: name, name: key))
        }
        cfg.environments[name] = nil
        if cfg.active == name { cfg.active = nil }
        try store.save(cfg)
    }

    /// environment == nil targets the base layer.
    public func setVariable(environment: String?, key: String, value: String, secret: Bool) throws {
        var cfg = try store.load()
        if let env = environment, cfg.environments[env] == nil { throw EnvSwitchError.environmentNotFound(env) }
        let stored: VarValue = secret ? .secret : .plain(value)
        if let env = environment { cfg.environments[env, default: [:]][key] = stored }
        else { cfg.base[key] = stored }
        if secret { try keychain.set(secret: value, account: KeychainAccount.key(env: environment, name: key)) }
        try store.save(cfg)
    }

    public func unsetVariable(environment: String?, key: String) throws {
        var cfg = try store.load()
        let existing: VarValue?
        if let env = environment { existing = cfg.environments[env]?[key]; cfg.environments[env]?[key] = nil }
        else { existing = cfg.base[key]; cfg.base[key] = nil }
        if existing == .secret { try keychain.delete(account: KeychainAccount.key(env: environment, name: key)) }
        try store.save(cfg)
    }

    // MARK: Activation
    public func use(_ name: String) throws {
        var cfg = try store.load()
        guard cfg.environments[name] != nil else { throw EnvSwitchError.environmentNotFound(name) }
        cfg.active = name
        try store.save(cfg)
        try regenerateActiveFile(cfg: cfg)
    }

    public func reload() throws {
        let cfg = try store.load()
        try regenerateActiveFile(cfg: cfg)
    }

    private func regenerateActiveFile(cfg: EnvConfig) throws {
        guard let active = cfg.active else { try ActiveFile.clear(paths: paths); return }
        let lines = try resolvedExportLines(cfg: cfg, environment: active)
        try ActiveFile.write(lines: lines, environmentName: active, paths: paths)
        if cfg.launchctlSync {
            let resolved = try resolvedValues(cfg: cfg, environment: active)
            try LaunchctlSync(runner: runner).apply(resolved)
        }
    }

    // MARK: Resolution (origin-aware secret lookup)
    private func resolvedValues(cfg: EnvConfig, environment: String) throws -> [String: String] {
        let merged = try Merge.merged(config: cfg, environment: environment)
        var out: [String: String] = [:]
        for (key, value) in merged {
            switch value {
            case .plain(let v): out[key] = v
            case .secret:
                let envAccount = KeychainAccount.key(env: environment, name: key)
                let baseAccount = KeychainAccount.key(env: nil, name: key)
                if let v = try keychain.get(account: envAccount) ?? keychain.get(account: baseAccount) { out[key] = v }
            }
        }
        return out
    }

    private func resolvedExportLines(cfg: EnvConfig, environment: String) throws -> [String] {
        let resolved = try resolvedValues(cfg: cfg, environment: environment)
        let merged = try Merge.merged(config: cfg, environment: environment)
        var lines: [String] = []
        for key in merged.keys.sorted() {
            if let v = resolved[key] { lines.append("export \(key)=\(ShellExport.escape(v))") }
            else { lines.append("# \(key): secret value missing from keychain") }
        }
        return lines
    }

    public func resolvedValue(forKey key: String) throws -> String? {
        let cfg = try store.load()
        guard let active = cfg.active else { return nil }
        return try resolvedValues(cfg: cfg, environment: active)[key]
    }

    public func exportScript() throws -> String {
        let cfg = try store.load()
        guard let active = cfg.active else { return "" }
        return try resolvedExportLines(cfg: cfg, environment: active).joined(separator: "\n") + "\n"
    }

    public func setLaunchctlSync(_ enabled: Bool) throws {
        var cfg = try store.load()
        cfg.launchctlSync = enabled
        try store.save(cfg)
    }

    public func shellHookSnippet() -> String { ShellHook.zshSnippet(paths: paths) }
}
