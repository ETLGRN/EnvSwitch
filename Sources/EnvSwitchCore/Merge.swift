import Foundation

public enum Merge {
    public static func merged(config: EnvConfig, environment: String) throws -> VarMap {
        guard let env = config.environments[environment] else {
            throw EnvSwitchError.environmentNotFound(environment)
        }
        var result = config.base
        for (key, value) in env { result[key] = value }
        return result
    }
}
