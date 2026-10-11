import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let library = LibraryModel()
    var openMainWindow: (() -> Void)?
    private var settingsWindow: NSWindow?
    private var serviceWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The model is ready before registering: Services may arrive immediately.
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        DispatchQueue.main.async { self.installMenu() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // SwiftUI can rebuild commands when a window changes; keep the visible bar minimal.
        DispatchQueue.main.async { self.installMenu() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openMedia(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func openMedia(_ urls: [URL]) {
        let files = urls.filter { $0.isFileURL }.map { $0.standardizedFileURL }
        guard !files.isEmpty else { return }
        library.search = ""
        library.add(files)
        // Finder requests should display the requested file, even with an existing selection.
        library.selection = library.items.first { $0.url.standardizedFileURL == files[0] }?.id
        showMainWindow()
    }

    @objc func inspectMedia(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let modern = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let legacy = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] ?? []
        let urls = modern.isEmpty ? legacy.map { URL(fileURLWithPath: $0) } : modern
        guard !urls.isEmpty else {
            error.pointee = "无法读取所选文件，请在访达中选择媒体文件后重试。"
            return
        }
        openMedia(urls)
    }

    private func showMainWindow() {
        if let window = NSApp.windows.first(where: { $0.title == "MediaLens" }) {
            window.makeKeyAndOrderFront(nil)
        } else if let openMainWindow {
            openMainWindow()
        } else {
            // A Services launch may skip SwiftUI's initial window, so no openWindow
            // action exists yet. Host the same SwiftUI content in a native window.
            if serviceWindow == nil {
                let controller = NSHostingController(rootView: ContentView(library: library))
                let window = NSWindow(contentViewController: controller)
                window.title = "MediaLens"
                window.identifier = NSUserInterfaceItemIdentifier("main")
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                window.setContentSize(NSSize(width: 1120, height: 760))
                window.minSize = NSSize(width: 820, height: 560)
                window.isReleasedWhenClosed = false
                window.center()
                serviceWindow = window
            }
            serviceWindow?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func installMenu() {
        if let bar = NSApp.mainMenu, bar.items.count == 1,
           bar.items.first?.submenu?.items.contains(where: { $0.action == #selector(showSettings(_:)) && $0.target === self }) == true {
            return
        }
        let bar = NSMenu()
        let root = NSMenuItem(title: "MediaLens", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "MediaLens")
        root.submenu = menu
        bar.addItem(root)
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出MediaLens", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        // Invisible key equivalents retain app and native text-editing shortcuts without extra menus.
        shortcut(menu, "打开", #selector(openFiles(_:)), "o", target: self)
        shortcut(menu, "复制报告", #selector(copyReport(_:)), "c", modifiers: [.command, .shift], target: self)
        shortcut(menu, "导出文本", #selector(exportText(_:)), "e", target: self)
        shortcut(menu, "重新检查", #selector(retry(_:)), "r", target: self)
        for (title, action, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a"), ("撤销", "undo:", "z"), ("关闭窗口", "performClose:", "w")] {
            shortcut(menu, title, Selector(action), key)
        }
        shortcut(menu, "重做", Selector(("redo:")), "z", modifiers: [.command, .shift])
        NSApp.mainMenu = bar
    }

    private func shortcut(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String,
                          modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        item.isHidden = true
        item.allowsKeyEquivalentWhenHidden = true
        menu.addItem(item)
    }

    @objc private func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(library: library))
            let window = NSWindow(contentViewController: controller)
            window.title = "设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openFiles(_ sender: Any?) { library.openFiles() }
    @objc private func copyReport(_ sender: Any?) { library.copyReport() }
    @objc private func exportText(_ sender: Any?) { library.exportReport(json: false) }
    @objc private func retry(_ sender: Any?) { library.retry() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copyReport(_:)) || menuItem.action == #selector(exportText(_:)) {
            return library.selected?.report != nil
        }
        if menuItem.action == #selector(retry(_:)) {
            return library.selected != nil && library.selected?.isLoading == false
        }
        return true
    }
}
