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

    func createTemplate(name: String, typedTrigger: String, prompt: String) throws -> TemplateRecord {
        let templateName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trigger = typedTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = Self.slug(for: templateName.isEmpty ? "template" : templateName)
        let url = uniqueTemplateURL(for: id)
        let template = FlintTemplate(
            schemaVersion: 1,
            id: url.deletingPathExtension().lastPathComponent,
            name: templateName,
            triggers: FlintTemplate.Triggers(typed: trigger.isEmpty ? [] : [trigger]),
            targets: ["generic": body]
        )
        let document = TemplateYAMLDocument(
            template: template,
            targetOrder: ["generic"],
            variableOrder: []
        )
        let record = TemplateRecord(url: url, document: document)
        try save(EditableTemplateDraft(document: document), for: record)
        return record
    }

    private func uniqueTemplateURL(for id: String) -> URL {
        var candidate = templatesURL.appendingPathComponent("\(id).yaml")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = templatesURL.appendingPathComponent("\(id)-\(suffix).yaml")
            suffix += 1
        }
        return candidate
    }

    private static func slug(for value: String) -> String {
        let lowered = value.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "template" : collapsed
    }
}

struct TemplateRecord: Identifiable, Equatable {
    let url: URL
    let document: TemplateYAMLDocument

    var id: String { url.standardizedFileURL.path }
    var template: FlintTemplate { document.template }
    var unsupportedSaveReason: String? { document.unsupportedSaveReason }
}
