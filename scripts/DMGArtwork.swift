import AppKit

// Finder uses logical points. Keep a 2× bitmap for crisp Retina typography.
let output = CommandLine.arguments[1]
let size = NSSize(width: 760, height: 480)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1520, pixelsHigh: 960, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
}
func text(_ string: String, x: CGFloat = 32, y: CGFloat, width: CGFloat = 696, size: CGFloat, ink: NSColor, weight: NSFont.Weight = .regular) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    (string as NSString).draw(in: NSRect(x: x, y: y, width: width, height: ceil(size * 1.5)), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: ink, .paragraphStyle: paragraph])
}
let ink = color(0.10, 0.17, 0.28)
let muted = color(0.40, 0.47, 0.57)
NSGradient(starting: color(0.98, 0.99, 1), ending: color(0.90, 0.94, 0.98))!.draw(in: NSRect(origin: .zero, size: size), angle: -90)
// Quiet color accents echo the four corners of the application icon.
let accents = [color(0.95, 0.31, 0.20), color(0.47, 0.72, 0.13), color(0.05, 0.63, 0.88), color(0.98, 0.72, 0.06)]
for (i, accent) in accents.enumerated() {
    accent.setFill()
    NSBezierPath(roundedRect: NSRect(x: 349 + CGFloat(i) * 17, y: 443, width: 11, height: 4), xRadius: 2, yRadius: 2).fill()
}
text("MediaLens", y: 374, size: 38, ink: ink, weight: .semibold)
text("看见媒体的每一处细节。", y: 342, size: 17, ink: muted)
// Actual Finder icons sit on these platforms; the background contains no fake icons.
for x: CGFloat in [220, 540] {
    color(0.99, 0.995, 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: x - 84, y: 156, width: 168, height: 150), xRadius: 24, yRadius: 24).fill()
}
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 348, y: 232)); arrow.line(to: NSPoint(x: 412, y: 232))
arrow.move(to: NSPoint(x: 399, y: 245)); arrow.line(to: NSPoint(x: 412, y: 232)); arrow.line(to: NSPoint(x: 399, y: 219))
arrow.lineWidth = 3.5; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
color(0.35, 0.47, 0.64).setStroke(); arrow.stroke()
text("拖入右侧文件夹，即可安装", y: 92, size: 16, ink: ink, weight: .medium)
text("安装后打开 MediaLens，将媒体文件拖入窗口", y: 64, size: 12, ink: muted)
color(0.80, 0.85, 0.91).setFill()
NSRect(x: 48, y: 51, width: 664, height: 0.5).fill()
text("原生 macOS 媒体信息查看器     ·     macOS 14+     ·     Intel / Apple Silicon", y: 8, size: 11, ink: muted)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
