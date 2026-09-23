"""Annotated 68000 disassembler for classic Mac CODE resources (THINK Pascal flavour)."""
import re, struct, sys, os, importlib
sys.path.insert(0, os.path.dirname(__file__))
import capstone as cs, rsrc, traps, symbols

md = cs.Cs(cs.CS_ARCH_M68K, cs.CS_MODE_BIG_ENDIAN | cs.CS_MODE_M68K_000)
BRANCH = re.compile(r'^(bra|bsr|b(hi|ls|cc|cs|ne|eq|vc|vs|pl|mi|ge|lt|gt|le)|db[a-z]+)(\.[bwsl])?$')
NAMECH = set(b'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_% .')

def load(path):
    res = rsrc.parse(open(path, 'rb').read())
    c0 = rsrc.get(res, 'CODE', 0)
    above, below, jtsize, jtoff = struct.unpack('>IIII', c0[:16])
    jt = {}
    for i in range(0, jtsize, 8):
        off, push, seg, trap = struct.unpack('>HHHH', c0[16 + i:24 + i])
        if push == 0x3F3C:
            jt[jtoff + i + 2] = (seg, off)
    segs = {r['id']: r['data'][4:] for r in res if r['type'] == 'CODE' and r['id'] > 0}
    return res, jt, segs, (above, below)

def find_names(c):
    """MacsBug symbols: 8 upper-case chars right after RTS / JMP (A0) / RTD n."""
    names = {}
    for p in range(2, len(c) - 7, 2):
        w = struct.unpack('>H', c[p - 2:p])[0]
        if w in (0x4E75, 0x4ED0) or (p >= 4 and struct.unpack('>H', c[p-4:p-2])[0] == 0x4E74):
            s = bytes([c[p] & 0x7F]) + c[p + 1:p + 8]
            if all(b in NAMECH for b in s) and s[:1].isalpha():
                names[p] = s.decode().rstrip()
    return names

def trace(c, seeds):
    code, starts, insns = set(), set(seeds), {}
    work = list(seeds)
    while work:
        pc = work.pop()
        while 0 <= pc < len(c) and pc not in insns:
            w = struct.unpack('>H', c[pc:pc + 2])[0]
            if w & 0xF000 == 0xA000:
                insns[pc] = ('trap', w, 2)
                pc += 2
                if w == 0xA9F4: break
                continue
            ins = next(md.disasm(c[pc:pc + 10], pc, 1), None)
            if ins is None:
                insns[pc] = ('bad', w, 2); break
            insns[pc] = ('ins', ins, ins.size)
            m, ops = ins.mnemonic, ins.op_str
            tgt = re.match(r'^\$([0-9a-f]+)$', ops.split(',')[-1].strip())
            pcrel = re.match(r'^\$([0-9a-f]+)\(pc\)$', ops)
            if BRANCH.match(m):
                if tgt:
                    t = int(tgt.group(1), 16)
                    work.append(t)
                    if m.startswith('bsr'): starts.add(t)
                if m.startswith('bra'): break
            elif m.startswith(('jsr', 'jmp')):
                if pcrel:
                    t = int(pcrel.group(1), 16); work.append(t)
                    if m.startswith('jsr'): starts.add(t)
                if m.startswith('jmp'): break
            elif m in ('rts', 'rte', 'rtr', 'rtd'):
                break
            pc += ins.size
    return insns, starts

def ascii(b):
    return ''.join(chr(x) if 32 <= x < 127 else '.' for x in b)

def disasm_seg(n, c, jt, out):
    names = find_names(c)
    seeds = {off for (s, off) in jt.values() if s == n}
    # procedure entry after each name block: first LINK A6 at/after name end
    for p in names:
        q = p + 8
        while q < len(c) - 1 and struct.unpack('>H', c[q:q + 2])[0] != 0x4E56:
            q += 2
        if q < len(c) - 1: seeds.add(q)
    insns, starts = trace(c, seeds)
    starts |= seeds
    fnames = {}
    for p, nm in names.items():
        prev = max([s for s in starts if s < p], default=None)
        if prev is not None: fnames.setdefault(prev, nm)
    for (s, off), nm in symbols.FUNCS.items():
        if s == n: fnames[off] = nm
    def fname(off):
        return fnames.get(off, 'sub_%d_%04X' % (n, off))
    jt_rev = {v: k for k, v in jt.items()}
    labels = set()
    for p, (k, i, sz) in insns.items():
        if k == 'ins':
            m = re.search(r'\$([0-9a-f]+)$', i.op_str)
            if m and BRANCH.match(i.mnemonic): labels.add(int(m.group(1), 16))
    dataref = {}
    for p, (k, i, sz) in insns.items():
        if k == 'ins':
            for m in re.finditer(r'\$([0-9a-f]+)\(pc', i.op_str):
                dataref.setdefault(int(m.group(1), 16), p)

    def a5ann(txt):
        notes = []
        def rep(m):
            neg, v = m.group(1), int(m.group(2), 16)
            off = -v if neg else v
            if off in jt:
                s, o = jt[off]
                notes.append('JT → CODE %d+%04X' % (s, o))
                return fname(o) if s == n else seg_fn[s](o)
            g = symbols.GLOBALS.get(off)
            if g: return g + '(a5)'
            return m.group(0)
        txt = re.sub(r'(-)?\$([0-9a-f]+)\(a5\)', rep, txt)
        return txt, notes

    out.write('\n; ' + '=' * 70 + '\n; CODE %d  (%d bytes)\n; ' % (n, len(c)) + '=' * 70 + '\n')
    pc = 0
    while pc < len(c):
        if pc in starts or pc in fnames:
            tag = ' [JT %s]' % hex(jt_rev[(n, pc)]) if (n, pc) in jt_rev else ''
            out.write('\n; ---------- %s%s ----------\n%s:\n' % (fname(pc), tag, fname(pc)))
        elif pc in labels:
            out.write('L%04X:\n' % pc)
        cm = symbols.COMMENTS.get((n, pc))
        if cm: out.write('    ; %s\n' % cm)
        if pc in insns:
            k, i, sz = insns[pc]
            raw = c[pc:pc + sz].hex().upper()
            if k == 'trap':
                t = traps.name(i) or '???'
                out.write('  %04X  %-20s _%s\n' % (pc, raw, t))
            elif k == 'bad':
                out.write('  %04X  %-20s dc.w    $%04X   ; ???\n' % (pc, raw, i))
            else:
                ops, notes = a5ann(i.op_str)
                im = re.match(r'#\$([0-9a-f]+), d\d$', i.op_str)
                if im and i.mnemonic.startswith('addi.w'):
                    v = int(im.group(1), 16); v = v - 0x10000 if v >= 0x8000 else v
                    if v in symbols.ARRAY_BASES: notes.append('A5 ' + symbols.ARRAY_BASES[v])
                lm = re.match(r'-\$([0-9a-f]+)\(a5\), a\d$', i.op_str)
                if lm and i.mnemonic.startswith('lea') and -int(lm.group(1), 16) in symbols.ARRAY_BASES:
                    notes.append('A5 ' + symbols.ARRAY_BASES[-int(lm.group(1), 16)])
                ops = re.sub(r'#\$([0-9a-f]+)', lambda m: '#$%X' % int(m.group(1), 16), ops)
                if i.mnemonic.startswith('link'):
                    d = struct.unpack('>h', c[pc + 2:pc + 4])[0]; ops = 'a6, #%d' % d
                m = re.search(r'\$([0-9a-f]+)(\(pc)?', ops)
                if m:
                    t = int(m.group(1), 16)
                    if BRANCH.match(i.mnemonic) and not m.group(2):
                        ops = ops[:m.start()] + (fname(t) if t in fnames or t in starts else 'L%04X' % t) + ops[m.end():]
                    elif m.group(2):
                        if t in fnames or t in starts:
                            ops = ops.replace(m.group(0), fname(t) + '(pc')
                        elif t not in insns and t < len(c):
                            l = c[t]
                            s = c[t + 1:t + 1 + l]
                            if 0 < l < 256 and all(32 <= x < 127 or x in (13,) for x in s):
                                notes.append('"%s"' % s.decode('mac_roman').replace('\r', '\\r'))
                            else:
                                notes.append('data @%04X' % t)
                out.write('  %04X  %-20s %-8s %s%s\n' % (pc, raw, i.mnemonic, ops,
                          ('   ; ' + '; '.join(notes)) if notes else ''))
            pc += sz
        else:
            q = pc
            while q < len(c) and q not in insns and q not in starts: q += 1
            blk = c[pc:q]
            if pc in names and len(blk) >= 8:
                out.write('  %04X  %-20s dc.b    \'%s\'   ; MacsBug name\n' % (pc, blk[:8].hex().upper(), names[pc]))
                pc += 8; continue
            for r in range(0, len(blk), 16):
                chunk = blk[r:r + 16]
                out.write('  %04X  dc.b  %-48s %s\n' % (pc + r, chunk.hex(' ').upper(), ascii(chunk)))
            pc = q
    return fnames

seg_fn = {}

def main(path, outdir):
    res, jt, segs, (above, below) = load(path)
    os.makedirs(outdir, exist_ok=True)
    # pre-pass so cross-segment JT calls can be named
    pre = {}
    for n, c in segs.items():
        import io
        seg_fn[n] = lambda o, n=n: 'CODE%d_%04X' % (n, o)
    for n, c in segs.items():
        import io
        pre[n] = disasm_seg(n, c, jt, io.StringIO())
    for n in segs:
        seg_fn[n] = lambda o, n=n: pre[n].get(o, 'sub_%d_%04X' % (n, o))
    for n, c in sorted(segs.items()):
        with open(os.path.join(outdir, 'CODE_%d.s' % n), 'w') as f:
            f.write('; Beast 1.0 — CODE %d disassembly (generated by tools/disasm.py)\n' % n)
            f.write('; A5 world: above=%d below=%d\n' % (above, below))
            disasm_seg(n, c, jt, f)
    with open(os.path.join(outdir, 'jumptable.txt'), 'w') as f:
        for k, (s, o) in sorted(jt.items()):
            f.write('%4X(a5)  CODE %d +%04X  %s\n' % (k, s, o, pre[s].get(o, '?')))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
