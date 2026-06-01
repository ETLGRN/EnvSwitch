import Foundation

public protocol CommandRunner {
    func run(_ executable: String, _ args: [String]) throws
}

public struct ProcessRunner: CommandRunner {
    public init() {}
    public func run(_ executable: String, _ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw EnvSwitchError.io("\(executable) exited \(process.terminationStatus)")
        }
    }
}

public struct LaunchctlSync {
    private let runner: CommandRunner
    public init(runner: CommandRunner = ProcessRunner()) { self.runner = runner }

    public func apply(_ resolved: [String: String]) throws {
        for key in resolved.keys.sorted() {
            try runner.run("/bin/launchctl", ["setenv", key, resolved[key]!])
        }
    }
}
