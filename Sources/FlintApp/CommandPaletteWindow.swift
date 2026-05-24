import AppKit
import FlintCore
import SwiftUI

final class CommandPaletteWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CommandPaletteWindowController: NSWindowController {
    private static let windowSize = NSSize(width: 760, height: 480)

    private let viewModel: CommandPaletteViewModel
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init(repository: TemplateRepository) {
        let viewModel = CommandPaletteViewModel(repository: repository)
        self.viewModel = viewModel
        let rootView = CommandPaletteView(viewModel: viewModel)
        let window = CommandPaletteWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        super.init(window: window)
        installDismissMonitors()
        installKeyboardMonitor()
    }

    required init?(coder: NSCoder) { nil }

    func togglePalette() {
        if window?.isVisible == true {
            dismissPalette()
        } else {
            showPalette()
        }
    }

    func showPalette() {
        if let hostingView = window?.contentView as? NSHostingView<CommandPaletteView> {
            hostingView.rootView.viewModel.reloadFromRepository()
            hostingView.rootView.viewModel.showCommandList()
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissPalette() {
        window?.orderOut(nil)
    }

    private func installDismissMonitors() {
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            self?.dismissIfClickIsOutsidePalette(event)
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            DispatchQueue.main.async {
                self?.dismissIfClickIsOutsidePalette(event)
            }
        }
    }

    private func installKeyboardMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isVisible == true else { return event }
            if event.modifierFlags.contains(.command), event.keyCode == 45 {
                self.viewModel.showNewTemplatePage()
                return nil
            }
            if event.modifierFlags.contains(.command), event.keyCode == 1 {
                self.viewModel.createDraftTemplate()
                return nil
            }
            guard self.viewModel.page == .commandList else { return event }
            switch event.keyCode {
            case 125:
                self.viewModel.moveSelectionDown()
                return nil
            case 126:
                self.viewModel.moveSelectionUp()
                return nil
            case 36, 76:
                self.viewModel.copySelectedPrompt()
                return nil
            default:
                return event
            }
        }
    }

    private func dismissIfClickIsOutsidePalette(_ event: NSEvent) {
        guard let window, window.isVisible else { return }
        if event.window === window { return }
        if window.frame.contains(NSEvent.mouseLocation) { return }
        dismissPalette()
    }
}

@MainActor
final class CommandPaletteViewModel: ObservableObject {
    enum Page {
        case commandList
        case newTemplate
    }

    @Published var page: Page = .commandList
    @Published var query = ""
    @Published private(set) var records: [TemplateRecord] = []
    @Published var selectedRecord: TemplateRecord?
    @Published var renderedPrompt = ""
    @Published var statusMessage = "Copy"
    @Published var draftName = ""
    @Published var draftTrigger = ""
    @Published var draftPrompt = ""

    private let repository: TemplateRepository
    private let renderer = TemplateRenderer()
    private let insertionService = PromptInsertionService()

    init(repository: TemplateRepository) {
        self.repository = repository
        reloadFromRepository()
    }

    var filteredRecords: [TemplateRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return records }
        return records.filter {
            $0.template.name.localizedCaseInsensitiveContains(normalizedQuery) ||
            $0.template.id.localizedCaseInsensitiveContains(normalizedQuery) ||
            ($0.template.description?.localizedCaseInsensitiveContains(normalizedQuery) ?? false) ||
            $0.template.triggers.typed.contains(where: { $0.localizedCaseInsensitiveContains(normalizedQuery) })
        }
    }

    var selectedRecordID: String? {
        selectedRecord?.id
    }

    var selectedRecordDisplayName: String {
        selectedRecord?.template.name ?? "No template"
    }

    var isShowingNewTemplatePage: Bool {
        page == .newTemplate
    }

    var canCreateDraftTemplate: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectableRecords: [TemplateRecord] {
        filteredRecords.isEmpty ? records : filteredRecords
    }

    func reloadFromRepository() {
        do {
            let loadedRecords = try repository.loadTemplateRecords()
            records = loadedRecords
            if let selectedRecord, loadedRecords.contains(where: { $0.id == selectedRecord.id }) {
                select(selectedRecord)
            } else {
                select(loadedRecords.first)
            }
        } catch {
            records = []
            selectedRecord = nil
            renderedPrompt = ""
            statusMessage = "Could not load templates"
        }
    }

    func showCommandList() {
        page = .commandList
        statusMessage = selectedRecord.map { "Copy \($0.template.name)" } ?? "Copy"
    }

    func showNewTemplatePage() {
        page = .newTemplate
        statusMessage = "New template"
    }

    func createDraftTemplate() {
        guard page == .newTemplate else { return }
        guard canCreateDraftTemplate else {
            statusMessage = "Name and prompt are required"
            return
        }
        do {
            let created = try repository.createTemplate(
                name: draftName,
                typedTrigger: draftTrigger,
                prompt: draftPrompt
            )
            draftName = ""
            draftTrigger = ""
            draftPrompt = ""
            NotificationCenter.default.post(name: TypedTriggerExpander.templatesDidChangeNotification, object: nil)
            reloadFromRepository()
            select(records.first { $0.id == created.id } ?? created)
            showCommandList()
            statusMessage = "Created \(selectedRecordDisplayName)"
        } catch {
            statusMessage = "Could not create template: \(error)"
        }
    }

    func select(_ record: TemplateRecord?) {
        selectedRecord = record
        guard let template = record?.template else {
            renderedPrompt = ""
            statusMessage = "No local templates"
            return
        }
        do {
            renderedPrompt = try renderer.render(template, target: "generic")
            statusMessage = "Copy \(template.name)"
        } catch {
            renderedPrompt = ""
            statusMessage = "Could not render template"
        }
    }

    func copySelectedPrompt() {
        guard page == .commandList else {
            statusMessage = "New template"
            return
        }
        guard !renderedPrompt.isEmpty else {
            statusMessage = "Nothing to copy"
            return
        }
        insertionService.copyToClipboard(renderedPrompt)
        statusMessage = "Copied \(selectedRecordDisplayName)"
    }

    func moveSelectionDown() {
        guard page == .commandList else { return }
        moveSelection(by: 1)
    }

    func moveSelectionUp() {
        guard page == .commandList else { return }
        moveSelection(by: -1)
    }

    private func moveSelection(by offset: Int) {
        let candidates = selectableRecords
        guard !candidates.isEmpty else {
            select(nil)
            return
        }

        let currentIndex = selectedRecord.flatMap { selected in
            candidates.firstIndex { $0.id == selected.id }
        } ?? (offset > 0 ? -1 : candidates.count)
        let nextIndex = min(max(currentIndex + offset, 0), candidates.count - 1)
        select(candidates[nextIndex])
    }
}

struct CommandPaletteView: View {
    enum FocusTarget {
        case search
        case draftName
        case draftTrigger
        case draftPrompt
    }

    @ObservedObject var viewModel: CommandPaletteViewModel
    @FocusState private var focusedField: FocusTarget?
    @State private var didAppear = false

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            if viewModel.isShowingNewTemplatePage {
                newTemplatePage
                Spacer(minLength: 0)
            } else {
                commandList
                Spacer(minLength: 0)
                Divider()
                actionBar
            }
        }
        .frame(width: 760, height: 480)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FlintTheme.windowBackground)
                .overlay(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.84).opacity(0.72),
                            Color.clear
                        ],
                        startPoint: .topTrailing,
                        endPoint: .center
                    )
                    .frame(width: 210, height: 150)
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(FlintTheme.hairline, lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .light)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 8)
        .onAppear {
            focusedField = viewModel.isShowingNewTemplatePage ? .draftName : .search
            withAnimation(.easeOut(duration: 0.16)) {
                didAppear = true
            }
        }
        .onChange(of: viewModel.page) { _, page in
            DispatchQueue.main.async {
                focusedField = page == .newTemplate ? .draftName : .search
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            if viewModel.isShowingNewTemplatePage {
                Button {
                    viewModel.showCommandList()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(FlintTheme.secondaryText)

                Text("New Template")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FlintTheme.primaryText)
                Spacer()
                Button {
                    viewModel.createDraftTemplate()
                } label: {
                    HStack(spacing: 7) {
                        Text("Create")
                            .font(.system(size: 13, weight: .semibold))
                        KeyBadge("⌘")
                        KeyBadge("S")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    viewModel.canCreateDraftTemplate ? FlintTheme.primaryText : FlintTheme.mutedText
                )
                .disabled(!viewModel.canCreateDraftTemplate)
            } else {
                TextField("Search prompts and commands...", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(FlintTheme.primaryText)
                    .focused($focusedField, equals: .search)
                    .onChange(of: viewModel.query) { _, _ in
                        viewModel.select(viewModel.filteredRecords.first ?? viewModel.records.first)
                    }

                Button {
                    viewModel.showNewTemplatePage()
                } label: {
                    HStack(spacing: 7) {
                        Text("New Template")
                            .font(.system(size: 13, weight: .semibold))
                        KeyBadge("⌘")
                        KeyBadge("N")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(FlintTheme.secondaryText)
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .frame(height: 64)
    }

    private var newTemplatePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                templateDraftField(
                    title: "Name",
                    placeholder: "Untitled Template",
                    text: $viewModel.draftName,
                    focusTarget: .draftName
                )
                templateDraftField(
                    title: "Trigger",
                    placeholder: ":shortcut",
                    text: $viewModel.draftTrigger,
                    focusTarget: .draftTrigger
                )
                templateDraftEditor(
                    title: "Prompt",
                    placeholder: "Write the reusable prompt body...",
                    text: $viewModel.draftPrompt
                )
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
    }

    private func templateDraftField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        focusTarget: FocusTarget
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FlintTheme.secondaryText)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(FlintTheme.primaryText)
                .focused($focusedField, equals: focusTarget)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(FlintTheme.fieldFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(FlintTheme.hairline, lineWidth: 1)
                        }
                }
        }
    }

    private func templateDraftEditor(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FlintTheme.secondaryText)
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundStyle(FlintTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .draftPrompt)
                    .padding(8)

                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(FlintTheme.mutedText)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(FlintTheme.fieldFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(FlintTheme.hairline, lineWidth: 1)
                    }
            }
        }
    }

    private var commandList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                sectionTitle("Templates")

                if viewModel.filteredRecords.isEmpty {
                    emptyRow
                } else {
                    ForEach(viewModel.filteredRecords) { record in
                        commandRow(record)
                    }
                }

            }
            .padding(.top, 12)
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(FlintTheme.secondaryText)
            .padding(.horizontal, 15)
            .padding(.vertical, 6)
    }

    private var emptyRow: some View {
        HStack(spacing: 12) {
            commandIcon(systemName: "magnifyingglass", accent: .gray)
            Text("No matching prompts")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FlintTheme.primaryText)
            Spacer()
        }
        .padding(.horizontal, 15)
        .frame(height: 44)
    }

    private func commandRow(_ record: TemplateRecord) -> some View {
        let isSelected = viewModel.selectedRecordID == record.id
        return Button {
            viewModel.select(record)
        } label: {
            HStack(spacing: 12) {
                commandIcon(systemName: iconName(for: record), accent: accentColor(for: record))
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(record.template.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FlintTheme.primaryText)
                    if let trigger = record.template.triggers.typed.first {
                        Text(trigger)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(FlintTheme.secondaryText)
                    }
                }
                Spacer()
                Text("Prompt")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FlintTheme.secondaryText)
            }
            .padding(.horizontal, 15)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? FlintTheme.selectedRow : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }

    private func commandIcon(systemName: String, accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 22, height: 22)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FlintTheme.mutedText)

            Spacer()

            if viewModel.isShowingNewTemplatePage {
                Button("Back") {
                    viewModel.showCommandList()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FlintTheme.primaryText)
            } else {
                Button("Copy") {
                    viewModel.copySelectedPrompt()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FlintTheme.primaryText)

                KeyBadge("↩")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
    }

    private func iconName(for record: TemplateRecord) -> String {
        let id = record.template.id.lowercased()
        if id.contains("debug") { return "stethoscope" }
        if id.contains("review") { return "checklist" }
        if id.contains("codex") { return "terminal" }
        if id.contains("plan") { return "list.bullet.rectangle" }
        if id.contains("critic") { return "exclamationmark.bubble" }
        return "doc.text"
    }

    private func accentColor(for record: TemplateRecord) -> Color {
        let id = record.template.id.lowercased()
        if id.contains("debug") { return Color(red: 0.12, green: 0.47, blue: 0.96) }
        if id.contains("review") { return Color(red: 0.11, green: 0.58, blue: 0.35) }
        if id.contains("codex") { return Color(red: 0.85, green: 0.20, blue: 0.25) }
        if id.contains("plan") { return Color(red: 0.56, green: 0.36, blue: 0.93) }
        if id.contains("critic") { return Color(red: 0.95, green: 0.45, blue: 0.12) }
        return .black
    }
}

private struct KeyBadge: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FlintTheme.secondaryText)
            .frame(minWidth: 22, minHeight: 21)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(FlintTheme.keyFill)
            }
    }
}

private enum FlintTheme {
    static let windowBackground = Color(red: 0.948, green: 0.948, blue: 0.965)
    static let selectedRow = Color(red: 0.830, green: 0.830, blue: 0.850)
    static let keyFill = Color(red: 0.840, green: 0.840, blue: 0.865)
    static let fieldFill = Color(red: 0.970, green: 0.970, blue: 0.982)
    static let badgeFill = Color(red: 0.930, green: 0.895, blue: 0.905)
    static let badgeStroke = Color(red: 0.620, green: 0.520, blue: 0.540).opacity(0.42)
    static let hairline = Color(red: 0.800, green: 0.800, blue: 0.825)
    static let primaryText = Color(red: 0.070, green: 0.070, blue: 0.080)
    static let secondaryText = Color(red: 0.390, green: 0.390, blue: 0.410)
    static let mutedText = Color(red: 0.560, green: 0.560, blue: 0.590)
}
