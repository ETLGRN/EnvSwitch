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
        if let base = table["base"]?.table { cfg.base = Self.parseVarList(base) }
        if let envParent = table["env"]?.table {
            for key in envParent.keys {
                if let envTable = envParent[key]?.table { cfg.environments[key] = Self.parseVarList(envTable) }
            }
        }
        return cfg
    }

    public func save(_ cfg: EnvConfig) throws {
        let root = TOMLTable()
        if let active = cfg.active { root["active"] = active }
        root["launchctl_sync"] = cfg.launchctlSync
        if !cfg.base.isEmpty { root["base"] = Self.serializeVarList(cfg.base) }
        if !cfg.environments.isEmpty {
            let envParent = TOMLTable()
            for (name, vars) in cfg.environments { envParent[name] = Self.serializeVarList(vars) }
            root["env"] = envParent
        }
        let text = root.convert()
        try paths.ensureRootExists()
        try AtomicWrite.write(text, to: paths.configFile, posixPermissions: 0o644)
    }

    /// New format: a `vars` array of tables ({key, value, group?}) preserving order.
    /// Legacy format: plain KEY = "value" pairs directly on the layer table;
    /// migrated to ungrouped entries sorted by key.
    private static func parseVarList(_ table: TOMLTable) -> VarList {
        var list: VarList = []
        if let varsArray = table["vars"]?.array {
            for item in varsArray {
                guard let entryTable = item.table,
                      let key = entryTable["key"]?.string,
                      let value = entryTable["value"]?.string else { continue }
                let group = entryTable["group"]?.string
                list.append(VarEntry(key: key, value: value,
                                     group: (group?.isEmpty == true) ? nil : group))
            }
        }
        // Legacy plain key/value pairs (skip the reserved "vars" key).
        let legacyKeys = table.keys.filter { $0 != "vars" && table[$0]?.string != nil }
        for key in legacyKeys.sorted() {
            if list.contains(where: { $0.key == key }) { continue }
            list.append(VarEntry(key: key, value: table[key]!.string!, group: nil))
        }
        return list
    }

    private static func serializeVarList(_ list: VarList) -> TOMLTable {
        let layer = TOMLTable()
        let vars = TOMLArray()
        for entry in list {
            let t = TOMLTable()
            t["key"] = entry.key
            t["value"] = entry.value
            if let group = entry.group, !group.isEmpty { t["group"] = group }
            vars.append(t)
        }
        layer["vars"] = vars
        return layer
    }
}
