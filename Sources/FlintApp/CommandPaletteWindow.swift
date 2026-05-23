import AppKit
import FlintCore
import SwiftUI

final class CommandPaletteWindowController: NSWindowController {
    private let repository: TemplateRepository

    init(repository: TemplateRepository) {
        self.repository = repository
        let viewModel = CommandPaletteViewModel(repository: repository)
        let rootView = CommandPaletteView(viewModel: viewModel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Flint"
        window.level = .floating
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
    @Published private(set) var templates: [FlintTemplate] = []
    @Published var selectedTemplate: FlintTemplate?
    @Published var renderedPrompt = ""
    @Published var statusMessage = "Select a template to preview its expanded prompt."

    private let repository: TemplateRepository
    private let renderer = TemplateRenderer()
    private let insertionService = PromptInsertionService()

    init(repository: TemplateRepository) {
        self.repository = repository
        reloadFromRepository()
    }

    var filteredTemplates: [FlintTemplate] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return templates }
        return templates.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.id.localizedCaseInsensitiveContains(query) ||
            ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func reloadFromRepository() {
        do {
            reload(templates: try repository.loadTemplates())
        } catch {
            templates = []
            selectedTemplate = nil
            renderedPrompt = ""
            statusMessage = "Could not load local templates: \(error)"
        }
    }

    private func reload(templates: [FlintTemplate]) {
        self.templates = templates
        if selectedTemplate == nil || !templates.contains(where: { $0.id == selectedTemplate?.id }) {
            selectedTemplate = templates.first
        }
        renderSelectedTemplate()
    }

    func select(_ template: FlintTemplate) {
        selectedTemplate = template
        renderSelectedTemplate()
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
            statusMessage = "Previewing \\(selectedTemplate.name)."
        } catch {
            renderedPrompt = ""
            statusMessage = "Could not render template: \\(error)"
        }
    }
}

struct CommandPaletteView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flint Command Palette")
                .font(.title2.bold())
            TextField("Search templates", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)

            HSplitView {
                List(viewModel.filteredTemplates, id: \.id, selection: Binding(
                    get: { viewModel.selectedTemplate?.id },
                    set: { selectedID in
                        if let template = viewModel.filteredTemplates.first(where: { $0.id == selectedID }) {
                            viewModel.select(template)
                        }
                    }
                )) { template in
                    VStack(alignment: .leading) {
                        Text(template.name).font(.headline)
                        if let description = template.description {
                            Text(description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minWidth: 240)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Expanded prompt preview").font(.headline)
                    ScrollView {
                        Text(viewModel.renderedPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    HStack {
                        Button("Copy") { viewModel.copyRenderedPrompt() }
                        Button("Insert or Copy") { viewModel.insertRenderedPrompt() }
                    }
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 8)
            }
        }
        .padding(16)
        .frame(minWidth: 680, minHeight: 460)
    }
}
