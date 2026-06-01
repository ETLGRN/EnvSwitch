import Testing
@testable import EnvSwitchCore

final class FakeRunner: CommandRunner {
    var calls: [[String]] = []
    func run(_ executable: String, _ args: [String]) throws {
        calls.append([executable] + args)
    }
}

@Test func testSetenvForEachVar() throws {
    let runner = FakeRunner()
    let sync = LaunchctlSync(runner: runner)
    try sync.apply(["API_HOST": "dev.example.com", "TOKEN": "abc"])
    #expect(runner.calls.contains(["/bin/launchctl", "setenv", "API_HOST", "dev.example.com"]))
    #expect(runner.calls.contains(["/bin/launchctl", "setenv", "TOKEN", "abc"]))
}
