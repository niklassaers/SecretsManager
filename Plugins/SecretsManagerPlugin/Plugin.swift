
import PackagePlugin
import class Foundation.FileManager
import struct Foundation.Date

@main
struct SecretsManagerPlugin: BuildToolPlugin {

    fileprivate func checkForWarnings(envPath: Path, outPath: Path) -> [Command]? {
        // .env file must exist
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: envPath.string) else {
            Diagnostics.error("❗️ No .env file at path '\(envPath)'")
            return []
        }
        
        // skip if outPath is newer than envPath
        if fileManager.fileExists(atPath: outPath.string),
           let envAttributes = try? fileManager.attributesOfItem(atPath: envPath.string),
           let outAttributes = try? fileManager.attributesOfItem(atPath: outPath.string),
           let envDate = envAttributes[.modificationDate] as? Date,
           let outDate = outAttributes[.modificationDate] as? Date,
           envDate < outDate {
            Diagnostics.remark("\(outPath.string) is newer than \(envPath.string) so skipping re-generation")
            return []
        }
        
        return nil
    }
    
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let envPath = context.package.directory.appending(subpath: ".env")
        let outPath = context.pluginWorkDirectory.appending(subpath: "GeneratedSecrets.swift")

        if let stopCommands = checkForWarnings(envPath: envPath, outPath: outPath) {
            return stopCommands
        }
        
        return [command("SecretsManager", executable: try context.tool(named: "SecretsManager").path, envPath: envPath, outPath: outPath)]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SecretsManagerPlugin: XcodeBuildToolPlugin {

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let envPath = context.xcodeProject.directory.appending(subpath: ".env")
        let outPath = context.pluginWorkDirectory.appending(subpath: "GeneratedSecrets.swift")

        if let stopCommands = checkForWarnings(envPath: envPath, outPath: outPath) {
            return stopCommands
        }
        
        return [command("SecretsManager", executable: try context.tool(named: "SecretsManager").path, envPath: envPath, outPath: outPath)]
    }
}
#endif

func command(_ name: String, executable: Path, envPath: Path, outPath: Path) -> Command {
    .buildCommand(
        displayName: name,
        executable: executable,
        arguments: [envPath.string, outPath.string],
        inputFiles: [envPath],
        outputFiles: [outPath]
    )
}
