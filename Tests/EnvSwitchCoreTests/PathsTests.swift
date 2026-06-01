import Testing
import Foundation
@testable import EnvSwitchCore

@Test func pathsUnderProvidedRoot() {
    let root = URL(fileURLWithPath: "/tmp/eswtest")
    let paths = EnvPaths(root: root)
    #expect(paths.configFile.path == "/tmp/eswtest/config.toml")
    #expect(paths.activeFile.path == "/tmp/eswtest/active.env")
}

@Test func defaultRootUsesConfigEnvswitch() {
    let paths2 = EnvPaths.default(home: URL(fileURLWithPath: "/Users/x"))
    #expect(paths2.root.path == "/Users/x/.config/envswitch")
}
