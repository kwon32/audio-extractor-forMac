import AppKit
import UniformTypeIdentifiers

enum Preset: Int, CaseIterable {
    case transcription
    case highQualityMP3
    case wav
    case audioCopy

    var title: String {
        switch self {
        case .transcription: return "전사용 MP3 (16kHz · 모노)"
        case .highQualityMP3: return "고음질 MP3"
        case .wav: return "WAV (무손실)"
        case .audioCopy: return "원본 오디오 복사 (빠름)"
        }
    }

    var outputExtension: String {
        switch self {
        case .transcription, .highQualityMP3: return "mp3"
        case .wav: return "wav"
        case .audioCopy: return "m4a"
        }
    }

    var arguments: [String] {
        switch self {
        case .transcription:
            return ["-vn", "-ac", "1", "-ar", "16000", "-b:a", "32k"]
        case .highQualityMP3:
            return ["-vn", "-codec:a", "libmp3lame", "-q:a", "0"]
        case .wav:
            return ["-vn"]
        case .audioCopy:
            return ["-vn", "-c:a", "copy"]
        }
    }
}

protocol DropViewDelegate: AnyObject {
    func dropView(didReceive urls: [URL])
}

final class DropView: NSView {
    weak var delegate: DropViewDelegate?
    private let label = NSTextField(labelWithString: "여기에 영상이나 폴더를 끌어다 놓으세요")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        registerForDraggedTypes([.fileURL])

        label.alignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { restoreStyle() }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        restoreStyle()
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return false }
        delegate?.dropView(didReceive: urls)
        return true
    }

    private func restoreStyle() {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
}

final class ViewController: NSViewController, DropViewDelegate {
    private let supportedExtensions: Set<String> = ["mp4", "mov", "mkv", "avi", "webm", "m4v", "flv", "wmv", "mts", "m2ts"]
    private var files: [URL] = []
    private var currentProcess: Process?
    private var isConverting = false

    private let fileList = NSTextView()
    private let presetPopup = NSPopUpButton()
    private let statusLabel = NSTextField(labelWithString: "영상이나 폴더를 추가하세요.")
    private let progress = NSProgressIndicator()
    private let convertButton = NSButton(title: "음성 추출", target: nil, action: nil)
    private let clearButton = NSButton(title: "모두 지우기", target: nil, action: nil)
    private let addButton = NSButton(title: "파일 추가", target: nil, action: nil)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 560))
        setupUI()
    }

    private func setupUI() {
        let title = NSTextField(labelWithString: "움성 추출기")
        title.font = .systemFont(ofSize: 26, weight: .bold)

        let subtitle = NSTextField(labelWithString: "ffmpeg로 영상에서 오디오만 빠르게 추출합니다.")
        subtitle.textColor = .secondaryLabelColor

        let dropView = DropView()
        dropView.delegate = self
        dropView.translatesAutoresizingMaskIntoConstraints = false

        addButton.target = self
        addButton.action = #selector(addFiles)
        clearButton.target = self
        clearButton.action = #selector(clearFiles)

        let buttonRow = NSStackView(views: [addButton, clearButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        fileList.isEditable = false
        fileList.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        fileList.textContainerInset = NSSize(width: 8, height: 8)
        let scroll = NSScrollView()
        scroll.documentView = fileList
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let presetLabel = NSTextField(labelWithString: "추출 형식")
        presetLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        Preset.allCases.forEach { presetPopup.addItem(withTitle: $0.title) }
        presetPopup.selectItem(at: 0)

        let presetRow = NSStackView(views: [presetLabel, presetPopup])
        presetRow.orientation = .horizontal
        presetRow.spacing = 12
        presetPopup.setContentHuggingPriority(.defaultLow, for: .horizontal)

        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle

        convertButton.target = self
        convertButton.action = #selector(convertOrCancel)
        convertButton.bezelStyle = .rounded
        convertButton.keyEquivalent = "\r"
        convertButton.isEnabled = false

        let bottomRow = NSStackView(views: [statusLabel, convertButton])
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 12
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [title, subtitle, dropView, buttonRow, scroll, presetRow, progress, bottomRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -22),
            dropView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dropView.heightAnchor.constraint(equalToConstant: 90),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 180),
            presetRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bottomRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    func dropView(didReceive urls: [URL]) { add(urls: urls) }

    @objc private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "추가"
        panel.begin { [weak self] response in
            if response == .OK { self?.add(urls: panel.urls) }
        }
    }

    @objc private func clearFiles() {
        guard !isConverting else { return }
        files.removeAll()
        refreshFileList()
    }

    private func add(urls: [URL]) {
        guard !isConverting else { return }
        var candidates: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    candidates.append(contentsOf: contents.filter { supportedExtensions.contains($0.pathExtension.lowercased()) })
                }
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                candidates.append(url)
            }
        }
        for url in candidates.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) where !files.contains(url) {
            files.append(url)
        }
        refreshFileList()
    }

    private func refreshFileList() {
        fileList.string = files.enumerated().map { "\($0.offset + 1). \($0.element.lastPathComponent)" }.joined(separator: "\n")
        convertButton.isEnabled = !files.isEmpty
        statusLabel.stringValue = files.isEmpty ? "영상이나 폴더를 추가하세요." : "\(files.count)개 파일 선택됨 · 원본과 같은 폴더에 저장"
    }

    @objc private func convertOrCancel() {
        if isConverting {
            isConverting = false
            currentProcess?.terminate()
            statusLabel.stringValue = "추출을 취소하는 중입니다…"
        } else {
            startConversion()
        }
    }

    private func ffmpegURL() -> URL? {
        let paths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    private func uniqueOutputURL(for input: URL, preset: Preset) -> URL {
        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        var candidate = directory.appendingPathComponent(base).appendingPathExtension(preset.outputExtension)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) \(suffix)").appendingPathExtension(preset.outputExtension)
            suffix += 1
        }
        return candidate
    }

    private func startConversion() {
        guard let ffmpeg = ffmpegURL() else {
            showAlert(title: "ffmpeg가 없습니다", message: "Homebrew에서 brew install ffmpeg로 설치해 주세요.")
            return
        }
        guard let preset = Preset(rawValue: presetPopup.indexOfSelectedItem) else { return }

        isConverting = true
        setControlsEnabled(false)
        convertButton.isEnabled = true
        convertButton.title = "취소"
        progress.maxValue = Double(files.count)
        progress.doubleValue = 0
        let inputs = files

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var successes: [URL] = []
            var failures: [String] = []

            for (index, input) in inputs.enumerated() {
                if !self.isConverting { break }
                let output = self.uniqueOutputURL(for: input, preset: preset)
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "\(index + 1)/\(inputs.count)  \(input.lastPathComponent)"
                }

                let process = Process()
                process.executableURL = ffmpeg
                process.arguments = ["-hide_banner", "-nostdin", "-y", "-i", input.path] + preset.arguments + [output.path]
                let errorPipe = Pipe()
                process.standardError = errorPipe
                process.standardOutput = FileHandle.nullDevice
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    _ = handle.availableData
                }
                self.currentProcess = process

                do {
                    try process.run()
                    process.waitUntilExit()
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    if process.terminationStatus == 0 {
                        successes.append(output)
                    } else if self.isConverting {
                        failures.append(input.lastPathComponent)
                        try? FileManager.default.removeItem(at: output)
                    }
                } catch {
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    failures.append(input.lastPathComponent)
                    try? FileManager.default.removeItem(at: output)
                }

                DispatchQueue.main.async { self.progress.doubleValue = Double(index + 1) }
            }

            let wasCancelled = !self.isConverting
            self.currentProcess = nil
            DispatchQueue.main.async {
                self.finishConversion(successes: successes, failures: failures, cancelled: wasCancelled)
            }
        }
    }

    private func finishConversion(successes: [URL], failures: [String], cancelled: Bool) {
        isConverting = false
        setControlsEnabled(true)
        convertButton.title = "음성 추출"
        convertButton.isEnabled = !files.isEmpty

        if cancelled {
            statusLabel.stringValue = "취소됨 · 완료 \(successes.count)개"
        } else if failures.isEmpty {
            statusLabel.stringValue = "완료 · \(successes.count)개 파일 추출 완료"
            NSSound(named: "Glass")?.play()
            if let first = successes.first {
                NSWorkspace.shared.activateFileViewerSelecting(successes.isEmpty ? [first] : successes)
            }
        } else {
            statusLabel.stringValue = "완료 \(successes.count)개 · 실패 \(failures.count)개"
            showAlert(title: "일부 파일을 처리하지 못했습니다", message: failures.joined(separator: "\n"))
        }
    }

    private func setControlsEnabled(_ enabled: Bool) {
        addButton.isEnabled = enabled
        clearButton.isEnabled = enabled
        presetPopup.isEnabled = enabled
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = ViewController()
        window = NSWindow(contentViewController: controller)
        window.title = "움성 추출기"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
