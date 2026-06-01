import Foundation

enum AtomicWrite {
    static func write(_ text: String, to url: URL, posixPermissions: Int) throws {
        let dir = url.deletingLastPathComponent()
        let tmp = dir.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try text.data(using: .utf8)!.write(to: tmp)
            try FileManager.default.setAttributes([.posixPermissions: posixPermissions], ofItemAtPath: tmp.path)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: url)
            }
            // replaceItemAt can preserve the pre-existing destination's permissions,
            // so explicitly enforce the requested mode on the final destination.
            try FileManager.default.setAttributes([.posixPermissions: posixPermissions], ofItemAtPath: url.path)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw EnvSwitchError.io("atomic write failed: \(error.localizedDescription)")
        }
    }
}
