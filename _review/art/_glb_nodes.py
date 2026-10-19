import json, struct, sys

def load(path):
    d = open(path, 'rb').read()
    off = 12
    js = None
    while off < len(d):
        clen, ctype = struct.unpack_from('<II', d, off)
        off += 8
        ch = d[off:off+clen]
        off += clen
        if ctype == 0x4E4F534A:
            js = json.loads(ch.decode('utf-8'))
    return js

for p in sys.argv[1:]:
    js = load(p)
    print('=' * 60)
    print(p)
    print('nodes:', len(js.get('nodes', [])))
    for i, n in enumerate(js.get('nodes', [])):
        tag = []
        if 'mesh' in n: tag.append('mesh')
        if 'skin' in n: tag.append('skin')
        if 'children' in n: tag.append('kids=%d' % len(n['children']))
        print('  %2d %-24s %s' % (i, n.get('name', ''), ' '.join(tag)))
    for s in js.get('skins', []):
        print('skin joints:', len(s.get('joints', [])))
