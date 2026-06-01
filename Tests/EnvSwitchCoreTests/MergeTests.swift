import Testing
@testable import EnvSwitchCore

@Test func testEnvOverridesBase() throws {
    let cfg = EnvConfig(
        base: ["LANG": "zh_CN.UTF-8", "API_HOST": "base.example.com"],
        environments: ["dev": ["API_HOST": "dev.example.com", "TOKEN": "abc123"]]
    )
    let merged = try Merge.merged(config: cfg, environment: "dev")
    #expect(merged["LANG"] == "zh_CN.UTF-8")
    #expect(merged["API_HOST"] == "dev.example.com")
    #expect(merged["TOKEN"] == "abc123")
}

@Test func testUnknownEnvironmentThrows() throws {
    let cfg2 = EnvConfig(environments: ["dev": [:]])
    #expect(throws: EnvSwitchError.environmentNotFound("nope")) {
        _ = try Merge.merged(config: cfg2, environment: "nope")
    }
}
