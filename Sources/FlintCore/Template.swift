import Foundation

public struct FlintTemplate: Equatable, Sendable {
    public struct Triggers: Equatable, Sendable {
        public let typed: [String]
        public let spoken: [String]

        public init(typed: [String] = [], spoken: [String] = []) {
            self.typed = typed
            self.spoken = spoken
        }
    }

    public struct Variable: Equatable, Sendable {
        public let defaultValue: String?

        public init(defaultValue: String?) {
            self.defaultValue = defaultValue
        }
    }

    public let schemaVersion: Int
    public let id: String
    public let name: String
    public let description: String?
    public let triggers: Triggers
    public let variables: [String: Variable]
    public let targets: [String: String]

    public init(
        schemaVersion: Int,
        id: String,
        name: String,
        description: String? = nil,
        triggers: Triggers = Triggers(),
        variables: [String: Variable] = [:],
        targets: [String: String]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.description = description
        self.triggers = triggers
        self.variables = variables
        self.targets = targets
    }
}

public enum TemplateRendererError: Error, Equatable, CustomStringConvertible {
    case invalidTemplate(String)
    case unknownTarget(String)
    case missingVariable(String)

    public var description: String {
        switch self {
        case .invalidTemplate(let reason): "Invalid template: \(reason)"
        case .unknownTarget(let target): "Unknown target: \(target)"
        case .missingVariable(let name): "Missing variable: \(name)"
        }
    }
}
