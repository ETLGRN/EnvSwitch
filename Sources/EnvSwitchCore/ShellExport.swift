import Foundation

public enum ShellExport {
    /// Single-quote a value for safe zsh evaluation.
    public static func escape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func exportLines(merged: VarMap) -> [String] {
        merged.keys.sorted().map { key in "export \(key)=\(escape(merged[key]!))" }
    }
}
