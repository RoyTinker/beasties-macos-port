import AppKit
import BeastCore

/// A modal dialog built from a Dialog Manager item list (DITL). Items are numbered from 1,
/// and `run()` returns the number of the button that was clicked. As with `ModalDialog`,
/// item 1 is the default button.
final class ClassicDialog: NSObject {
    enum Item {
        case button(String)
        case text(String)
        case picture(PICTImage)
        case field(String)
    }

    private let panel: NSPanel
    private var result = 0
    private var fields: [Int: NSTextField] = [:]

    /// `items` holds each item and its rectangle, as (top, left, bottom, right) in the original
    /// DITL resource.
    init(title: String, width: Int, height: Int, items: [(Item, (Int, Int, Int, Int))]) {
        // Modern controls are taller than 1989 ones, so leave a little extra room at the bottom.
        let size = NSSize(width: width, height: height + 6)
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled],
                        backing: .buffered, defer: true)
        super.init()
        panel.title = title
        let content = FlippedView(frame: NSRect(origin: .zero, size: size))
        panel.contentView = content

        for (index, (item, (t, l, b, r))) in items.enumerated() {
            let number = index + 1
            let rect = NSRect(x: l, y: t, width: r - l, height: b - t)
            switch item {
            case .button(let title):
                let button = NSButton(title: title, target: self, action: #selector(hit(_:)))
                button.bezelStyle = .push
                button.tag = number
                if number == 1 { button.keyEquivalent = "\r" }
                // Push buttons draw inside a margin, so widen the frame to keep the visible
                // button the size of the original rectangle.
                let h = button.fittingSize.height
                button.frame = NSRect(x: rect.minX - 6, y: rect.midY - h / 2, width: rect.width + 12, height: h)
                content.addSubview(button)
            case .text(let string):
                let label = NSTextField(wrappingLabelWithString: string)
                label.font = .systemFont(ofSize: 12)
                label.frame = rect
                content.addSubview(label)
            case .picture(let pict):
                let view = NSImageView(frame: rect)
                view.image = pict.image
                view.imageScaling = .scaleAxesIndependently      // DrawPicture scales to the rect
                content.addSubview(view)
            case .field(let string):
                let field = NSTextField(string: string)
                field.font = .systemFont(ofSize: 12)
                let h = max(rect.height, field.fittingSize.height)
                field.frame = NSRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
                fields[number] = field
                content.addSubview(field)
            }
        }
    }

    /// Text of edit-text item `number`.
    func text(of number: Int) -> String {
        fields[number]?.stringValue ?? ""
    }

    /// The dialog's contents, for --snapshot.
    var contentView: NSView { panel.contentView! }

    func run() -> Int {
        panel.center()
        if let first = fields.keys.min() { panel.initialFirstResponder = fields[first] }
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return result
    }

    @objc private func hit(_ sender: NSButton) {
        result = sender.tag
        NSApp.stopModal()
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// The original's alerts and dialogs. Each item rectangle is copied from its DITL resource
/// (see resources/Beast.r).
enum Dialogs {
    /// [ERROR]: ALRT 129 / DITL 24872 with the text "^0".
    static func error(_ message: String) {
        _ = errorDialog(message).run()
    }

    static func errorDialog(_ message: String) -> ClassicDialog {
        ClassicDialog(title: "Beast", width: 222, height: 80, items: [
            (.button("OK"), (52, 80, 72, 140)),
            (.text(message), (7, 4, 39, 220)),
        ])
    }

    /// [MDESKABO]: ALRT 128, which leads to Help! (ALRT 130) or Info (ALRT 131).
    static func about() {
        let item = aboutDialog().run()
        if item == 4 {
            help()
        } else if item == 5 {
            info()
        }
    }

    static func aboutDialog() -> ClassicDialog {
        // ParamText('1.0', ' 3/4/89', '', '') into "Beast ^0,^1.\rCopyright BIAP, 1989."
        ClassicDialog(title: "About Beast", width: 214, height: 206, items: [
            (.button("OK"), (176, 8, 196, 68)),
            (.text("Beast 1.0, 3/4/89.\nCopyright BIAP, 1989."), (127, 13, 169, 199)),
            (.picture(PICTImage(Artwork.aboutPicture)), (4, 39, 123, 172)),
            (.button("Help!"), (176, 79, 196, 139)),
            (.button("Info"), (176, 143, 196, 203)),
        ])
    }

    /// ALRT 130 / DITL 3250: the "Help Playing Beast…" picture.
    static func help() {
        _ = helpDialog().run()
    }

    static func helpDialog() -> ClassicDialog {
        ClassicDialog(title: "Help!", width: 200, height: 225, items: [
            (.button("OK"), (200, 72, 220, 132)),
            (.picture(PICTImage(Artwork.help)), (0, 0, 195, 197)),
        ])
    }

    /// ALRT 131 / DITL 131: the "Info On Beast, the Program" picture.
    static func info() {
        _ = infoDialog().run()
    }

    static func infoDialog() -> ClassicDialog {
        ClassicDialog(title: "Info", width: 200, height: 225, items: [
            (.button("OK"), (200, 72, 220, 132)),
            (.picture(PICTImage(Artwork.info)), (0, 0, 195, 196)),
        ])
    }

    /// [DOSETTIN]: DLOG 129 "Game Parameters" / DITL 8011. As in the original there is only
    /// an OK button. The values are checked by [VERIFYSE] before they are returned.
    static func settings(_ current: BeastSettings) -> BeastSettings {
        let dialog = settingsDialog(current)
        _ = dialog.run()
        return BeastSettings(numBeasts: stringToNum(dialog.text(of: 5)),
                             delay: stringToNum(dialog.text(of: 6)),
                             density: stringToNum(dialog.text(of: 7))).verified()
    }

    static func settingsDialog(_ current: BeastSettings) -> ClassicDialog {
        ClassicDialog(title: "Game Parameters", width: 242, height: 136, items: [
            (.button("OK"), (96, 80, 116, 140)),
            (.text("Number of Beasts (1-10)"), (24, 8, 41, 175)),
            (.text("Beast Delay (sec/60)"), (48, 8, 64, 176)),
            (.text("Block Density (2-10)"), (72, 8, 88, 176)),
            (.field(String(current.numBeasts)), (24, 184, 40, 224)),
            (.field(String(current.delay)), (48, 184, 64, 224)),
            (.field(String(current.density)), (72, 184, 88, 224)),
            (.picture(PICTImage(Artwork.man)), (112, 192, 128, 208)),
            (.picture(PICTImage(Artwork.beast)), (96, 168, 112, 184)),
        ])
    }
}
