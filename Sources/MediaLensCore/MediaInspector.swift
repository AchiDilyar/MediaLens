import Foundation
import AVFoundation
import ImageIO
import CoreMedia

public enum MediaInspector {
    public static func probeURL(customPath: String? = nil) -> URL? {
        let paths: [String?] = [customPath, Bundle.main.url(forResource: "ffprobe", withExtension: nil, subdirectory: "bin")?.path,
                     "/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe", "/usr/bin/ffprobe"]
        return paths.compactMap { $0 }.filter { !$0.isEmpty }.map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public static func inspect(_ url: URL, customPath: String? = nil, nativeOnly: Bool = false) async throws -> MediaReport {
        guard url.isFileURL else { throw InspectionError.failed("仅支持本地文件") }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw InspectionError.failed("请拖入文件，而不是文件夹") }
        let size = Int64(values.fileSize ?? 0)
        if !nativeOnly, let executable = probeURL(customPath: customPath) {
            return try await Task.detached(priority: .userInitiated) {
                let data = try runProbe(executable, file: url)
                return try ProbeParser.parse(data, url: url, size: size)
            }.value
        }
        return try await nativeReport(url, size: size)
    }

    // Use files instead of pipes so neither stdout nor stderr can deadlock on a full pipe.
    private static func runProbe(_ executable: URL, file: URL) throws -> Data {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MediaLens-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("output.json")
        let errors = directory.appendingPathComponent("error.txt")
        FileManager.default.createFile(atPath: output.path, contents: nil)
        FileManager.default.createFile(atPath: errors.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: output)
        let stderr = try FileHandle(forWritingTo: errors)
        defer { try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = executable
        // Protocol allowlist prevents a local playlist from opening network resources.
        process.arguments = ["-v", "error", "-protocol_whitelist", "file,crypto,data", "-show_format", "-show_streams", "-show_chapters", "-of", "json", "-i", file.path]
        process.standardOutput = stdout; process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(30)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                // SIGTERM may be ignored by malformed input or a custom executable.
                Thread.sleep(forTimeInterval: 0.1)
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
                throw InspectionError.timeout
            }
            Thread.sleep(forTimeInterval: 0.04)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = try Data(contentsOf: errors)
            let reason = String(decoding: errorData.prefix(2000), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw InspectionError.failed(reason.isEmpty ? "引擎退出代码 \(process.terminationStatus)" : reason)
        }
        return try Data(contentsOf: output)
    }

    private static func nativeReport(_ url: URL, size: Int64) async throws -> MediaReport {
        var sections = [InfoSection(id: "general", title: "文件与容器", symbol: "doc", fields: [InfoField("文件名", url.lastPathComponent), InfoField("位置", url.path), InfoField("文件大小", DisplayValue.bytes(size)), InfoField("扩展名", url.pathExtension.uppercased()), InfoField("解析范围", "Apple 原生框架提供基本信息；完整编码、字幕与标签信息请使用 ffprobe。")])]
        var video: String?, audio: String?, duration: Double?
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            let w = properties[kCGImagePropertyPixelWidth as String].map { String(describing: $0) } ?? "?"
            let h = properties[kCGImagePropertyPixelHeight as String].map { String(describing: $0) } ?? "?"
            let imageType = CGImageSourceGetType(source).map { $0 as String } ?? url.pathExtension
            var fields = [InfoField("图像格式", imageType), InfoField("像素尺寸", "\(w) × \(h)"), InfoField("图像数量", String(CGImageSourceGetCount(source)))]
            for (key, label) in [(kCGImagePropertyDepth as String, "位深"), (kCGImagePropertyColorModel as String, "颜色模型"), (kCGImagePropertyProfileName as String, "色彩配置文件")] {
                if let value = properties[key] { fields.append(InfoField(label, String(describing: value))) }
            }
            sections.append(InfoSection(id: "image", title: "图像", symbol: "photo", fields: fields))
            video = "\(w) × \(h)"
        } else {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let prefix = try handle.read(upToCount: 64) ?? Data()
            // A local HLS playlist can reference remote URLs; keep native fallback local too.
            if String(decoding: prefix, as: UTF8.self).contains("#EXTM3U") { throw InspectionError.unsupported }
            let asset = AVURLAsset(url: url)
            let tracks: [AVAssetTrack]
            do {
                tracks = try await asset.load(.tracks)
                let time = try await asset.load(.duration).seconds
                if time.isFinite { duration = time }
            } catch { throw InspectionError.unsupported }
            guard !tracks.isEmpty else { throw InspectionError.unsupported }
            for (index, track) in tracks.enumerated() {
                let type = track.mediaType
                let descriptions = try await track.load(.formatDescriptions)
                var fields = [InfoField("媒体类型", type.rawValue)]
                if let description = descriptions.first {
                    let code = CMFormatDescriptionGetMediaSubType(description)
                    let bytes: [UInt8] = [UInt8((code >> 24) & 255), UInt8((code >> 16) & 255), UInt8((code >> 8) & 255), UInt8(code & 255)]
                    fields.append(InfoField("编码 FourCC", String(bytes: bytes, encoding: .ascii) ?? String(code)))
                    if type == .audio, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee {
                        fields.append(InfoField("采样率", String(format: "%.0f Hz", asbd.mSampleRate)))
                        fields.append(InfoField("声道数量", String(asbd.mChannelsPerFrame)))
                        audio = "\(asbd.mChannelsPerFrame) 声道 · \(Int(asbd.mSampleRate)) Hz"
                    }
                }
                if type == .video {
                    let dimensions = try await track.load(.naturalSize)
                    let fps = try await track.load(.nominalFrameRate)
                    video = "\(Int(dimensions.width)) × \(Int(dimensions.height))"
                    fields.append(InfoField("编码尺寸", video!))
                    fields.append(InfoField("标称帧率", String(format: "%.3f fps", fps)))
                }
                let bitrate = try await track.load(.estimatedDataRate)
                if let rate = DisplayValue.bitrate(String(bitrate)) { fields.append(InfoField("估算码率", rate)) }
                sections.append(InfoSection(id: "native-\(index)", title: "\(type == .video ? "视频" : type == .audio ? "音频" : "媒体流") · #\(index)", symbol: type == .video ? "film" : "waveform", fields: fields))
            }
        }
        if let duration { sections.append(InfoSection(id: "timing", title: "时间", symbol: "clock", fields: [InfoField("时长", DisplayValue.duration(duration))])) }
        let raw: [String: Any] = ["engine": "Apple frameworks", "file": url.path, "sections": sections.map { section in ["title": section.title, "fields": section.fields.map { ["key": $0.key, "value": $0.value] }] as [String: Any] }]
        let data = try JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return MediaReport(url: url, engine: "Apple 原生", sections: sections, rawJSON: String(decoding: data, as: UTF8.self), duration: duration, size: size, format: url.pathExtension.uppercased(), videoSummary: video, audioSummary: audio)
    }
}
