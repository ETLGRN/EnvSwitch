import Testing
import Foundation
@testable import EnvSwitchCore

@Test func testHookSnippetReferencesActiveFile() {
    let paths = EnvPaths(root: URL(fileURLWithPath: "/Users/x/.config/envswitch"))
    let snippet = ShellHook.zshSnippet(paths: paths)
    #expect(snippet.contains("/Users/x/.config/envswitch/active.env"))
    #expect(snippet.contains("# >>> envswitch >>>"))
    #expect(snippet.contains("# <<< envswitch <<<"))
}
