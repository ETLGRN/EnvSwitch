import Foundation

public enum Merge {
    /// base merged with the named environment; the environment wins on key conflicts.
    public static func merged(config: EnvConfig, environment: String) throws -> VarMap {
        guard let env = config.environments[environment] else {
            throw EnvSwitchError.environmentNotFound(environment)
        }
        var result = config.base.asMap
        for entry in env { result[entry.key] = entry.value }
        return result
    }
}
