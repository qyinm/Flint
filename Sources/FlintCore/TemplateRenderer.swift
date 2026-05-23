import Foundation

public struct TemplateRenderer: Sendable {
    public init() {}

    public func render(
        _ template: FlintTemplate,
        target requestedTarget: String = "generic",
        variables suppliedVariables: [String: String] = [:]
    ) throws -> String {
        let target = template.targets[requestedTarget] != nil ? requestedTarget : "generic"
        guard var output = template.targets[target] else {
            throw TemplateRendererError.unknownTarget(requestedTarget)
        }

        let placeholders = Self.placeholders(in: output)
        for placeholder in placeholders {
            let value: String
            if let supplied = suppliedVariables[placeholder] {
                value = supplied
            } else if let defaultValue = template.variables[placeholder]?.defaultValue {
                value = defaultValue
            } else {
                throw TemplateRendererError.missingVariable(placeholder)
            }
            output = Self.replacePlaceholder(named: placeholder, in: output, with: value)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func placeholders(in text: String) -> Set<String> {
        let pattern = #"\{\{\s*([A-Za-z0-9_-]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        })
    }

    private static func replacePlaceholder(named name: String, in text: String, with value: String) -> String {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\{\{\s*"# + escapedName + #"\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: value)
    }
}
