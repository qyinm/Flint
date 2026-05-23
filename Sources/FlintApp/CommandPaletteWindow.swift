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
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flint"
        window.level = .floating
        window.backgroundColor = .windowBackgroundColor
        window.titlebarAppearsTransparent = false
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
                    .font(.title2.bold())
                Text("Type a shortcut, pick a template, and copy it without leaving flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LiquidGlassPanel {
                TextField("Search templates", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
            }

            HSplitView {
                LiquidGlassPanel(fillsHeight: true) {
                    List(viewModel.filteredTemplates, id: \.id, selection: Binding(
                        get: { viewModel.selectedTemplate?.id },
                        set: { selectedID in
                            if let template = viewModel.filteredTemplates.first(where: { $0.id == selectedID }) {
                                viewModel.select(template)
                            }
                        }
                    )) { template in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(template.name).font(.headline)
                            if let description = template.description {
                                Text(description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(selectionHighlight(for: template))
                        .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .animation(.easeInOut(duration: 0.18), value: viewModel.selectedTemplate?.id)
                }
                .frame(minWidth: 240)

                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassPanel(fillsHeight: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expanded prompt preview").font(.headline)
                            ScrollView {
                                Text(viewModel.renderedPrompt)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    LiquidGlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Copy") { viewModel.copyRenderedPrompt() }
                                .buttonStyle(.borderedProminent)
                                .tint(FlintGlassTheme.controlTint)
                            Text(viewModel.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(16)
        .frame(minWidth: 680, minHeight: 460)
        .background(FlintWindowBackground())
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) {
                didAppear = true
            }
        }
    }

    @ViewBuilder
    private func selectionHighlight(for template: FlintTemplate) -> some View {
        if viewModel.selectedTemplate?.id == template.id {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FlintGlassTheme.selectionFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(FlintGlassTheme.selectionStroke, lineWidth: 1)
                }
        }
    }
}

private enum FlintGlassTheme {
    static let panelCornerRadius: CGFloat = 18
    static let panelStroke = Color.primary.opacity(0.10)
    static let panelShadow = Color.black.opacity(0.10)
    static let controlTint = Color.primary.opacity(0.86)
    static let selectionFill = Color.primary.opacity(0.08)
    static let selectionStroke = Color.primary.opacity(0.16)
}

private struct FlintWindowBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.primary.opacity(0.035),
                    Color(nsColor: .windowBackgroundColor).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
    }
}

private struct LiquidGlassPanel<Content: View>: View {
    var fillsHeight = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous)
                            .strokeBorder(FlintGlassTheme.panelStroke, lineWidth: 1)
                    }
                    .shadow(color: FlintGlassTheme.panelShadow, radius: 10, x: 0, y: 4)
            }
    }
}
