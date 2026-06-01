import Testing
@testable import EnvSwitchCore

@Test func testPlainAndSecretValues() {
    let plain = VarValue.plain("dev.example.com")
    let secret = VarValue.secret
    #expect(plain.literal == "dev.example.com")
    #expect(secret.literal == nil)
    #expect(secret.isSecret)
    #expect(!plain.isSecret)
}

@Test func testConfigLookup() {
    let cfg = EnvConfig(
        active: "dev",
        launchctlSync: false,
        base: ["LANG": .plain("zh_CN.UTF-8")],
        environments: ["dev": ["API_HOST": .plain("dev.example.com")]]
    )
    #expect(cfg.environmentNames.sorted() == ["dev"])
    #expect(cfg.environments["dev"]?["API_HOST"]?.literal == "dev.example.com")
}
