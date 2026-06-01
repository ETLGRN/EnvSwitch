import Foundation

public enum VarValue: Equatable {
    case plain(String)
    case secret   // real value stored in Keychain

    public var isSecret: Bool {
        if case .secret = self { return true }
        return false
    }

    public var literal: String? {
        if case .plain(let v) = self { return v }
        return nil
    }
}

public typealias VarMap = [String: VarValue]

public struct EnvConfig: Equatable {
    public var active: String?
    public var launchctlSync: Bool
    public var base: VarMap
    public var environments: [String: VarMap]

    public init(active: String? = nil,
                launchctlSync: Bool = false,
                base: VarMap = [:],
                environments: [String: VarMap] = [:]) {
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
    case keychain(String)
    case io(String)
}
