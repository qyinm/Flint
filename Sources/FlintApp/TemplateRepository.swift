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

    func loadTemplateRecords() throws -> [TemplateRecord] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: templatesURL,
            includingPropertiesForKeys: nil
        )
        .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try urls.map { url in
            let yaml = try String(contentsOf: url, encoding: .utf8)
            let document = try FlintTemplateYAMLCodec.document(from: yaml)
            return TemplateRecord(url: url, document: document)
        }
    }

    func save(_ draft: EditableTemplateDraft, for record: TemplateRecord) throws {
        let yaml = try FlintTemplateYAMLCodec.serialize(draft)
        let directory = record.url.deletingLastPathComponent()
        let temporaryURL = directory.appendingPathComponent(".\(record.url.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            try yaml.write(to: temporaryURL, atomically: true, encoding: .utf8)
            _ = try TemplateLoader.loadTemplate(from: temporaryURL)
            if FileManager.default.fileExists(atPath: record.url.path) {
                _ = try FileManager.default.replaceItemAt(record.url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: record.url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }
}

struct TemplateRecord: Identifiable, Equatable {
    let url: URL
    let document: TemplateYAMLDocument

    var id: String { url.standardizedFileURL.path }
    var template: FlintTemplate { document.template }
    var unsupportedSaveReason: String? { document.unsupportedSaveReason }
}
