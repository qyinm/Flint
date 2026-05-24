import Testing
@testable import FlintCore

@Suite("Template YAML codec")
struct TemplateYAMLCodecTests {
    @Test("serializes edited fields while preserving variable and target order")
    func serializesEditedFieldsWithOrder() throws {
        let document = try FlintTemplateYAMLCodec.document(from: Self.sampleYAML)
        var draft = EditableTemplateDraft(document: document)
        draft.name = #"Edited: "Name" \ Test"#
        draft.description = "Hash # and colon: preserved"
        draft.typedTriggers = [":edited"]
        draft.targets["generic"] = "Updated generic\n\nBody"

        let yaml = try FlintTemplateYAMLCodec.serialize(draft)
        let reparsed = try TemplateLoader.parse(yaml)

        #expect(reparsed.name == #"Edited: "Name" \ Test"#)
        #expect(reparsed.description == "Hash # and colon: preserved")
        #expect(reparsed.triggers.typed == [":edited"])
        #expect(reparsed.variables["focus"]?.defaultValue == "correctness")
        #expect(Array(yaml.split(separator: "\n")).contains("  generic: |"))
        #expect(yaml.range(of: "  generic: |")!.lowerBound < yaml.range(of: "  codex: |")!.lowerBound)
        #expect(reparsed.targets["generic"] == "Updated generic\n\nBody")
    }

    @Test("reports unsupported comments without blocking parse")
    func reportsUnsupportedComments() throws {
        let document = try FlintTemplateYAMLCodec.document(from: """
        # user note
        schema_version: 1
        id: noted
        name: Noted
        targets:
          generic: |
            Hello
        """)

        #expect(document.template.name == "Noted")
        #expect(document.unsupportedSaveReason == "comments are not yet safely round-trippable")
        #expect(throws: TemplateYAMLCodecError.unsupported("comments are not yet safely round-trippable")) {
            _ = try FlintTemplateYAMLCodec.serialize(EditableTemplateDraft(document: document))
        }
    }


    @Test("allows markdown headings inside target body")
    func allowsMarkdownHeadingsInsideTargetBody() throws {
        let document = try FlintTemplateYAMLCodec.document(from: """
        schema_version: 1
        id: markdown
        name: Markdown
        targets:
          generic: |
            # Heading
            Body
        """)

        #expect(document.unsupportedSaveReason == nil)
        #expect(document.template.targets["generic"] == "# Heading\nBody")
    }

    @Test("rejects trigger values with commas or newlines")
    func rejectsUnsafeTriggerValues() throws {
        let document = try FlintTemplateYAMLCodec.document(from: Self.sampleYAML)
        var draft = EditableTemplateDraft(document: document)
        draft.typedTriggers = [":bad,trigger"]

        #expect(throws: TemplateYAMLCodecError.invalid("trigger values cannot contain commas or newlines")) {
            _ = try FlintTemplateYAMLCodec.serialize(draft)
        }
    }

    @Test("unescapes double quoted scalar values")
    func unescapesDoubleQuotedScalars() throws {
        let template = try TemplateLoader.parse("""
        schema_version: 1
        id: quoted
        name: "Quote: \\"hello\\" \\\\ path"
        description: "Hash # colon: slash \\\\"
        targets:
          generic: |
            Hello
        """)

        #expect(template.name == #"Quote: "hello" \ path"#)
        #expect(template.description == #"Hash # colon: slash \"#)
    }

    private static let sampleYAML = """
    schema_version: 1
    id: sample
    name: Sample
    description: Sample description
    triggers:
      typed: [":sample"]
      spoken: ["sample prompt"]
    variables:
      focus:
        default: "correctness"
    targets:
      generic: |
        Generic {{focus}}
      codex: |
        Codex {{focus}}
    """
}
