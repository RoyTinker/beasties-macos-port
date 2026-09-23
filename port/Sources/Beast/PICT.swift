import AppKit
import CoreText

/// Draws QuickDraw PICT version 1 data: the opcodes used by Beast's six pictures (bitmaps,
/// text, rectangles, lines, and the pen/text state that goes with them).
/// Unsupported opcodes stop drawing and are logged.
final class PICTImage {
    private let data: [UInt8]
    /// picFrame, in the picture's own QuickDraw coordinates.
    let frame: CGRect

    init(_ data: [UInt8]) {
        self.data = data
        let t = Self.int16(data, 2), l = Self.int16(data, 4)
        let b = Self.int16(data, 6), r = Self.int16(data, 8)
        frame = CGRect(x: l, y: t, width: r - l, height: b - t)
    }

    var size: NSSize { frame.size }

    /// An `NSImage` that redraws the picture at whatever resolution it is displayed at.
    /// The image keeps this picture alive.
    var image: NSImage {
        NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            self.draw(in: ctx)
            return true
        }
    }

    // MARK: - Interpreter

    private struct State {
        var textFont = 0
        var textSize = 0
        var textFace: UInt8 = 0
        var textOrigin = CGPoint.zero
        var penSize = CGSize(width: 1, height: 1)
        var fillPattern = [UInt8](repeating: 0xFF, count: 8)
        var lastRect = CGRect.zero
    }

    /// Draws into a y-down context, with the top-left of `frame` at the context's origin.
    func draw(in ctx: CGContext) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.translateBy(x: -frame.minX, y: -frame.minY)
        ctx.clip(to: frame)
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)

        var st = State()
        var p = 10
        guard data.count > 12, data[10] == 0x11, data[11] == 0x01 else {
            NSLog("PICT: not a version 1 picture")
            return
        }
        p = 12
        while p < data.count {
            let op = data[p]
            p += 1
            switch op {
            case 0x00:                                              // NOP
                break
            case 0x01:                                              // ClipRgn (ignored)
                p += Int(Self.uint16(data, p))
            case 0x03:                                              // TxFont
                st.textFont = Int(Self.int16(data, p)); p += 2
            case 0x04:                                              // TxFace
                st.textFace = data[p]; p += 1
            case 0x05, 0x08, 0x23:                                  // TxMode, PnMode, ShortLineFrom
                p += 2
            case 0x06, 0x0B, 0x0C, 0x0E, 0x0F, 0x21:                // SpExtra, OvSize, Origin, colours, LineFrom
                p += 4
            case 0x07:                                              // PnSize
                st.penSize = CGSize(width: Self.int16(data, p + 2), height: Self.int16(data, p)); p += 4
            case 0x02, 0x09:                                        // BkPat, PnPat
                p += 8
            case 0x0A:                                              // FillPat
                st.fillPattern = Array(data[p..<p + 8]); p += 8
            case 0x0D:                                              // TxSize
                st.textSize = Int(Self.int16(data, p)); p += 2
            case 0x10:                                              // TxRatio
                p += 8
            case 0x11:                                              // Version
                p += 1
            case 0x20:                                              // Line
                let from = Self.point(data, p), to = Self.point(data, p + 4); p += 8
                drawLine(ctx, from, to, st.penSize)
            case 0x22:                                              // ShortLine
                let from = Self.point(data, p)
                let to = CGPoint(x: from.x + CGFloat(Int8(bitPattern: data[p + 4])),
                                 y: from.y + CGFloat(Int8(bitPattern: data[p + 5])))
                p += 6
                drawLine(ctx, from, to, st.penSize)
            case 0x28:                                              // LongText
                st.textOrigin = Self.point(data, p)
                let n = Int(data[p + 4])
                drawText(ctx, Array(data[p + 5..<p + 5 + n]), st); p += 5 + n
            case 0x29:                                              // DHText
                st.textOrigin.x += CGFloat(data[p])
                let n = Int(data[p + 1])
                drawText(ctx, Array(data[p + 2..<p + 2 + n]), st); p += 2 + n
            case 0x2A:                                              // DVText
                st.textOrigin.y += CGFloat(data[p])
                let n = Int(data[p + 1])
                drawText(ctx, Array(data[p + 2..<p + 2 + n]), st); p += 2 + n
            case 0x2B:                                              // DHDVText
                st.textOrigin.x += CGFloat(data[p])
                st.textOrigin.y += CGFloat(data[p + 1])
                let n = Int(data[p + 2])
                drawText(ctx, Array(data[p + 3..<p + 3 + n]), st); p += 3 + n
            case 0x30...0x34:                                       // frame/paint/erase/invert/fillRect
                st.lastRect = Self.rect(data, p); p += 8
                drawRect(ctx, verb: op - 0x30, st)
            case 0x38...0x3C:                                       // same, on the last rect
                drawRect(ctx, verb: op - 0x38, st)
            case 0x90, 0x91, 0x98, 0x99:                            // (Packed)BitsRect(Rgn)
                p = drawBits(ctx, op: op, at: p)
            case 0xA0:                                              // ShortComment
                p += 2
            case 0xA1:                                              // LongComment
                p += 4 + Int(Self.uint16(data, p + 2))
            case 0xFF:                                              // EndOfPicture
                return
            default:
                NSLog("PICT: unsupported opcode 0x%02X at %d", op, p - 1)
                return
            }
        }
    }

    // MARK: - Drawing primitives

    /// QuickDraw pens hang below and to the right of the line.
    private func drawLine(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ pen: CGSize) {
        ctx.setFillColor(.black)
        if a.y == b.y || a.x == b.x {
            ctx.fill(CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                            width: abs(b.x - a.x) + pen.width, height: abs(b.y - a.y) + pen.height))
        } else {
            ctx.setStrokeColor(.black)
            ctx.setLineWidth(max(pen.width, pen.height))
            ctx.strokeLineSegments(between: [CGPoint(x: a.x + pen.width / 2, y: a.y + pen.height / 2),
                                             CGPoint(x: b.x + pen.width / 2, y: b.y + pen.height / 2)])
        }
    }

    private func drawRect(_ ctx: CGContext, verb: UInt8, _ st: State) {
        let r = st.lastRect
        switch verb {
        case 0:                                                     // frame
            ctx.setFillColor(.black)
            let w = st.penSize.width, h = st.penSize.height
            ctx.fill([CGRect(x: r.minX, y: r.minY, width: r.width, height: h),
                      CGRect(x: r.minX, y: r.maxY - h, width: r.width, height: h),
                      CGRect(x: r.minX, y: r.minY, width: w, height: r.height),
                      CGRect(x: r.maxX - w, y: r.minY, width: w, height: r.height)])
        case 1:                                                     // paint (pen pattern: black)
            ctx.setFillColor(.black)
            ctx.fill(r)
        case 2:                                                     // erase
            ctx.setFillColor(.white)
            ctx.fill(r)
        case 3:                                                     // invert
            ctx.saveGState()
            ctx.setBlendMode(.difference)
            ctx.setFillColor(.white)
            ctx.fill(r)
            ctx.restoreGState()
        default:                                                    // fill with the fill pattern
            let ones = st.fillPattern.reduce(0) { $0 + $1.nonzeroBitCount }
            ctx.setFillColor(gray: 1 - CGFloat(ones) / 64, alpha: 1)
            ctx.fill(r)
        }
    }

    private func drawText(_ ctx: CGContext, _ bytes: [UInt8], _ st: State) {
        let text = (String(bytes: bytes, encoding: .macOSRoman) ?? "")
            .replacingOccurrences(of: "\r", with: "")               // lines are positioned explicitly
        let size = CGFloat(st.textSize == 0 ? 12 : st.textSize)
        var font: NSFont
        switch st.textFont {
        case 0:  font = .boldSystemFont(ofSize: size)               // Chicago
        case 4:  font = NSFont(name: "Monaco", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        default: font = NSFont(name: "Geneva", size: size) ?? .systemFont(ofSize: size)
        }
        if st.textFace & 1 != 0 { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        if st.textFace & 2 != 0 { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        if st.textFace & 4 != 0 { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        ctx.saveGState()
        ctx.setShouldAntialias(true)
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)        // the context is y-down
        ctx.textPosition = st.textOrigin                            // QuickDraw text origin = baseline
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// BitsRect / PackBitsRect. Returns the offset just past the opcode's data.
    private func drawBits(_ ctx: CGContext, op: UInt8, at start: Int) -> Int {
        var p = start
        let rowBytes = Int(Self.uint16(data, p) & 0x3FFF)
        let bounds = Self.rect(data, p + 2)
        let src = Self.rect(data, p + 10)
        let dst = Self.rect(data, p + 18)
        let mode = Int(Self.int16(data, p + 26))
        p += 28
        if op == 0x91 || op == 0x99 { p += Int(Self.uint16(data, p)) }   // mask region

        let rows = Int(bounds.height)
        var bits = [UInt8]()
        bits.reserveCapacity(rows * rowBytes)
        for _ in 0..<rows {
            if (op == 0x98 || op == 0x99) && rowBytes >= 8 {
                let count: Int
                if rowBytes > 250 { count = Int(Self.uint16(data, p)); p += 2 } else { count = Int(data[p]); p += 1 }
                bits += Self.unpackBits(Array(data[p..<p + count]), rowBytes)
                p += count
            } else {
                bits += data[p..<p + rowBytes]
                p += rowBytes
            }
        }

        // Cut out srcRect as RGBA: black where a bit is set; white (srcCopy) or clear (srcOr).
        let w = Int(src.width), h = Int(src.height)
        let x0 = Int(src.minX - bounds.minX), y0 = Int(src.minY - bounds.minY)
        let clearPixel: [UInt8] = mode == 0 ? [255, 255, 255, 255] : [0, 0, 0, 0]
        var rgba = [UInt8]()
        rgba.reserveCapacity(w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let bx = x0 + x, by = y0 + y
                let on = bits[by * rowBytes + bx / 8] >> (7 - UInt8(bx % 8)) & 1 == 1
                rgba += on ? [0, 0, 0, 255] : clearPixel
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent)
        else { return p }
        // CGContext.draw assumes y-up, so flip around the destination rectangle.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: dst.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: dst.minX, y: 0, width: dst.width, height: dst.height))
        ctx.restoreGState()
        return p
    }

    // MARK: - Byte helpers

    private static func uint16(_ d: [UInt8], _ p: Int) -> UInt16 { UInt16(d[p]) << 8 | UInt16(d[p + 1]) }
    private static func int16(_ d: [UInt8], _ p: Int) -> CGFloat { CGFloat(Int16(bitPattern: uint16(d, p))) }
    /// A QuickDraw Point is (v, h).
    private static func point(_ d: [UInt8], _ p: Int) -> CGPoint { CGPoint(x: int16(d, p + 2), y: int16(d, p)) }
    /// A QuickDraw Rect is (top, left, bottom, right).
    private static func rect(_ d: [UInt8], _ p: Int) -> CGRect {
        let t = int16(d, p), l = int16(d, p + 2), b = int16(d, p + 4), r = int16(d, p + 6)
        return CGRect(x: l, y: t, width: r - l, height: b - t)
    }

    private static func unpackBits(_ d: [UInt8], _ n: Int) -> [UInt8] {
        var out = [UInt8]()
        var p = 0
        while out.count < n && p < d.count {
            let c = Int8(bitPattern: d[p]); p += 1
            if c >= 0 {
                let len = Int(c) + 1
                out += d[p..<min(p + len, d.count)]; p += len
            } else if c != -128 {
                out += [UInt8](repeating: d[p], count: 1 - Int(c)); p += 1
            }
        }
        return Array(out.prefix(n)) + [UInt8](repeating: 0, count: max(0, n - out.count))
    }
}
