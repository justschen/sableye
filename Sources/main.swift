import Cocoa

// MARK: - Persistence

enum Store {
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Sableye", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.txt")
    }

    static func load() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    static func save(_ text: String) {
        try? text.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Status badge (rounded pill in the header)

final class BadgeView: NSView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        label.font = .systemFont(ofSize: 11.5, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [iconView, label])
        stack.orientation = .horizontal
        stack.spacing = 5
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            iconView.widthAnchor.constraint(equalToConstant: 13),
            iconView.heightAnchor.constraint(equalToConstant: 13),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(hidden: Bool) {
        let symbol = hidden ? "eye.slash.fill" : "eye.fill"
        let tint = hidden ? NSColor.systemGreen : NSColor.systemOrange
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        iconView.contentTintColor = tint
        label.stringValue = hidden ? "Hidden" : "Visible"
        label.textColor = tint
        layer?.backgroundColor = tint.withAlphaComponent(0.15).cgColor
    }
}

// MARK: - Lightweight Markdown renderer

enum MarkdownRenderer {
    static func render(_ markdown: String, baseSize: CGFloat = 14) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        let textColor = NSColor.labelColor
        var inFence = false
        var fence: [String] = []

        func flushFence() {
            let para = NSMutableParagraphStyle()
            para.paragraphSpacing = 10
            para.paragraphSpacingBefore = 4
            para.firstLineHeadIndent = 14
            para.headIndent = 14
            let a: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: baseSize - 1, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.10),
                .paragraphStyle: para,
            ]
            result.append(NSAttributedString(string: fence.joined(separator: "\n") + "\n", attributes: a))
            fence.removeAll()
        }

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inFence { flushFence() }
                inFence.toggle()
                continue
            }
            if inFence { fence.append(raw); continue }
            if trimmed.isEmpty { result.append(NSAttributedString(string: "\n")); continue }

            // Heading (#..######)
            if trimmed.first == "#" {
                var level = 0
                for ch in trimmed { if ch == "#" { level += 1 } else { break } }
                let chars = Array(trimmed)
                if level >= 1 && level <= 6 && chars.count > level && chars[level] == " " {
                    let content = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    let sizes: [CGFloat] = [baseSize + 12, baseSize + 8, baseSize + 5, baseSize + 3, baseSize + 1, baseSize]
                    let f = NSFont.boldSystemFont(ofSize: sizes[level - 1])
                    let para = NSMutableParagraphStyle()
                    para.paragraphSpacingBefore = 12
                    para.paragraphSpacing = 4
                    let m = NSMutableAttributedString(attributedString: attributedInline(content, base: f, color: textColor))
                    m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
                    m.append(NSAttributedString(string: "\n"))
                    result.append(m)
                    continue
                }
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                let para = NSMutableParagraphStyle()
                para.paragraphSpacingBefore = 6
                para.paragraphSpacing = 8
                let a: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 5),
                    .strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                    .strikethroughColor: NSColor.separatorColor,
                    .paragraphStyle: para,
                ]
                result.append(NSAttributedString(string: "\u{00A0}\u{2003}\u{2003}\u{2003}\u{2003}\u{2003}\u{2003}\u{2003}\u{2003}\u{2003}\u{2003}\n", attributes: a))
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                let content = String(trimmed.drop(while: { $0 == ">" || $0 == " " }))
                let para = NSMutableParagraphStyle()
                para.firstLineHeadIndent = 16
                para.headIndent = 16
                para.paragraphSpacing = 4
                let m = NSMutableAttributedString(attributedString: attributedInline(content, base: NSFont.systemFont(ofSize: baseSize), color: .secondaryLabelColor))
                m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
                m.append(NSAttributedString(string: "\n"))
                result.append(m)
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let content = String(trimmed.dropFirst(2))
                let para = NSMutableParagraphStyle()
                para.firstLineHeadIndent = 14
                para.headIndent = 30
                para.paragraphSpacing = 3
                let f = NSFont.systemFont(ofSize: baseSize)
                let m = NSMutableAttributedString(string: "•  ", attributes: [.font: f, .foregroundColor: NSColor.secondaryLabelColor])
                m.append(attributedInline(content, base: f, color: textColor))
                m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
                m.append(NSAttributedString(string: "\n"))
                result.append(m)
                continue
            }

            // Ordered list
            if let dot = trimmed.firstIndex(of: "."),
               dot != trimmed.startIndex,
               trimmed[trimmed.startIndex..<dot].allSatisfy({ $0.isNumber }),
               trimmed.index(after: dot) < trimmed.endIndex,
               trimmed[trimmed.index(after: dot)] == " " {
                let number = String(trimmed[trimmed.startIndex..<dot])
                let content = String(trimmed[trimmed.index(dot, offsetBy: 2)...])
                let para = NSMutableParagraphStyle()
                para.firstLineHeadIndent = 14
                para.headIndent = 32
                para.paragraphSpacing = 3
                let f = NSFont.systemFont(ofSize: baseSize)
                let m = NSMutableAttributedString(string: "\(number).  ", attributes: [.font: NSFont.systemFont(ofSize: baseSize, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor])
                m.append(attributedInline(content, base: f, color: textColor))
                m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
                m.append(NSAttributedString(string: "\n"))
                result.append(m)
                continue
            }

            // Paragraph
            let para = NSMutableParagraphStyle()
            para.paragraphSpacing = 7
            para.lineSpacing = 2
            let m = NSMutableAttributedString(attributedString: attributedInline(trimmed, base: NSFont.systemFont(ofSize: baseSize), color: textColor))
            m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
            m.append(NSAttributedString(string: "\n"))
            result.append(m)
        }
        if inFence { flushFence() }
        return result
    }

    // Inline styling: **bold**, *italic*/_italic_, `code`, ~~strike~~, [text](url), \escape
    private static func attributedInline(_ text: String, base: NSFont, color: NSColor) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let chars = Array(text)
        var i = 0
        var bold = false, italic = false, strike = false, code = false

        func currentFont() -> NSFont {
            if code { return .monospacedSystemFont(ofSize: base.pointSize, weight: .regular) }
            var traits: NSFontDescriptor.SymbolicTraits = []
            if bold { traits.insert(.bold) }
            if italic { traits.insert(.italic) }
            if traits.isEmpty { return base }
            let d = base.fontDescriptor.withSymbolicTraits(traits)
            return NSFont(descriptor: d, size: base.pointSize) ?? base
        }
        func attrs() -> [NSAttributedString.Key: Any] {
            var a: [NSAttributedString.Key: Any] = [.font: currentFont(), .foregroundColor: color]
            if code {
                a[.foregroundColor] = NSColor.systemPink
                a[.backgroundColor] = NSColor.secondaryLabelColor.withAlphaComponent(0.12)
            }
            if strike { a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            return a
        }
        func emit(_ s: String) { out.append(NSAttributedString(string: s, attributes: attrs())) }

        while i < chars.count {
            let c = chars[i]
            if c == "`" { code.toggle(); i += 1; continue }
            if code { emit(String(c)); i += 1; continue }
            if c == "\\", i + 1 < chars.count { emit(String(chars[i + 1])); i += 2; continue }
            if (c == "*" || c == "_"), i + 1 < chars.count, chars[i + 1] == c { bold.toggle(); i += 2; continue }
            if c == "~", i + 1 < chars.count, chars[i + 1] == "~" { strike.toggle(); i += 2; continue }
            if c == "*" || c == "_" { italic.toggle(); i += 1; continue }
            if c == "[", let close = indexOf(chars, "]", from: i + 1),
               close + 1 < chars.count, chars[close + 1] == "(",
               let paren = indexOf(chars, ")", from: close + 2) {
                let label = String(chars[(i + 1)..<close])
                let urlStr = String(chars[(close + 2)..<paren])
                var a = attrs()
                a[.foregroundColor] = NSColor.linkColor
                a[.underlineStyle] = NSUnderlineStyle.single.rawValue
                if let url = URL(string: urlStr) { a[.link] = url }
                out.append(NSAttributedString(string: label, attributes: a))
                i = paren + 1
                continue
            }
            emit(String(c)); i += 1
        }
        return out
    }

    private static func indexOf(_ chars: [Character], _ target: Character, from: Int) -> Int? {
        var i = from
        while i < chars.count { if chars[i] == target { return i }; i += 1 }
        return nil
    }
}

// MARK: - Floating panel

// A non-activating panel is the key to true cross-Space stickiness. An ordinary
// NSWindow belonging to a background app cannot draw over *another* app's
// full-screen Space, so it gets left behind when you swipe. A non-activating
// floating panel can: it shows over other apps (including their full-screen
// Spaces) without stealing focus, while still becoming key so you can type.
final class StickyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, NSWindowDelegate {
    var window: NSWindow!
    var textView: NSTextView!
    var editorScroll: NSScrollView!
    var previewScroll: NSScrollView!
    var previewTextView: NSTextView!
    var previewSegment: NSSegmentedControl!
    var statusBadge: BadgeView!
    var hideSwitch: NSSwitch!
    var onTopSwitch: NSSwitch!
    var opacitySlider: NSSlider!
    var isPreviewMode = false
    var saveTimer: Timer?

    // Compact (icon-only) toolbar shown when the window is too narrow for the
    // full labeled controls; each labeled control collapses to one icon button.
    var compactPreviewButton: NSButton!
    var compactHideButton: NSButton!
    var compactTopButton: NSButton!
    var compactOpacityButton: NSButton!
    var compactOpacitySlider: NSSlider?
    var opacityPopover: NSPopover?
    var expandedToolbarItems: [NSView] = []
    var compactToolbarItems: [NSView] = []
    var expandedToolbarWidth: CGFloat = 0
    var isCompactToolbar = false
    var isOnTop = true

    // Whether the window is excluded from screen capture.
    var isHiddenFromCapture = true {
        didSet { applyCaptureState() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        applyCaptureState()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        updateToolbarLayout()
    }

    // The main UI lives in an NSPanel, which AppKit does *not* count in its
    // automatic "last window closed" tally. With auto-terminate on, dismissing
    // any auxiliary window (e.g. the opacity popover) made AppKit believe the
    // last window had closed and quit the entire app. So we opt out of
    // auto-terminate and quit explicitly only when the main panel itself closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === window {
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Store.save(textView.string)
    }

    // MARK: Window

    private func buildWindow() {
        let frame = NSRect(x: 0, y: 0, width: 640, height: 460)
        let panel = StickyPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Float as a utility panel and keep it alive when the app isn't frontmost.
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        window = panel
        window.delegate = self
        window.title = "Sableye"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("SableyeWindow")
        window.backgroundColor = NSColor.windowBackgroundColor

        // Stay above other windows and follow you across Spaces *and* other
        // apps' full-screen Spaces, so swiping between full-screen apps keeps
        // the window pinned in view.
        window.level = Self.onTopLevel
        window.collectionBehavior = Self.stickyBehavior
        window.hidesOnDeactivate = false
        // Let the user freely resize the window small in either dimension.
        window.minSize = NSSize(width: 180, height: 120)

        let content = NSView(frame: frame)
        window.contentView = content

        // --- Modern blurred header bar ---
        let header = NSVisualEffectView()
        header.material = .headerView
        header.blendingMode = .withinWindow
        header.state = .active
        header.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(header)

        statusBadge = BadgeView()

        // Edit / Preview segmented control
        previewSegment = NSSegmentedControl(
            labels: ["Edit", "Preview"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(changeMode(_:))
        )
        previewSegment.setImage(NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Edit"), forSegment: 0)
        previewSegment.setImage(NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "Preview"), forSegment: 1)
        previewSegment.setImageScaling(.scaleProportionallyDown, forSegment: 0)
        previewSegment.setImageScaling(.scaleProportionallyDown, forSegment: 1)
        previewSegment.segmentStyle = .rounded
        previewSegment.selectedSegment = 0
        previewSegment.toolTip = "Toggle Markdown preview (⇧⌘P)"
        previewSegment.translatesAutoresizingMaskIntoConstraints = false

        // Hide-from-capture switch
        hideSwitch = NSSwitch()
        hideSwitch.state = isHiddenFromCapture ? .on : .off
        hideSwitch.target = self
        hideSwitch.action = #selector(toggleHidden(_:))
        let hideCaption = NSTextField(labelWithString: "Hide")
        hideCaption.font = .systemFont(ofSize: 11, weight: .medium)
        hideCaption.textColor = .secondaryLabelColor
        hideCaption.toolTip = "Hide this window from screen sharing and recording"
        let hideStack = NSStackView(views: [hideCaption, hideSwitch])
        hideStack.spacing = 5
        hideStack.alignment = .centerY

        // Always-on-top switch
        onTopSwitch = NSSwitch()
        onTopSwitch.state = .on
        onTopSwitch.target = self
        onTopSwitch.action = #selector(toggleOnTop(_:))
        let topCaption = NSTextField(labelWithString: "Top")
        topCaption.font = .systemFont(ofSize: 11, weight: .medium)
        topCaption.textColor = .secondaryLabelColor
        topCaption.toolTip = "Keep window above other apps"
        let topStack = NSStackView(views: [topCaption, onTopSwitch])
        topStack.spacing = 5
        topStack.alignment = .centerY

        // Opacity control
        let opacityIcon = NSImageView()
        opacityIcon.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Opacity")
        opacityIcon.contentTintColor = .secondaryLabelColor
        opacityIcon.translatesAutoresizingMaskIntoConstraints = false
        opacityIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
        opacityIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let opacity = NSSlider(value: 1.0, minValue: 0.3, maxValue: 1.0, target: self, action: #selector(changeOpacity(_:)))
        opacity.controlSize = .small
        opacity.toolTip = "Window opacity"
        opacity.translatesAutoresizingMaskIntoConstraints = false
        opacity.widthAnchor.constraint(equalToConstant: 80).isActive = true
        opacitySlider = opacity
        let opacityStack = NSStackView(views: [opacityIcon, opacity])
        opacityStack.spacing = 5
        opacityStack.alignment = .centerY

        func verticalSeparator() -> NSBox {
            let v = NSBox()
            v.boxType = .separator
            v.translatesAutoresizingMaskIntoConstraints = false
            v.widthAnchor.constraint(equalToConstant: 1).isActive = true
            v.heightAnchor.constraint(equalToConstant: 22).isActive = true
            return v
        }

        let bar = NSStackView()
        bar.orientation = .horizontal
        bar.alignment = .centerY
        bar.spacing = 10
        bar.translatesAutoresizingMaskIntoConstraints = false

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Compact icon buttons: each collapses a labeled control into a single
        // icon button. They stay hidden until the window is too narrow to fit
        // the full controls (see updateToolbarLayout()).
        func compactButton(symbol: String, tooltip: String, toggle: Bool, action: Selector) -> NSButton {
            let b = NSButton()
            b.translatesAutoresizingMaskIntoConstraints = false
            b.bezelStyle = .texturedRounded
            b.setButtonType(toggle ? .toggle : .momentaryPushIn)
            b.imagePosition = .imageOnly
            b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
            b.imageScaling = .scaleProportionallyDown
            b.toolTip = tooltip
            b.target = self
            b.action = action
            b.isHidden = true
            b.widthAnchor.constraint(equalToConstant: 30).isActive = true
            return b
        }

        compactPreviewButton = compactButton(symbol: "square.and.pencil", tooltip: "Toggle Markdown preview (⇧⌘P)", toggle: true, action: #selector(togglePreviewCompact(_:)))
        compactHideButton = compactButton(symbol: "eye.slash.fill", tooltip: "Hide from screen sharing (⇧⌘H)", toggle: true, action: #selector(toggleHiddenCompact(_:)))
        compactHideButton.state = isHiddenFromCapture ? .on : .off
        compactTopButton = compactButton(symbol: "pin.fill", tooltip: "Keep window above other apps", toggle: true, action: #selector(toggleTopCompact(_:)))
        compactTopButton.state = isOnTop ? .on : .off
        compactOpacityButton = compactButton(symbol: "circle.lefthalf.filled", tooltip: "Window opacity", toggle: false, action: #selector(showOpacityPopover(_:)))

        let sep1 = verticalSeparator()
        let sep2 = verticalSeparator()

        bar.addArrangedSubview(statusBadge)
        bar.addArrangedSubview(spacer)
        bar.addArrangedSubview(previewSegment)
        bar.addArrangedSubview(sep1)
        bar.addArrangedSubview(hideStack)
        bar.addArrangedSubview(topStack)
        bar.addArrangedSubview(sep2)
        bar.addArrangedSubview(opacityStack)
        bar.addArrangedSubview(compactPreviewButton)
        bar.addArrangedSubview(compactHideButton)
        bar.addArrangedSubview(compactTopButton)
        bar.addArrangedSubview(compactOpacityButton)
        header.addSubview(bar)

        expandedToolbarItems = [statusBadge, previewSegment, sep1, hideStack, topStack, sep2, opacityStack]
        compactToolbarItems = [compactPreviewButton, compactHideButton, compactTopButton, compactOpacityButton]

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(divider)

        // --- Text editor ---
        editorScroll = NSScrollView()
        editorScroll.translatesAutoresizingMaskIntoConstraints = false
        editorScroll.hasVerticalScroller = true
        editorScroll.borderType = .noBorder
        editorScroll.drawsBackground = false

        textView = NSTextView()
        textView.delegate = self
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.string = Store.load()
        editorScroll.documentView = textView
        content.addSubview(editorScroll)

        // --- Markdown preview (read-only) ---
        previewScroll = NSScrollView()
        previewScroll.translatesAutoresizingMaskIntoConstraints = false
        previewScroll.hasVerticalScroller = true
        previewScroll.borderType = .noBorder
        previewScroll.drawsBackground = false
        previewScroll.isHidden = true

        previewTextView = NSTextView()
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.drawsBackground = false
        previewTextView.textContainerInset = NSSize(width: 14, height: 14)
        previewTextView.autoresizingMask = [.width]
        previewTextView.minSize = NSSize(width: 0, height: 0)
        previewTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = false
        previewTextView.textContainer?.widthTracksTextView = true
        previewTextView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        previewScroll.documentView = previewTextView
        content.addSubview(previewScroll)

        // The toolbar's natural width would otherwise force a hard minimum window
        // width. Make its trailing pin yield (controls clip on the right) and let
        // it compress, so the window can be dragged narrower freely.
        let barTrailing = bar.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14)
        barTrailing.priority = .defaultHigh
        bar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // NSStackView guards its content with a *clipping resistance* priority
        // (default .defaultHigh), which is the real reason the window stopped
        // shrinking at the toolbar's natural width. Lower it (and hugging) so the
        // stack will clip its trailing controls instead of pinning a minimum width.
        bar.setClippingResistancePriority(.defaultLow, for: .horizontal)
        bar.setHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 64),

            bar.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            barTrailing,
            bar.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -9),

            divider.topAnchor.constraint(equalTo: header.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            editorScroll.topAnchor.constraint(equalTo: divider.bottomAnchor),
            editorScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            editorScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            editorScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            previewScroll.topAnchor.constraint(equalTo: divider.bottomAnchor),
            previewScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            previewScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            previewScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        statusBadge.update(hidden: isHiddenFromCapture)

        // Measure the natural width of the full toolbar so we know the point at
        // which it should collapse to the compact icon buttons.
        content.layoutSubtreeIfNeeded()
        expandedToolbarWidth = bar.fittingSize.width
    }

    // MARK: Capture state

    private func applyCaptureState() {
        guard window != nil else { return }
        // The crucial bit: .none excludes the window from screen capture.
        window.sharingType = isHiddenFromCapture ? .none : .readOnly
        statusBadge?.update(hidden: isHiddenFromCapture)
        hideSwitch?.state = isHiddenFromCapture ? .on : .off
        compactHideButton?.state = isHiddenFromCapture ? .on : .off
        compactHideButton?.image = NSImage(
            systemSymbolName: isHiddenFromCapture ? "eye.slash.fill" : "eye.fill",
            accessibilityDescription: isHiddenFromCapture ? "Hidden" : "Visible"
        )
    }

    // MARK: Responsive toolbar

    func windowDidResize(_ notification: Notification) {
        updateToolbarLayout()
    }

    // Swap the full labeled controls for compact icon buttons once the window is
    // too narrow to fit them (accounting for the bar's 16pt leading / 14pt
    // trailing insets). The threshold is the full toolbar's measured width, so
    // the swap is stable and won't oscillate.
    private func updateToolbarLayout() {
        guard let content = window?.contentView, expandedToolbarWidth > 0 else { return }
        let needCompact = content.bounds.width < expandedToolbarWidth + 30
        if needCompact == isCompactToolbar { return }
        isCompactToolbar = needCompact
        for v in expandedToolbarItems { v.isHidden = needCompact }
        for v in compactToolbarItems { v.isHidden = !needCompact }
    }

    // MARK: Actions

    @objc private func toggleHidden(_ sender: NSSwitch) {
        isHiddenFromCapture = (sender.state == .on)
    }

    @objc private func toggleHiddenCompact(_ sender: NSButton) {
        isHiddenFromCapture = (sender.state == .on)
    }

    // Above full-screen apps so the panel stays pinned across Space swipes.
    // With a non-activating StickyPanel this level no longer pins the window to
    // its origin Space, so it follows you everywhere (verified on macOS 26).
    static let onTopLevel = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

    // Follows you across every Space. `.canJoinAllSpaces` puts the panel on all
    // regular desktop Spaces; `.fullScreenAuxiliary` lets it join full-screen
    // Spaces; and `.canJoinAllApplications` (macOS 13+) extends that to *other*
    // apps' full-screen Spaces so swiping between full-screen apps keeps it in view.
    static var stickyBehavior: NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        if #available(macOS 13.0, *) {
            behavior.insert(.canJoinAllApplications)
        }
        return behavior
    }

    @objc private func toggleOnTop(_ sender: NSSwitch) {
        setOnTop(sender.state == .on)
    }

    @objc private func toggleTopCompact(_ sender: NSButton) {
        setOnTop(sender.state == .on)
    }

    private func setOnTop(_ on: Bool) {
        isOnTop = on
        window.level = on ? Self.onTopLevel : .normal
        // Keep the window sticky across Spaces regardless of the on-top toggle.
        window.collectionBehavior = Self.stickyBehavior
        onTopSwitch?.state = on ? .on : .off
        compactTopButton?.state = on ? .on : .off
        compactTopButton?.image = NSImage(
            systemSymbolName: on ? "pin.fill" : "pin.slash.fill",
            accessibilityDescription: "Top"
        )
    }

    @objc private func changeOpacity(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        window.alphaValue = value
        opacitySlider?.doubleValue = Double(value)
        compactOpacitySlider?.doubleValue = Double(value)
    }

    @objc private func showOpacityPopover(_ sender: NSButton) {
        if opacityPopover == nil {
            let pop = NSPopover()
            pop.behavior = .transient
            let vc = NSViewController()
            let container = NSView()
            let icon = NSImageView()
            icon.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Opacity")
            icon.contentTintColor = .secondaryLabelColor
            icon.translatesAutoresizingMaskIntoConstraints = false
            let slider = NSSlider(value: Double(window.alphaValue), minValue: 0.3, maxValue: 1.0, target: self, action: #selector(changeOpacity(_:)))
            slider.controlSize = .small
            slider.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(icon)
            container.addSubview(slider)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 14),
                icon.heightAnchor.constraint(equalToConstant: 14),
                slider.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
                slider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                slider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                slider.widthAnchor.constraint(equalToConstant: 120),
                container.heightAnchor.constraint(equalToConstant: 40),
            ])
            vc.view = container
            pop.contentViewController = vc
            pop.contentSize = NSSize(width: 166, height: 40)
            opacityPopover = pop
            compactOpacitySlider = slider
        }
        compactOpacitySlider?.doubleValue = Double(window.alphaValue)
        opacityPopover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        // Mirror the window's capture-hidden state so the popover can't be used
        // to reveal the app indirectly during screen sharing.
        if isHiddenFromCapture {
            opacityPopover?.contentViewController?.view.window?.sharingType = .none
        }
    }

    @objc private func toggleHiddenMenu(_ sender: Any?) {
        isHiddenFromCapture.toggle()
    }

    @objc private func changeMode(_ sender: NSSegmentedControl) {
        setPreviewMode(sender.selectedSegment == 1)
    }

    @objc private func togglePreviewMenu(_ sender: Any?) {
        setPreviewMode(!isPreviewMode)
    }

    @objc private func togglePreviewCompact(_ sender: NSButton) {
        setPreviewMode(sender.state == .on)
    }

    private func setPreviewMode(_ on: Bool) {
        isPreviewMode = on
        if on {
            previewTextView.textStorage?.setAttributedString(MarkdownRenderer.render(textView.string))
        }
        editorScroll.isHidden = on
        previewScroll.isHidden = !on
        previewSegment.selectedSegment = on ? 1 : 0
        compactPreviewButton?.state = on ? .on : .off
        compactPreviewButton?.image = NSImage(
            systemSymbolName: on ? "doc.richtext" : "square.and.pencil",
            accessibilityDescription: on ? "Preview" : "Edit"
        )
        if !on { window.makeFirstResponder(textView) }
    }

    // MARK: Text changes -> debounced autosave

    func textDidChange(_ notification: Notification) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Store.save(self.textView.string)
        }
    }

    // MARK: Menu

    private func buildMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Sableye", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let hideItem = NSMenuItem(title: "Toggle Hide From Screen Share", action: #selector(toggleHiddenMenu(_:)), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(hideItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Sableye", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // Edit menu (gives copy/paste/undo/select-all to the text view)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        let previewItem = NSMenuItem(title: "Toggle Markdown Preview", action: #selector(togglePreviewMenu(_:)), keyEquivalent: "p")
        previewItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(previewItem)
        viewMenuItem.submenu = viewMenu

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
