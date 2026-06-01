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
