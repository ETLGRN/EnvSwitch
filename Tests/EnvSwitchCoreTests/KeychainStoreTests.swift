import Testing
@testable import EnvSwitchCore

@Test func testInMemorySetGetDelete() throws {
    let store = InMemoryKeychainStore()
    try store.set(secret: "abc123", account: "dev/TOKEN")
    #expect(try store.get(account: "dev/TOKEN") == "abc123")
    try store.delete(account: "dev/TOKEN")
    #expect(try store.get(account: "dev/TOKEN") == nil)
}

@Test func testAccountKeyHelper() throws {
    #expect(KeychainAccount.key(env: "dev", name: "TOKEN") == "dev/TOKEN")
    #expect(KeychainAccount.key(env: nil, name: "TOKEN") == "base/TOKEN")
}
