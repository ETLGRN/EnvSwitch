import Testing
@testable import EnvSwitchCore

@Test func versionExists() {
    #expect(!EnvSwitchCore.version.isEmpty)
}
