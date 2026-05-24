import Foundation

public enum TemplateYAMLCodecError: Error, Equatable, CustomStringConvertible {
    case unsupported(String)
    case invalid(String)

    public var description: String {
        switch self {
        case .unsupported(let reason): "Unsupported template YAML: \(reason)"
        case .invalid(let reason): "Invalid template YAML: \(reason)"
        }
    }
}

public struct TemplateYAMLDocument: Equatable, Sendable {
    public let template: FlintTemplate
    public let targetOrder: [String]
    public let variableOrder: [String]
    public let unsupportedSaveReason: String?

    public init(
        template: FlintTemplate,
        targetOrder: [String],
        variableOrder: [String],
        unsupportedSaveReason: String? = nil
    ) {
        self.template = template
        self.targetOrder = targetOrder
        self.variableOrder = variableOrder
        self.unsupportedSaveReason = unsupportedSaveReason
    }
}

public struct EditableTemplateDraft: Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public var name: String
    public var description: String?
    public var typedTriggers: [String]
    public var spokenTriggers: [String]
    public var targets: [String: String]
    public let targetOrder: [String]
    public let variables: [String: FlintTemplate.Variable]
    public let variableOrder: [String]
    public let unsupportedSaveReason: String?

    public init(document: TemplateYAMLDocument) {
        self.schemaVersion = document.template.schemaVersion
        self.id = document.template.id
        self.name = document.template.name
        self.description = document.template.description
        self.typedTriggers = document.template.triggers.typed
        self.spokenTriggers = document.template.triggers.spoken
        self.targets = document.template.targets
        self.targetOrder = document.targetOrder
        self.variables = document.template.variables
        self.variableOrder = document.variableOrder
        self.unsupportedSaveReason = document.unsupportedSaveReason
    }
}

public enum FlintTemplateYAMLCodec {
    public static func document(from yaml: String) throws -> TemplateYAMLDocument {
        let normalized = yaml.replacingOccurrences(of: "\r\n", with: "\n")
        let template = try TemplateLoader.parse(normalized)
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let unsupportedReason = unsupportedSaveReason(in: lines)
        return TemplateYAMLDocument(
            template: template,
            targetOrder: orderedKeys(in: lines, section: "targets"),
            variableOrder: orderedVariableKeys(in: lines),
            unsupportedSaveReason: unsupportedReason
        )
    }

    public static func serialize(_ draft: EditableTemplateDraft) throws -> String {
        try validate(draft)

        var lines: [String] = []
        lines.append("schema_version: \(draft.schemaVersion)")
        lines.append("id: \(quotedScalar(draft.id))")
        lines.append("name: \(quotedScalar(draft.name))")
        if let description = draft.description, !description.isEmpty {
            lines.append("description: \(quotedScalar(description))")
        }
        lines.append("triggers:")
        lines.append("  typed: \(inlineArray(draft.typedTriggers))")
        lines.append("  spoken: \(inlineArray(draft.spokenTriggers))")
        if !draft.variableOrder.isEmpty {
            lines.append("variables:")
            for key in draft.variableOrder where draft.variables[key] != nil {
                lines.append("  \(key):")
                if let defaultValue = draft.variables[key]?.defaultValue {
                    lines.append("    default: \(quotedScalar(defaultValue))")
                }
            }
        }
        lines.append("targets:")
        let targetKeys = orderedKeys(preferred: draft.targetOrder, available: draft.targets)
        for key in targetKeys {
            lines.append("  \(key): |")
            lines.append(contentsOf: blockLines(for: draft.targets[key] ?? ""))
        }

        let yaml = lines.joined(separator: "\n") + "\n"
        let parsed = try TemplateLoader.parse(yaml)
        _ = try TemplateRenderer().render(parsed, target: "generic")
        return yaml
    }

    public static func template(from draft: EditableTemplateDraft) throws -> FlintTemplate {
        try TemplateLoader.parse(serialize(draft))
    }

    public static func validate(_ draft: EditableTemplateDraft) throws {
        if let unsupportedSaveReason = draft.unsupportedSaveReason {
            throw TemplateYAMLCodecError.unsupported(unsupportedSaveReason)
        }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TemplateYAMLCodecError.invalid("name cannot be blank")
        }
        guard let generic = draft.targets["generic"],
              !generic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TemplateYAMLCodecError.invalid("generic target cannot be blank")
        }
        for trigger in draft.typedTriggers + draft.spokenTriggers {
            if trigger.contains(",") || trigger.contains("\n") {
                throw TemplateYAMLCodecError.invalid("trigger values cannot contain commas or newlines")
            }
        }
    }

    public static func quotedScalar(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func inlineArray(_ values: [String]) -> String {
        "[" + values.map(quotedScalar).joined(separator: ", ") + "]"
    }

    private static func blockLines(for value: String) -> [String] {
        let lines = value.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.isEmpty { return ["    "] }
        return lines.map { "    \($0)" }
    }

    private static func orderedKeys(preferred: [String], available: [String: String]) -> [String] {
        let preferredExisting = preferred.filter { available[$0] != nil }
        let remaining = available.keys.filter { !preferredExisting.contains($0) }.sorted()
        return preferredExisting + remaining
    }

    private static func orderedKeys(in lines: [String], section: String) -> [String] {
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "\(section):" }) else {
            return []
        }
        var keys: [String] = []
        var index = start + 1
        while index < lines.count {
            let line = lines[index]
            if indentation(of: line) == 0, !line.trimmingCharacters(in: .whitespaces).isEmpty { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if indentation(of: line) == 2, let key = sectionKey(from: trimmed) {
                keys.append(key)
            }
            index += 1
        }
        return keys
    }

    private static func orderedVariableKeys(in lines: [String]) -> [String] {
        orderedKeys(in: lines, section: "variables")
    }

    private static func sectionKey(from trimmed: String) -> String? {
        if trimmed.hasSuffix(": |") {
            return String(trimmed.dropLast(3))
        }
        if trimmed.hasSuffix(":") {
            return String(trimmed.dropLast())
        }
        return nil
    }

    private static func unsupportedSaveReason(in lines: [String]) -> String? {
        let knownTopLevel = Set(["schema_version", "id", "name", "description", "triggers", "variables", "targets"])
        var section: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let indent = indentation(of: line)
            if section == "targets", indent > 2 {
                continue
            }
            if trimmed.hasPrefix("#") {
                return "comments are not yet safely round-trippable"
            }
            if indent == 0 {
                guard let key = trimmed.split(separator: ":", maxSplits: 1).first.map(String.init) else { continue }
                guard knownTopLevel.contains(key) else { return "unknown top-level key \(key)" }
                section = key
                continue
            }
            if section == "triggers", indent == 2 {
                if !(trimmed.hasPrefix("typed: [") || trimmed.hasPrefix("spoken: [")) {
                    return "trigger arrays must use inline array syntax"
                }
            }
            if section == "targets", indent == 2, !trimmed.hasSuffix(": |") {
                return "target bodies must use block scalar syntax"
            }
        }
        return nil
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }
}
