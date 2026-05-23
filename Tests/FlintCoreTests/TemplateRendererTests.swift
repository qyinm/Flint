import Foundation
import Testing
@testable import FlintCore

@Suite("Template renderer")
struct TemplateRendererTests {
    @Test("renders selected template with default variables")
    func rendersWithDefaults() throws {
        let template = try TemplateLoader.parse(Self.sampleTemplate)
        let output = try TemplateRenderer().render(template)
        #expect(output.contains("Focus on: correctness, tests."))
    }

    @Test("renders supplied variables over defaults")
    func rendersSuppliedVariables() throws {
        let template = try TemplateLoader.parse(Self.sampleTemplate)
        let output = try TemplateRenderer().render(template, variables: ["focus": "security"])
        #expect(output.contains("Focus on: security."))
    }


    @Test("renders placeholders with surrounding spaces")
    func rendersWhitespaceWrappedPlaceholders() throws {
        let template = try TemplateLoader.parse("""
        schema_version: 1
        id: whitespace
        name: Whitespace
        variables:
          focus:
            default: "edge cases"
        targets:
          generic: |
            Focus on {{ focus }}.
        """)
        let output = try TemplateRenderer().render(template)
        #expect(output == "Focus on edge cases.")
    }

    @Test("selects target-specific output")
    func rendersTargetSpecificOutput() throws {
        let template = try TemplateLoader.parse(Self.sampleTemplate)
        let output = try TemplateRenderer().render(template, target: "codex")
        #expect(output.contains("Codex-specific review"))
    }

    @Test("reports missing required variables")
    func reportsMissingVariable() throws {
        let template = try TemplateLoader.parse(Self.requiredVariableTemplate)
        #expect(throws: TemplateRendererError.missingVariable("focus")) {
            _ = try TemplateRenderer().render(template)
        }
    }

    @Test("rejects invalid template shape")
    func rejectsInvalidTemplate() throws {
        #expect(throws: TemplateRendererError.invalidTemplate("missing id")) {
            _ = try TemplateLoader.parse("""
            schema_version: 1
            name: Missing ID
            targets:
              generic: |
                Hello
            """)
        }
    }

    @Test("loads repository templates")
    func loadsRepositoryTemplates() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let templatesURL = root.appending(path: "templates")
        let templates = try TemplateLoader.loadTemplates(from: templatesURL)
        #expect(templates.count == 5)
        #expect(templates.allSatisfy { $0.targets["generic"] != nil })
        #expect(templates.flatMap(\.triggers.typed).contains(":debug"))
    }

    @Test("parses typed and spoken triggers")
    func parsesTriggers() throws {
        let template = try TemplateLoader.parse(Self.sampleTemplate)
        #expect(template.triggers.typed == [":review"])
        #expect(template.triggers.spoken == ["review prompt"])
    }

    private static let sampleTemplate = """
    schema_version: 1
    id: review
    name: Review
    triggers:
      typed: [":review"]
      spoken: ["review prompt"]
    variables:
      focus:
        default: "correctness, tests"
    targets:
      generic: |
        Focus on: {{focus}}.
      codex: |
        Codex-specific review: {{focus}}.
    """

    private static let requiredVariableTemplate = """
    schema_version: 1
    id: required
    name: Required
    targets:
      generic: |
        Focus on: {{focus}}.
    """
}
