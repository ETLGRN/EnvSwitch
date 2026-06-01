import Foundation

public final class EnvSwitchService {
    private let paths: EnvPaths
    private let store: ConfigStore
    private let runner: CommandRunner

    public init(paths: EnvPaths = .default(),
                runner: CommandRunner = ProcessRunner()) {
        self.paths = paths
        self.store = ConfigStore(paths: paths)
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
        cfg.environments[name] = nil
        if cfg.active == name { cfg.active = nil }
        try store.save(cfg)
        try regenerateActiveFile(cfg: cfg)
    }

    /// environment == nil targets the base layer.
    public func setVariable(environment: String?, key: String, value: String) throws {
        var cfg = try store.load()
        if let env = environment, cfg.environments[env] == nil { throw EnvSwitchError.environmentNotFound(env) }
        if let env = environment { cfg.environments[env, default: [:]][key] = value }
        else { cfg.base[key] = value }
        try store.save(cfg)
        // Keep active.env in sync so edits to base / the active environment go live.
        try regenerateActiveFile(cfg: cfg)
    }

    public func unsetVariable(environment: String?, key: String) throws {
        var cfg = try store.load()
        if let env = environment { cfg.environments[env]?[key] = nil }
        else { cfg.base[key] = nil }
        try store.save(cfg)
        try regenerateActiveFile(cfg: cfg)
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

    /// Writes active.env from the base layer merged with the active environment (if any).
    /// When no environment is active, base-layer variables are still exported.
    private func regenerateActiveFile(cfg: EnvConfig) throws {
        let merged = try mergedMap(cfg: cfg, environment: cfg.active)
        let lines = ShellExport.exportLines(merged: merged)
        try ActiveFile.write(lines: lines, environmentName: cfg.active ?? "base", paths: paths)
        if cfg.launchctlSync {
            try LaunchctlSync(runner: runner).apply(merged)
        }
    }

    // MARK: Resolution

    /// base merged with the named environment (environment wins). nil → base only.
    private func mergedMap(cfg: EnvConfig, environment: String?) throws -> VarMap {
        guard let environment else { return cfg.base }
        return try Merge.merged(config: cfg, environment: environment)
    }

    public func resolvedValue(forKey key: String) throws -> String? {
        let cfg = try store.load()
        return try mergedMap(cfg: cfg, environment: cfg.active)[key]
    }

    public func exportScript() throws -> String {
        let cfg = try store.load()
        let merged = try mergedMap(cfg: cfg, environment: cfg.active)
        return ShellExport.exportLines(merged: merged).joined(separator: "\n") + "\n"
    }

    public func setLaunchctlSync(_ enabled: Bool) throws {
        var cfg = try store.load()
        cfg.launchctlSync = enabled
        try store.save(cfg)
    }

    public func shellHookSnippet() -> String { ShellHook.zshSnippet(paths: paths) }
}
