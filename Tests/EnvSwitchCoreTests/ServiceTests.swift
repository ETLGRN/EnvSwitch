import Foundation
import Testing
@testable import EnvSwitchCore

final class ServiceFakeRunner: CommandRunner {
    var calls: [[String]] = []
    func run(_ executable: String, _ args: [String]) throws {
        calls.append([executable] + args)
    }
}

private struct ServiceFixture {
    let paths: EnvPaths
    let runner: ServiceFakeRunner
    let service: EnvSwitchService
}

private func makeFixture() throws -> ServiceFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("envswitch-service-\(UUID().uuidString)")
    let paths = EnvPaths(root: root)
    try paths.ensureRootExists()
    let runner = ServiceFakeRunner()
    let service = EnvSwitchService(paths: paths, runner: runner)
    return ServiceFixture(paths: paths, runner: runner, service: service)
}

@Test func testSetPlainAndUse() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: "dev", key: "API_HOST", value: "dev.example.com")
    try f.service.use("dev")
    let active = try String(contentsOf: f.paths.activeFile, encoding: .utf8)
    #expect(active.contains("export API_HOST='dev.example.com'"))
    #expect(try f.service.currentEnvironmentName() == "dev")
}

@Test func testBaseValueResolvesForActiveEnvironment() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: nil, key: "GLOBAL_KEY", value: "g") // base
    try f.service.use("dev")
    #expect(try f.service.resolvedValue(forKey: "GLOBAL_KEY") == "g")
}

@Test func testUnknownEnvUseThrows() throws {
    let f = try makeFixture()
    #expect(throws: (any Error).self) { try f.service.use("ghost") }
}

@Test func testNewKeysAppendAtEndAndUpdateKeepsPosition() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: "dev", key: "B", value: "2")
    try f.service.setVariable(environment: "dev", key: "A", value: "1")
    try f.service.setVariable(environment: "dev", key: "C", value: "3")
    // Updating an existing key must not move it.
    try f.service.setVariable(environment: "dev", key: "B", value: "22")
    let cfg = try f.service.loadConfig()
    #expect(cfg.environments["dev"]?.map(\.key) == ["B", "A", "C"])
    #expect(cfg.environments["dev"]?.value(forKey: "B") == "22")
}

@Test func testMoveVariableReorders() throws {
    let f = try makeFixture()
    for (k, v) in [("A", "1"), ("B", "2"), ("C", "3")] {
        try f.service.setVariable(environment: nil, key: k, value: v)
    }
    // Move A (0) after C → list semantics: insert before index 3.
    try f.service.moveVariable(environment: nil, fromIndex: 0, toIndex: 3)
    #expect(try f.service.loadConfig().base.map(\.key) == ["B", "C", "A"])
    // Move C (1) to the front.
    try f.service.moveVariable(environment: nil, fromIndex: 1, toIndex: 0)
    #expect(try f.service.loadConfig().base.map(\.key) == ["C", "B", "A"])
    // Out-of-range indices are ignored.
    try f.service.moveVariable(environment: nil, fromIndex: 9, toIndex: 0)
    #expect(try f.service.loadConfig().base.map(\.key) == ["C", "B", "A"])
}

@Test func testSetGroupAssignsAndClears() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: "dev", key: "API_HOST", value: "h", group: .some("api"))
    var cfg = try f.service.loadConfig()
    #expect(cfg.environments["dev"]?.first?.group == "api")

    try f.service.setGroup(environment: "dev", key: "API_HOST", group: "backend")
    cfg = try f.service.loadConfig()
    #expect(cfg.environments["dev"]?.first?.group == "backend")

    try f.service.setGroup(environment: "dev", key: "API_HOST", group: nil)
    cfg = try f.service.loadConfig()
    #expect(cfg.environments["dev"]?.first?.group == nil)
}

@Test func testGroupDoesNotAffectExport() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: "dev", key: "Z", value: "z", group: .some("g"))
    try f.service.setVariable(environment: "dev", key: "A", value: "a")
    try f.service.use("dev")
    let active = try String(contentsOf: f.paths.activeFile, encoding: .utf8)
    // active.env stays alphabetical regardless of stored order / groups.
    let aIdx = active.range(of: "export A=")!.lowerBound
    let zIdx = active.range(of: "export Z=")!.lowerBound
    #expect(aIdx < zIdx)
}

@Test func testRenameGroupRenamesAllEntriesAndMerges() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: "dev", key: "A", value: "1", group: .some("old"))
    try f.service.setVariable(environment: "dev", key: "B", value: "2", group: .some("old"))
    try f.service.setVariable(environment: "dev", key: "C", value: "3", group: .some("other"))

    try f.service.renameGroup(environment: "dev", from: "old", to: "new")
    var groups = try f.service.loadConfig().environments["dev"]!.map(\.group)
    #expect(groups == ["new", "new", "other"])

    // Renaming onto an existing group merges.
    try f.service.renameGroup(environment: "dev", from: "new", to: "other")
    groups = try f.service.loadConfig().environments["dev"]!.map(\.group)
    #expect(groups == ["other", "other", "other"])

    // Empty / identical target is a no-op.
    try f.service.renameGroup(environment: "dev", from: "other", to: "  ")
    #expect(try f.service.loadConfig().environments["dev"]!.map(\.group) == ["other", "other", "other"])
}

@Test func testMoveInUnknownEnvironmentThrows() throws {
    let f = try makeFixture()
    #expect(throws: EnvSwitchError.environmentNotFound("ghost")) {
        try f.service.moveVariable(environment: "ghost", fromIndex: 0, toIndex: 1)
    }
}
