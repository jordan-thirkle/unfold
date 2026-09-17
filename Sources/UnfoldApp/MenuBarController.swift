import AppKit
import UnfoldCore

/// The menu bar item.
///
/// All configuration lives here for v0.1: there is no preferences window yet,
/// and no setting is reachable by another route, so this menu is the single
/// source of truth for the user.
@MainActor
final class MenuBarController {

    private let statusItem: NSStatusItem
    private let onPreview: () -> Void
    private let onConfigChanged: (UnfoldConfiguration) -> Void

    private var configuration: UnfoldConfiguration
    private var problem: String?

    init(
        configuration: UnfoldConfiguration,
        problem: String?,
        onPreview: @escaping () -> Void,
        onConfigChanged: @escaping (UnfoldConfiguration) -> Void
    ) {
        self.configuration = configuration
        self.problem = problem
        self.onPreview = onPreview
        self.onConfigChanged = onConfigChanged
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Unfold")
            button.toolTip = "Unfold — animation when the Mac wakes"
        }
        rebuildMenu()
    }

    /// Surfaces a failure in the menu itself. A setting that silently did
    /// nothing is worse than no setting.
    func report(_ message: String?) {
        problem = message
        rebuildMenu()
    }

    func update(configuration: UnfoldConfiguration) {
        self.configuration = configuration
        rebuildMenu()
    }

    var onSnapshotPreview: (() -> Void)?
    var onSnapshotToggle: (() -> Void)?
    var onSnapshotStop: (() -> Void)?
    var snapshotEnabled = false { didSet { rebuildMenu() } }

    private func rebuildMenu() {
        let menu = NSMenu()
        let snapshotPreview = NSMenuItem(title: "Snapshot perspective preview…", action: #selector(snapshotPreviewAction), keyEquivalent: "")
        snapshotPreview.target = self
        menu.addItem(snapshotPreview)
        let tracking = NSMenuItem(title: "Track lid angle (experimental)…", action: #selector(snapshotToggleAction), keyEquivalent: "")
        tracking.target = self
        tracking.state = snapshotEnabled ? .on : .off
        menu.addItem(tracking)
        let stop = NSMenuItem(title: "Stop snapshot effect", action: #selector(snapshotStopAction), keyEquivalent: "")
        stop.target = self
        menu.addItem(stop)
        menu.addItem(.separator())

        if let problem {
            let item = NSMenuItem(title: problem, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }

        let open = NSMenuItem(title: "Animate when the Mac wakes", action: #selector(toggleOpen), keyEquivalent: "")
        open.target = self
        open.state = configuration.animateOnOpen ? .on : .off
        menu.addItem(open)

        let close = NSMenuItem(title: "Animate when the lid closes", action: #selector(toggleClose), keyEquivalent: "")
        close.target = self
        close.state = configuration.animateOnClose ? .on : .off
        menu.addItem(close)

        let closeNote = NSMenuItem(
            title: "Closing is best-effort — macOS sleeps the Mac straight away",
            action: nil,
            keyEquivalent: ""
        )
        closeNote.isEnabled = false
        closeNote.indentationLevel = 1
        menu.addItem(closeNote)

        let motion = NSMenuItem(title: "Respect Reduce Motion", action: #selector(toggleReduceMotion), keyEquivalent: "")
        motion.target = self
        motion.state = configuration.respectReduceMotion ? .on : .off
        menu.addItem(motion)

        menu.addItem(.separator())

        let presetHeader = NSMenuItem(title: "Animation", action: nil, keyEquivalent: "")
        presetHeader.isEnabled = false
        menu.addItem(presetHeader)
        for preset in AnimationPreset.all {
            let item = NSMenuItem(title: preset.name, action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            item.state = preset.id == configuration.presetID ? .on : .off
            item.toolTip = preset.summary
            item.indentationLevel = 1
            menu.addItem(item)
        }

        addDurationItems(to: menu, title: "Opening speed", choices: UnfoldConfiguration.openDurationChoices,
                         selected: configuration.openDuration, format: "%.1f",
                         action: #selector(selectOpenDuration(_:)))
        addDurationItems(to: menu, title: "Closing speed", choices: UnfoldConfiguration.closeDurationChoices,
                         selected: configuration.closeDuration, format: "%.2f",
                         action: #selector(selectCloseDuration(_:)))

        menu.addItem(.separator())

        let preview = NSMenuItem(title: "Preview animation", action: #selector(preview), keyEquivalent: "p")
        preview.target = self
        menu.addItem(preview)

        let login = NSMenuItem(title: "Start at login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        login.isEnabled = LoginItem.isAvailable
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Unfold", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func addDurationItems(
        to menu: NSMenu,
        title: String,
        choices: [Double],
        selected: Double,
        format: String,
        action: Selector
    ) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for choice in choices {
            let item = NSMenuItem(title: "\(String(format: format, choice))s", action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = choice
            item.state = choice == selected ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }
    }

    private func commit() {
        onConfigChanged(configuration)
        rebuildMenu()
    }

    // MARK: - Actions

    @objc private func toggleOpen() {
        configuration.animateOnOpen.toggle()
        commit()
    }

    @objc private func toggleClose() {
        configuration.animateOnClose.toggle()
        commit()
    }

    @objc private func toggleReduceMotion() {
        configuration.respectReduceMotion.toggle()
        commit()
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        configuration.presetID = id
        commit()
    }

    @objc private func selectOpenDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? Double else { return }
        configuration.openDuration = duration
        commit()
    }

    @objc private func selectCloseDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? Double else { return }
        configuration.closeDuration = duration
        commit()
    }

    @objc private func preview() {
        onPreview()
    }

    @objc private func toggleLoginItem() {
        let enabling = !LoginItem.isEnabled
        report(LoginItem.setEnabled(enabling))
        rebuildMenu()
    }

    @objc private func snapshotPreviewAction() { onSnapshotPreview?() }
    @objc private func snapshotToggleAction() { onSnapshotToggle?() }
    @objc private func snapshotStopAction() { onSnapshotStop?() }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}