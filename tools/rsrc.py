"""Minimal classic Mac OS resource-fork parser."""
import struct

def parse(data):
    doff, moff, dlen, mlen = struct.unpack('>IIII', data[:16])
    m = data[moff:moff + mlen]
    tl_off, nl_off = struct.unpack('>HH', m[24:28])
    ntypes = struct.unpack('>H', m[tl_off:tl_off + 2])[0] + 1
    out = []
    for i in range(ntypes):
        e = tl_off + 2 + i * 8
        rtype = m[e:e + 4].decode('mac_roman')
        n, ref = struct.unpack('>HH', m[e + 4:e + 8])
        for j in range(n + 1):
            r = tl_off + ref + j * 12
            rid, noff, attr = struct.unpack('>hHB', m[r:r + 5])
            off = int.from_bytes(m[r + 5:r + 8], 'big')
            name = None
            if noff != 0xFFFF:
                p = nl_off + noff
                name = m[p + 1:p + 1 + m[p]].decode('mac_roman')
            p = doff + off
            ln = struct.unpack('>I', data[p:p + 4])[0]
            out.append(dict(type=rtype, id=rid, name=name, attr=attr,
                            data=data[p + 4:p + 4 + ln]))
    return out

def get(res, rtype, rid):
    for r in res:
        if r['type'] == rtype and r['id'] == rid:
            return r['data']
    raise KeyError((rtype, rid))
