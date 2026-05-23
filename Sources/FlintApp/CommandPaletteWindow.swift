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
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
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
    @State private var didAppear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flint Command Palette")
                        .font(.title2.bold())
                    Text("Type a shortcut, pick a template, and expand it without leaving flow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("AI native")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlintGlassTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(FlintGlassTheme.accent.opacity(0.13)))
                    .overlay {
                        Capsule().strokeBorder(FlintGlassTheme.accent.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: FlintGlassTheme.accent.opacity(0.35), radius: 12, x: 0, y: 0)
            }

            GlassCard {
                TextField("Search templates", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
            }

            HSplitView {
                GlassCard {
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
                    GlassCard {
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

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("Copy") { viewModel.copyRenderedPrompt() }
                                    .buttonStyle(GlassButtonStyle())
                                Button("Insert or Copy") { viewModel.insertRenderedPrompt() }
                                    .buttonStyle(GlassButtonStyle(isPrimary: true))
                            }
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
        .background(FlintGlassShell())
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
                .fill(FlintGlassTheme.accent.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(FlintGlassTheme.accent.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

private enum FlintGlassTheme {
    static let shellCornerRadius: CGFloat = 28
    static let cardCornerRadius: CGFloat = 18
    static let shellStroke = Color.white.opacity(0.24)
    static let cardStroke = Color.white.opacity(0.18)
    static let shellShadow = Color.black.opacity(0.28)
    static let cardShadow = Color.black.opacity(0.14)
    static let accent = Color(red: 0.50, green: 0.78, blue: 1.00)
    static let secondaryAccent = Color(red: 0.72, green: 0.48, blue: 1.00)
}

private struct FlintGlassShell: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FlintGlassTheme.shellCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    FlintGlassTheme.accent.opacity(0.28),
                    FlintGlassTheme.secondaryAccent.opacity(0.16),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: FlintGlassTheme.shellCornerRadius, style: .continuous)
                .strokeBorder(FlintGlassTheme.shellStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: FlintGlassTheme.shellCornerRadius, style: .continuous))
        .shadow(color: FlintGlassTheme.shellShadow, radius: 30, x: 0, y: 18)
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(FlintGlassTheme.accent.opacity(0.20))
                .frame(width: 180, height: 180)
                .blur(radius: 54)
                .offset(x: -44, y: -54)
                .allowsHitTesting(false)
        }
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: FlintGlassTheme.cardCornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: FlintGlassTheme.cardCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FlintGlassTheme.cardCornerRadius, style: .continuous)
                            .strokeBorder(FlintGlassTheme.cardStroke, lineWidth: 1)
                    }
                    .shadow(color: FlintGlassTheme.cardShadow, radius: 14, x: 0, y: 8)
            }
    }
}

private struct GlassButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isPrimary ? Color.white : .primary)
            .background {
                Capsule()
                    .fill(isPrimary ? FlintGlassTheme.accent.opacity(0.42) : Color.white.opacity(0.10))
                    .overlay {
                        Capsule().strokeBorder(
                            isPrimary ? FlintGlassTheme.accent.opacity(0.55) : Color.white.opacity(0.20),
                            lineWidth: 1
                        )
                    }
            }
            .shadow(
                color: isPrimary ? FlintGlassTheme.accent.opacity(configuration.isPressed ? 0.10 : 0.26) : .clear,
                radius: configuration.isPressed ? 4 : 10,
                x: 0,
                y: 0
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
