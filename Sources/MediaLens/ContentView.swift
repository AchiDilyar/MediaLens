import SwiftUI
import AppKit
import MediaLensCore

struct ContentView: View {
    @ObservedObject var library: LibraryModel
    @State private var isTargeted = false
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("媒体库").font(.headline)
                    Spacer()
                    Text("\(library.items.count)").foregroundStyle(.secondary).monospacedDigit()
                }.padding(.horizontal, 16).padding(.vertical, 14)
                if library.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
                        Text("拖入文件开始检查").font(.callout).foregroundStyle(.secondary)
                        Button("选择文件…", action: library.openFiles)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $library.selection) {
                        ForEach(library.items) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.symbol).font(.title3).foregroundStyle(item.error == nil ? Color.accentColor : .orange).frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                    Text(item.isLoading ? "等待 / 正在解析…" : item.error != nil ? "无法读取" : item.report?.format ?? "媒体文件")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                if item.isLoading { ProgressView().controlSize(.small) }
                            }.padding(.vertical, 6).tag(item.id)
                            .onDrag { NSItemProvider(object: item.url as NSURL) }
                            .contextMenu {
                                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                            }
                        }
                    }.listStyle(.sidebar)
                }
                Divider()
                HStack {
                    Label(library.engineLabel, systemImage: "cpu").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(action: library.clear) { Image(systemName: "trash") }.buttonStyle(.borderless).help("清空媒体库").disabled(library.items.isEmpty)
                }.padding(14)
            }.navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 360)
        } detail: {
            Group {
                if let item = library.selected {
                    if let report = item.report {
                        ReportView(report: report, search: library.search)
                    } else if let error = item.error {
                        ContentUnavailableView {
                            Label("无法读取此文件", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(item.url.lastPathComponent).font(.headline)
                            Text(error).textSelection(.enabled)
                        } actions: {
                            Button("重新检查", action: library.retry)
                            Button("选择其他文件…", action: library.openFiles)
                        }
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("正在读取媒体信息").font(.headline)
                            Text(item.url.lastPathComponent).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else { welcome }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 820, minHeight: 560)
        .navigationTitle("MediaLens")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: library.openFiles) { Label("打开", systemImage: "plus") }.help("打开媒体文件（⌘O）")
                Button(action: library.copyReport) { Label("复制报告", systemImage: "doc.on.doc") }.help("复制报告（⇧⌘C）").disabled(library.selected?.report == nil)
                Menu {
                    Button("导出文本报告…") { library.exportReport(json: false) }
                    Button("导出JSON…") { library.exportReport(json: true) }
                    Divider()
                    Button("重新检查", action: library.retry).disabled(library.selected?.isLoading == true)
                    Button("在 Finder 中显示") {
                        if let url = library.selected?.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                    Button("从列表移除", action: library.removeSelection)
                } label: { Label("更多", systemImage: "ellipsis.circle") }.disabled(library.selected == nil)
            }
        }
        .searchable(text: $library.search, placement: .toolbar, prompt: "查找属性或值")
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            // Providers finish asynchronously; collect in drag order before adding to the library.
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { value, _ in
                            if let url = value as? URL { continuation.resume(returning: url) }
                            else if let data = value as? Data { continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil)) }
                            else { continuation.resume(returning: nil) }
                        }
                    }
                    if let url { urls.append(url) }
                }
                library.add(urls)
            }
            return !providers.isEmpty
        }
        .overlay {
            if isTargeted {
                ZStack {
                    Color.accentColor.opacity(0.08)
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10])).padding(8)
                    Label("松开以检查媒体文件", systemImage: "arrow.down.doc").font(.title2).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }.allowsHitTesting(false)
            }
        }
        .alert("MediaLens", isPresented: Binding(get: { library.notice != nil }, set: { if !$0 { library.notice = nil } })) {
            Button("好") { library.notice = nil }
        } message: { Text(library.notice ?? "") }
    }
    private var welcome: some View {
        VStack(spacing: 0) {
            Image(systemName: "viewfinder").font(.system(size: 66, weight: .ultraLight)).foregroundStyle(Color.accentColor).padding(.bottom, 26)
            Text("看见媒体的每一处细节").font(.system(size: 28, weight: .semibold)).padding(.bottom, 14)
            Text("拖入视频、音频或图片\n容器、编码与轨道信息，一目了然。")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(6)
            Button("选择媒体文件…", action: library.openFiles).buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 28)
            HStack(spacing: 24) {
                Label("批量检查", systemImage: "square.stack")
                Label("本机解析", systemImage: "desktopcomputer")
                Label("导出报告", systemImage: "square.and.arrow.up")
            }.font(.caption).foregroundStyle(.secondary).padding(.top, 36)
            Text("⌘O 打开文件").font(.caption2).foregroundStyle(.tertiary).padding(.top, 30)
        }.padding(36).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReportView: View {
    let report: MediaReport
    let search: String
    private var sections: [InfoSection] {
        guard !search.isEmpty else { return report.sections }
        return report.sections.compactMap { section in
            let fields = section.fields.filter { section.title.localizedCaseInsensitiveContains(search) || $0.key.localizedCaseInsensitiveContains(search) || $0.value.localizedCaseInsensitiveContains(search) }
            return fields.isEmpty ? nil : InfoSection(id: section.id, title: section.title, symbol: section.symbol, fields: fields)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if sections.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(section.title, systemImage: section.symbol).font(.headline)
                            VStack(spacing: 0) {
                                ForEach(Array(section.fields.enumerated()), id: \.offset) { index, field in
                                    HStack(alignment: .top, spacing: 16) {
                                        Text(field.key).foregroundStyle(.secondary).frame(width: 180, alignment: .leading)
                                        Text(field.value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    }.font(.system(size: 13)).padding(.horizontal, 12).padding(.vertical, 4)
                                        .background(index.isMultiple(of: 2) ? Color(nsColor: .controlBackgroundColor).opacity(0.65) : .clear)
                                }
                            }.clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                HStack {
                    Label(report.engine, systemImage: "cpu")
                    Text("·")
                    Text("仅展示文件提供的属性")
                    Spacer()
                }.font(.caption).foregroundStyle(.tertiary)
            }.padding(24).frame(maxWidth: 1080, alignment: .leading).frame(maxWidth: .infinity)
        }
        .id(report.url)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                MediaFileView(url: report.url).frame(width: 92, height: 88)
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(report.url.lastPathComponent).font(.system(size: 18, weight: .semibold)).textSelection(.enabled).lineLimit(2)
                        Text(report.format).font(.callout).foregroundStyle(.secondary)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 24) { summaryMetrics }
                        VStack(alignment: .leading, spacing: 4) { summaryMetrics }
                    }
                    if let audio = report.audioSummary { Label(audio, systemImage: "waveform").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            Divider()
        }
    }
    @ViewBuilder private var summaryMetrics: some View {
        metric("大小", DisplayValue.bytes(report.size))
        if report.duration != nil { metric("时长", DisplayValue.duration(report.duration)) }
        if let video = report.videoSummary { metric("画面", video) }
    }
    private func metric(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced)).textSelection(.enabled)
        }
    }
}
