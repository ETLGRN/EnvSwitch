import Testing
@testable import EnvSwitchCore

@Test func testConfigLookup() {
    let cfg = EnvConfig(
        active: "dev",
        launchctlSync: false,
        base: [VarEntry(key: "LANG", value: "zh_CN.UTF-8")],
        environments: ["dev": [VarEntry(key: "API_HOST", value: "dev.example.com")]]
    )
    #expect(cfg.environmentNames.sorted() == ["dev"])
    #expect(cfg.environments["dev"]?.value(forKey: "API_HOST") == "dev.example.com")
}

@Test func testVarListSetValueAppendsNewKeyAtEnd() {
    var list: VarList = [VarEntry(key: "A", value: "1"), VarEntry(key: "B", value: "2")]
    list.setValue("3", forKey: "C")
    #expect(list.map(\.key) == ["A", "B", "C"])
}

@Test func testVarListSetValueUpdatesInPlaceKeepingGroup() {
    var list: VarList = [
        VarEntry(key: "A", value: "1", group: "g1"),
        VarEntry(key: "B", value: "2"),
    ]
    list.setValue("9", forKey: "A")
    #expect(list[0] == VarEntry(key: "A", value: "9", group: "g1"))
    #expect(list.map(\.key) == ["A", "B"])
}

@Test func testVarListSetValueCanChangeGroupExplicitly() {
    var list: VarList = [VarEntry(key: "A", value: "1", group: "g1")]
    list.setValue("1", forKey: "A", group: .some("g2"))
    #expect(list[0].group == "g2")
    list.setValue("1", forKey: "A", group: .some(nil))
    #expect(list[0].group == nil)
}

@Test func testVarListGroupNamesInFirstAppearanceOrder() {
    let list: VarList = [
        VarEntry(key: "A", value: "1", group: "beta"),
        VarEntry(key: "B", value: "2"),
        VarEntry(key: "C", value: "3", group: "alpha"),
        VarEntry(key: "D", value: "4", group: "beta"),
    ]
    #expect(list.groupNames == ["beta", "alpha"])
}
