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
    private let enabledItem = NSMenuItem(title: "Activado", action: #selector(toggleEnabled), keyEquivalent: "")
    private let historyMenu = NSMenu()
    private let accessibilityItem = NSMenuItem(
        title: "⚠︎ Falta permiso de Accesibilidad…",
        action: #selector(openAccessibilitySettings),
        keyEquivalent: ""
    )

    private var config = Config.defaults
    private var monitor = HotkeyMonitor(hotkey: .fn)
    private var controller = DictationController(
        pipeline: DictationPipeline(config: .defaults, secrets: [:], vocabulary: .empty)
    )
    private var permissionTimer: Timer?
    private let pill = PillPanel()

    /// Kept only in memory on purpose: dictations never get written to disk.
    private var history: [String] = []
    private static let historyLimit = 10

    private static let enabledKey = "enabled"
    private var enabled = UserDefaults.standard.object(forKey: AppDelegate.enabledKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
            if !enabled { controller.escapePressed() }
            render(controller.state)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        monitor.onPress = { [unowned self] in if enabled { controller.hotkeyPressed() } }
        monitor.onRelease = { [unowned self] in controller.hotkeyReleased() }
        monitor.onOtherKey = { [unowned self] in controller.otherKeyPressed() }
        monitor.onEscape = { [unowned self] in controller.escapePressed() }
        pill.levelProvider = { [unowned self] in controller.audioLevel }
        pill.startedAtProvider = { [unowned self] in controller.recordingStartedAt }
        controller.onStateChange = { [unowned self] in render($0) }
        controller.onError = { [unowned self] in showMessage($0) }
        controller.onNotice = { [unowned self] in showMessage($0, beep: false) }
        controller.onDictation = { [unowned self] in remember($0) }
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
        enabledItem.target = self
        menu.addItem(enabledItem)
        let historyItem = NSMenuItem(title: "Historial", action: nil, keyEquivalent: "")
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)
        renderHistory()
        menu.addItem(.separator())
        menu.addItem(item("Abrir configuración…", #selector(openConfig)))
        menu.addItem(item("Editar diccionario…", #selector(openVocabulary)))
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
        let title: String = switch state {
        case .idle: enabled ? "Listo" : "Desactivado"
        case .recording(.hold): "Grabando…"
        case .recording(.handsFree): "Grabando (manos libres)…"
        case .transcribing: "Transcribiendo…"
        }
        if let button = statusItem.button {
            button.image = MenuBarIcon.wave
            button.contentTintColor = if case .recording = state { .systemRed } else { nil }
            button.alphaValue = state == .transcribing ? 0.55 : 1
            button.appearsDisabled = !enabled
            button.toolTip = "Susurro — \(title)"
        }
        stateItem.title = "Susurro — \(title)"
        enabledItem.state = enabled ? .on : .off
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
        let pipeline = DictationPipeline(config: config, secrets: ConfigStore.secrets(), vocabulary: ConfigStore.vocabulary())
        controller.pipeline = pipeline
        controller.restoreClipboard = config.restoreClipboard
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

    private func remember(_ text: String) {
        history.insert(text, at: 0)
        history = Array(history.prefix(Self.historyLimit))
        renderHistory()
    }

    private func renderHistory() {
        historyMenu.removeAllItems()
        if history.isEmpty {
            let empty = NSMenuItem(title: "Sin dictados todavía", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
            return
        }
        let hint = NSMenuItem(title: "Clic para copiar", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        historyMenu.addItem(hint)
        for (index, text) in history.enumerated() {
            let entry = item(Self.preview(text), #selector(copyHistoryEntry(_:)))
            entry.tag = index
            entry.toolTip = text
            historyMenu.addItem(entry)
        }
        historyMenu.addItem(.separator())
        historyMenu.addItem(item("Borrar historial", #selector(clearHistory)))
    }

    private static func preview(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return line.count > 60 ? line.prefix(60).trimmingCharacters(in: .whitespaces) + "…" : line
    }

    @objc private func copyHistoryEntry(_ sender: NSMenuItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(history[sender.tag], forType: .string)
    }

    @objc private func clearHistory() {
        history.removeAll()
        renderHistory()
    }

    @objc private func openConfig() {
        _ = try? ConfigStore.load()
        openInTextEditor(Paths.configFile)
    }

    @objc private func openVocabulary() {
        try? ConfigStore.ensureVocabularyFile()
        openInTextEditor(Paths.vocabularyFile)
    }

    private func openInTextEditor(_ file: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-t", file.path]
        try? process.run()
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
    }

    @objc private func reloadConfigAction() {
        messageItem.isHidden = true
        reloadConfig()
    }
}
