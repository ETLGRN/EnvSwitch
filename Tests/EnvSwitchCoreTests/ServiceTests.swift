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
    let keychain: InMemoryKeychainStore
    let runner: ServiceFakeRunner
    let service: EnvSwitchService
}

private func makeFixture() throws -> ServiceFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("envswitch-service-\(UUID().uuidString)")
    let paths = EnvPaths(root: root)
    try paths.ensureRootExists()
    let keychain = InMemoryKeychainStore()
    let runner = ServiceFakeRunner()
    let service = EnvSwitchService(paths: paths, keychain: keychain, runner: runner)
    return ServiceFixture(paths: paths, keychain: keychain, runner: runner, service: service)
}

@Test func testSetPlainAndUse() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: "dev", key: "API_HOST", value: "dev.example.com", secret: false)
    try f.service.use("dev")
    let active = try String(contentsOf: f.paths.activeFile, encoding: .utf8)
    #expect(active.contains("export API_HOST='dev.example.com'"))
    #expect(try f.service.currentEnvironmentName() == "dev")
}

@Test func testSetSecretStoresInKeychainNotConfig() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: "dev", key: "TOKEN", value: "s3cr3t", secret: true)
    let configText = try String(contentsOf: f.paths.configFile, encoding: .utf8)
    #expect(!configText.contains("s3cr3t"))
    #expect(try f.keychain.get(account: "dev/TOKEN") == "s3cr3t")
    try f.service.use("dev")
    let active = try String(contentsOf: f.paths.activeFile, encoding: .utf8)
    #expect(active.contains("export TOKEN='s3cr3t'"))
}

@Test func testBaseSecretResolvesFromBaseAccount() throws {
    let f = try makeFixture()
    try f.service.addEnvironment("dev")
    try f.service.setVariable(environment: nil, key: "GLOBAL_KEY", value: "g", secret: true) // base
    #expect(try f.keychain.get(account: "base/GLOBAL_KEY") == "g")
    try f.service.use("dev")
    #expect(try f.service.resolvedValue(forKey: "GLOBAL_KEY") == "g")
}

@Test func testUnknownEnvUseThrows() throws {
    let f = try makeFixture()
    #expect(throws: (any Error).self) { try f.service.use("ghost") }
}
