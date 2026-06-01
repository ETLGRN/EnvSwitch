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
