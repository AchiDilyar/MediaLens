import SwiftUI
import AppKit
import MediaLensCore

@main
struct MediaLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    init() {
        // The same binary provides a headless inspector for scripts and integration checks.
        if CommandLine.arguments.contains("--engine-path") {
            print(MediaInspector.probeURL()?.path ?? "Apple 原生")
            exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--inspect"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            Task {
                do {
                    let report = try await MediaInspector.inspect(URL(fileURLWithPath: path), nativeOnly: CommandLine.arguments.contains("--native"))
                    print(report.rawJSON); exit(0)
                } catch {
                    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1)
                }
            }
            dispatchMain()
        }
        NSApplication.shared.setActivationPolicy(.regular)
        // Refresh the running Dock tile from this bundle after an in-place app update.
        if let iconURL = Bundle.main.url(forResource: "MediaLens", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
    var body: some Scene {
        Window("MediaLens", id: "main") {
            MainWindowContent(delegate: delegate)
        }
        .defaultSize(width: 1120, height: 760)
        .commandsRemoved()
    }
}

struct SettingsView: View {
    @ObservedObject var library: LibraryModel
    var body: some View {
        Form {
            Section("解析引擎") {
                LabeledContent("当前引擎", value: library.engineLabel)
                TextField("ffprobe 自定义路径", text: $library.ffprobePath, prompt: Text("留空使用内置引擎"))
                Text("留空时优先使用内置 ffprobe，源码运行时查找本机安装；未找到时使用 Apple 原生框架。修改后可重新检查文件。").font(.caption).foregroundStyle(.secondary)
                Button("选择 ffprobe…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = false
                    let completion: (NSApplication.ModalResponse) -> Void = { response in
                        if response == .OK, let url = panel.url {
                            Task { @MainActor in library.ffprobePath = url.path }
                        }
                    }
                    if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
                    else { panel.begin(completionHandler: completion) }
                }
            }
            Section("MediaLens \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版")") {
                Text("媒体信息，清晰呈现。\n所有解析均在本机完成；应用不上传文件。")
            }
        }.formStyle(.grouped).padding().frame(width: 520, height: 330)
    }
}

private struct MainWindowContent: View {
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ContentView(library: delegate.library)
            .onAppear {
                delegate.openMainWindow = { openWindow(id: "main") }
                delegate.installMenu()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
    }
}
