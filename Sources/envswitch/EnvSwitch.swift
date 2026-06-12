import ArgumentParser
import EnvSwitchCore
import Foundation

private func makeService() -> EnvSwitchService {
    EnvSwitchService(paths: .resolved())
}

@main
struct EnvSwitch: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "envswitch",
        abstract: "Manage and switch local environment-variable profiles.",
        subcommands: [List.self, Use.self, Reload.self, Current.self, Get.self,
                      Set.self, Unset.self, Add.self, Remove.self, Edit.self,
                      Export.self, Import.self, ShellInit.self]
    )
}

extension EnvSwitch {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List environments.")
        func run() throws {
            let cfg = try makeService().loadConfig()
            let active = cfg.active
            for name in cfg.environmentNames.sorted() {
                print("\(name == active ? "* " : "  ")\(name)")
            }
        }
    }
    struct Use: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Switch active environment.")
        @Argument var environment: String
        func run() throws {
            try makeService().use(environment)
            print("Activated \(environment). New shells load it automatically.")
            print("For an already-open shell, run:  eval \"$(envswitch export)\"")
        }
    }
    struct Reload: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Regenerate active.env for the current environment.")
        func run() throws { try makeService().reload() }
    }
    struct Current: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show active environment.")
        func run() throws {
            let service = makeService()
            if let name = try service.currentEnvironmentName() {
                print("Active: \(name)")
                print(try service.exportScript())
            } else { print("No active environment.") }
        }
    }
    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Print a resolved variable value.")
        @Argument var key: String
        func run() throws {
            if let v = try makeService().resolvedValue(forKey: key) { print(v) }
            else { throw ValidationError("Key not set in active environment: \(key)") }
        }
    }
    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Set a variable (use \"base\" as <env> for the base layer).")
        @Argument var environment: String
        @Argument var key: String
        @Argument var value: String
        @Option(name: .long, help: "Assign the variable to a group (display only).")
        var group: String?
        func run() throws {
            let env = environment == "base" ? nil : environment
            try makeService().setVariable(environment: env, key: key, value: value,
                                          group: group == nil ? nil : .some(group))
        }
    }
    struct Unset: ParsableCommand {
        @Argument var environment: String
        @Argument var key: String
        func run() throws {
            let env = environment == "base" ? nil : environment
            try makeService().unsetVariable(environment: env, key: key)
        }
    }
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Create an environment.")
        @Argument var environment: String
        func run() throws { try makeService().addEnvironment(environment) }
    }
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "rm", abstract: "Delete an environment.")
        @Argument var environment: String
        func run() throws { try makeService().removeEnvironment(environment) }
    }
    struct Edit: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Open config.toml in $EDITOR.")
        func run() throws {
            let paths = EnvPaths.resolved()
            try paths.ensureRootExists()
            let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "vi"
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = [editor, paths.configFile.path]
            try p.run(); p.waitUntilExit()
        }
    }
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Print export statements for eval.")
        func run() throws { print(try makeService().exportScript(), terminator: "") }
    }
    struct Import: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Import KEY=VALUE lines from a .env file.")
        @Argument var environment: String
        @Argument var file: String
        func run() throws {
            let env = environment == "base" ? nil : environment
            let service = makeService()
            if env != nil { try service.addEnvironment(environment) }
            let text = try String(contentsOfFile: file, encoding: .utf8)
            for raw in text.split(separator: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }
                guard let eq = line.firstIndex(of: "=") else { continue }
                let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "export ", with: "")
                var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                if value.count >= 2, (value.first == "\"" || value.first == "'"), value.first == value.last {
                    value = String(value.dropFirst().dropLast())
                }
                try service.setVariable(environment: env, key: key, value: value)
            }
        }
    }
    struct ShellInit: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "shell-init", abstract: "Print the zsh hook to add to ~/.zshrc.")
        func run() throws { print(makeService().shellHookSnippet()) }
    }
}
