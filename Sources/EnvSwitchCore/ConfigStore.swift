import Foundation
import TOMLKit

public struct ConfigStore {
    private let paths: EnvPaths
    public init(paths: EnvPaths) { self.paths = paths }

    public func load() throws -> EnvConfig {
        guard FileManager.default.fileExists(atPath: paths.configFile.path) else { return EnvConfig() }
        let text: String
        do { text = try String(contentsOf: paths.configFile, encoding: .utf8) }
        catch { throw EnvSwitchError.io("cannot read config: \(error.localizedDescription)") }
        let table: TOMLTable
        do { table = try TOMLTable(string: text) }
        catch { throw EnvSwitchError.parse("invalid TOML: \(error)") }
        var cfg = EnvConfig()
        cfg.active = table["active"]?.string
        cfg.launchctlSync = table["launchctl_sync"]?.bool ?? false
        if let base = table["base"]?.table { cfg.base = Self.parseVarMap(base) }
        if let envParent = table["env"]?.table {
            for key in envParent.keys {
                if let envTable = envParent[key]?.table { cfg.environments[key] = Self.parseVarMap(envTable) }
            }
        }
        return cfg
    }

    public func save(_ cfg: EnvConfig) throws {
        let root = TOMLTable()
        if let active = cfg.active { root["active"] = active }
        root["launchctl_sync"] = cfg.launchctlSync
        if !cfg.base.isEmpty { root["base"] = Self.serializeVarMap(cfg.base) }
        if !cfg.environments.isEmpty {
            let envParent = TOMLTable()
            for (name, vars) in cfg.environments { envParent[name] = Self.serializeVarMap(vars) }
            root["env"] = envParent
        }
        let text = root.convert()
        try paths.ensureRootExists()
        try AtomicWrite.write(text, to: paths.configFile, posixPermissions: 0o644)
    }

    private static func parseVarMap(_ table: TOMLTable) -> VarMap {
        var map: VarMap = [:]
        for key in table.keys {
            guard let node = table[key] else { continue }
            if let s = node.string { map[key] = .plain(s) }
            else if let inner = node.table, inner["secret"]?.bool == true { map[key] = .secret }
        }
        return map
    }

    private static func serializeVarMap(_ map: VarMap) -> TOMLTable {
        let table = TOMLTable()
        for (key, value) in map {
            switch value {
            case .plain(let v): table[key] = v
            case .secret:
                let inline = TOMLTable(inline: true)
                inline["secret"] = true
                table[key] = inline
            }
        }
        return table
    }
}
