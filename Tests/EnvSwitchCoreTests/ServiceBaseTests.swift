import Testing
import Foundation
@testable import EnvSwitchCore

private final class BaseFakeRunner: CommandRunner {
    func run(_ executable: String, _ args: [String]) throws {}
}

private func makeService() throws -> (EnvSwitchService, EnvPaths) {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("esw-base-\(UUID().uuidString)")
    let paths = EnvPaths(root: dir)
    try paths.ensureRootExists()
    let service = EnvSwitchService(paths: paths, runner: BaseFakeRunner())
    return (service, paths)
}

@Test func baseVariableExportsWithoutActiveEnvironment() throws {
    let (service, paths) = try makeService()
    // No environment activated; setting a base variable should still produce active.env.
    try service.setVariable(environment: nil, key: "NAME1", value: "hello")
    let active = try String(contentsOf: paths.activeFile, encoding: .utf8)
    #expect(active.contains("export NAME1='hello'"))
}

@Test func editingActiveEnvironmentRegeneratesLive() throws {
    let (service, paths) = try makeService()
    try service.addEnvironment("dev")
    try service.use("dev")
    // Edit AFTER activation — active.env must update without an explicit reload.
    try service.setVariable(environment: "dev", key: "API_HOST", value: "dev.example.com")
    let active = try String(contentsOf: paths.activeFile, encoding: .utf8)
    #expect(active.contains("export API_HOST='dev.example.com'"))
}
