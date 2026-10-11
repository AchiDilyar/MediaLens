import Foundation
import MediaLensCore

struct ProbeParserTests {
    private let url = URL(fileURLWithPath: "/tmp/中文 sample.mp4")
    func testVideoAudioAndSubtitleReport() throws {
        let json = #"{"format":{"format_name":"mov,mp4","duration":"61.125","bit_rate":"1500000","tags":{"title":"演示"}},"streams":[{"index":0,"codec_type":"video","codec_name":"h264","width":1920,"height":1080,"avg_frame_rate":"30000/1001","color_primaries":"bt709"},{"index":1,"codec_type":"audio","codec_name":"aac","channels":2,"sample_rate":"48000","channel_layout":"stereo","tags":{"language":"zho"}},{"index":2,"codec_type":"subtitle","codec_name":"subrip"}],"chapters":[{"start_time":"0","tags":{"title":"开场"}}]}"#
        let report = try ProbeParser.parse(Data(json.utf8), url: url, size: 1024)
        expectEqual(report.duration, 61.125)
        expectEqual(report.sections.count, 5)
        expectEqual(report.videoSummary, "1920 × 1080 · H264")
        expectTrue(report.text.contains("29.970 fps"))
        expectTrue(report.text.contains("zho"))
        expectTrue(report.text.contains("开场"))
        expectNoThrow(try JSONSerialization.jsonObject(with: Data(report.rawJSON.utf8)))
    }
    func testCoverArtIsNotMainVideo() throws {
        let json = #"{"streams":[{"index":0,"codec_type":"video","codec_name":"mjpeg","width":500,"height":500,"disposition":{"attached_pic":1}},{"index":1,"codec_type":"audio","codec_name":"mp3"}]}"#
        let report = try ProbeParser.parse(Data(json.utf8), url: url, size: 12)
        expectNil(report.videoSummary)
        expectEqual(report.sections[1].title, "封面图 · #0")
        expectEqual(report.audioSummary, "MP3")
    }
    func testMissingOptionalFieldsAndInvalidInput() throws {
        let report = try ProbeParser.parse(Data(#"{"streams":[{"codec_type":"audio","codec_name":"flac","duration":"N/A","bits_per_sample":0,"level":-99,"tags":{"empty":null}}]}"#.utf8), url: url, size: 0)
        expectNil(report.duration)
        expectFalse(report.text.contains("N/A"))
        expectFalse(report.text.contains("采样位深"))
        expectFalse(report.text.contains("Level"))
        expectThrows(try ProbeParser.parse(Data("{}".utf8), url: url, size: 0))
        expectThrows(try ProbeParser.parse(Data("[]".utf8), url: url, size: 0))
        expectThrows(try ProbeParser.parse(Data("invalid".utf8), url: url, size: 0))
    }
    func testNumericBoundaries() {
        expectNil(DisplayValue.rate("0/0"))
        expectNil(DisplayValue.rate("NaN"))
        expectNil(DisplayValue.bitrate("inf"))
        expectEqual(DisplayValue.duration(.infinity), "未知")
        expectEqual(DisplayValue.duration(-1), "未知")
        expectEqual(DisplayValue.duration(3661.125), "01:01:01.125")
    }
    func testNativeAudioInspection() async throws {
        // Generate a small valid PCM WAV in memory; no external tools needed.
        var data = Data()
        func ascii(_ text: String) { data.append(Data(text.utf8)) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(1636); ascii("WAVEfmt "); u32(16); u16(1); u16(1); u32(8000); u32(16000); u16(2); u16(16)
        ascii("data"); u32(1600); data.append(Data(repeating: 0, count: 1600))
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("MediaLens-test-\(UUID()).wav")
        try data.write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }
        let report = try await MediaInspector.inspect(temp, nativeOnly: true)
        expectEqual(report.engine, "Apple 原生")
        expectEqual(report.duration ?? 0, 0.1, accuracy: 0.001)
        expectTrue(report.audioSummary?.contains("8000 Hz") == true)
    }
}


// Standalone checks also run with Command Line Tools installations without XCTest.
private func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    precondition(value, "Expected true at \(file):\(line)")
}
private func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    expectTrue(!value, file: file, line: line)
}
private func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) {
    precondition(lhs == rhs, "\(lhs) != \(rhs) at \(file):\(line)")
}
private func expectEqual(_ lhs: Double, _ rhs: Double, accuracy: Double) {
    precondition(abs(lhs - rhs) <= accuracy)
}
private func expectNil<T>(_ value: T?) { precondition(value == nil) }
private func expectNoThrow<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() } catch { preconditionFailure("Unexpected error: \(error)") }
}
private func expectThrows<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() } catch { return }
    preconditionFailure("Expected an error")
}

@main
struct CheckRunner {
    static func main() async throws {
        let tests = ProbeParserTests()
        try tests.testVideoAudioAndSubtitleReport()
        try tests.testCoverArtIsNotMainVideo()
        try tests.testMissingOptionalFieldsAndInvalidInput()
        tests.testNumericBoundaries()
        try await tests.testNativeAudioInspection()
        print("PASS: 5 core checks (tracks, cover art, invalid/missing data, numeric boundaries, native WAV)")
    }
}
