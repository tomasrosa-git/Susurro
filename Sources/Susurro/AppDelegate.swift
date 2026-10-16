import AppKit
import ApplicationServices
import SusurroCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hotkeyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pipelineItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let messageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "⚠︎ Falta permiso de Accesibilidad…",
        action: #selector(openAccessibilitySettings),
        keyEquivalent: ""
    )

    private var config = Config.defaults
    private var monitor = HotkeyMonitor(hotkey: .fn)
    private var controller = DictationController(pipeline: DictationPipeline(config: .defaults, secrets: [:]))
    private var permissionTimer: Timer?
    private let pill = PillPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        monitor.onPress = { [unowned self] in controller.hotkeyPressed() }
        monitor.onRelease = { [unowned self] in controller.hotkeyReleased() }
        monitor.onOtherKey = { [unowned self] in controller.otherKeyPressed() }
        monitor.onEscape = { [unowned self] in controller.escapePressed() }
        pill.levelProvider = { [unowned self] in controller.audioLevel }
        pill.startedAtProvider = { [unowned self] in controller.recordingStartedAt }
        controller.onStateChange = { [unowned self] in render($0) }
        controller.onError = { [unowned self] in showMessage($0) }
        controller.onNotice = { [unowned self] in showMessage($0, beep: false) }
        reloadConfig()
        render(.idle)

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) || !monitor.start() {
            waitForAccessibility()
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        stateItem.isEnabled = false
        hotkeyItem.isEnabled = false
        pipelineItem.isEnabled = false
        messageItem.isEnabled = false
        messageItem.isHidden = true
        accessibilityItem.target = self
        accessibilityItem.isHidden = true
        for item in [stateItem, hotkeyItem, pipelineItem, messageItem, accessibilityItem] { menu.addItem(item) }
        menu.addItem(.separator())
        menu.addItem(item("Abrir configuración…", #selector(openConfig)))
        menu.addItem(item("Recargar configuración", #selector(reloadConfigAction)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir de Susurro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func render(_ state: DictationController.State) {
        let (symbol, title, tint): (String, String, NSColor?) = switch state {
        case .idle: ("mic", "Listo", nil)
        case .recording(.hold): ("mic.fill", "Grabando…", .systemRed)
        case .recording(.handsFree): ("mic.fill", "Grabando (manos libres)…", .systemRed)
        case .transcribing: ("waveform", "Transcribiendo…", nil)
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Susurro: \(title)")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.contentTintColor = tint
        stateItem.title = "Susurro — \(title)"
        if case .recording = state { messageItem.isHidden = true }
        pill.show(state)
    }

    private func showMessage(_ text: String, beep: Bool = true) {
        messageItem.title = text
        messageItem.isHidden = false
        if beep { NSSound.beep() }
    }

    private func reloadConfig() {
        do {
            config = try ConfigStore.load()
        } catch {
            showMessage("config.json inválido: \(error.localizedDescription)")
        }
        let pipeline = DictationPipeline(config: config, secrets: ConfigStore.secrets())
        controller.pipeline = pipeline
        pipelineItem.title = pipeline.summary
        if let warning = pipeline.warnings.first { showMessage(warning, beep: false) }
        do {
            monitor.setHotkey(try Hotkey.parse(config.hotkey))
            hotkeyItem.title = "Mantené \(config.hotkey) para dictar · doble toque: manos libres"
        } catch {
            monitor.setHotkey(.fn)
            hotkeyItem.title = "Mantené fn para dictar · doble toque: manos libres"
            showMessage("Atajo inválido \"\(config.hotkey)\", uso fn.")
        }
    }

    private func waitForAccessibility() {
        accessibilityItem.isHidden = false
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted(), self.monitor.start() else { return }
                self.accessibilityItem.isHidden = true
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func openConfig() {
        _ = try? ConfigStore.load()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-t", Paths.configFile.path]
        try? process.run()
    }

    @objc private func reloadConfigAction() {
        messageItem.isHidden = true
        reloadConfig()
    }
}
