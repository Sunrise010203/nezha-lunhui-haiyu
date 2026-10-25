import ctypes, sys
from ctypes import wintypes as wt
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
adv = ctypes.WinDLL("advapi32", use_last_error=True)
H = ctypes.c_void_p
k32.OpenProcess.restype = H; k32.OpenProcess.argtypes=[wt.DWORD, wt.BOOL, wt.DWORD]
k32.CloseHandle.restype = wt.BOOL; k32.CloseHandle.argtypes=[H]
k32.LocalFree.restype = H; k32.LocalFree.argtypes=[H]
adv.OpenProcessToken.restype = wt.BOOL; adv.OpenProcessToken.argtypes=[H, wt.DWORD, ctypes.POINTER(H)]
adv.GetTokenInformation.restype = wt.BOOL
adv.GetTokenInformation.argtypes=[H, ctypes.c_int, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD)]
adv.ConvertSidToStringSidW.restype = wt.BOOL
adv.ConvertSidToStringSidW.argtypes=[ctypes.c_void_p, ctypes.POINTER(wt.LPWSTR)]
adv.LookupAccountSidW.restype = wt.BOOL
adv.LookupAccountSidW.argtypes=[wt.LPWSTR, ctypes.c_void_p, wt.LPWSTR, ctypes.POINTER(wt.DWORD), wt.LPWSTR, ctypes.POINTER(wt.DWORD), ctypes.POINTER(wt.DWORD)]

def sid_str(psid):
    p = wt.LPWSTR()
    if not adv.ConvertSidToStringSidW(psid, ctypes.byref(p)):
        return "?"
    s = p.value
    k32.LocalFree(p)
    return s

def sid_name(psid):
    n = ctypes.create_unicode_buffer(256); d = ctypes.create_unicode_buffer(256)
    nl = wt.DWORD(256); dl = wt.DWORD(256); sn = wt.DWORD(0)
    if adv.LookupAccountSidW(None, psid, n, ctypes.byref(nl), d, ctypes.byref(dl), ctypes.byref(sn)):
        return f"{d.value}\\{n.value}"
    return "?"

def get(tok, cls, elem_sz_offset=None):
    size = wt.DWORD(0)
    adv.GetTokenInformation(tok, cls, None, 0, ctypes.byref(size))
    buf = ctypes.create_string_buffer(max(size.value, 8))
    if not adv.GetTokenInformation(tok, cls, buf, size.value, ctypes.byref(size)):
        return None, ctypes.get_last_error()
    return buf, size.value

def token_info(pid):
    h = k32.OpenProcess(0x1000, False, pid)
    if not h: return {"error": f"OpenProcess {ctypes.get_last_error()}"}
    tok = H()
    if not adv.OpenProcessToken(h, 0x0008, ctypes.byref(tok)):
        return {"error": f"OpenProcessToken {ctypes.get_last_error()}"}
    out = {"pid": pid}
    buf, sz = get(tok, 25)  # IntegrityLevel: TOKEN_MANDATORY_LABEL{SID_AND_ATTRIBUTES}
    if buf:
        struct = ctypes.cast(buf, ctypes.POINTER(ctypes.c_void_p * 2))[0]
        # layout: SID ptr then DWORD attrs
        raw = buf.raw[:sz]
        psid = ctypes.c_void_p(int.from_bytes(raw[0:8], "little"))
        out["integrity_sid"] = sid_str(psid)
    else:
        out["integrity_sid"] = "err"
    buf, sz = get(tok, 11)  # RestrictedSids
    if buf:
        cnt = int.from_bytes(buf.raw[0:4], "little")
        out["restricted_count"] = cnt
        ptrs = []
        for i in range(cnt):
            off = 8 + i*16
            ptrs.append(int.from_bytes(buf.raw[off:off+8], "little"))
        out["restricted"] = [sid_str(ctypes.c_void_p(p)) + " " + sid_name(ctypes.c_void_p(p)) for p in ptrs]
    else:
        out["restricted_count"] = 0
    buf, sz = get(tok, 2)  # Groups
    if buf:
        cnt = int.from_bytes(buf.raw[0:4], "little")
        gl = []
        for i in range(cnt):
            off = 8 + i*16
            p = int.from_bytes(buf.raw[off:off+8], "little")
            attr = int.from_bytes(buf.raw[off+8:off+12], "little")
            gl.append(sid_str(ctypes.c_void_p(p)) + f" attr=0x{attr:x}")
        out["groups"] = gl
    buf, sz = get(tok, 1)  # User
    if buf:
        p = int.from_bytes(buf.raw[0:8], "little")
        out["user_sid"] = sid_str(ctypes.c_void_p(p))
    buf, sz = get(tok, 18)  # TokenElevationType
    if buf:
        out["elevation_type"] = int.from_bytes(buf.raw[0:4], "little")
    k32.CloseHandle(tok); k32.CloseHandle(h)
    return out

if __name__ == "__main__":
    pid = int(sys.argv[1]) if len(sys.argv) > 1 else __import__("os").getpid()
    print(__import__("json").dumps(token_info(pid), indent=1))
