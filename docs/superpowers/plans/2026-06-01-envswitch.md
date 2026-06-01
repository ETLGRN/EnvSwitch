# EnvSwitch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS app (CLI + GUI) that manages multiple environment-variable profiles with one-click switching, SwitchHosts-style, storing config under `~/.config/envswitch/`.

**Architecture:** A SwiftPM package with a shared `EnvSwitchCore` library (TOML config, base+env merge, Keychain, active.env generation, launchctl sync), a thin `envswitch` CLI (swift-argument-parser) and an `EnvSwitchGUI` SwiftUI app (MenuBarExtra + main window). Switching an environment = merge base+env, write `~/.config/envswitch/active.env`, and rely on a zsh hook that sources it in new shells.

**Tech Stack:** Swift 5.9+, macOS 14+, SwiftPM, [TOMLKit](https://github.com/LebJe/TOMLKit) for TOML read/write, swift-argument-parser for the CLI, SwiftUI for the GUI, Security.framework for Keychain.

---

## File Structure

```
envswitch/
├── Package.swift
├── Sources/
│   ├── EnvSwitchCore/
│   │   ├── Models.swift            # EnvConfig, Variable, MergedEnv
│   │   ├── ConfigStore.swift       # load/save config.toml (atomic)
│   │   ├── Paths.swift             # ~/.config/envswitch locations (injectable root)
│   │   ├── Merge.swift             # base + env merge
│   │   ├── KeychainStore.swift     # protocol + Security impl + in-memory impl
│   │   ├── ShellExport.swift       # export-line generation + escaping
│   │   ├── ActiveFile.swift        # write active.env atomically (chmod 600)
│   │   ├── ShellHook.swift         # zsh hook snippet generation
│   │   ├── LaunchctlSync.swift     # launchctl setenv wrapper
│   │   └── EnvSwitchService.swift  # facade tying it together (use/reload/current/set...)
│   ├── envswitch/                  # CLI executable
│   │   ├── EnvSwitch.swift         # ParsableCommand root + subcommands
│   │   └── main.swift
│   └── EnvSwitchGUI/               # SwiftUI app executable
│       ├── EnvSwitchApp.swift      # @main App, MenuBarExtra + WindowGroup
│       ├── AppModel.swift          # ObservableObject wrapping EnvSwitchService
│       ├── MenuBarView.swift
│       ├── MainWindowView.swift
│       ├── EnvironmentListView.swift
│       ├── VariableTableView.swift
│       └── SettingsView.swift
└── Tests/
    └── EnvSwitchCoreTests/
        ├── ConfigStoreTests.swift
        ├── MergeTests.swift
        ├── ShellExportTests.swift
        ├── ActiveFileTests.swift
        ├── ShellHookTests.swift
        └── ServiceTests.swift
```

All Core logic takes an injectable root directory and an injectable `KeychainStore` so tests run against a temp HOME with an in-memory keychain.

---

## Task 1: Project scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/EnvSwitchCore/Placeholder.swift`
- Create: `Sources/envswitch/main.swift`
- Create: `Tests/EnvSwitchCoreTests/SmokeTests.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnvSwitch",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EnvSwitchCore", targets: ["EnvSwitchCore"]),
        .executable(name: "envswitch", targets: ["envswitch"]),
        .executable(name: "EnvSwitchGUI", targets: ["EnvSwitchGUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "EnvSwitchCore",
            dependencies: [.product(name: "TOMLKit", package: "TOMLKit")]
        ),
        .executableTarget(
            name: "envswitch",
            dependencies: [
                "EnvSwitchCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "EnvSwitchGUI",
            dependencies: ["EnvSwitchCore"]
        ),
        .testTarget(
            name: "EnvSwitchCoreTests",
            dependencies: ["EnvSwitchCore"]
        ),
    ]
)
```

- [ ] **Step 2: Add placeholder sources so the package builds**

`Sources/EnvSwitchCore/Placeholder.swift`:
```swift
public enum EnvSwitchCore {
    public static let version = "0.1.0"
}
```

`Sources/envswitch/main.swift`:
```swift
import EnvSwitchCore
print("envswitch \(EnvSwitchCore.version)")
```

Create `Sources/EnvSwitchGUI/EnvSwitchApp.swift` minimal stub:
```swift
import SwiftUI

@main
struct EnvSwitchApp: App {
    var body: some Scene {
        WindowGroup { Text("EnvSwitch") }
    }
}
```

- [ ] **Step 3: Write a smoke test**

`Tests/EnvSwitchCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertFalse(EnvSwitchCore.version.isEmpty)
    }
}
```

- [ ] **Step 4: Build and test**

Run: `swift build && swift test`
Expected: builds; 1 test passes. (First run downloads TOMLKit and ArgumentParser.)

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold SwiftPM package with Core/CLI/GUI targets"
```

---

## Task 2: Path resolution (injectable root)

**Files:**
- Create: `Sources/EnvSwitchCore/Paths.swift`
- Test: `Tests/EnvSwitchCoreTests/PathsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/EnvSwitchCoreTests/PathsTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class PathsTests: XCTestCase {
    func testPathsUnderProvidedRoot() {
        let root = URL(fileURLWithPath: "/tmp/eswtest")
        let paths = EnvPaths(root: root)
        XCTAssertEqual(paths.configFile.path, "/tmp/eswtest/config.toml")
        XCTAssertEqual(paths.activeFile.path, "/tmp/eswtest/active.env")
    }

    func testDefaultRootUsesConfigHome() {
        let paths = EnvPaths.default(home: URL(fileURLWithPath: "/Users/x"))
        XCTAssertEqual(paths.root.path, "/Users/x/.config/envswitch")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PathsTests`
Expected: FAIL — `EnvPaths` not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/Paths.swift`:
```swift
import Foundation

public struct EnvPaths {
    public let root: URL

    public init(root: URL) { self.root = root }

    public var configFile: URL { root.appendingPathComponent("config.toml") }
    public var activeFile: URL { root.appendingPathComponent("active.env") }

    public static func `default`(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> EnvPaths {
        EnvPaths(root: home.appendingPathComponent(".config/envswitch"))
    }

    public func ensureRootExists() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PathsTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/EnvSwitchCore/Paths.swift Tests/EnvSwitchCoreTests/PathsTests.swift
git commit -m "feat(core): add injectable path resolution"
```

---

## Task 3: Data model

**Files:**
- Create: `Sources/EnvSwitchCore/Models.swift`
- Test: `Tests/EnvSwitchCoreTests/ModelsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/EnvSwitchCoreTests/ModelsTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class ModelsTests: XCTestCase {
    func testPlainAndSecretValues() {
        let plain = VarValue.plain("dev.example.com")
        let secret = VarValue.secret
        XCTAssertEqual(plain.literal, "dev.example.com")
        XCTAssertNil(secret.literal)
        XCTAssertTrue(secret.isSecret)
        XCTAssertFalse(plain.isSecret)
    }

    func testConfigLookup() {
        let cfg = EnvConfig(
            active: "dev",
            launchctlSync: false,
            base: ["LANG": .plain("zh_CN.UTF-8")],
            environments: ["dev": ["API_HOST": .plain("dev.example.com")]]
        )
        XCTAssertEqual(cfg.environmentNames.sorted(), ["dev"])
        XCTAssertEqual(cfg.environments["dev"]?["API_HOST"]?.literal, "dev.example.com")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ModelsTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/Models.swift`:
```swift
import Foundation

public enum VarValue: Equatable {
    case plain(String)
    case secret   // real value stored in Keychain

    public var isSecret: Bool {
        if case .secret = self { return true }
        return false
    }

    public var literal: String? {
        if case .plain(let v) = self { return v }
        return nil
    }
}

public typealias VarMap = [String: VarValue]

public struct EnvConfig: Equatable {
    public var active: String?
    public var launchctlSync: Bool
    public var base: VarMap
    public var environments: [String: VarMap]

    public init(active: String? = nil,
                launchctlSync: Bool = false,
                base: VarMap = [:],
                environments: [String: VarMap] = [:]) {
        self.active = active
        self.launchctlSync = launchctlSync
        self.base = base
        self.environments = environments
    }

    public var environmentNames: [String] { Array(environments.keys) }
}

public enum EnvSwitchError: Error, Equatable {
    case parse(String)
    case environmentNotFound(String)
    case keychain(String)
    case io(String)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ModelsTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/EnvSwitchCore/Models.swift Tests/EnvSwitchCoreTests/ModelsTests.swift
git commit -m "feat(core): add config data model"
```

---

## Task 4: TOML load/save round-trip

**Files:**
- Create: `Sources/EnvSwitchCore/ConfigStore.swift`
- Test: `Tests/EnvSwitchCoreTests/ConfigStoreTests.swift`

TOML mapping rules:
- top-level `active` (string, optional), `launchctl_sync` (bool).
- `[base]` table: each key is either a string (plain) or an inline table `{ secret = true }`.
- `[env.<name>]` tables under the `env` parent table, same value rules.

- [ ] **Step 1: Write the failing test**

`Tests/EnvSwitchCoreTests/ConfigStoreTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class ConfigStoreTests: XCTestCase {
    private func tempPaths() throws -> EnvPaths {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("esw-\(UUID().uuidString)")
        let paths = EnvPaths(root: dir)
        try paths.ensureRootExists()
        return paths
    }

    func testRoundTrip() throws {
        let paths = try tempPaths()
        let store = ConfigStore(paths: paths)
        let cfg = EnvConfig(
            active: "dev",
            launchctlSync: true,
            base: ["LANG": .plain("zh_CN.UTF-8")],
            environments: [
                "dev": ["API_HOST": .plain("dev.example.com"), "TOKEN": .secret],
                "prod": ["API_HOST": .plain("prod.example.com")],
            ]
        )
        try store.save(cfg)
        let loaded = try store.load()
        XCTAssertEqual(loaded, cfg)
    }

    func testLoadMissingReturnsEmpty() throws {
        let paths = try tempPaths()
        let store = ConfigStore(paths: paths)
        let loaded = try store.load()
        XCTAssertEqual(loaded, EnvConfig())
    }

    func testParseErrorThrows() throws {
        let paths = try tempPaths()
        try "this is = = not toml ===".write(to: paths.configFile, atomically: true, encoding: .utf8)
        let store = ConfigStore(paths: paths)
        XCTAssertThrowsError(try store.load())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConfigStoreTests`
Expected: FAIL — `ConfigStore` not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/ConfigStore.swift`:
```swift
import Foundation
import TOMLKit

public struct ConfigStore {
    private let paths: EnvPaths

    public init(paths: EnvPaths) { self.paths = paths }

    public func load() throws -> EnvConfig {
        guard FileManager.default.fileExists(atPath: paths.configFile.path) else {
            return EnvConfig()
        }
        let text: String
        do { text = try String(contentsOf: paths.configFile, encoding: .utf8) }
        catch { throw EnvSwitchError.io("cannot read config: \(error.localizedDescription)") }

        let table: TOMLTable
        do { table = try TOMLTable(string: text) }
        catch { throw EnvSwitchError.parse("invalid TOML: \(error)") }

        var cfg = EnvConfig()
        cfg.active = table["active"]?.string
        cfg.launchctlSync = table["launchctl_sync"]?.bool ?? false
        if let base = table["base"]?.table {
            cfg.base = Self.parseVarMap(base)
        }
        if let envParent = table["env"]?.table {
            for key in envParent.keys {
                if let envTable = envParent[key]?.table {
                    cfg.environments[key] = Self.parseVarMap(envTable)
                }
            }
        }
        return cfg
    }

    public func save(_ cfg: EnvConfig) throws {
        let root = TOMLTable()
        if let active = cfg.active { root["active"] = TOMLValueConvertible(active) }
        root["launchctl_sync"] = TOMLValueConvertible(cfg.launchctlSync)
        if !cfg.base.isEmpty { root["base"] = Self.serializeVarMap(cfg.base) }
        if !cfg.environments.isEmpty {
            let envParent = TOMLTable()
            for (name, vars) in cfg.environments {
                envParent[name] = Self.serializeVarMap(vars)
            }
            root["env"] = envParent
        }
        let text = root.convert()
        try paths.ensureRootExists()
        try AtomicWrite.write(text, to: paths.configFile, posixPermissions: 0o644)
    }

    private static func parseVarMap(_ table: TOMLTable) -> VarMap {
        var map: VarMap = [:]
        for key in table.keys {
            guard let node = table[key] else { continue }
            if let s = node.string {
                map[key] = .plain(s)
            } else if let inner = node.table, inner["secret"]?.bool == true {
                map[key] = .secret
            }
        }
        return map
    }

    private static func serializeVarMap(_ map: VarMap) -> TOMLTable {
        let table = TOMLTable()
        for (key, value) in map {
            switch value {
            case .plain(let v):
                table[key] = TOMLValueConvertible(v)
            case .secret:
                let inline = TOMLTable()
                inline["secret"] = TOMLValueConvertible(true)
                table[key] = inline
            }
        }
        return table
    }
}
```

> Note: TOMLKit's exact API for reading a node's `.string`/`.bool`/`.table` and for building values may differ slightly by version. If `TOMLValueConvertible(...)` initializers don't match, use TOMLKit's documented conversion (e.g. assign Swift `String`/`Bool` directly, which TOMLKit bridges). Verify against the resolved TOMLKit version after `swift build` and adjust these accessors only.

- [ ] **Step 4: Create the atomic writer used above**

`Sources/EnvSwitchCore/AtomicWrite.swift`:
```swift
import Foundation

enum AtomicWrite {
    static func write(_ text: String, to url: URL, posixPermissions: Int) throws {
        let dir = url.deletingLastPathComponent()
        let tmp = dir.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try text.data(using: .utf8)!.write(to: tmp)
            try FileManager.default.setAttributes(
                [.posixPermissions: posixPermissions], ofItemAtPath: tmp.path)
            // Atomic replace.
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw EnvSwitchError.io("atomic write failed: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter ConfigStoreTests`
Expected: PASS (3 tests). Fix TOMLKit accessor mismatches per the note if the build fails.

- [ ] **Step 6: Commit**

```bash
git add Sources/EnvSwitchCore/ConfigStore.swift Sources/EnvSwitchCore/AtomicWrite.swift Tests/EnvSwitchCoreTests/ConfigStoreTests.swift
git commit -m "feat(core): TOML config load/save with atomic write"
```

---

## Task 5: Base + environment merge

**Files:**
- Create: `Sources/EnvSwitchCore/Merge.swift`
- Test: `Tests/EnvSwitchCoreTests/MergeTests.swift`

Merge rule: start with `base`, overlay the named environment; environment keys override base keys. Result keeps `VarValue` (secret markers preserved) for later resolution.

- [ ] **Step 1: Write the failing test**

`Tests/EnvSwitchCoreTests/MergeTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class MergeTests: XCTestCase {
    func testEnvOverridesBase() throws {
        let cfg = EnvConfig(
            base: ["LANG": .plain("zh_CN.UTF-8"), "API_HOST": .plain("base.example.com")],
            environments: ["dev": ["API_HOST": .plain("dev.example.com"), "TOKEN": .secret]]
        )
        let merged = try Merge.merged(config: cfg, environment: "dev")
        XCTAssertEqual(merged["LANG"], .plain("zh_CN.UTF-8"))
        XCTAssertEqual(merged["API_HOST"], .plain("dev.example.com"))
        XCTAssertEqual(merged["TOKEN"], .secret)
    }

    func testUnknownEnvironmentThrows() {
        let cfg = EnvConfig(environments: ["dev": [:]])
        XCTAssertThrowsError(try Merge.merged(config: cfg, environment: "nope")) {
            XCTAssertEqual($0 as? EnvSwitchError, .environmentNotFound("nope"))
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MergeTests`
Expected: FAIL — `Merge` not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/Merge.swift`:
```swift
import Foundation

public enum Merge {
    public static func merged(config: EnvConfig, environment: String) throws -> VarMap {
        guard let env = config.environments[environment] else {
            throw EnvSwitchError.environmentNotFound(environment)
        }
        var result = config.base
        for (key, value) in env { result[key] = value }
        return result
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MergeTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/EnvSwitchCore/Merge.swift Tests/EnvSwitchCoreTests/MergeTests.swift
git commit -m "feat(core): base+environment merge"
```

---

## Task 6: Keychain store (protocol + in-memory + Security impl)

**Files:**
- Create: `Sources/EnvSwitchCore/KeychainStore.swift`
- Test: `Tests/EnvSwitchCoreTests/KeychainStoreTests.swift`

Account key convention: `"<env>/<KEY>"`, base uses `"base/<KEY>"`. Service is `"envswitch"`.

- [ ] **Step 1: Write the failing test (against the in-memory impl)**

`Tests/EnvSwitchCoreTests/KeychainStoreTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class KeychainStoreTests: XCTestCase {
    func testInMemorySetGetDelete() throws {
        let store = InMemoryKeychainStore()
        try store.set(secret: "abc123", account: "dev/TOKEN")
        XCTAssertEqual(try store.get(account: "dev/TOKEN"), "abc123")
        try store.delete(account: "dev/TOKEN")
        XCTAssertNil(try store.get(account: "dev/TOKEN"))
    }

    func testAccountKeyHelper() {
        XCTAssertEqual(KeychainAccount.key(env: "dev", name: "TOKEN"), "dev/TOKEN")
        XCTAssertEqual(KeychainAccount.key(env: nil, name: "TOKEN"), "base/TOKEN")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KeychainStoreTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement protocol + helpers + both impls**

`Sources/EnvSwitchCore/KeychainStore.swift`:
```swift
import Foundation
import Security

public protocol KeychainStore {
    func set(secret: String, account: String) throws
    func get(account: String) throws -> String?
    func delete(account: String) throws
}

public enum KeychainAccount {
    public static func key(env: String?, name: String) -> String {
        "\(env ?? "base")/\(name)"
    }
}

public final class InMemoryKeychainStore: KeychainStore {
    private var storage: [String: String] = [:]
    public init() {}
    public func set(secret: String, account: String) throws { storage[account] = secret }
    public func get(account: String) throws -> String? { storage[account] }
    public func delete(account: String) throws { storage[account] = nil }
}

public final class SecurityKeychainStore: KeychainStore {
    private let service: String
    public init(service: String = "envswitch") { self.service = service }

    public func set(secret: String, account: String) throws {
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(secret.utf8),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EnvSwitchError.keychain("add failed: \(status)")
        }
    }

    public func get(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw EnvSwitchError.keychain("read failed: \(status)")
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EnvSwitchError.keychain("delete failed: \(status)")
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter KeychainStoreTests`
Expected: PASS (only in-memory exercised in tests; Security impl is used at runtime).

- [ ] **Step 5: Commit**

```bash
git add Sources/EnvSwitchCore/KeychainStore.swift Tests/EnvSwitchCoreTests/KeychainStoreTests.swift
git commit -m "feat(core): keychain store protocol with in-memory and Security impls"
```

---

## Task 7: Shell export generation + escaping

**Files:**
- Create: `Sources/EnvSwitchCore/ShellExport.swift`
- Test: `Tests/EnvSwitchCoreTests/ShellExportTests.swift`

Resolves a merged `VarMap` into `export KEY='VALUE'` lines. Secret values are fetched from the keychain. Use single-quote escaping (`'` → `'\''`) which is robust for zsh.

- [ ] **Step 1: Write the failing test**

`Tests/EnvSwitchCoreTests/ShellExportTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class ShellExportTests: XCTestCase {
    func testEscapesSingleQuotes() {
        XCTAssertEqual(ShellExport.escape("a'b"), "'a'\\''b'")
        XCTAssertEqual(ShellExport.escape("plain"), "'plain'")
        XCTAssertEqual(ShellExport.escape("has space"), "'has space'")
    }

    func testGeneratesSortedExports() throws {
        let keychain = InMemoryKeychainStore()
        try keychain.set(secret: "s3cr3t", account: "dev/TOKEN")
        let merged: VarMap = [
            "API_HOST": .plain("dev.example.com"),
            "TOKEN": .secret,
        ]
        let lines = try ShellExport.exportLines(
            merged: merged, environment: "dev", keychain: keychain)
        XCTAssertEqual(lines, [
            "export API_HOST='dev.example.com'",
            "export TOKEN='s3cr3t'",
        ])
    }

    func testMissingSecretIsSkippedWithComment() throws {
        let keychain = InMemoryKeychainStore()
        let merged: VarMap = ["TOKEN": .secret]
        let lines = try ShellExport.exportLines(
            merged: merged, environment: "dev", keychain: keychain)
        XCTAssertEqual(lines, ["# TOKEN: secret value missing from keychain"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ShellExportTests`
Expected: FAIL — `ShellExport` not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/ShellExport.swift`:
```swift
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
```

> Secret lookup uses the environment that *owns* the variable. For merge results we lose origin; for the MVP, look up under the active environment first, then `base`. Update `exportLines` to accept the originating config in Task 9 where the service has full context. For this unit, the single-environment lookup above is sufficient and tested.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ShellExportTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/EnvSwitchCore/ShellExport.swift Tests/EnvSwitchCoreTests/ShellExportTests.swift
git commit -m "feat(core): shell export generation with quote escaping"
```

---

## Task 8: active.env writer + zsh hook snippet

**Files:**
- Create: `Sources/EnvSwitchCore/ActiveFile.swift`
- Create: `Sources/EnvSwitchCore/ShellHook.swift`
- Test: `Tests/EnvSwitchCoreTests/ActiveFileTests.swift`
- Test: `Tests/EnvSwitchCoreTests/ShellHookTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/EnvSwitchCoreTests/ActiveFileTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class ActiveFileTests: XCTestCase {
    func testWritesFileWith600Permissions() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("esw-\(UUID().uuidString)")
        let paths = EnvPaths(root: dir)
        try paths.ensureRootExists()

        try ActiveFile.write(
            lines: ["export API_HOST='dev.example.com'"],
            environmentName: "dev",
            paths: paths)

        let content = try String(contentsOf: paths.activeFile, encoding: .utf8)
        XCTAssertTrue(content.contains("export API_HOST='dev.example.com'"))
        XCTAssertTrue(content.contains("# EnvSwitch active environment: dev"))

        let attrs = try FileManager.default.attributesOfItem(atPath: paths.activeFile.path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o600)
    }
}
```

`Tests/EnvSwitchCoreTests/ShellHookTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class ShellHookTests: XCTestCase {
    func testHookSnippetReferencesActiveFile() {
        let paths = EnvPaths(root: URL(fileURLWithPath: "/Users/x/.config/envswitch"))
        let snippet = ShellHook.zshSnippet(paths: paths)
        XCTAssertTrue(snippet.contains("/Users/x/.config/envswitch/active.env"))
        XCTAssertTrue(snippet.contains("# >>> envswitch >>>"))
        XCTAssertTrue(snippet.contains("# <<< envswitch <<<"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ActiveFileTests` and `swift test --filter ShellHookTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/ActiveFile.swift`:
```swift
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
```

`Sources/EnvSwitchCore/ShellHook.swift`:
```swift
import Foundation

public enum ShellHook {
    public static func zshSnippet(paths: EnvPaths) -> String {
        let file = paths.activeFile.path
        return """
        # >>> envswitch >>>
        # Loads the currently active EnvSwitch environment in every new zsh.
        [ -f "\(file)" ] && source "\(file)"
        # <<< envswitch <<<
        """
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ActiveFileTests` and `swift test --filter ShellHookTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/EnvSwitchCore/ActiveFile.swift Sources/EnvSwitchCore/ShellHook.swift Tests/EnvSwitchCoreTests/ActiveFileTests.swift Tests/EnvSwitchCoreTests/ShellHookTests.swift
git commit -m "feat(core): active.env writer and zsh hook snippet"
```

---

## Task 9: launchctl sync wrapper

**Files:**
- Create: `Sources/EnvSwitchCore/LaunchctlSync.swift`
- Test: `Tests/EnvSwitchCoreTests/LaunchctlSyncTests.swift`

Wrap a process runner behind a protocol so tests assert on the invoked commands instead of spawning `launchctl`.

- [ ] **Step 1: Write the failing test**

`Tests/EnvSwitchCoreTests/LaunchctlSyncTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class FakeRunner: CommandRunner {
    var calls: [[String]] = []
    func run(_ executable: String, _ args: [String]) throws {
        calls.append([executable] + args)
    }
}

final class LaunchctlSyncTests: XCTestCase {
    func testSetenvForEachVar() throws {
        let runner = FakeRunner()
        let sync = LaunchctlSync(runner: runner)
        try sync.apply(["API_HOST": "dev.example.com", "TOKEN": "abc"])
        XCTAssertTrue(runner.calls.contains(["/bin/launchctl", "setenv", "API_HOST", "dev.example.com"]))
        XCTAssertTrue(runner.calls.contains(["/bin/launchctl", "setenv", "TOKEN", "abc"]))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LaunchctlSyncTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/LaunchctlSync.swift`:
```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LaunchctlSyncTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/EnvSwitchCore/LaunchctlSync.swift Tests/EnvSwitchCoreTests/LaunchctlSyncTests.swift
git commit -m "feat(core): launchctl setenv sync wrapper"
```

---

## Task 10: EnvSwitchService facade

**Files:**
- Create: `Sources/EnvSwitchCore/EnvSwitchService.swift`
- Test: `Tests/EnvSwitchCoreTests/ServiceTests.swift`

The facade is what CLI and GUI both call. It owns a `ConfigStore`, `KeychainStore`, `EnvPaths`, and optional `LaunchctlSync`. It also resolves secrets correctly using the originating environment (active env first, then base).

- [ ] **Step 1: Write the failing test**

`Tests/EnvSwitchCoreTests/ServiceTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class ServiceTests: XCTestCase {
    private func makeService() throws -> (EnvSwitchService, EnvPaths, InMemoryKeychainStore) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("esw-\(UUID().uuidString)")
        let paths = EnvPaths(root: dir)
        try paths.ensureRootExists()
        let keychain = InMemoryKeychainStore()
        let service = EnvSwitchService(paths: paths, keychain: keychain, runner: FakeRunner())
        return (service, paths, keychain)
    }

    func testSetPlainAndUse() throws {
        let (service, paths, _) = try makeService()
        try service.addEnvironment("dev")
        try service.setVariable(environment: "dev", key: "API_HOST", value: "dev.example.com", secret: false)
        try service.use("dev")

        let active = try String(contentsOf: paths.activeFile, encoding: .utf8)
        XCTAssertTrue(active.contains("export API_HOST='dev.example.com'"))
        XCTAssertEqual(try service.currentEnvironmentName(), "dev")
    }

    func testSetSecretStoresInKeychainNotConfig() throws {
        let (service, paths, keychain) = try makeService()
        try service.addEnvironment("dev")
        try service.setVariable(environment: "dev", key: "TOKEN", value: "s3cr3t", secret: true)

        let configText = try String(contentsOf: paths.configFile, encoding: .utf8)
        XCTAssertFalse(configText.contains("s3cr3t"))
        XCTAssertEqual(try keychain.get(account: "dev/TOKEN"), "s3cr3t")

        try service.use("dev")
        let active = try String(contentsOf: paths.activeFile, encoding: .utf8)
        XCTAssertTrue(active.contains("export TOKEN='s3cr3t'"))
    }

    func testBaseSecretResolvesFromBaseAccount() throws {
        let (service, _, keychain) = try makeService()
        try service.addEnvironment("dev")
        try service.setVariable(environment: nil, key: "GLOBAL_KEY", value: "g", secret: true) // base
        XCTAssertEqual(try keychain.get(account: "base/GLOBAL_KEY"), "g")

        try service.use("dev")
        XCTAssertEqual(try service.resolvedValue(forKey: "GLOBAL_KEY"), "g")
    }

    func testUnknownEnvUseThrows() throws {
        let (service, _, _) = try makeService()
        XCTAssertThrowsError(try service.use("ghost"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ServiceTests`
Expected: FAIL — `EnvSwitchService` not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/EnvSwitchService.swift`:
```swift
import Foundation

public final class EnvSwitchService {
    private let paths: EnvPaths
    private let store: ConfigStore
    private let keychain: KeychainStore
    private let runner: CommandRunner

    public init(paths: EnvPaths = .default(),
                keychain: KeychainStore = SecurityKeychainStore(),
                runner: CommandRunner = ProcessRunner()) {
        self.paths = paths
        self.store = ConfigStore(paths: paths)
        self.keychain = keychain
        self.runner = runner
    }

    // MARK: Config access

    public func loadConfig() throws -> EnvConfig { try store.load() }

    public func environmentNames() throws -> [String] {
        try store.load().environmentNames.sorted()
    }

    public func currentEnvironmentName() throws -> String? {
        try store.load().active
    }

    // MARK: Mutations

    public func addEnvironment(_ name: String) throws {
        var cfg = try store.load()
        if cfg.environments[name] == nil { cfg.environments[name] = [:] }
        try store.save(cfg)
    }

    public func removeEnvironment(_ name: String) throws {
        var cfg = try store.load()
        guard cfg.environments[name] != nil else {
            throw EnvSwitchError.environmentNotFound(name)
        }
        for key in cfg.environments[name]!.keys where cfg.environments[name]![key] == .secret {
            try keychain.delete(account: KeychainAccount.key(env: name, name: key))
        }
        cfg.environments[name] = nil
        if cfg.active == name { cfg.active = nil }
        try store.save(cfg)
    }

    /// environment == nil targets the base layer.
    public func setVariable(environment: String?, key: String, value: String, secret: Bool) throws {
        var cfg = try store.load()
        if let env = environment, cfg.environments[env] == nil {
            throw EnvSwitchError.environmentNotFound(env)
        }
        let stored: VarValue = secret ? .secret : .plain(value)
        if let env = environment {
            cfg.environments[env, default: [:]][key] = stored
        } else {
            cfg.base[key] = stored
        }
        if secret {
            try keychain.set(secret: value, account: KeychainAccount.key(env: environment, name: key))
        }
        try store.save(cfg)
    }

    public func unsetVariable(environment: String?, key: String) throws {
        var cfg = try store.load()
        let existing: VarValue?
        if let env = environment {
            existing = cfg.environments[env]?[key]
            cfg.environments[env]?[key] = nil
        } else {
            existing = cfg.base[key]
            cfg.base[key] = nil
        }
        if existing == .secret {
            try keychain.delete(account: KeychainAccount.key(env: environment, name: key))
        }
        try store.save(cfg)
    }

    // MARK: Activation

    public func use(_ name: String) throws {
        var cfg = try store.load()
        guard cfg.environments[name] != nil else {
            throw EnvSwitchError.environmentNotFound(name)
        }
        cfg.active = name
        try store.save(cfg)
        try regenerateActiveFile(cfg: cfg)
    }

    /// Re-write active.env for whatever is currently active (used by `reload`).
    public func reload() throws {
        let cfg = try store.load()
        try regenerateActiveFile(cfg: cfg)
    }

    private func regenerateActiveFile(cfg: EnvConfig) throws {
        guard let active = cfg.active else {
            try ActiveFile.clear(paths: paths)
            return
        }
        let lines = try resolvedExportLines(cfg: cfg, environment: active)
        try ActiveFile.write(lines: lines, environmentName: active, paths: paths)

        if cfg.launchctlSync {
            let resolved = try resolvedValues(cfg: cfg, environment: active)
            try LaunchctlSync(runner: runner).apply(resolved)
        }
    }

    // MARK: Resolution (origin-aware secret lookup)

    /// Returns merged values with secrets resolved to literals, or nil per missing secret.
    private func resolvedValues(cfg: EnvConfig, environment: String) throws -> [String: String] {
        let merged = try Merge.merged(config: cfg, environment: environment)
        var out: [String: String] = [:]
        for (key, value) in merged {
            switch value {
            case .plain(let v):
                out[key] = v
            case .secret:
                // Env overrides base, so prefer the env-scoped secret, fall back to base.
                let envAccount = KeychainAccount.key(env: environment, name: key)
                let baseAccount = KeychainAccount.key(env: nil, name: key)
                if let v = try keychain.get(account: envAccount) ?? keychain.get(account: baseAccount) {
                    out[key] = v
                }
            }
        }
        return out
    }

    private func resolvedExportLines(cfg: EnvConfig, environment: String) throws -> [String] {
        let resolved = try resolvedValues(cfg: cfg, environment: environment)
        let merged = try Merge.merged(config: cfg, environment: environment)
        var lines: [String] = []
        for key in merged.keys.sorted() {
            if let v = resolved[key] {
                lines.append("export \(key)=\(ShellExport.escape(v))")
            } else {
                lines.append("# \(key): secret value missing from keychain")
            }
        }
        return lines
    }

    public func resolvedValue(forKey key: String) throws -> String? {
        let cfg = try store.load()
        guard let active = cfg.active else { return nil }
        return try resolvedValues(cfg: cfg, environment: active)[key]
    }

    public func exportScript() throws -> String {
        let cfg = try store.load()
        guard let active = cfg.active else { return "" }
        return try resolvedExportLines(cfg: cfg, environment: active).joined(separator: "\n") + "\n"
    }

    public func setLaunchctlSync(_ enabled: Bool) throws {
        var cfg = try store.load()
        cfg.launchctlSync = enabled
        try store.save(cfg)
    }

    public func shellHookSnippet() -> String { ShellHook.zshSnippet(paths: paths) }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ServiceTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full suite**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/EnvSwitchCore/EnvSwitchService.swift Tests/EnvSwitchCoreTests/ServiceTests.swift
git commit -m "feat(core): EnvSwitchService facade with origin-aware secret resolution"
```

---

## Task 11: CLI commands

**Files:**
- Modify/replace: `Sources/envswitch/main.swift` → split into `EnvSwitch.swift` + `main.swift`
- Create: `Sources/envswitch/EnvSwitch.swift`

CLI is a thin wrapper over `EnvSwitchService`. It uses the default paths/keychain at runtime. There is no unit test target for the executable; verification is a manual smoke test against a temp HOME (`envswitch` honors `ENVSWITCH_HOME` if set, to keep tests isolated).

- [ ] **Step 1: Add `ENVSWITCH_HOME` override to `EnvPaths`**

Modify `Sources/EnvSwitchCore/Paths.swift` — add:
```swift
    public static func resolved(environment: [String: String] = ProcessInfo.processInfo.environment) -> EnvPaths {
        if let override = environment["ENVSWITCH_HOME"], !override.isEmpty {
            return EnvPaths(root: URL(fileURLWithPath: override))
        }
        return .default()
    }
```

- [ ] **Step 2: Replace `main.swift` and add the command tree**

Delete the old `print` body of `Sources/envswitch/main.swift` and set it to:
```swift
import EnvSwitchCore
EnvSwitch.main()
```

`Sources/envswitch/EnvSwitch.swift`:
```swift
import ArgumentParser
import EnvSwitchCore
import Foundation

private func makeService() -> EnvSwitchService {
    EnvSwitchService(paths: .resolved())
}

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
            let service = makeService()
            let cfg = try service.loadConfig()
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
            print("Activated \(environment). New shells pick it up automatically; run `envswitch reload` in open shells.")
        }
    }

    struct Reload: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Regenerate active.env for the current environment.")
        func run() throws { try makeService().reload() }
    }

    struct Current: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show active environment.")
        func run() throws {
            let service = makeService()
            if let name = try service.currentEnvironmentName() {
                print("Active: \(name)")
                print(try service.exportScript())
            } else {
                print("No active environment.")
            }
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
        static let configuration = CommandConfiguration(abstract: "Set a variable.")
        @Argument var environment: String
        @Argument var key: String
        @Argument var value: String?
        @Flag(name: .long, help: "Store value in the macOS Keychain.") var secret = false
        func run() throws {
            let env = environment == "base" ? nil : environment
            var v = value ?? ""
            if secret && (value == nil) {
                v = String(cString: getpass("Secret value: "))
            }
            try makeService().setVariable(environment: env, key: key, value: v, secret: secret)
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
                try service.setVariable(environment: env, key: key, value: value, secret: false)
            }
        }
    }

    struct ShellInit: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "shell-init",
            abstract: "Print the zsh hook to add to ~/.zshrc.")
        func run() throws { print(makeService().shellHookSnippet()) }
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds with no errors.

- [ ] **Step 4: Manual smoke test against an isolated HOME**

Run:
```bash
export ENVSWITCH_HOME="$(mktemp -d)/envswitch"
swift run envswitch add dev
swift run envswitch set dev API_HOST dev.example.com
swift run envswitch set dev TOKEN s3cr3t --secret
swift run envswitch use dev
swift run envswitch current
cat "$ENVSWITCH_HOME/active.env"
swift run envswitch list
```
Expected: `current` prints `Active: dev` and the exports; `active.env` contains `export API_HOST='dev.example.com'` and `export TOKEN='s3cr3t'`; `list` shows `* dev`. (Keychain access on first run may prompt for permission.)

- [ ] **Step 5: Commit**

```bash
git add Sources/envswitch Sources/EnvSwitchCore/Paths.swift
git commit -m "feat(cli): full envswitch command surface"
```

---

## Task 12: GUI AppModel (ObservableObject over the service)

**Files:**
- Create: `Sources/EnvSwitchGUI/AppModel.swift`

There is no unit test for the GUI; the `EnvSwitchService` it wraps is already fully tested. Verification is manual (`swift run EnvSwitchGUI`).

- [ ] **Step 1: Implement the model**

`Sources/EnvSwitchGUI/AppModel.swift`:
```swift
import Foundation
import EnvSwitchCore
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var environmentNames: [String] = []
    @Published var activeName: String?
    @Published var selectedEnvironment: String?
    @Published var variables: [VariableRow] = []
    @Published var launchctlSync = false
    @Published var lastError: String?

    struct VariableRow: Identifiable {
        let id = UUID()
        var key: String
        var value: String   // shown value; for secrets this is "" until revealed
        var isSecret: Bool
    }

    private let service = EnvSwitchService(paths: .resolved())

    func refresh() {
        do {
            let cfg = try service.loadConfig()
            environmentNames = cfg.environmentNames.sorted()
            activeName = cfg.active
            launchctlSync = cfg.launchctlSync
            if selectedEnvironment == nil { selectedEnvironment = cfg.active ?? environmentNames.first }
            loadVariables()
        } catch { lastError = "\(error)" }
    }

    func loadVariables() {
        guard let env = selectedEnvironment else { variables = []; return }
        do {
            let cfg = try service.loadConfig()
            let map = env == "base" ? cfg.base : (cfg.environments[env] ?? [:])
            variables = map.keys.sorted().map { key in
                let v = map[key]!
                return VariableRow(key: key, value: v.literal ?? "", isSecret: v.isSecret)
            }
        } catch { lastError = "\(error)" }
    }

    func activate(_ name: String) {
        do { try service.use(name); refresh() } catch { lastError = "\(error)" }
    }

    func addEnvironment(_ name: String) {
        do { try service.addEnvironment(name); selectedEnvironment = name; refresh() }
        catch { lastError = "\(error)" }
    }

    func removeEnvironment(_ name: String) {
        do { try service.removeEnvironment(name); selectedEnvironment = nil; refresh() }
        catch { lastError = "\(error)" }
    }

    func setVariable(key: String, value: String, secret: Bool) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.setVariable(environment: target, key: key, value: value, secret: secret); loadVariables() }
        catch { lastError = "\(error)" }
    }

    func unsetVariable(key: String) {
        guard let env = selectedEnvironment else { return }
        let target = env == "base" ? nil : env
        do { try service.unsetVariable(environment: target, key: key); loadVariables() }
        catch { lastError = "\(error)" }
    }

    func setLaunchctlSync(_ on: Bool) {
        do { try service.setLaunchctlSync(on); launchctlSync = on } catch { lastError = "\(error)" }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds.

- [ ] **Step 3: Commit**

```bash
git add Sources/EnvSwitchGUI/AppModel.swift
git commit -m "feat(gui): app model wrapping EnvSwitchService"
```

---

## Task 13: GUI views (menu bar + main window + settings)

**Files:**
- Replace: `Sources/EnvSwitchGUI/EnvSwitchApp.swift`
- Create: `Sources/EnvSwitchGUI/MenuBarView.swift`
- Create: `Sources/EnvSwitchGUI/MainWindowView.swift`
- Create: `Sources/EnvSwitchGUI/SettingsView.swift`

- [ ] **Step 1: App entry with MenuBarExtra + window**

`Sources/EnvSwitchGUI/EnvSwitchApp.swift`:
```swift
import SwiftUI

@main
struct EnvSwitchApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("EnvSwitch", id: "main") {
            MainWindowView().environmentObject(model).onAppear { model.refresh() }
        }
        .defaultSize(width: 720, height: 460)

        MenuBarExtra("EnvSwitch", systemImage: "switch.2") {
            MenuBarView().environmentObject(model)
        }
        .menuBarExtraStyle(.menu)

        Settings { SettingsView().environmentObject(model) }
    }
}
```

- [ ] **Step 2: Menu bar quick switch**

`Sources/EnvSwitchGUI/MenuBarView.swift`:
```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(model.environmentNames, id: \.self) { name in
            Button {
                model.activate(name)
            } label: {
                Label(name, systemImage: name == model.activeName ? "largecircle.fill.circle" : "circle")
            }
        }
        Divider()
        Button("Edit Environments…") { openWindow(id: "main") }
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
    .onAppear { model.refresh() }
}
```

> Note: `.onAppear` cannot attach to a `ForEach`-rooted body directly; wrap the menu content in a `Group { … }.onAppear { model.refresh() }` if the compiler objects.

- [ ] **Step 3: Main window (list + variable table)**

`Sources/EnvSwitchGUI/MainWindowView.swift`:
```swift
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @State private var newEnvName = ""
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var newSecret = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                List(selection: $model.selectedEnvironment) {
                    Section("Layers") { Text("base").tag("base") }
                    Section("Environments") {
                        ForEach(model.environmentNames, id: \.self) { name in
                            HStack {
                                Text(name)
                                if name == model.activeName {
                                    Spacer(); Image(systemName: "largecircle.fill.circle")
                                }
                            }.tag(name)
                        }
                    }
                }
                .onChange(of: model.selectedEnvironment) { _, _ in model.loadVariables() }

                HStack {
                    TextField("New environment", text: $newEnvName)
                    Button("Add") {
                        guard !newEnvName.isEmpty else { return }
                        model.addEnvironment(newEnvName); newEnvName = ""
                    }
                }.padding(8)
            }
            .frame(minWidth: 200)
        } detail: {
            VStack(alignment: .leading) {
                HStack {
                    Text(model.selectedEnvironment ?? "—").font(.title2)
                    Spacer()
                    if let env = model.selectedEnvironment, env != "base" {
                        Button("Activate") { model.activate(env) }
                            .disabled(env == model.activeName)
                    }
                }.padding(.horizontal)

                Table(model.variables) {
                    TableColumn("Key") { Text($0.key) }
                    TableColumn("Value") { row in
                        Text(row.isSecret ? "••••••" : row.value)
                    }
                    TableColumn("Secret") { Text($0.isSecret ? "🔒" : "") }
                    TableColumn("") { row in
                        Button(role: .destructive) { model.unsetVariable(key: row.key) } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

                HStack {
                    TextField("KEY", text: $newKey)
                    TextField("value", text: $newValue)
                    Toggle("Secret", isOn: $newSecret)
                    Button("Set") {
                        guard !newKey.isEmpty else { return }
                        model.setVariable(key: newKey, value: newValue, secret: newSecret)
                        newKey = ""; newValue = ""; newSecret = false
                    }
                }.padding()
            }
        }
        .alert("Error", isPresented: .constant(model.lastError != nil)) {
            Button("OK") { model.lastError = nil }
        } message: { Text(model.lastError ?? "") }
    }
}
```

- [ ] **Step 4: Settings**

`Sources/EnvSwitchGUI/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Toggle("Sync to GUI apps (launchctl setenv)", isOn: Binding(
                get: { model.launchctlSync },
                set: { model.setLaunchctlSync($0) }))
            Text("New shells load the active environment automatically once the zsh hook is installed. Use the CLI `envswitch shell-init` to print the hook.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { model.refresh() }
    }
}
```

- [ ] **Step 5: Build and manually run**

Run: `swift build`
Then: `ENVSWITCH_HOME="$(mktemp -d)/envswitch" swift run EnvSwitchGUI`
Expected: a window opens with the base/environment list and variable table; the menu bar shows a switch icon with the environment list. Add an environment, set a variable, click Activate, confirm the menu bar radio dot moves.

- [ ] **Step 6: Commit**

```bash
git add Sources/EnvSwitchGUI
git commit -m "feat(gui): menu bar quick switch, main window editor, settings"
```

---

## Task 14: First-run setup (CLI symlink + zsh hook install)

**Files:**
- Create: `Sources/EnvSwitchCore/Installer.swift`
- Create: `Sources/EnvSwitchGUI/FirstRunView.swift`
- Test: `Tests/EnvSwitchCoreTests/InstallerTests.swift`
- Modify: `Sources/EnvSwitchGUI/EnvSwitchApp.swift` (present first-run if hook missing)

The installer (a) ensures the zsh hook block exists in `~/.zshrc` (idempotent, marker-delimited), and (b) reports whether `envswitch` is on PATH. Symlink creation to `/usr/local/bin` may need privileges, so the GUI shows the command for the user to run rather than silently sudo-ing.

- [ ] **Step 1: Write the failing test for idempotent hook install**

`Tests/EnvSwitchCoreTests/InstallerTests.swift`:
```swift
import XCTest
@testable import EnvSwitchCore

final class InstallerTests: XCTestCase {
    func testInstallHookIsIdempotent() throws {
        let zshrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("zshrc-\(UUID().uuidString)")
        try "export FOO=1\n".write(to: zshrc, atomically: true, encoding: .utf8)
        let paths = EnvPaths(root: URL(fileURLWithPath: "/Users/x/.config/envswitch"))

        try Installer.installZshHook(into: zshrc, paths: paths)
        try Installer.installZshHook(into: zshrc, paths: paths) // twice

        let text = try String(contentsOf: zshrc, encoding: .utf8)
        let occurrences = text.components(separatedBy: "# >>> envswitch >>>").count - 1
        XCTAssertEqual(occurrences, 1)
        XCTAssertTrue(text.contains("export FOO=1"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter InstallerTests`
Expected: FAIL — `Installer` not defined.

- [ ] **Step 3: Implement**

`Sources/EnvSwitchCore/Installer.swift`:
```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter InstallerTests`
Expected: PASS

- [ ] **Step 5: Add a first-run sheet in the GUI**

`Sources/EnvSwitchGUI/FirstRunView.swift`:
```swift
import SwiftUI
import EnvSwitchCore

struct FirstRunView: View {
    let onInstallHook: () -> Void
    let symlinkCommand: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Finish EnvSwitch setup").font(.title2.bold())
            Text("1. Add the zsh hook so new terminals load the active environment:")
            Button("Install zsh hook into ~/.zshrc", action: onInstallHook)
            Text("2. Put the CLI on your PATH by running this in Terminal:")
            Text(symlinkCommand).font(.system(.body, design: .monospaced))
                .textSelection(.enabled).padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(24)
        .frame(width: 520)
    }
}
```

Wire it in `EnvSwitchApp.swift` by presenting `FirstRunView` as a sheet from `MainWindowView` when `Installer.hookInstalled(in: ~/.zshrc)` is false. Add to `AppModel`:
```swift
func installZshHook() {
    let zshrc = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
    do { try Installer.installZshHook(into: zshrc, paths: .resolved()) } catch { lastError = "\(error)" }
}
var needsHook: Bool {
    let zshrc = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
    return !Installer.hookInstalled(in: zshrc)
}
var cliSymlinkCommand: String {
    Installer.symlinkCommand(cliPath: Bundle.main.bundlePath + "/Contents/MacOS/envswitch")
}
```

In `MainWindowView` add:
```swift
.sheet(isPresented: .constant(model.needsHook)) {
    FirstRunView(onInstallHook: { model.installZshHook(); model.objectWillChange.send() },
                 symlinkCommand: model.cliSymlinkCommand)
}
```

- [ ] **Step 6: Build, test, manual check**

Run: `swift build && swift test`
Expected: all tests pass.
Manual: launch GUI with a temp HOME, confirm first-run sheet appears, click install, confirm the hook lands in `~/.zshrc` exactly once.

- [ ] **Step 7: Commit**

```bash
git add Sources/EnvSwitchCore/Installer.swift Sources/EnvSwitchGUI Tests/EnvSwitchCoreTests/InstallerTests.swift
git commit -m "feat: first-run zsh hook install and CLI symlink guidance"
```

---

## Task 15: README and packaging notes

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

`README.md` covering: what it does, the activation model (new shells auto-load; `reload` for open shells; optional launchctl), install (build with `swift build -c release`, embed `envswitch` binary in the `.app` bundle's `Contents/MacOS`, symlink to PATH), CLI command reference (copy from this plan's Task 11), config format example (copy from the spec), and the security note that secrets live in Keychain. Include the `~/.config/envswitch/config.toml` example.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage, config, and install"
```

> **Packaging the .app for distribution (out of scope for MVP automation, documented for later):** to ship a real double-clickable `.app` with a working `MenuBarExtra`, create a thin Xcode project (or use a tool like `swift bundler`) that wraps the `EnvSwitchGUI` target, sets `Info.plist` `LSUIElement`/bundle id, embeds the release `envswitch` binary under `Contents/MacOS/`, and code-signs. The SwiftPM `swift run EnvSwitchGUI` path is sufficient for development and verification in this plan.

---

## Self-Review

**1. Spec coverage:**
- §2 architecture (Core/CLI/GUI shared lib) → Tasks 1, 10, 11, 12–13. ✓
- §3 single TOML, base+env, secret marker → Tasks 3, 4, 5. ✓
- §4 activation: shell integration (active.env + hook) → Tasks 8, 10; reload → Task 10/11; launchctl optional → Task 9/10. ✓
- §5 Keychain for secrets, 600 perms, masked in GUI → Tasks 6, 8, 10, 13. ✓
- §6 CLI command set (zsh) → Task 11. ✓
- §7 GUI menu bar + window + settings → Tasks 12, 13. ✓
- §8 distribution: app embeds CLI, symlink, hook install, macOS 14+ → Tasks 1 (platform), 14, 15. ✓
- §9 atomic writes, escaping, error types → Tasks 4 (AtomicWrite), 7 (escape), 3 (EnvSwitchError). ✓
- §10 tests on Core → Tasks 2–10, 14. ✓
- §11 YAGNI exclusions respected (zsh-only, no layering, no cloud, CLI bundled not brew). ✓

**2. Placeholder scan:** No TBD/TODO in steps; the two `> Note` blocks flag *version-specific API verification* (TOMLKit accessors, SwiftUI `.onAppear` on `ForEach`) and `.app` packaging which is explicitly deferred — these are guidance, not missing implementation.

**3. Type consistency:** `VarValue`, `VarMap`, `EnvConfig`, `EnvSwitchError`, `EnvPaths`, `ConfigStore`, `Merge.merged`, `KeychainStore`/`KeychainAccount.key`, `ShellExport.escape`/`exportLines`, `ActiveFile.write/clear`, `ShellHook.zshSnippet`, `CommandRunner`/`LaunchctlSync.apply`, `EnvSwitchService` method names, and `Installer` API names are used consistently across tasks and in the CLI/GUI consumers.
