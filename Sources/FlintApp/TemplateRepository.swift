import Foundation
import FlintCore

struct TemplateRepository {
    private let templatesURL: URL

    static func defaultRepository() -> TemplateRepository {
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let developmentTemplatesURL = workingDirectory.appending(path: "templates")
        if FileManager.default.fileExists(atPath: developmentTemplatesURL.path) {
            return TemplateRepository(templatesURL: developmentTemplatesURL)
        }

        let applicationSupportURL = applicationSupportTemplatesURL()
        do {
            try seedBundledTemplatesIfNeeded(into: applicationSupportURL)
        } catch {
            NSLog("Flint could not prepare application support templates: \(error)")
        }
        return TemplateRepository(templatesURL: applicationSupportURL)
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

    private static func applicationSupportTemplatesURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return baseURL.appending(path: "Flint/templates", directoryHint: .isDirectory)
    }

    private static func seedBundledTemplatesIfNeeded(into templatesURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: templatesURL, withIntermediateDirectories: true)

        let existingTemplates = try fileManager.contentsOfDirectory(
            at: templatesURL,
            includingPropertiesForKeys: nil
        )
        .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
        guard existingTemplates.isEmpty, let bundledTemplatesURL = bundledTemplatesURL() else { return }

        let bundledTemplates = try fileManager.contentsOfDirectory(
            at: bundledTemplatesURL,
            includingPropertiesForKeys: nil
        )
        .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }

        for sourceURL in bundledTemplates {
            let destinationURL = templatesURL.appending(path: sourceURL.lastPathComponent)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    private static func bundledTemplatesURL() -> URL? {
        let candidates = [
            Bundle.main.resourceURL?.appending(path: "templates", directoryHint: .isDirectory),
            Bundle.main.bundleURL.appending(path: "templates", directoryHint: .isDirectory),
            Bundle.main.executableURL?.deletingLastPathComponent().appending(path: "templates", directoryHint: .isDirectory)
        ].compactMap { $0 }

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

struct TemplateRecord: Identifiable, Equatable {
    let url: URL
    let document: TemplateYAMLDocument

    var id: String { url.standardizedFileURL.path }
    var template: FlintTemplate { document.template }
    var unsupportedSaveReason: String? { document.unsupportedSaveReason }
}
