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
        if cfg.environments[name] == nil { cfg.environments[name] = [] }
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
    /// Existing keys update in place (keeping position; group untouched unless
    /// explicitly provided); new keys append at the end.
    public func setVariable(environment: String?, key: String, value: String, group: String?? = nil) throws {
        var cfg = try store.load()
        if let env = environment, cfg.environments[env] == nil { throw EnvSwitchError.environmentNotFound(env) }
        if let env = environment { cfg.environments[env, default: []].setValue(value, forKey: key, group: group) }
        else { cfg.base.setValue(value, forKey: key, group: group) }
        try store.save(cfg)
        // Keep active.env in sync so edits to base / the active environment go live.
        try regenerateActiveFile(cfg: cfg)
    }

    public func unsetVariable(environment: String?, key: String) throws {
        var cfg = try store.load()
        if let env = environment { cfg.environments[env]?.removeValue(forKey: key) }
        else { cfg.base.removeValue(forKey: key) }
        try store.save(cfg)
        try regenerateActiveFile(cfg: cfg)
    }

    /// Reorder an entry within a layer (indices into the layer's full VarList).
    /// environment == nil targets the base layer. Export semantics are unaffected.
    public func moveVariable(environment: String?, fromIndex: Int, toIndex: Int) throws {
        var cfg = try store.load()
        if let env = environment {
            guard var list = cfg.environments[env] else { throw EnvSwitchError.environmentNotFound(env) }
            Self.move(&list, from: fromIndex, to: toIndex)
            cfg.environments[env] = list
        } else {
            Self.move(&cfg.base, from: fromIndex, to: toIndex)
        }
        try store.save(cfg)
    }

    /// Rename a group across a layer. Renaming onto an existing group merges them.
    public func renameGroup(environment: String?, from: String, to: String) throws {
        let target = to.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, target != from else { return }
        var cfg = try store.load()
        if let env = environment {
            guard var list = cfg.environments[env] else { throw EnvSwitchError.environmentNotFound(env) }
            Self.rename(&list, from: from, to: target)
            cfg.environments[env] = list
        } else {
            Self.rename(&cfg.base, from: from, to: target)
        }
        try store.save(cfg)
    }

    private static func rename(_ list: inout VarList, from: String, to: String) {
        for idx in list.indices where list[idx].group == from {
            list[idx].group = to
        }
    }

    /// Assign (or clear, with nil/empty) the group of an existing key.
    public func setGroup(environment: String?, key: String, group: String?) throws {
        var cfg = try store.load()
        let normalized = (group?.isEmpty == true) ? nil : group
        if let env = environment {
            guard var list = cfg.environments[env] else { throw EnvSwitchError.environmentNotFound(env) }
            guard let idx = list.firstIndex(where: { $0.key == key }) else { return }
            list[idx].group = normalized
            cfg.environments[env] = list
        } else {
            guard let idx = cfg.base.firstIndex(where: { $0.key == key }) else { return }
            cfg.base[idx].group = normalized
        }
        try store.save(cfg)
    }

    private static func move(_ list: inout VarList, from: Int, to: Int) {
        guard list.indices.contains(from), to >= 0, to <= list.count, from != to else { return }
        let entry = list.remove(at: from)
        let dest = to > from ? to - 1 : to
        list.insert(entry, at: Swift.min(dest, list.count))
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
        guard let environment else { return cfg.base.asMap }
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
