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
        base: [VarEntry(key: "LANG", value: "zh_CN.UTF-8")],
        environments: [
            "dev": [VarEntry(key: "API_HOST", value: "dev.example.com", group: "api"),
                    VarEntry(key: "TOKEN", value: "abc123")],
            "prod": [VarEntry(key: "API_HOST", value: "prod.example.com")],
        ]
    )
    try store.save(cfg)
    let loaded = try store.load()
    #expect(loaded == cfg)
}

@Test func roundTripPreservesInsertionOrder() throws {
    let paths = try makeTempPaths()
    let store = ConfigStore(paths: paths)
    // Deliberately non-alphabetical order.
    let vars: VarList = [
        VarEntry(key: "ZULU", value: "1"),
        VarEntry(key: "ALPHA", value: "2", group: "g"),
        VarEntry(key: "MIKE", value: "3"),
    ]
    try store.save(EnvConfig(environments: ["dev": vars]))
    let loaded = try store.load()
    #expect(loaded.environments["dev"]?.map(\.key) == ["ZULU", "ALPHA", "MIKE"])
    #expect(loaded.environments["dev"]?[1].group == "g")
}

@Test func legacyPlainTableMigratesToOrderedEntries() throws {
    let paths = try makeTempPaths()
    let legacy = """
    active = "dev"
    launchctl_sync = false

    [base]
    LANG = "zh_CN.UTF-8"

    [env.dev]
    TOKEN = "abc123"
    API_HOST = "dev.example.com"
    """
    try legacy.write(to: paths.configFile, atomically: true, encoding: .utf8)
    let store = ConfigStore(paths: paths)
    let loaded = try store.load()
    // Legacy keys come in sorted by name, ungrouped.
    #expect(loaded.base == [VarEntry(key: "LANG", value: "zh_CN.UTF-8")])
    #expect(loaded.environments["dev"]?.map(\.key) == ["API_HOST", "TOKEN"])
    #expect(loaded.environments["dev"]?.allSatisfy { $0.group == nil } == true)

    // Saving rewrites in the new array-of-tables format.
    try store.save(loaded)
    let text = try String(contentsOf: paths.configFile, encoding: .utf8)
    #expect(text.contains("[[env.dev.vars]]"))
    #expect(try store.load() == loaded)
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
