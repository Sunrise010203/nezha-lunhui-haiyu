#!/usr/bin/env python3
"""Probe the Windows token (user/groups/integrity/appcontainer/restricted SIDs)
of this process and of a freshly launched child, to explain file-access diffs.

Usage: python token_probe.py [--exe PATH] [--appdata PATH] [--env clean] [--keep SEC]
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import json
import os
import subprocess
import sys
import time

k32 = ctypes.WinDLL('kernel32', use_last_error=True)
advapi = ctypes.WinDLL('advapi32', use_last_error=True)

TOKEN_QUERY = 0x0008
TokenUser = 1
TokenGroups = 2
TokenRestrictedSids = 11
TokenIntegrityLevel = 25
TokenIsAppContainer = 29
TokenType = 8

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

_H = ctypes.c_void_p
k32.OpenProcess.restype = _H
k32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
k32.CloseHandle.restype = wt.BOOL
k32.CloseHandle.argtypes = [_H]
k32.LocalFree.restype = _H
k32.LocalFree.argtypes = [_H]
advapi.OpenProcessToken.restype = wt.BOOL
advapi.OpenProcessToken.argtypes = [_H, wt.DWORD, ctypes.POINTER(_H)]
advapi.GetTokenInformation.restype = wt.BOOL
advapi.GetTokenInformation.argtypes = [_H, ctypes.c_int, ctypes.c_void_p, wt.DWORD,
                                       ctypes.POINTER(wt.DWORD)]
advapi.ConvertSidToStringSidW.restype = wt.BOOL
advapi.ConvertSidToStringSidW.argtypes = [ctypes.c_void_p, ctypes.POINTER(wt.LPWSTR)]
advapi.LookupAccountSidW.restype = wt.BOOL
advapi.LookupAccountSidW.argtypes = [wt.LPWSTR, ctypes.c_void_p, wt.LPWSTR,
                                     ctypes.POINTER(wt.DWORD), wt.LPWSTR,
                                     ctypes.POINTER(wt.DWORD), ctypes.POINTER(wt.DWORD)]

INTEGRITY = {0x0000: 'Untrusted', 0x1000: 'Low', 0x2000: 'Medium', 0x2100: 'MediumPlus',
             0x3000: 'High', 0x4000: 'System', 0x5000: 'ProtectedProcess'}


def sid_to_string(psid):
    s = wt.LPWSTR()
    if not advapi.ConvertSidToStringSidW(psid, ctypes.byref(s)):
        return '<sid err %d>' % ctypes.get_last_error()
    try:
        return s.value
    finally:
        k32.LocalFree(s)


def sid_name(psid):
    name = ctypes.create_unicode_buffer(256)
    dom = ctypes.create_unicode_buffer(256)
    n = wt.DWORD(256)
    d = wt.DWORD(256)
    use = wt.DWORD(0)
    if advapi.LookupAccountSidW(None, psid, name, ctypes.byref(n), dom, ctypes.byref(d),
                                ctypes.byref(use)):
        return ('%s\\%s' % (dom.value, name.value)) if dom.value else name.value
    return ''


def token_info(pid):
    h = k32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return {'error': 'OpenProcess %d' % ctypes.get_last_error()}
    tok = _H()
    if not advapi.OpenProcessToken(h, TOKEN_QUERY, ctypes.byref(tok)):
        k32.CloseHandle(h)
        return {'error': 'OpenProcessToken %d' % ctypes.get_last_error()}
    out = {}
    size = wt.DWORD(0)
    # token type
    buf = ctypes.create_string_buffer(16)
    if advapi.GetTokenInformation(tok, TokenType, buf, 16, ctypes.byref(size)):
        out['token_type'] = 'Primary' if ctypes.cast(buf, ctypes.POINTER(wt.DWORD)).contents.value == 1 else 'Impersonation'
    # appcontainer
    buf = ctypes.create_string_buffer(16)
    if advapi.GetTokenInformation(tok, TokenIsAppContainer, buf, 16, ctypes.byref(size)):
        out['is_appcontainer'] = bool(ctypes.cast(buf, ctypes.POINTER(wt.DWORD)).contents.value)

    def get_sids(kind):
        advapi.GetTokenInformation(tok, kind, None, 0, ctypes.byref(size))
        b = ctypes.create_string_buffer(max(size.value, 4))
        if not advapi.GetTokenInformation(tok, kind, b, size.value, ctypes.byref(size)):
            return None
        cnt = ctypes.cast(b, ctypes.POINTER(wt.DWORD)).contents.value
        # SID_AND_ATTRIBUTES: SID* (8) + DWORD attributes (4) + pad(4) = 16 bytes
        res = []
        base = ctypes.addressof(b) + 8
        for i in range(cnt):
            off = base + i * 16
            psid = ctypes.cast(off, ctypes.POINTER(ctypes.c_void_p)).contents.value
            attr = ctypes.cast(off + 8, ctypes.POINTER(wt.DWORD)).contents.value
            res.append((sid_to_string(psid), sid_name(psid), hex(attr)))
        return res

    u = get_sids(TokenUser)
    if u:
        out['user'] = {'sid': u[0][0], 'name': u[0][1]}
    g = get_sids(TokenGroups)
    if g:
        out['groups'] = ['%s (%s) %s' % (n or s, s, a) for s, n, a in g]
    r = get_sids(TokenRestrictedSids)
    if r is not None:
        out['restricted_sids'] = ['%s (%s)' % (n or s, s) for s, n, a in r]
    # integrity
    advapi.GetTokenInformation(tok, TokenIntegrityLevel, None, 0, ctypes.byref(size))
    b = ctypes.create_string_buffer(max(size.value, 4))
    if advapi.GetTokenInformation(tok, TokenIntegrityLevel, b, size.value, ctypes.byref(size)):
        psid = ctypes.cast(b, ctypes.POINTER(ctypes.c_void_p)).contents.value
        sub = ctypes.cast(psid, ctypes.POINTER(ctypes.c_ubyte))[7]
        out['integrity_raw'] = hex(sub * 0x1000)
        out['integrity'] = INTEGRITY.get(sub * 0x1000, hex(sub * 0x1000))
    k32.CloseHandle(tok)
    k32.CloseHandle(h)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--exe', default=None)
    ap.add_argument('--appdata', default=None)
    ap.add_argument('--env', default='clean')
    ap.add_argument('--keep', type=float, default=6.0)
    a = ap.parse_args()

    print('== current python process (pid %d) ==' % os.getpid())
    print(json.dumps(token_info(os.getpid()), indent=1, ensure_ascii=False))

    if a.exe:
        if a.env == 'inherit':
            env = dict(os.environ)
        else:
            base = os.environ.get('USERPROFILE', r'C:\Users\Sunrise')
            env = {'SystemRoot': r'C:\Windows', 'windir': r'C:\Windows',
                   'SystemDrive': 'C:', 'ComSpec': r'C:\Windows\system32\cmd.exe',
                   'PATH': r'C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem',
                   'PATHEXT': '.COM;.EXE;.BAT;.CMD',
                   'TEMP': os.path.join(base, 'AppData', 'Local', 'Temp'),
                   'TMP': os.path.join(base, 'AppData', 'Local', 'Temp'),
                   'USERPROFILE': base, 'USERNAME': os.environ.get('USERNAME', 'Sunrise'),
                   'USERDOMAIN': os.environ.get('USERDOMAIN', ''),
                   'APPDATA': os.path.join(base, 'AppData', 'Roaming'),
                   'LOCALAPPDATA': os.path.join(base, 'AppData', 'Local'),
                   'NUMBER_OF_PROCESSORS': '24', 'PROCESSOR_ARCHITECTURE': 'AMD64',
                   'OS': 'Windows_NT'}
        if a.appdata:
            env['APPDATA'] = a.appdata
        exe = os.path.abspath(a.exe)
        p = subprocess.Popen([exe], cwd=os.path.dirname(exe), env=env,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1.5)
        print('\n== child %s pid %d (still running: %s) ==' %
              (os.path.basename(exe), p.pid, p.poll() is None))
        print(json.dumps(token_info(p.pid), indent=1, ensure_ascii=False))
        try:
            p.wait(timeout=max(0.1, a.keep))
        except subprocess.TimeoutExpired:
            p.terminate()
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                p.kill()


if __name__ == '__main__':
    main()
