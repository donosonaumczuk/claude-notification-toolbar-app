import AppKit
import Combine
import SwiftUI

/// Menu bar icon. Left click turns all notifications on or off, right click
/// (or Control-click) opens the settings panel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigStore()
    private let library = SoundLibrary()
    private let loginItem = LoginItem()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!
    private var subscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let panel = PanelView()
            .environmentObject(store)
            .environmentObject(library)
            .environmentObject(loginItem)
        let hosting = NSHostingController(rootView: panel)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient

        subscription = store.$config
            .map(\.enabled)
            .removeDuplicates()
            .sink { [weak self] enabled in self?.updateIcon(enabled: enabled) }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if !isRightClick {
            if popover.isShown { popover.performClose(nil) }
            store.config.enabled.toggle()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.reload()
            library.refresh()
            loginItem.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon(enabled: Bool) {
        let name = enabled ? "bell.fill" : "bell.slash"
        let label = enabled ? "Claude notifications on" : "Claude notifications off"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "\(label)\nLeft-click: turn on/off · Right-click: settings"
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
