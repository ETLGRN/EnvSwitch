import Testing
import Foundation
@testable import EnvSwitchCore

private func makeTempPaths() throws -> EnvPaths {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("esw-\(UUID().uuidString)")
    let paths = EnvPaths(root: root)
    try paths.ensureRootExists()
    return paths
}

@Test func configRoundTrip() throws {
    let paths = try makeTempPaths()
    let store = ConfigStore(paths: paths)
    let cfg = EnvConfig(
        active: "dev",
        launchctlSync: true,
        base: ["LANG": "zh_CN.UTF-8"],
        environments: [
            "dev": ["API_HOST": "dev.example.com", "TOKEN": "abc123"],
            "prod": ["API_HOST": "prod.example.com"],
        ]
    )
    try store.save(cfg)
    let loaded = try store.load()
    #expect(loaded == cfg)
}

@Test func loadMissingReturnsEmpty() throws {
    let paths = try makeTempPaths()
    let store = ConfigStore(paths: paths)
    #expect(!FileManager.default.fileExists(atPath: paths.configFile.path))
    let loaded = try store.load()
    #expect(loaded == EnvConfig())
}

@Test func loadParseErrorThrows() throws {
    let paths = try makeTempPaths()
    try "this is = = not toml ===".write(to: paths.configFile, atomically: true, encoding: .utf8)
    let store = ConfigStore(paths: paths)
    #expect(throws: (any Error).self) {
        try store.load()
    }
}
