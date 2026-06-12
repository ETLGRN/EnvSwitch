import Foundation

/// One variable entry. Order in the containing array is the user-defined order.
public struct VarEntry: Equatable {
    public var key: String
    public var value: String
    /// nil = ungrouped.
    public var group: String?

    public init(key: String, value: String, group: String? = nil) {
        self.key = key
        self.value = value
        self.group = group
    }
}

/// An ordered list of variables for one layer (base or an environment).
public typealias VarList = [VarEntry]

/// A merged view used for export: KEY = value (order-insensitive).
public typealias VarMap = [String: String]

public extension VarList {
    func value(forKey key: String) -> String? {
        first(where: { $0.key == key })?.value
    }

    /// Update in place if the key exists (keeping position and group unless a
    /// group is explicitly provided); otherwise append at the end.
    mutating func setValue(_ value: String, forKey key: String, group: String?? = nil) {
        if let idx = firstIndex(where: { $0.key == key }) {
            self[idx].value = value
            if let group { self[idx].group = group }
        } else {
            append(VarEntry(key: key, value: value, group: group ?? nil))
        }
    }

    mutating func removeValue(forKey key: String) {
        removeAll { $0.key == key }
    }

    /// Collapse to a dictionary; later entries win on duplicate keys.
    var asMap: VarMap {
        var map: VarMap = [:]
        for entry in self { map[entry.key] = entry.value }
        return map
    }

    /// Distinct group names in first-appearance order.
    var groupNames: [String] {
        var seen = Swift.Set<String>()
        var names: [String] = []
        for entry in self {
            if let g = entry.group, !g.isEmpty, seen.insert(g).inserted { names.append(g) }
        }
        return names
    }
}

public struct EnvConfig: Equatable {
    public var active: String?
    public var launchctlSync: Bool
    public var base: VarList
    public var environments: [String: VarList]

    public init(active: String? = nil,
                launchctlSync: Bool = false,
                base: VarList = [],
                environments: [String: VarList] = [:]) {
        self.active = active
        self.launchctlSync = launchctlSync
        self.base = base
        self.environments = environments
    }

    public var environmentNames: [String] { Array(environments.keys) }
}

public enum EnvSwitchError: Error, Equatable {
    case parse(String)
    case environmentNotFound(String)
    case io(String)
}
