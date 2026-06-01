import Testing
@testable import EnvSwitchCore

@Test func testEnvOverridesBase() throws {
    let cfg = EnvConfig(
        base: ["LANG": .plain("zh_CN.UTF-8"), "API_HOST": .plain("base.example.com")],
        environments: ["dev": ["API_HOST": .plain("dev.example.com"), "TOKEN": .secret]]
    )
    let merged = try Merge.merged(config: cfg, environment: "dev")
    #expect(merged["LANG"] == .plain("zh_CN.UTF-8"))
    #expect(merged["API_HOST"] == .plain("dev.example.com"))
    #expect(merged["TOKEN"] == .secret)
}

@Test func testUnknownEnvironmentThrows() throws {
    let cfg2 = EnvConfig(environments: ["dev": [:]])
    #expect(throws: EnvSwitchError.environmentNotFound("nope")) {
        _ = try Merge.merged(config: cfg2, environment: "nope")
    }
}
