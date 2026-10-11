import AppKit
import SwiftUI
import QuickLookThumbnailing
import UniformTypeIdentifiers
import Quartz

/// A real file representation: selection, default-app opening and copy-only file dragging.
struct MediaFileView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> FileThumbnailView { FileThumbnailView() }
    func updateNSView(_ view: FileThumbnailView, context: Context) { view.load(url) }
    static func dismantleNSView(_ view: FileThumbnailView, coordinator: ()) { view.cancelThumbnail() }
}

final class FileThumbnailView: NSView, NSDraggingSource, QLPreviewPanelDataSource {
    private var fileURL: URL?
    private var image: NSImage?
    private var selected = false
    private var mouseDownPoint: NSPoint?
    private var request: QLThumbnailGenerator.Request?
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    func cancelThumbnail() {
        if let request { QLThumbnailGenerator.shared.cancel(request) }
        request = nil
        if QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(), panel.dataSource === self {
            panel.orderOut(nil)
            panel.dataSource = nil
        }
    }

    func load(_ url: URL) {
        guard fileURL != url else { return }
        cancelThumbnail()
        fileURL = url
        selected = false
        image = NSWorkspace.shared.icon(forFile: url.path)
        toolTip = "\(url.lastPathComponent)\n单击选中 · 双击打开 · 拖出复制 · 空格快速查看"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(url.lastPathComponent)
        setAccessibilityHelp("双击使用默认应用打开文件，拖动可复制文件")
        needsDisplay = true
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        // Audio deliberately keeps its system file icon, rather than album artwork.
        guard type?.conforms(to: .audio) != true else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 160, height: 160), scale: 2, representationTypes: .thumbnail)
        self.request = request
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            DispatchQueue.main.async {
                guard let self, self.fileURL == url, self.request === request else { return }
                if let representation { self.image = representation.nsImage; self.needsDisplay = true }
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8).fill()
        }
        guard let image else { return }
        let available = bounds.insetBy(dx: 6, dy: 6)
        let scale = min(available.width / max(image.size.width, 1), available.height / max(image.size.height, 1))
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        selected = true
        needsDisplay = true
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2, let fileURL { NSWorkspace.shared.open(fileURL) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let fileURL, let start = mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - start.x, point.y - start.y) > 4 else { return }
        mouseDownPoint = nil
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        item.setDraggingFrame(bounds.insetBy(dx: 6, dy: 6), contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    override func resignFirstResponder() -> Bool { selected = false; needsDisplay = true; return super.resignFirstResponder() }
    @objc func copy(_ sender: Any?) {
        guard let fileURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([fileURL as NSURL])
    }
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " { quickLook(nil) }
        else { super.keyDown(with: event) }
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        for (title, action) in [("打开", #selector(openFile(_:))), ("快速查看", #selector(quickLook(_:))), ("复制文件", #selector(copy(_:))), ("在访达中显示", #selector(revealFile(_:)))] {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
        }
        return menu
    }
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = self }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { if panel.dataSource === self { panel.dataSource = nil } }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { fileURL == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! { fileURL as NSURL? }
    @objc private func openFile(_ sender: Any?) { if let fileURL { NSWorkspace.shared.open(fileURL) } }
    @objc private func revealFile(_ sender: Any?) { if let fileURL { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) } }
    @objc private func quickLook(_ sender: Any?) {
        guard fileURL != nil, let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
}
