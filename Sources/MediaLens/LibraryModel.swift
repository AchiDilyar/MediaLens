import SwiftUI
import AppKit
import MediaLensCore

struct MediaItem: Identifiable {
    let id = UUID()
    let url: URL
    var report: MediaReport?
    var error: String?
    var isLoading = true
    var symbol: String {
        if error != nil { return "exclamationmark.triangle" }
        if report?.audioSummary != nil && report?.videoSummary == nil { return "waveform" }
        return "doc.richtext"
    }
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var selection: UUID?
    @Published var search = ""
    @Published var notice: String?
    @Published var ffprobePath: String {
        didSet { UserDefaults.standard.set(ffprobePath, forKey: "ffprobePath") }
    }
    init() { ffprobePath = UserDefaults.standard.string(forKey: "ffprobePath") ?? "" }
    var selected: MediaItem? { items.first { $0.id == selection } }
    var engineLabel: String {
        guard let engine = MediaInspector.probeURL(customPath: ffprobePath) else { return "Apple 原生引擎" }
        return engine.path.hasPrefix(Bundle.main.bundlePath + "/") ? "内置 ffprobe 引擎" : "ffprobe 引擎"
    }
    private var pending: [UUID] = []
    private var worker: Task<Void, Never>?

    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL {
            let normalized = url.standardizedFileURL
            if let existing = items.first(where: { $0.url.standardizedFileURL == normalized }) { selection = existing.id; continue }
            let item = MediaItem(url: url)
            items.append(item); pending.append(item.id)
            if selection == nil { selection = item.id }
        }
        processQueue()
    }
    private func processQueue() {
        guard worker == nil else { return }
        worker = Task {
            while !pending.isEmpty {
                let id = pending.removeFirst()
                guard let item = items.first(where: { $0.id == id }) else { continue }
                do {
                    let report = try await MediaInspector.inspect(item.url, customPath: ffprobePath)
                    if let index = items.firstIndex(where: { $0.id == id }) { items[index].report = report; items[index].isLoading = false }
                } catch {
                    if let index = items.firstIndex(where: { $0.id == id }) { items[index].error = error.localizedDescription; items[index].isLoading = false }
                }
            }
            worker = nil
        }
    }
    func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.title = "选择要检查的媒体文件"
        panel.prompt = "检查"
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in self?.add(panel.urls) }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    func removeSelection() {
        guard let selection else { return }
        pending.removeAll { $0 == selection }
        items.removeAll { $0.id == selection }
        self.selection = items.first?.id
    }
    func clear() { items.removeAll(); pending.removeAll(); selection = nil }
    func retry() {
        guard let id = selection, let index = items.firstIndex(where: { $0.id == id }), !items[index].isLoading else { return }
        items[index].error = nil; items[index].report = nil; items[index].isLoading = true
        pending.append(id); processQueue()
    }
    func copyReport() {
        guard let report = selected?.report else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report.text, forType: .string)
        notice = "报告已复制"
    }
    func exportReport(json: Bool) {
        guard let report = selected?.report else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = report.url.deletingPathExtension().lastPathComponent + (json ? "-info.json" : "-info.txt")
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do { try (json ? report.rawJSON : report.text).write(to: url, atomically: true, encoding: .utf8); self?.notice = "报告已导出" }
                catch { self?.notice = "导出失败：\(error.localizedDescription)" }
            }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
}
