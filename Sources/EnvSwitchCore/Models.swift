import Foundation

/// A layer's variables: KEY = value. All values are plain text.
public typealias VarMap = [String: String]

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
    case io(String)
}
