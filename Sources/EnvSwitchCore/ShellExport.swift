import Foundation

public enum ShellExport {
    /// Single-quote a value for safe zsh evaluation.
    public static func escape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func exportLines(merged: VarMap,
                                   environment: String?,
                                   keychain: KeychainStore) throws -> [String] {
        var lines: [String] = []
        for key in merged.keys.sorted() {
            switch merged[key]! {
            case .plain(let value):
                lines.append("export \(key)=\(escape(value))")
            case .secret:
                let account = KeychainAccount.key(env: environment, name: key)
                if let value = try keychain.get(account: account) {
                    lines.append("export \(key)=\(escape(value))")
                } else {
                    lines.append("# \(key): secret value missing from keychain")
                }
            }
        }
        return lines
    }
}
