import Testing
@testable import EnvSwitchCore

@Test func testConfigLookup() {
    let cfg = EnvConfig(
        active: "dev",
        launchctlSync: false,
        base: ["LANG": "zh_CN.UTF-8"],
        environments: ["dev": ["API_HOST": "dev.example.com"]]
    )
    #expect(cfg.environmentNames.sorted() == ["dev"])
    #expect(cfg.environments["dev"]?["API_HOST"] == "dev.example.com")
}
