import AppKit
import FlintCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var paletteController: CommandPaletteWindowController?
    private var hotKeyController: HotKeyController?
    private var typedTriggerExpander: TypedTriggerExpander?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let repository = TemplateRepository.defaultRepository()
        let paletteController = CommandPaletteWindowController(repository: repository)
        self.paletteController = paletteController
        self.hotKeyController = HotKeyController { [weak paletteController] in
            paletteController?.togglePalette()
        }
        startTypedTriggerExpander(repository: repository)
        setupStatusItem()
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let icon = makeMenuBarIcon() {
                button.image = icon
                button.imagePosition = .imageOnly
            } else {
                button.title = "Flint"
            }
            button.toolTip = "Open Flint quick palette"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Quick Palette", action: #selector(openPalette), keyEquivalent: "f"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Flint", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func makeMenuBarIcon() -> NSImage? {
        guard
            let iconURL = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
            let image = NSImage(contentsOf: iconURL)
        else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    private func startTypedTriggerExpander(repository: TemplateRepository) {
        let expander = TypedTriggerExpander(repository: repository)
        do {
            try expander.start()
            typedTriggerExpander = expander
        } catch {
            NSLog("Flint typed trigger expansion disabled: \(error)")
        }
    }

    @objc private func openPalette() {
        paletteController?.showPalette()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
