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
                            ForEach(viewModel.filteredTemplates, id: \.id) { template in
                                let isSelected = viewModel.selectedTemplate?.id == template.id
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isSelected ? FlintGlassTheme.selectedText : FlintGlassTheme.primaryText)
                                    if let description = template.description {
                                        Text(description)
                                            .font(.system(size: 12, weight: .regular))
                                            .tracking(0.15)
                                            .foregroundStyle(isSelected ? FlintGlassTheme.selectedMutedText : FlintGlassTheme.secondaryText)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectionHighlight(for: template))
                                .contentShape(RoundedRectangle(cornerRadius: FlintGlassTheme.panelCornerRadius, style: .continuous))
                                .onTapGesture {
                                    viewModel.select(template)
                                }
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .background(Color.clear)
                    .animation(.easeInOut(duration: 0.18), value: viewModel.selectedTemplate?.id)
                }
                .frame(minWidth: 240, maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassPanel(fillsHeight: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expanded prompt preview")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FlintGlassTheme.primaryText)
                            ScrollView {
                                Text(viewModel.renderedPrompt)
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundStyle(FlintGlassTheme.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    LiquidGlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Copy") { viewModel.copyRenderedPrompt() }
                                .buttonStyle(FlintPillButtonStyle())
                            Text(viewModel.statusMessage)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(FlintGlassTheme.secondaryText)
                        }
                    }
                }
                .frame(minWidth: 240, maxWidth: .infinity)
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
    private func selectionHighlight(for template: FlintTemplate) -> some View {
        let isSelected = viewModel.selectedTemplate?.id == template.id
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
