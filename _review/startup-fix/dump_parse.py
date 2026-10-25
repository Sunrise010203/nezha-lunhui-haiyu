#!/usr/bin/env python3
"""Parse a Windows x64 minidump: exception, modules, faulting thread, stack scan.

Usage: python dump_parse.py <dump.dmp> [--max-frames N]
Prints exception code/address + module+offset and candidate return addresses
(module+offset) found in the faulting thread's stack memory.
"""
import struct
import sys

MODNAMES = {}


def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]
def u64(b, o): return struct.unpack_from('<Q', b, o)[0]


def read_minidump_string(data, rva):
    if rva == 0:
        return ''
    n = u32(data, rva)
    raw = data[rva + 4:rva + 4 + n]
    try:
        return raw.decode('utf-16-le').rstrip('\x00')
    except Exception:
        return repr(raw)


def main():
    path = sys.argv[1]
    max_frames = 40
    if '--max-frames' in sys.argv:
        max_frames = int(sys.argv[sys.argv.index('--max-frames') + 1])
    data = open(path, 'rb').read()
    sig = data[:4]
    print('file:', path, 'size:', len(data), 'sig:', sig)
    if sig != b'MDMP':
        print('not a minidump')
        return
    nstreams = u32(data, 8)
    dira = u32(data, 12)
    streams = {}
    for i in range(nstreams):
        t = u32(data, dira + i * 12)
        size = u32(data, dira + i * 12 + 4)
        rva = u32(data, dira + i * 12 + 8)
        streams[t] = (size, rva)
    print('streams:', sorted(streams.keys()))

    # modules
    modules = []
    if 4 in streams:
        _, rva = streams[4]
        n = u32(data, rva)
        off = rva + 4
        for _ in range(n):
            base = u64(data, off)
            size = u32(data, off + 8)
            name_rva = u32(data, off + 20)
            modules.append((base, size, read_minidump_string(data, name_rva)))
            off += 108
        print('\n== modules (%d) ==' % n)
        for base, size, name in modules:
            print('  %016x-%016x %s' % (base, base + size, name))

    def resolve(addr):
        for base, size, name in modules:
            if base <= addr < base + size:
                return '%s+0x%x' % (name, addr - base)
        return '0x%016x (unknown)' % addr

    # exception
    exc = None
    if 6 in streams:
        _, rva = streams[6]
        tid = u32(data, rva)
        code = u32(data, rva + 8)
        flags = u32(data, rva + 12)
        addr = u64(data, rva + 24)
        nparams = u32(data, rva + 32)
        params = [u64(data, rva + 40 + 8 * i) for i in range(min(nparams, 15))]
        ctx_size = u32(data, rva + 160)
        ctx_rva = u32(data, rva + 164)
        exc = (tid, code, flags, addr, params, ctx_rva)
        print('\n== exception ==')
        print('  thread id: %d' % tid)
        print('  code:      0x%08x' % code)
        print('  flags:     0x%08x' % flags)
        print('  address:   %s' % resolve(addr))
        print('  params:    ' + ', '.join('0x%x' % p for p in params))
        if code == 0xc0000005:
            access = {0: 'READ', 1: 'WRITE', 8: 'EXECUTE'}.get(params[0], str(params[0]))
            print('  -> access violation %s at 0x%x' % (access, params[1] if len(params) > 1 else 0))

    # threads
    threads = []
    if 3 in streams:
        _, rva = streams[3]
        n = u32(data, rva)
        off = rva + 4
        for _ in range(n):
            tid = u32(data, off)
            teb = u64(data, off + 16)
            stk_start = u64(data, off + 24)
            stk_size = u32(data, off + 32)
            stk_rva = u32(data, off + 36)
            ctx_size = u32(data, off + 40)
            ctx_rva = u32(data, off + 44)
            threads.append(dict(tid=tid, teb=teb, stack=(stk_start, stk_size, stk_rva),
                                ctx=(ctx_size, ctx_rva)))
            off += 48
        print('\n== threads: %d ==' % n)
        for t in threads:
            print('  tid %-8d teb=%016x stack=%016x+0x%x' % (t['tid'], t['teb'], t['stack'][0], t['stack'][1]))

    if exc:
        tid, code, flags, addr, params, ctx_rva = exc
        t = next((x for x in threads if x['tid'] == tid), None)
        if t:
            ctx = data[t['ctx'][1]:t['ctx'][1] + t['ctx'][0]]
            rsp = u64(ctx, 0x98)
            rbp = u64(ctx, 0xA0)
            rip = u64(ctx, 0xF8)
            print('\n== faulting context ==')
            print('  rip=%s' % resolve(rip))
            print('  rsp=%016x rbp=%016x' % (rsp, rbp))
            print('  rax=%016x rbx=%016x rcx=%016x rdx=%016x' % (
                u64(ctx, 0x78), u64(ctx, 0x90), u64(ctx, 0x80), u64(ctx, 0x88)))
            print('  rsi=%016x rdi=%016x r8=%016x r9=%016x' % (
                u64(ctx, 0xA8), u64(ctx, 0xB0), u64(ctx, 0xB8), u64(ctx, 0xC0)))
            # stack scan
            start, size, rva = t['stack']
            stack = data[rva:rva + size]
            print('\n== stack scan (rsp ..) candidates in modules ==')
            n = 0
            for i in range(0, len(stack) - 8, 8):
                v = u64(stack, i)
                s = resolve(v)
                if '(unknown)' in s:
                    continue
                print('  [rsp+0x%04x] %016x  %s' % (i, v, s))
                n += 1
                if n >= max_frames:
                    break


if __name__ == '__main__':
    main()
