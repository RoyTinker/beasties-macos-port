"""Tiny QuickDraw PICT v1 interpreter: dumps opcodes and renders bitmaps + text to PNG."""
import struct, sys, os, zlib

def unpackbits(d, p, n):
    out = bytearray()
    while len(out) < n:
        c = d[p]; p += 1
        if c < 128:
            out += d[p:p + c + 1]; p += c + 1
        elif c > 128:
            out += bytes([d[p]]) * (257 - c); p += 1
    return bytes(out), p

def rect(d, p): return struct.unpack('>hhhh', d[p:p + 8])  # t l b r

def parse(d):
    size, = struct.unpack('>H', d[:2]); frame = rect(d, 2)
    p = 10; ops = []
    assert d[p:p + 2] == b'\x11\x01', 'not PICT v1'
    p += 2
    while p < len(d):
        op = d[p]; p += 1
        if op == 0xFF: break
        if op == 0x00: continue
        if op == 0x01:  # clipRgn
            n, = struct.unpack('>H', d[p:p + 2]); p += n; continue
        if op in (0x90, 0x91, 0x98, 0x99):  # BitsRect / PackBitsRect (+Rgn)
            rb, = struct.unpack('>H', d[p:p + 2]); bounds = rect(d, p + 2)
            src = rect(d, p + 10); dst = rect(d, p + 18); mode, = struct.unpack('>H', d[p + 26:p + 28])
            p += 28
            if op in (0x91, 0x99):
                n, = struct.unpack('>H', d[p:p + 2]); p += n
            rows = bounds[2] - bounds[0]; bits = bytearray()
            for _ in range(rows):
                if op in (0x98, 0x99) and rb >= 8:
                    if rb > 250: bc, = struct.unpack('>H', d[p:p + 2]); p += 2
                    else: bc = d[p]; p += 1
                    row, _q = unpackbits(d, p, rb); p += bc
                else:
                    row = d[p:p + rb]; p += rb
                bits += row[:rb]
            ops.append(('bits', rb, bounds, src, dst, mode, bytes(bits)))
            continue
        if op == 0x28:  # LongText
            pt = struct.unpack('>hh', d[p:p + 4]); n = d[p + 4]
            ops.append(('text', pt, d[p + 5:p + 5 + n].decode('mac_roman'))); p += 5 + n; continue
        if op in (0x29, 0x2A):  # DHText / DVText
            dd = d[p]; n = d[p + 1]
            ops.append(('dtext', op, dd, d[p + 2:p + 2 + n].decode('mac_roman'))); p += 2 + n; continue
        if op == 0x2B:
            dh, dv, n = d[p], d[p + 1], d[p + 2]
            ops.append(('dhvtext', dh, dv, d[p + 3:p + 3 + n].decode('mac_roman'))); p += 3 + n; continue
        if op == 0xA1:  # LongComment
            kind, n = struct.unpack('>HH', d[p:p + 4]); p += 4 + n; continue
        if op == 0xA0: p += 2; continue
        fixed = {0x03: 2, 0x04: 1, 0x05: 2, 0x06: 4, 0x07: 4, 0x08: 2, 0x09: 8, 0x0A: 8, 0x0B: 4,
                 0x0C: 4, 0x0D: 2, 0x0E: 4, 0x0F: 4, 0x10: 8, 0x11: 1, 0x1A: 6, 0x1B: 6, 0x1C: 0,
                 0x1D: 6, 0x1E: 0, 0x1F: 6, 0x20: 8, 0x21: 4, 0x22: 6, 0x23: 2, 0x2C: None, 0x2E: None}
        if 0x30 <= op <= 0x34: ops.append(('rect', op, rect(d, p))); p += 8; continue
        if 0x38 <= op <= 0x3C: ops.append(('samerect', op)); continue
        if 0x40 <= op <= 0x44: p += 8; continue
        if 0x50 <= op <= 0x54: ops.append(('oval', op, rect(d, p))); p += 8; continue
        if 0x60 <= op <= 0x64: p += 12; continue
        if 0x70 <= op <= 0x74 or 0x80 <= op <= 0x84:
            n, = struct.unpack('>H', d[p:p + 2]); ops.append(('poly/rgn', op)); p += n; continue
        if op in (0x2C, 0x2E):
            n, = struct.unpack('>H', d[p:p + 2]); p += 2 + n; continue
        if op in fixed:
            ops.append(('op', hex(op), d[p:p + fixed[op]].hex())); p += fixed[op]; continue
        ops.append(('UNKNOWN', hex(op), p)); break
    return frame, ops

def png(path, w, h, pix):  # pix: list of rows of 0/1 (1 = black)
    raw = b''.join(b'\0' + bytes(255 - 255 * v for v in row) for row in pix)
    def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b))
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))

def render_bits(frame, ops, path):
    t, l, b, r = frame; W, H = r - l, b - t
    pix = [[0] * W for _ in range(H)]
    for o in ops:
        if o[0] != 'bits': continue
        _, rb, bounds, src, dst, mode, bits = o
        for y in range(dst[0], dst[2]):
            for x in range(dst[1], dst[3]):
                sy, sx = y - dst[0] + src[0] - bounds[0], x - dst[1] + src[1] - bounds[1]
                v = (bits[sy * rb + sx // 8] >> (7 - sx % 8)) & 1
                if 0 <= y - t < H and 0 <= x - l < W: pix[y - t][x - l] = v
        for o2 in ops:
            if o2[0] == 'rect' and o2[1] == 0x30:  # frameRect
                rt, rl, rbm, rr = o2[2]
                for x in range(rl, rr):
                    for y in (rt, rbm - 1):
                        if 0 <= y - t < H and 0 <= x - l < W: pix[y - t][x - l] = 1
                for y in range(rt, rbm):
                    for x in (rl, rr - 1):
                        if 0 <= y - t < H and 0 <= x - l < W: pix[y - t][x - l] = 1
    png(path, W, H, pix)

if __name__ == '__main__':
    for f in sys.argv[1:]:
        d = open(f, 'rb').read()[512:]
        frame, ops = parse(d)
        print('==', f, 'frame', frame)
        for o in ops:
            print('  ', o if o[0] != 'bits' else o[:6] + ('%d bytes' % len(o[6]),))
        render_bits(frame, ops, f.replace('.pict', '.png'))
