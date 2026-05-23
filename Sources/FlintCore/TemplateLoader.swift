import Foundation

public enum TemplateLoader {
    public static func loadTemplate(from url: URL) throws -> FlintTemplate {
        try parse(String(contentsOf: url, encoding: .utf8))
    }

    public static func loadTemplates(from directory: URL) throws -> [FlintTemplate] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try urls.map(loadTemplate(from:))
    }

    public static func parse(_ yaml: String) throws -> FlintTemplate {
        let lines = yaml.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var schemaVersion: Int?
        var id: String?
        var name: String?
        var description: String?
        var variables: [String: FlintTemplate.Variable] = [:]
        var targets: [String: String] = [:]

        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            if let value = topLevelValue(trimmed, key: "schema_version") {
                schemaVersion = Int(unquote(value))
                index += 1
            } else if let value = topLevelValue(trimmed, key: "id") {
                id = unquote(value)
                index += 1
            } else if let value = topLevelValue(trimmed, key: "name") {
                name = unquote(value)
                index += 1
            } else if let value = topLevelValue(trimmed, key: "description") {
                description = unquote(value)
                index += 1
            } else if trimmed == "variables:" {
                index += 1
                while index < lines.count {
                    let variableLine = lines[index]
                    let variableTrimmed = variableLine.trimmingCharacters(in: .whitespaces)
                    if indentation(of: variableLine) == 0 { break }
                    if indentation(of: variableLine) == 2, variableTrimmed.hasSuffix(":") {
                        let variableName = String(variableTrimmed.dropLast())
                        var defaultValue: String?
                        index += 1
                        while index < lines.count, indentation(of: lines[index]) >= 4 {
                            let fieldTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                            if let value = topLevelValue(fieldTrimmed, key: "default") {
                                defaultValue = unquote(value)
                            }
                            index += 1
                        }
                        variables[variableName] = FlintTemplate.Variable(defaultValue: defaultValue)
                    } else {
                        index += 1
                    }
                }
            } else if trimmed == "targets:" {
                index += 1
                while index < lines.count {
                    let targetLine = lines[index]
                    let targetTrimmed = targetLine.trimmingCharacters(in: .whitespaces)
                    if indentation(of: targetLine) == 0 { break }
                    if indentation(of: targetLine) == 2, targetTrimmed.hasSuffix(": |") {
                        let targetName = String(targetTrimmed.dropLast(3))
                        index += 1
                        var block: [String] = []
                        while index < lines.count, indentation(of: lines[index]) >= 4 {
                            block.append(stripBlockIndent(lines[index], spaces: 4))
                            index += 1
                        }
                        targets[targetName] = block.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        index += 1
                    }
                }
            } else {
                index += 1
            }
        }

        guard let schemaVersion else { throw TemplateRendererError.invalidTemplate("missing schema_version") }
        guard let id, !id.isEmpty else { throw TemplateRendererError.invalidTemplate("missing id") }
        guard let name, !name.isEmpty else { throw TemplateRendererError.invalidTemplate("missing name") }
        guard !targets.isEmpty else { throw TemplateRendererError.invalidTemplate("missing targets") }
        guard targets["generic"] != nil else { throw TemplateRendererError.invalidTemplate("missing generic target") }

        return FlintTemplate(
            schemaVersion: schemaVersion,
            id: id,
            name: name,
            description: description,
            variables: variables,
            targets: targets
        )
    }

    private static func topLevelValue(_ line: String, key: String) -> String? {
        let prefix = "\(key):"
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func stripBlockIndent(_ line: String, spaces: Int) -> String {
        guard line.count >= spaces else { return "" }
        let index = line.index(line.startIndex, offsetBy: spaces)
        return String(line[index...])
    }

    private static func unquote(_ value: String) -> String {
        var value = value.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\"") && value.hasSuffix("\""), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }
}
