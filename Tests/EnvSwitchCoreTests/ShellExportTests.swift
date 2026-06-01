import Testing
@testable import EnvSwitchCore

@Test func testEscapesSingleQuotes() throws {
    #expect(ShellExport.escape("a'b") == "'a'\\''b'")
    #expect(ShellExport.escape("plain") == "'plain'")
    #expect(ShellExport.escape("has space") == "'has space'")
}

@Test func testGeneratesSortedExports() throws {
    let keychain = InMemoryKeychainStore()
    try keychain.set(secret: "s3cr3t", account: "dev/TOKEN")
    let merged: VarMap = ["API_HOST": .plain("dev.example.com"), "TOKEN": .secret]
    let lines = try ShellExport.exportLines(merged: merged, environment: "dev", keychain: keychain)
    #expect(lines == ["export API_HOST='dev.example.com'", "export TOKEN='s3cr3t'"])
}

@Test func testMissingSecretIsSkippedWithComment() throws {
    let keychain2 = InMemoryKeychainStore()
    let merged2: VarMap = ["TOKEN": .secret]
    let lines2 = try ShellExport.exportLines(merged: merged2, environment: "dev", keychain: keychain2)
    #expect(lines2 == ["# TOKEN: secret value missing from keychain"])
}
