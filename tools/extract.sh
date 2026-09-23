#!/bin/sh
# Regenerate everything under disasm/ and resources/ from original/Beast 1.0.rsrc
# (the resource fork of the original "Beast 1.0" application, saved as a plain file).
# Needs: macOS (DeRez), python3 with capstone (pip install -r tools/requirements.txt)
set -e
cd "$(dirname "$0")/.."
PY=${PYTHON:-python3}
RSRC="original/Beast 1.0.rsrc"
$PY tools/disasm.py "$RSRC" disasm
mkdir -p resources
DeRez -useDF "$RSRC" > resources/Beast.r
$PY - <<'PYEOF'
import sys; sys.path.insert(0, 'tools'); import rsrc
for r in rsrc.parse(open('original/Beast 1.0.rsrc', 'rb').read()):
    if r['type'] == 'PICT':
        open('resources/PICT_%d.pict' % r['id'], 'wb').write(b'\0' * 512 + r['data'])
PYEOF
$PY tools/pict.py resources/PICT_*.pict > resources/PICT_dump.txt
echo "done: disasm/ resources/"
