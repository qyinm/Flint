import Foundation
import FlintCore

struct TemplateRepository {
    private let templatesURL: URL

    static func defaultRepository() -> TemplateRepository {
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return TemplateRepository(templatesURL: workingDirectory.appending(path: "templates"))
    }

    func loadTemplates() throws -> [FlintTemplate] {
        try TemplateLoader.loadTemplates(from: templatesURL)
    }
}
