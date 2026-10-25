#!/usr/bin/env python3
"""Minimal Win32 x64 debugger in Python: launch an exe and capture the first
access violation (or any fatal exception) with registers + stack + modules.

Usage:
  python dbg_capture.py --exe <path> [--cwd DIR] [--appdata PATH]
                        [--args "a b c"] [--env clean|inherit]
                        [--first-chance-only] [--timeout SEC] [--tag NAME]
Writes <tag>.json next to this script (or --outdir).
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import json
import os
import struct
import sys
import time

k32 = ctypes.WinDLL('kernel32', use_last_error=True)

DEBUG_ONLY_THIS_PROCESS = 0x00000002
CREATE_UNICODE_ENVIRONMENT = 0x00000400
CREATE_NEW_CONSOLE = 0x00000010
STILL_ACTIVE = 259

DBG_CONTINUE = 0x00010002
DBG_EXCEPTION_NOT_HANDLED = 0x80010001

TH32CS_SNAPMODULE = 0x00000008
TH32CS_SNAPMODULE32 = 0x00000010
THREAD_GET_CONTEXT = 0x0008
THREAD_QUERY_INFORMATION = 0x0040
CONTEXT_CONTROL = 0x00100001
CONTEXT_INTEGER = 0x00100002
CONTEXT_FULL = CONTEXT_CONTROL | CONTEXT_INTEGER

MAX_PATH = 260
MAX_MODULE_NAME32 = 255


class STARTUPINFOW(ctypes.Structure):
    _fields_ = [
        ('cb', wt.DWORD), ('lpReserved', wt.LPWSTR), ('lpDesktop', wt.LPWSTR),
        ('lpTitle', wt.LPWSTR), ('dwX', wt.DWORD), ('dwY', wt.DWORD),
        ('dwXSize', wt.DWORD), ('dwYSize', wt.DWORD),
        ('dwXCountChars', wt.DWORD), ('dwYCountChars', wt.DWORD),
        ('dwFillAttribute', wt.DWORD), ('dwFlags', wt.DWORD),
        ('wShowWindow', wt.WORD), ('cbReserved2', wt.WORD),
        ('lpReserved2', ctypes.POINTER(ctypes.c_byte)),
        ('hStdInput', wt.HANDLE), ('hStdOutput', wt.HANDLE), ('hStdError', wt.HANDLE),
    ]


class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [('hProcess', wt.HANDLE), ('hThread', wt.HANDLE),
                ('dwProcessId', wt.DWORD), ('dwThreadId', wt.DWORD)]


class EXCEPTION_RECORD64(ctypes.Structure):
    _fields_ = [('ExceptionCode', wt.DWORD), ('ExceptionFlags', wt.DWORD),
                ('ExceptionRecord', ctypes.c_ulonglong),
                ('ExceptionAddress', ctypes.c_ulonglong),
                ('NumberParameters', wt.DWORD), ('__unusedAlignment', wt.DWORD),
                ('ExceptionInformation', ctypes.c_ulonglong * 15)]


class EXCEPTION_DEBUG_INFO(ctypes.Structure):
    _fields_ = [('ExceptionRecord', EXCEPTION_RECORD64), ('dwFirstChance', wt.DWORD)]


class _U(ctypes.Union):
    _fields_ = [('Exception', EXCEPTION_DEBUG_INFO),
                ('pad', ctypes.c_byte * 160)]


class DEBUG_EVENT(ctypes.Structure):
    _fields_ = [('dwDebugEventCode', wt.DWORD), ('dwProcessId', wt.DWORD),
                ('dwThreadId', wt.DWORD), ('pad0', wt.DWORD), ('u', _U)]


class CONTEXT64(ctypes.Structure):
    _fields_ = [
        ('P1Home', ctypes.c_ulonglong), ('P2Home', ctypes.c_ulonglong),
        ('P3Home', ctypes.c_ulonglong), ('P4Home', ctypes.c_ulonglong),
        ('P5Home', ctypes.c_ulonglong), ('P6Home', ctypes.c_ulonglong),
        ('ContextFlags', wt.DWORD), ('MxCsr', wt.DWORD),
        ('SegCs', wt.WORD), ('SegDs', wt.WORD), ('SegEs', wt.WORD),
        ('SegFs', wt.WORD), ('SegGs', wt.WORD), ('SegSs', wt.WORD),
        ('EFlags', wt.DWORD),
        ('Dr0', ctypes.c_ulonglong), ('Dr1', ctypes.c_ulonglong),
        ('Dr2', ctypes.c_ulonglong), ('Dr3', ctypes.c_ulonglong),
        ('Dr6', ctypes.c_ulonglong), ('Dr7', ctypes.c_ulonglong),
        ('Rax', ctypes.c_ulonglong), ('Rcx', ctypes.c_ulonglong),
        ('Rdx', ctypes.c_ulonglong), ('Rbx', ctypes.c_ulonglong),
        ('Rsp', ctypes.c_ulonglong), ('Rbp', ctypes.c_ulonglong),
        ('Rsi', ctypes.c_ulonglong), ('Rdi', ctypes.c_ulonglong),
        ('R8', ctypes.c_ulonglong), ('R9', ctypes.c_ulonglong),
        ('R10', ctypes.c_ulonglong), ('R11', ctypes.c_ulonglong),
        ('R12', ctypes.c_ulonglong), ('R13', ctypes.c_ulonglong),
        ('R14', ctypes.c_ulonglong), ('R15', ctypes.c_ulonglong),
        ('Rip', ctypes.c_ulonglong),
        ('FltSave', ctypes.c_byte * 512),
        ('VectorRegister', ctypes.c_byte * 26 * 16),
        ('VectorControl', ctypes.c_ulonglong),
        ('DebugControl', ctypes.c_ulonglong),
        ('LastExceptionToRip', ctypes.c_ulonglong),
        ('LastExceptionFromRip', ctypes.c_ulonglong),
    ]


class MODULEENTRY32W(ctypes.Structure):
    _fields_ = [('dwSize', wt.DWORD), ('th32ModuleID', wt.DWORD),
                ('th32ProcessID', wt.DWORD), ('GlblcntUsage', wt.DWORD),
                ('ProccntUsage', wt.DWORD), ('modBaseAddr', ctypes.c_void_p),
                ('modBaseSize', wt.DWORD), ('hModule', wt.HMODULE),
                ('szModule', wt.WCHAR * (MAX_MODULE_NAME32 + 1)),
                ('szExePath', wt.WCHAR * MAX_PATH)]


def build_env(mode, appdata):
    if mode == 'inherit':
        env = dict(os.environ)
    else:
        base = os.environ.get('USERPROFILE', r'C:\Users\Sunrise')
        env = {
            'SystemRoot': r'C:\Windows', 'windir': r'C:\Windows',
            'SystemDrive': 'C:', 'ComSpec': r'C:\Windows\system32\cmd.exe',
            'PATH': r'C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem',
            'PATHEXT': '.COM;.EXE;.BAT;.CMD',
            'TEMP': os.path.join(base, 'AppData', 'Local', 'Temp'),
            'TMP': os.path.join(base, 'AppData', 'Local', 'Temp'),
            'USERPROFILE': base, 'USERNAME': os.environ.get('USERNAME', 'Sunrise'),
            'USERDOMAIN': os.environ.get('USERDOMAIN', ''),
            'APPDATA': os.path.join(base, 'AppData', 'Roaming'),
            'LOCALAPPDATA': os.path.join(base, 'AppData', 'Local'),
            'NUMBER_OF_PROCESSORS': os.environ.get('NUMBER_OF_PROCESSORS', '24'),
            'PROCESSOR_ARCHITECTURE': 'AMD64', 'OS': 'Windows_NT',
        }
    if appdata:
        env['APPDATA'] = appdata
    return env


def make_env_block(env):
    parts = ['%s=%s' % (k, v) for k, v in env.items() if v is not None]
    block = '\x00'.join(parts) + '\x00\x00'
    return block.encode('utf-16-le')


def list_modules(pid):
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid)
    mods = []
    if snap == wt.HANDLE(-1).value or snap is None or snap == -1:
        return mods
    me = MODULEENTRY32W()
    me.dwSize = ctypes.sizeof(MODULEENTRY32W)
    ok = k32.Module32FirstW(snap, ctypes.byref(me))
    while ok:
        mods.append((me.modBaseAddr or 0, me.modBaseSize, me.szModule))
        ok = k32.Module32NextW(snap, ctypes.byref(me))
    k32.CloseHandle(snap)
    return mods


def resolve(mods, addr):
    for base, size, name in mods:
        if base <= addr < base + size:
            return '%s+0x%x' % (name, addr - base)
    return '0x%016x' % addr


def read_mem(hproc, addr, size):
    buf = ctypes.create_string_buffer(size)
    read = ctypes.c_size_t(0)
    ok = k32.ReadProcessMemory(hproc, ctypes.c_void_p(addr), buf, size,
                               ctypes.byref(read))
    if not ok:
        return b''
    return buf.raw[:read.value]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--exe', required=True)
    ap.add_argument('--cwd', default=None)
    ap.add_argument('--appdata', default=None)
    ap.add_argument('--args', default='')
    ap.add_argument('--env', default='clean')
    ap.add_argument('--timeout', type=float, default=30.0)
    ap.add_argument('--tag', default='dbg')
    ap.add_argument('--outdir', default=None)
    ap.add_argument('--stop-first-av', action='store_true', default=True)
    a = ap.parse_args()

    exe = os.path.abspath(a.exe)
    cwd = a.cwd or os.path.dirname(exe)
    outdir = a.outdir or os.path.dirname(os.path.abspath(__file__))
    cmdline = '"%s"' % exe + ((' ' + a.args) if a.args else '')

    env_block = make_env_block(build_env(a.env, a.appdata))
    env_buf = ctypes.create_string_buffer(env_block, len(env_block))

    si = STARTUPINFOW()
    si.cb = ctypes.sizeof(STARTUPINFOW)
    pi = PROCESS_INFORMATION()
    cmd_buf = ctypes.create_unicode_buffer(cmdline, len(cmdline) + 1)

    t0 = time.time()
    ok = k32.CreateProcessW(exe, cmd_buf, None, None, False,
                            DEBUG_ONLY_THIS_PROCESS | CREATE_UNICODE_ENVIRONMENT,
                            env_buf, cwd, ctypes.byref(si), ctypes.byref(pi))
    if not ok:
        print('CreateProcess failed', ctypes.get_last_error())
        sys.exit(1)
    pid = pi.dwProcessId
    print('started pid', pid)

    de = DEBUG_EVENT()
    captured = None
    exit_code = None
    events = []
    while True:
        if not k32.WaitForDebugEvent(ctypes.byref(de), 30000):
            print('WaitForDebugEvent timeout')
            break
        code = de.dwDebugEventCode
        cont = DBG_CONTINUE
        if code == 3:  # CREATE_PROCESS
            events.append({'t': round(time.time() - t0, 3), 'ev': 'create_process'})
        elif code == 6:  # LOAD_DLL
            pass
        elif code == 5:  # EXIT_PROCESS
            exit_code = struct.unpack_from('<I', bytes(de.u.pad), 8)[0]
            events.append({'t': round(time.time() - t0, 3), 'ev': 'exit_process',
                           'exit_code': exit_code})
            k32.ContinueDebugEvent(de.dwProcessId, de.dwThreadId, DBG_CONTINUE)
            break
        elif code == 1:  # EXCEPTION
            er = de.u.Exception.ExceptionRecord
            fc = de.u.Exception.dwFirstChance
            exc_code = er.ExceptionCode
            addr = er.ExceptionAddress
            params = list(er.ExceptionInformation[:min(er.NumberParameters, 15)])
            events.append({'t': round(time.time() - t0, 3), 'ev': 'exception',
                           'code': exc_code, 'first_chance': fc,
                           'address': addr, 'params': params,
                           'thread': de.dwThreadId})
            # initial breakpoint / non-fatal
            if exc_code in (0x80000003, 0x4000001f):
                k32.ContinueDebugEvent(de.dwProcessId, de.dwThreadId, DBG_CONTINUE)
                continue
            if exc_code not in (0xC0000005, 0xC0000409, 0xC0000374, 0xC000001D,
                                0xC0000094, 0xC00000FD, 0xC0000006, 0xE06D7363):
                k32.ContinueDebugEvent(de.dwProcessId, de.dwThreadId, DBG_CONTINUE)
                continue
            # capture
            hthread = k32.OpenThread(THREAD_GET_CONTEXT | THREAD_QUERY_INFORMATION,
                                     False, de.dwThreadId)
            ctx = CONTEXT64()
            ctx.ContextFlags = CONTEXT_FULL
            regs = {}
            stack = b''
            if hthread:
                if k32.GetThreadContext(hthread, ctypes.byref(ctx)):
                    regs = {n: getattr(ctx, n) for n in
                            ('Rip', 'Rsp', 'Rbp', 'Rax', 'Rbx', 'Rcx', 'Rdx', 'Rsi',
                             'Rdi', 'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15')}
                    stack = read_mem(pi.hProcess, ctx.Rsp, 0x8000)
                k32.CloseHandle(hthread)
            mods = list_modules(pid)
            # thread list via Toolhelp
            captured = {
                'pid': pid,
                't_s': round(time.time() - t0, 3),
                'exc': {'code': exc_code, 'address': addr, 'first_chance': fc,
                        'params': params,
                        'address_resolved': resolve(mods, addr),
                        'access': ({0: 'READ', 1: 'WRITE', 8: 'EXECUTE'}.get(params[0], str(params[0]))
                                   if params else None)},
                'regs': regs,
                'modules': [{'base': b, 'size': s, 'name': n} for b, s, n in mods],
                'stack_words': [
                    {'off': i, 'value': struct.unpack_from('<Q', stack, i)[0],
                     'resolved': resolve(mods, struct.unpack_from('<Q', stack, i)[0])}
                    for i in range(0, min(len(stack) - 8, 0x4000), 8)
                ],
            }
            print('CAPTURED:', json.dumps({k: captured[k] for k in ('exc', 'regs')},
                                          indent=2, default=str))
            k32.TerminateProcess(pi.hProcess, 0xC0000005)
            k32.ContinueDebugEvent(de.dwProcessId, de.dwThreadId, DBG_EXCEPTION_NOT_HANDLED)
            break
        k32.ContinueDebugEvent(de.dwProcessId, de.dwThreadId, cont)

    k32.CloseHandle(pi.hThread)
    k32.CloseHandle(pi.hProcess)
    result = {'tag': a.tag, 'pid': pid, 'exit_code': exit_code,
              'events': events, 'captured': captured}
    path = os.path.join(outdir, a.tag + '.dbg.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=1, default=str)
    print('wrote', path)
    if captured:
        print('\n== modules at crash (%d) ==' % len(captured['modules']))
        for m in captured['modules']:
            print('  %016x+0x%08x %s' % (m['base'], m['size'], m['name']))
        print('\n== stack words resolving into modules ==')
        n = 0
        for w in captured['stack_words']:
            if '0x' == w['resolved'][:2] and '+' not in w['resolved']:
                continue
            print('  [rsp+0x%04x] %016x %s' % (w['off'], w['value'], w['resolved']))
            n += 1
            if n > 60:
                break


if __name__ == '__main__':
    main()
