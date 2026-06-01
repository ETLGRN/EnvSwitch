import Testing
import Foundation
@testable import EnvSwitchCore

@Test func testInstallHookIsIdempotent() throws {
    let zshrc = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("zshrc-\(UUID().uuidString)")
    try "export FOO=1\n".write(to: zshrc, atomically: true, encoding: .utf8)
    let paths = EnvPaths(root: URL(fileURLWithPath: "/Users/x/.config/envswitch"))
    try Installer.installZshHook(into: zshrc, paths: paths)
    try Installer.installZshHook(into: zshrc, paths: paths) // twice
    let text = try String(contentsOf: zshrc, encoding: .utf8)
    let occurrences = text.components(separatedBy: "# >>> envswitch >>>").count - 1
    #expect(occurrences == 1)
    #expect(text.contains("export FOO=1"))
}
