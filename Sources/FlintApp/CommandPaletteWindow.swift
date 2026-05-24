import AppKit
import FlintCore
import SwiftUI

final class CommandPaletteWindowController: NSWindowController {
    private static let minimumWindowSize = NSSize(width: 720, height: 520)

    private let repository: TemplateRepository

    init(repository: TemplateRepository) {
        self.repository = repository
        let viewModel = CommandPaletteViewModel(repository: repository)
        let rootView = CommandPaletteView(viewModel: viewModel)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.minimumWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = Self.minimumWindowSize
        window.title = ""
        window.level = .floating
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.isOpaque = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func togglePalette() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            showPalette()
        }
    }

    func showPalette() {
        if let hostingView = window?.contentView as? NSHostingView<CommandPaletteView> {
            hostingView.rootView.viewModel.reloadFromRepository()
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class CommandPaletteViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var records: [TemplateRecord] = []
    @Published var selectedRecord: TemplateRecord?
    @Published var renderedPrompt = ""
    @Published var statusMessage = "Select a template to preview its expanded prompt."
    @Published private(set) var isEditing = false
    @Published var editDraft: EditableTemplateDraft?
    @Published var validationMessage: String?

    private let repository: TemplateRepository
    private let renderer = TemplateRenderer()
    private let insertionService = PromptInsertionService()

    init(repository: TemplateRepository) {
        self.repository = repository
        reloadFromRepository()
    }

    var filteredRecords: [TemplateRecord] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return records }
        return records.filter {
            $0.template.name.localizedCaseInsensitiveContains(query) ||
            $0.template.id.localizedCaseInsensitiveContains(query) ||
            ($0.template.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var selectedTemplate: FlintTemplate? {
        selectedRecord?.template
    }

    var selectedRecordID: String? {
        selectedRecord?.id
    }

    var typedTriggersText: String {
        editDraft?.typedTriggers.joined(separator: "\n") ?? ""
    }

    var spokenTriggersText: String {
        editDraft?.spokenTriggers.joined(separator: "\n") ?? ""
    }

    var draftTargetKeys: [String] {
        guard let editDraft else { return [] }
        let ordered = editDraft.targetOrder.filter { editDraft.targets[$0] != nil }
        let remaining = editDraft.targets.keys.filter { !ordered.contains($0) }.sorted()
        return ordered + remaining
    }

    func reloadFromRepository() {
        do {
            reload(records: try repository.loadTemplateRecords())
        } catch {
            records = []
            selectedRecord = nil
            renderedPrompt = ""
            statusMessage = "Could not load local templates: \(error)"
        }
    }

    private func reload(records: [TemplateRecord], preserving recordID: String? = nil) {
        let selectedID = recordID ?? selectedRecord?.id
        self.records = records
        if let selectedID, let matching = records.first(where: { $0.id == selectedID }) {
            selectedRecord = matching
        } else if selectedRecord == nil || !records.contains(where: { $0.id == selectedRecord?.id }) {
            selectedRecord = records.first
        }
        renderSelectedTemplate()
    }

    func select(_ record: TemplateRecord) {
        selectedRecord = record
        cancelEditing()
        renderSelectedTemplate()
    }

    func beginEditing() {
        guard let selectedRecord else {
            statusMessage = "Select a template to edit."
            return
        }
        guard selectedRecord.unsupportedSaveReason == nil else {
            let reason = selectedRecord.unsupportedSaveReason ?? "this template cannot be safely saved"
            statusMessage = "Editing disabled: \(reason)."
            validationMessage = statusMessage
            return
        }
        editDraft = EditableTemplateDraft(document: selectedRecord.document)
        isEditing = true
        validationMessage = nil
        statusMessage = "Editing \(selectedRecord.template.name)."
    }

    func cancelEditing() {
        isEditing = false
        editDraft = nil
        validationMessage = nil
    }

    func saveEditing() {
        guard let selectedRecord, let editDraft else {
            statusMessage = "Nothing to save."
            return
        }
        do {
            try repository.save(editDraft, for: selectedRecord)
            let selectedID = selectedRecord.id
            let reloaded = try repository.loadTemplateRecords()
            isEditing = false
            self.editDraft = nil
            validationMessage = nil
            reload(records: reloaded, preserving: selectedID)
            statusMessage = "Saved \(self.selectedRecord?.template.name ?? "template")."
        } catch {
            validationMessage = "\(error)"
            statusMessage = "Could not save template: \(error)"
        }
    }

    func updateDraftName(_ name: String) {
        updateDraft { $0.name = name }
    }

    func updateDraftDescription(_ description: String) {
        updateDraft { $0.description = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description }
    }

    func updateDraftTypedTriggersText(_ text: String) {
        updateDraft { $0.typedTriggers = Self.triggerValues(from: text) }
    }

    func updateDraftSpokenTriggersText(_ text: String) {
        updateDraft { $0.spokenTriggers = Self.triggerValues(from: text) }
    }

    func updateDraftTarget(_ key: String, body: String) {
        updateDraft { $0.targets[key] = body }
    }

    func updatePreviewFromDraft() {
        guard let editDraft else {
            renderSelectedTemplate()
            return
        }
        do {
            let template = try FlintTemplateYAMLCodec.template(from: editDraft)
            renderedPrompt = try renderer.render(template, target: "generic")
            validationMessage = nil
            statusMessage = "Previewing edits for \(template.name)."
        } catch {
            renderedPrompt = ""
            validationMessage = "\(error)"
            statusMessage = "Could not preview edits: \(error)"
        }
    }

    private func updateDraft(_ apply: (inout EditableTemplateDraft) -> Void) {
        guard var draft = editDraft else { return }
        apply(&draft)
        editDraft = draft
        updatePreviewFromDraft()
    }

    private static func triggerValues(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func copyRenderedPrompt() {
        guard !renderedPrompt.isEmpty else {
            statusMessage = "Nothing to copy."
            return
        }
        let result = insertionService.copyToClipboard(renderedPrompt)
        statusMessage = message(for: result)
    }

    func insertRenderedPrompt() {
        guard !renderedPrompt.isEmpty else {
            statusMessage = "Nothing to insert."
            return
        }
        let result = insertionService.insertIntoFocusedElementOrCopy(renderedPrompt)
        statusMessage = message(for: result)
    }

    private func message(for result: PromptInsertionService.InsertionResult) -> String {
        switch result {
        case .copiedToClipboard:
            return "Copied expanded prompt. Paste now in the active app."
        case .directInsertSucceeded:
            return "Inserted expanded prompt into the focused app."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is needed for direct insertion. The prompt was copied instead; paste now."
        case .directInsertFailed(let reason):
            return reason
        }
    }

    func renderSelectedTemplate() {
        guard let selectedTemplate else {
            renderedPrompt = ""
            statusMessage = "No local templates found."
            return
        }
        do {
            renderedPrompt = try renderer.render(selectedTemplate, target: "generic")
            statusMessage = "Previewing \(selectedTemplate.name)."
        } catch {
            renderedPrompt = ""
            statusMessage = "Could not render template: \(error)"
        }
    }
}

struct CommandPaletteView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel
    @State private var didAppear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Flint Command Palette")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FlintGlassTheme.primaryText)
                Text("Type a shortcut, pick a template, and copy it without leaving flow.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(FlintGlassTheme.secondaryText)
            }

            LiquidGlassPanel {
                TextField("Search templates", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .searchFieldChrome()
            }

            HStack(alignment: .top, spacing: 10) {
                LiquidGlassPanel(fillsHeight: true) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.filteredRecords) { record in
                                let isSelected = viewModel.selectedRecordID == record.id
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(record.template.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(isSelected ? FlintGlassTheme.selectedText : FlintGlassTheme.primaryText)
                                        if record.unsupportedSaveReason != nil {
                                            Text("Preview only")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(isSelected ? FlintGlassTheme.selectedMutedText : FlintGlassTheme.secondaryText)
                                        }
                                    }
                                    if let description = record.template.description {
                                        Text(description)
                                            .font(.system(size: 12, weight: .regular))
                                            .tracking(0.15)
                                            .foregroundStyle(isSelected ? FlintGlassTheme.selectedMutedText : FlintGlassTheme.secondaryText)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectionHighlight(for: record))
                                .contentShape(RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous))
                                .onTapGesture {
                                    viewModel.select(record)
                                }
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .background(Color.clear)
                    .animation(.easeInOut(duration: 0.18), value: viewModel.selectedRecordID)
                }
                .frame(minWidth: 240, maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassPanel(fillsHeight: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(viewModel.isEditing ? "Edit template" : "Expanded prompt preview")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(FlintGlassTheme.primaryText)
                                Spacer()
                                paletteActions
                            }

                            if viewModel.isEditing {
                                editForm
                            } else {
                                previewPane
                            }
                        }
                    }

                    LiquidGlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            if let validationMessage = viewModel.validationMessage {
                                Text(validationMessage)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.red)
                                    .textSelection(.enabled)
                            }
                            Text(viewModel.statusMessage)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(FlintGlassTheme.secondaryText)
                        }
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .frame(minWidth: 680, minHeight: 460)
        .background(FlintWindowBackground())
        .tint(FlintGlassTheme.controlTint)
        .environment(\.colorScheme, .light)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) {
                didAppear = true
            }
        }
    }

    @ViewBuilder
    private var paletteActions: some View {
        HStack(spacing: 8) {
            Button { viewModel.copyRenderedPrompt() } label: {
                Image(systemName: "doc.on.doc")
                    .accessibilityLabel("Copy")
            }
            .buttonStyle(FlintIconButtonStyle(kind: .secondary))
            .disabled(viewModel.renderedPrompt.isEmpty)
            .opacity(viewModel.renderedPrompt.isEmpty ? 0.45 : 1)

            if viewModel.isEditing {
                Button { viewModel.cancelEditing() } label: {
                    Image(systemName: "xmark")
                        .accessibilityLabel("Cancel")
                }
                .buttonStyle(FlintIconButtonStyle(kind: .secondary))
                Button { viewModel.saveEditing() } label: {
                    Image(systemName: "checkmark")
                        .accessibilityLabel("Save")
                }
                .buttonStyle(FlintIconButtonStyle(kind: .primary))
            } else {
                Button { viewModel.beginEditing() } label: {
                    Image(systemName: "pencil")
                        .accessibilityLabel("Edit")
                }
                .buttonStyle(FlintIconButtonStyle(kind: .secondary))
                .disabled(viewModel.selectedRecord == nil)
                .opacity(viewModel.selectedRecord == nil ? 0.45 : 1)
            }
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        ScrollView {
            Text(viewModel.renderedPrompt)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(FlintGlassTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var editForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                labeledTextField("Name", text: Binding(
                    get: { viewModel.editDraft?.name ?? "" },
                    set: { viewModel.updateDraftName($0) }
                ))
                labeledTextField("Description", text: Binding(
                    get: { viewModel.editDraft?.description ?? "" },
                    set: { viewModel.updateDraftDescription($0) }
                ))
                labeledTextEditor(
                    "Typed triggers",
                    help: "One trigger per line. Commas and newlines inside a trigger are rejected on save.",
                    minHeight: 64,
                    text: Binding(
                        get: { viewModel.typedTriggersText },
                        set: { viewModel.updateDraftTypedTriggersText($0) }
                    )
                )
                labeledTextEditor(
                    "Spoken triggers",
                    help: "One spoken phrase per line.",
                    minHeight: 64,
                    text: Binding(
                        get: { viewModel.spokenTriggersText },
                        set: { viewModel.updateDraftSpokenTriggersText($0) }
                    )
                )
                ForEach(viewModel.draftTargetKeys, id: \.self) { key in
                    labeledTextEditor(
                        "Target: \(key)",
                        help: key == "generic" ? "Generic target is required and cannot be blank." : nil,
                        minHeight: key == "generic" ? 150 : 120,
                        text: Binding(
                            get: { viewModel.editDraft?.targets[key] ?? "" },
                            set: { viewModel.updateDraftTarget(key, body: $0) }
                        )
                    )
                }
            }
            .padding(.trailing, 4)
        }
    }

    private func labeledTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FlintGlassTheme.primaryText)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(8)
                .background(FlintGlassTheme.searchFill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func labeledTextEditor(
        _ title: String,
        help: String? = nil,
        minHeight: CGFloat,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FlintGlassTheme.primaryText)
            if let help {
                Text(help)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(FlintGlassTheme.secondaryText)
            }
            TextEditor(text: text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(FlintGlassTheme.primaryText)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: minHeight)
                .background(FlintGlassTheme.searchFill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private func selectionHighlight(for record: TemplateRecord) -> some View {
        let isSelected = viewModel.selectedRecordID == record.id
        RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous)
            .fill(isSelected ? FlintGlassTheme.selectionFill : FlintGlassTheme.rowFill)
            .overlay {
                RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? FlintGlassTheme.selectionStroke : Color.clear, lineWidth: 1)
            }
    }
}

private enum FlintGlassTheme {
    static let panelCornerRadius: CGFloat = 12
    static let standardCornerRadius: CGFloat = 999
    static let primary = Color.black
    static let inkDeep = Color(red: 0.035, green: 0.035, blue: 0.035)
    static let canvas = Color.white
    static let surfaceSoft = Color(red: 0.980, green: 0.980, blue: 0.980)
    static let surfaceDark = Color(red: 0.090, green: 0.090, blue: 0.090)
    static let hairline = Color(red: 0.898, green: 0.898, blue: 0.898)
    static let hairlineStrong = Color(red: 0.831, green: 0.831, blue: 0.831)
    static let bodyText = Color(red: 0.451, green: 0.451, blue: 0.451)
    static let muteText = Color(red: 0.639, green: 0.639, blue: 0.639)
    static let focusRing = Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.50)

    static let windowBase = canvas
    static let panelFill = canvas
    static let panelStroke = hairline
    static let panelShadow = Color.clear
    static let primaryText = primary
    static let secondaryText = bodyText
    static let selectedText = primary
    static let selectedMutedText = bodyText
    static let controlTint = primary
    static let searchFill = surfaceSoft
    static let searchStroke = hairline
    static let searchFocusStroke = focusRing
    static let rowFill = surfaceSoft
    static let selectionFill = canvas
    static let selectionStroke = primary.opacity(0.72)
}

private struct FlintWindowBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(FlintGlassTheme.windowBase)
        }
    }
}

private struct LiquidGlassPanel<Content: View>: View {
    var fillsHeight = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous)
                    .fill(FlintGlassTheme.panelFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous)
                            .strokeBorder(FlintGlassTheme.panelStroke, lineWidth: 1)
                    }
                    .shadow(color: FlintGlassTheme.panelShadow, radius: 10, x: 0, y: 4)
            }
    }
}

private struct SearchFieldChrome: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .font(.system(size: 15))
            .foregroundStyle(FlintGlassTheme.primaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background {
                Capsule(style: .continuous)
                    .fill(FlintGlassTheme.searchFill)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isFocused ? FlintGlassTheme.searchFocusStroke : FlintGlassTheme.searchStroke,
                        lineWidth: isFocused ? 2 : 1
                    )
            }
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

private extension View {
    func searchFieldChrome() -> some View {
        modifier(SearchFieldChrome())
    }
}

private struct FlintPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(FlintGlassTheme.canvas)
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background {
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? FlintGlassTheme.inkDeep : FlintGlassTheme.controlTint)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}


private struct FlintIconButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(kind == .primary ? FlintGlassTheme.canvas : FlintGlassTheme.primaryText)
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                Circle()
                    .strokeBorder(kind == .primary ? Color.clear : FlintGlassTheme.hairline, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            return isPressed ? FlintGlassTheme.inkDeep : FlintGlassTheme.controlTint
        case .secondary:
            return isPressed ? FlintGlassTheme.hairlineStrong : FlintGlassTheme.surfaceSoft
        }
    }
}

private struct FlintSecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(FlintGlassTheme.primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background {
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? FlintGlassTheme.hairlineStrong : FlintGlassTheme.surfaceSoft)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(FlintGlassTheme.hairline, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
