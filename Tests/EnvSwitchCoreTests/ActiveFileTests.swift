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

@Test func testWritesFileWith600Permissions() throws {
    let paths = try makeTempPaths()
    try ActiveFile.write(lines: ["export API_HOST='dev.example.com'"],
                         environmentName: "dev",
                         paths: paths)
    let content = try String(contentsOf: paths.activeFile, encoding: .utf8)
    #expect(content.contains("export API_HOST='dev.example.com'"))
    #expect(content.contains("# EnvSwitch active environment: dev"))
    let attrs = try FileManager.default.attributesOfItem(atPath: paths.activeFile.path)
    #expect((attrs[.posixPermissions] as? Int) == 0o600)
}
