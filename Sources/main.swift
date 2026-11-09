// Idea Box — a floating "+ 想法" pill that opens a small text box.
// Enter appends to ~/Desktop/Ideas.md, Shift+Enter is a newline.
import Cocoa

// MARK: - Copy (translate the UI here)

enum L {
    static let pill = "＋ 想法"
    static let placeholder = "记下此刻的想法…"
    static let hint = "⏎ 保存 · ⇧⏎ 换行 · esc 收起"
    static let empty = "今天还没有想法"
    static let saveFailed = "保存失败："
    static func count(_ n: Int) -> String { "今天 \(n) 条" }
    static func saved(_ n: Int) -> String { "✓ 已保存 · 今天 \(n) 条" }
}

// MARK: - Storage

enum IdeaStore {
    static var fileURL: URL {
        if let override = ProcessInfo.processInfo.environment["IDEA_BOX_FILE"], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Ideas.md")
    }

    /// "November 2026" — one heading per month, never per day.
    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd"
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func monthKey(_ date: Date = Date()) -> String { monthFormatter.string(from: date) }
    static func dayKey(_ date: Date = Date()) -> String { dayFormatter.string(from: date) }

    static func read() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "# Ideas\n"
    }

    static func ensureFile(_ url: URL = IdeaStore.fileURL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# Ideas\n".write(to: url, atomically: true, encoding: .utf8)
    }

    /// Entries for today: lines under this month's heading that start with "- dd ".
    static func countToday(in content: String? = nil) -> Int {
        let lines = (content ?? read()).components(separatedBy: "\n")
        guard let start = lines.lastIndex(of: "## \(monthKey())") else { return 0 }
        let prefix = "- \(dayKey()) "
        var count = 0
        var index = start + 1
        while index < lines.count {
            if lines[index].hasPrefix("## ") { break }
            if lines[index].hasPrefix(prefix) { count += 1 }
            index += 1
        }
        return count
    }

    /// One entry as markdown: "- 09 21:16 text", continuations indented.
    static func format(_ text: String, at date: Date = Date()) -> [String] {
        let parts = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let head = parts.first else { return [] }
        var out = ["- \(dayKey(date)) \(timeFormatter.string(from: date)) \(head)"]
        for line in parts.dropFirst() where !line.isEmpty {
            out.append("  \(line)")
        }
        return out
    }

    @discardableResult
    static func append(_ text: String, at date: Date = Date()) throws -> (file: URL, count: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = fileURL
        try ensureFile(url)
        guard !trimmed.isEmpty else { return (url, countToday()) }

        var lines = read().components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }

        let heading = "## \(monthKey(date))"
        let entry = format(trimmed, at: date)

        if let start = lines.lastIndex(of: heading) {
            var end = lines.count
            var index = start + 1
            while index < lines.count {
                if lines[index].hasPrefix("## ") { end = index; break }
                index += 1
            }
            var insertAt = end
            while insertAt > start + 1 && lines[insertAt - 1].isEmpty { insertAt -= 1 }
            lines.insert(contentsOf: entry, at: insertAt)
        } else {
            while let last = lines.last, last.isEmpty { lines.removeLast() }
            lines.append("")
            lines.append(heading)
            lines.append(contentsOf: entry)
        }

        let out = lines.joined(separator: "\n") + "\n"
        try out.write(to: url, atomically: true, encoding: .utf8)
        return (url, countToday(in: out))
    }
}

// MARK: - Small views

/// Labels must never swallow clicks meant for the text view behind them.
final class PassthroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// The collapsed state: a frosted capsule (NSVisualEffectView) that opens the box.
final class PillView: NSVisualEffectView {
    var onTap: (() -> Void)?

    init(width: CGFloat, height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = height / 2
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        updateBorder()

        let label = PassthroughLabel(labelWithString: L.pill)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.frame = NSRect(x: 0, y: (height - 17) / 2, width: width, height: 17)
        label.autoresizingMask = [.width, .minYMargin]
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorder()
    }

    private func updateBorder() {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        layer?.borderColor = (dark ? NSColor(calibratedWhite: 1, alpha: 0.16) : NSColor(calibratedWhite: 0, alpha: 0.12)).cgColor
    }

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }
}

final class IdeaTextView: NSTextView {
    var onSave: (() -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:                       // Return / keypad Enter
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                onSave?()
            }
        case 53:                           // Escape
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}

/// Solid card (no vibrancy): white in light mode, dark grey in dark mode.
final class CardView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.masksToBounds = false
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func applyColors() {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        layer?.backgroundColor = (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor.white).cgColor
        layer?.borderColor = (dark ? NSColor(calibratedWhite: 1, alpha: 0.14) : NSColor(calibratedWhite: 0, alpha: 0.12)).cgColor
    }
}

/// The input surface: a white, rounded box the text sits on.
final class SurfaceView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func applyColors() {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        layer?.backgroundColor = (dark ? NSColor(calibratedWhite: 0.17, alpha: 1) : NSColor.white).cgColor
        layer?.borderColor = (dark ? NSColor(calibratedWhite: 1, alpha: 0.12) : NSColor(calibratedWhite: 0, alpha: 0.14)).cgColor
    }
}

/// Borderless windows ignore the keyboard unless they say otherwise.
final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate {
    private enum Mode { case pill, editor }

    private let pillSize = NSSize(width: 112, height: 38)
    private let editorSize = NSSize(width: 380, height: 200)
    private let margin: CGFloat = 18

    private var window: FloatingWindow!
    private var pill: PillView!
    private var editor: NSView!
    private var textView: IdeaTextView!
    private var placeholder: PassthroughLabel!
    private var status: PassthroughLabel!
    private var counter: Int = 0
    private var mode: Mode = .pill
    private var collapseTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        refreshCount()
        setMode(.pill, focus: false)
        if CommandLine.arguments.contains("--open-editor") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.setMode(.editor, focus: true)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.orderFrontRegardless()
        return true
    }

    // MARK: menu

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Open Idea Box", action: #selector(openBox), keyEquivalent: "n")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Idea Box", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = main
    }

    @objc private func openBox() {
        setMode(.editor, focus: true)
    }

    // MARK: window

    private func buildWindow() {
        window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: pillSize.width, height: pillSize.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.delegate = self

        let root = NSView(frame: NSRect(origin: .zero, size: pillSize))
        root.wantsLayer = true
        window.contentView = root

        pill = PillView(width: pillSize.width, height: pillSize.height)
        pill.onTap = { [weak self] in self?.setMode(.editor, focus: true) }
        root.addSubview(pill)

        editor = buildEditor(size: editorSize)
        editor.isHidden = true
        root.addSubview(editor)
    }

    private func buildEditor(size: NSSize) -> NSView {
        let container = CardView(frame: NSRect(origin: .zero, size: size))

        let width = size.width
        let surfaceTop = size.height - 12
        let surfaceBottom: CGFloat = 44
        let surfaceRect = NSRect(x: 12, y: surfaceBottom, width: width - 24, height: surfaceTop - surfaceBottom)

        let surface = SurfaceView(frame: surfaceRect)

        let inset: CGFloat = 8
        let scroll = NSScrollView(frame: surface.bounds.insetBy(dx: inset, dy: 6))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.autoresizingMask = [.width, .height]

        textView = IdeaTextView(frame: scroll.bounds)
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self
        textView.onSave = { [weak self] in self?.save() }
        textView.onEscape = { [weak self] in self?.setMode(.pill, focus: false) }
        scroll.documentView = textView
        surface.addSubview(scroll)

        placeholder = PassthroughLabel(labelWithString: L.placeholder)
        placeholder.font = .systemFont(ofSize: 14)
        placeholder.textColor = .placeholderTextColor
        placeholder.frame = NSRect(
            x: surfaceRect.minX + inset + 4,
            y: surfaceTop - 26,
            width: width - 60,
            height: 18
        )

        status = PassthroughLabel(labelWithString: "")
        status.font = .systemFont(ofSize: 11.5)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 14, y: 14, width: width - 170, height: 16)

        let hint = PassthroughLabel(labelWithString: L.hint)
        hint.font = .systemFont(ofSize: 11.5)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .right
        hint.frame = NSRect(x: width - 230, y: 14, width: 216, height: 16)

        container.addSubview(surface)
        container.addSubview(placeholder)
        container.addSubview(status)
        container.addSubview(hint)
        return container
    }

    private func setMode(_ next: Mode, focus: Bool) {
        mode = next
        collapseTimer?.invalidate()

        let size = next == .pill ? pillSize : editorSize
        let target = frame(for: size)

        pill.isHidden = next != .pill
        editor.isHidden = next != .editor
        window.contentView?.frame = NSRect(origin: .zero, size: size)
        pill.frame = NSRect(origin: .zero, size: pillSize)
        editor.frame = NSRect(origin: .zero, size: editorSize)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(target, display: true)
        }

        if next == .editor {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(textView)
            refreshCount()
        } else {
            if focus { NSApp.activate(ignoringOtherApps: true) }
            window.orderFrontRegardless()
        }
    }

    private func frame(for size: NSSize) -> NSRect {
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSRect(
            x: visible.maxX - size.width - margin,
            y: visible.minY + margin,
            width: size.width,
            height: size.height
        )
    }

    // MARK: saving

    private func refreshCount() {
        counter = IdeaStore.countToday()
        status.stringValue = counter == 0 ? L.empty : L.count(counter)
    }

    private func save() {
        let text = textView.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let result = try IdeaStore.append(text)
            counter = result.count
            textView.string = ""
            placeholder.isHidden = false
            status.stringValue = L.saved(counter)
            NSSound(named: "Tink")?.play()

            collapseTimer?.invalidate()
            collapseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.setMode(.pill, focus: false)
            }
        } catch {
            status.stringValue = L.saveFailed + error.localizedDescription
        }
    }

    func textDidChange(_ notification: Notification) {
        placeholder.isHidden = !textView.string.isEmpty
    }

    /// Clicking anywhere else folds the box back into the pill.
    func windowDidResignKey(_ notification: Notification) {
        // IDEA_BOX_KEEP_OPEN=1 keeps the box open (screenshot/automation aid).
        if ProcessInfo.processInfo.environment["IDEA_BOX_KEEP_OPEN"] == "1" { return }
        if mode == .editor { setMode(.pill, focus: false) }
    }
}

// MARK: - Self test (no window): IDEA_BOX_FILE=/tmp/x.md ./IdeaBox --selftest "text"

if CommandLine.arguments.contains("--selftest") {
    let index = CommandLine.arguments.firstIndex(of: "--selftest")!
    let text = CommandLine.arguments.count > index + 1 ? CommandLine.arguments[index + 1] : "selftest idea"
    do {
        let result = try IdeaStore.append(text)
        print("ok file=\(result.file.path) count=\(result.count)")
        exit(0)
    } catch {
        print("fail \(error)")
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
