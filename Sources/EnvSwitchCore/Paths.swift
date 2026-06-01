import Foundation

public struct EnvPaths {
    public let root: URL

    public init(root: URL) { self.root = root }

    public var configFile: URL { root.appendingPathComponent("config.toml") }
    public var activeFile: URL { root.appendingPathComponent("active.env") }

    public static func `default`(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> EnvPaths {
        EnvPaths(root: home.appendingPathComponent(".config/envswitch"))
    }

    public static func resolved(environment: [String: String] = ProcessInfo.processInfo.environment) -> EnvPaths {
        if let override = environment["ENVSWITCH_HOME"], !override.isEmpty {
            return EnvPaths(root: URL(fileURLWithPath: override))
        }
        return .default()
    }

    public func ensureRootExists() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
}
