import Testing
@testable import EnvSwitchCore

@Test func testEscapesSingleQuotes() throws {
    #expect(ShellExport.escape("a'b") == "'a'\\''b'")
    #expect(ShellExport.escape("plain") == "'plain'")
    #expect(ShellExport.escape("has space") == "'has space'")
}

@Test func testGeneratesSortedExports() throws {
    let merged: VarMap = ["API_HOST": "dev.example.com", "TOKEN": "s3cr3t"]
    let lines = ShellExport.exportLines(merged: merged)
    #expect(lines == ["export API_HOST='dev.example.com'", "export TOKEN='s3cr3t'"])
}
