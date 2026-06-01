import Foundation

public enum Installer {
    public static func installZshHook(into zshrc: URL, paths: EnvPaths) throws {
        let snippet = ShellHook.zshSnippet(paths: paths)
        var contents = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
        if contents.contains("# >>> envswitch >>>") { return } // already installed
        if !contents.isEmpty && !contents.hasSuffix("\n") { contents += "\n" }
        contents += "\n" + snippet + "\n"
        try contents.write(to: zshrc, atomically: true, encoding: .utf8)
    }

    public static func hookInstalled(in zshrc: URL) -> Bool {
        let contents = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
        return contents.contains("# >>> envswitch >>>")
    }

    /// Suggested command to symlink the embedded CLI onto PATH.
    public static func symlinkCommand(cliPath: String) -> String {
        "sudo ln -sf \"\(cliPath)\" /usr/local/bin/envswitch"
    }
}
