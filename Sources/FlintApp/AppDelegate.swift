import AppKit
import FlintCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var paletteController: CommandPaletteWindowController?
    private var hotKeyController: HotKeyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let repository = TemplateRepository.defaultRepository()
        let paletteController = CommandPaletteWindowController(repository: repository)
        self.paletteController = paletteController
        self.hotKeyController = HotKeyController { [weak paletteController] in
            paletteController?.togglePalette()
        }
        setupStatusItem()
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Flint"
        statusItem.button?.toolTip = "Open Flint command palette"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Command Palette", action: #selector(openPalette), keyEquivalent: "f"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Flint", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func openPalette() {
        paletteController?.showPalette()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
