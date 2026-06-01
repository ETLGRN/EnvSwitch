import Foundation

public enum ActiveFile {
    public static func write(lines: [String],
                             environmentName: String,
                             paths: EnvPaths) throws {
        try paths.ensureRootExists()
        var out = "# EnvSwitch active environment: \(environmentName)\n"
        out += "# Generated file — do not edit by hand.\n"
        out += lines.joined(separator: "\n")
        out += "\n"
        try AtomicWrite.write(out, to: paths.activeFile, posixPermissions: 0o600)
    }

    public static func clear(paths: EnvPaths) throws {
        try AtomicWrite.write("# EnvSwitch: no active environment\n",
                              to: paths.activeFile, posixPermissions: 0o600)
    }
}
