import Foundation

public struct InfoField: Identifiable, Sendable, Equatable {
    public var id: String { key }
    public let key: String
    public let value: String
    public init(_ key: String, _ value: String) { self.key = key; self.value = value }
}

public struct InfoSection: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let fields: [InfoField]
    public init(id: String, title: String, symbol: String, fields: [InfoField]) {
        self.id = id; self.title = title; self.symbol = symbol; self.fields = fields
    }
}

public struct MediaReport: Sendable {
    public let url: URL
    public let engine: String
    public let sections: [InfoSection]
    public let rawJSON: String
    public let duration: Double?
    public let size: Int64
    public let format: String
    public let videoSummary: String?
    public let audioSummary: String?
    public var text: String {
        (["MediaLens · \(url.lastPathComponent)", "解析引擎：\(engine)"] + sections.map {
            "\n[\($0.title)]\n" + $0.fields.map { "\($0.key)：\($0.value)" }.joined(separator: "\n")
        }).joined(separator: "\n")
    }
}

public enum DisplayValue {
    public static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0, seconds < Double(Int.max / 1000) else { return "未知" }
        let total = Int(seconds)
        return String(format: "%02d:%02d:%02d.%03d", total / 3600, total / 60 % 60, total % 60, Int(seconds * 1000) % 1000)
    }
    public static func bytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    public static func rate(_ value: String?) -> String? {
        guard let value else { return nil }
        let parts = value.split(separator: "/")
        let rate: Double
        if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 { rate = n / d }
        else if let n = Double(value) { rate = n }
        else { return nil }
        guard rate.isFinite, rate > 0 else { return nil }
        return String(format: "%.3f fps", rate)
    }
    public static func bitrate(_ value: String?) -> String? {
        guard let value, let n = Double(value), n.isFinite, n > 0 else { return nil }
        return n >= 1_000_000 ? String(format: "%.2f Mb/s", n / 1_000_000) : String(format: "%.0f kb/s", n / 1000)
    }
}

public enum ProbeParser {
    public static func parse(_ data: Data, url: URL, size: Int64) throws -> MediaReport {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InspectionError.invalidOutput
        }
        let format = root["format"] as? [String: Any] ?? [:]
        let streams = root["streams"] as? [[String: Any]] ?? []
        guard !streams.isEmpty else { throw InspectionError.noMedia }
        func str(_ dict: [String: Any], _ key: String) -> String? {
            guard let value = dict[key], !(value is NSNull) else { return nil }
            let text = String(describing: value)
            return text.isEmpty || text == "N/A" ? nil : text
        }
        func tags(_ dict: [String: Any]) -> [InfoField] {
            let values = dict["tags"] as? [String: Any] ?? [:]
            return values.keys.sorted().compactMap { key in str(values, key).map { InfoField("标签 · \(key)", $0) } }
        }
        let duration = str(format, "duration").flatMap(Double.init)
        let container = str(format, "format_long_name") ?? str(format, "format_name") ?? url.pathExtension.uppercased()
        var general = [InfoField("文件名", url.lastPathComponent), InfoField("位置", url.path), InfoField("容器", container), InfoField("文件大小", "\(DisplayValue.bytes(size))（\(size) 字节）")]
        if let duration { general.append(InfoField("时长", DisplayValue.duration(duration))) }
        if let rate = DisplayValue.bitrate(str(format, "bit_rate")) { general.append(InfoField("总码率", rate)) }
        general.append(InfoField("媒体流数量", String(streams.count)))
        general += tags(format)
        var sections = [InfoSection(id: "general", title: "文件与容器", symbol: "doc", fields: general)]
        var video: String?, audio: String?
        for (offset, stream) in streams.enumerated() {
            let type = str(stream, "codec_type") ?? "other"
            let index = str(stream, "index") ?? String(offset)
            let disposition = stream["disposition"] as? [String: Any] ?? [:]
            let cover = (disposition["attached_pic"] as? Int) == 1
            let title = cover ? "封面图" : ["video": "视频", "audio": "音频", "subtitle": "字幕", "data": "数据", "attachment": "附件"][type] ?? "其他"
            let symbol = cover ? "photo" : ["video": "film", "audio": "waveform", "subtitle": "captions.bubble"][type] ?? "doc.text"
            let codec = str(stream, "codec_long_name") ?? str(stream, "codec_name") ?? "未知"
            var fields = [InfoField("编码", codec)]
            let mappings = [("codec_tag_string", "编码标识"), ("profile", "Profile"), ("level", "Level"), ("pix_fmt", "像素格式"), ("sample_aspect_ratio", "像素宽高比"), ("display_aspect_ratio", "显示宽高比"), ("field_order", "扫描方式"), ("color_range", "色彩范围"), ("color_space", "色彩空间"), ("color_transfer", "传递函数"), ("color_primaries", "色彩原色"), ("bits_per_raw_sample", "原始位深"), ("sample_fmt", "采样格式"), ("channels", "声道数量"), ("channel_layout", "声道布局"), ("bits_per_sample", "采样位深"), ("nb_frames", "帧数"), ("time_base", "时间基准")]
            if let w = str(stream, "width"), let h = str(stream, "height") {
                fields.append(InfoField("分辨率", "\(w) × \(h)"))
                if type == "video", !cover, video == nil { video = "\(w) × \(h) · \(str(stream, "codec_name")?.uppercased() ?? codec)" }
            }
            for (key, label) in mappings {
                if let v = str(stream, key) {
                    if ["bits_per_sample", "bits_per_raw_sample", "level"].contains(key), let number = Int(v), number <= 0 { continue }
                    fields.append(InfoField(label, v))
                }
            }
            if let rate = DisplayValue.rate(str(stream, "avg_frame_rate")) { fields.append(InfoField("平均帧率", rate)) }
            if let sample = str(stream, "sample_rate") { fields.append(InfoField("采样率", "\(sample) Hz")) }
            if let rate = DisplayValue.bitrate(str(stream, "bit_rate")) { fields.append(InfoField("码率", rate)) }
            if let time = str(stream, "duration").flatMap(Double.init) { fields.append(InfoField("时长", DisplayValue.duration(time))) }
            if type == "audio", audio == nil {
                audio = [str(stream, "codec_name")?.uppercased(), str(stream, "channel_layout"), str(stream, "sample_rate").map { "\($0) Hz" }].compactMap { $0 }.joined(separator: " · ")
            }
            let flags = disposition.keys.sorted().filter { (disposition[$0] as? Int) == 1 }
            if !flags.isEmpty { fields.append(InfoField("流标记", flags.joined(separator: ", "))) }
            if let side = stream["side_data_list"] as? [[String: Any]] {
                for item in side {
                    if let rotation = str(item, "rotation") { fields.append(InfoField("旋转角度", rotation + "°")) }
                }
            }
            fields += tags(stream)
            sections.append(InfoSection(id: "stream-\(offset)", title: "\(title) · #\(index)", symbol: symbol, fields: fields))
        }
        if let chapters = root["chapters"] as? [[String: Any]], !chapters.isEmpty {
            let fields = chapters.enumerated().map { i, chapter in
                InfoField("章节 \(i + 1)", "\(DisplayValue.duration(str(chapter, "start_time").flatMap(Double.init))) · \(str(chapter["tags"] as? [String: Any] ?? [:], "title") ?? "未命名")")
            }
            sections.append(InfoSection(id: "chapters", title: "章节", symbol: "list.number", fields: fields))
        }
        let pretty = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return MediaReport(url: url, engine: "ffprobe", sections: sections, rawJSON: String(decoding: pretty, as: UTF8.self), duration: duration, size: size, format: container, videoSummary: video, audioSummary: audio)
    }
}

public enum InspectionError: LocalizedError {
    case invalidOutput, noMedia, timeout, failed(String), unsupported
    public var errorDescription: String? {
        switch self {
        case .invalidOutput: return "解析引擎返回了无效数据。"
        case .noMedia: return "没有找到可识别的媒体流。"
        case .timeout: return "解析超过 30 秒，请检查文件或重试。"
        case .failed(let reason): return "无法读取媒体信息：\(reason)"
        case .unsupported: return "原生引擎无法识别此文件。安装 ffprobe 可支持更多格式。"
        }
    }
}
