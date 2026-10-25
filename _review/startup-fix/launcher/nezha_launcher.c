/*
 * Portable launcher for "Nezha Ch1 playable" (nezha_ch1_playable_r2.exe).
 *
 * Why this exists:
 *   E:\godot_game_by_fable lives inside the managed tree of
 *   CodexSandboxService.OpenAI.Codex (the ChatGPT/Codex Windows sandbox).
 *   Every process started from that tree is forced to run with a Low
 *   Integrity token (S-1-16-4096). A Low-IL process has No-Write-Up against
 *   %APPDATA% (Medium label), so Godot cannot create/write user:// and dies
 *   with c0000005 at exe+0x2d985a7 (READ of 0x50) during startup.
 *
 *   This launcher redirects APPDATA (and TEMP/TMP) to a writable folder next
 *   to the game (userdata\), then starts the real game exe with the same
 *   working directory. It never touches global environment or security
 *   settings, and it only *copies* the old save, never moves/deletes it.
 *
 * Build:  gcc -O2 -municode -mwindows -o nezha_ch1_playable_r2_launcher.exe nezha_launcher.c
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdarg.h>
#include <wchar.h>

static void strip_filename(wchar_t *p)
{
    wchar_t *s = wcsrchr(p, L'\\');
    if (s) *s = L'\0';
}

/* recursive mkdir; already-exists is fine */
static BOOL ensure_dir(const wchar_t *dir)
{
    wchar_t buf[MAX_PATH * 2];
    int i;
    lstrcpynW(buf, dir, MAX_PATH * 2);
    for (i = 3; buf[i]; ++i) {
        if (buf[i] == L'\\') {
            buf[i] = L'\0';
            CreateDirectoryW(buf, NULL);
            buf[i] = L'\\';
        }
    }
    if (CreateDirectoryW(buf, NULL)) return TRUE;
    return GetLastError() == ERROR_ALREADY_EXISTS;
}

static void append_log(const wchar_t *file, const wchar_t *fmt, ...)
{
    wchar_t msg[2048];
    va_list ap;
    HANDLE h;
    DWORD wrote = 0;
    va_start(ap, fmt);
    vswprintf(msg, 2048, fmt, ap);
    va_end(ap);
    h = CreateFileW(file, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                    NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) return;
    SetFilePointer(h, 0, NULL, FILE_END);
    WriteFile(h, msg, (DWORD)(wcslen(msg) * sizeof(wchar_t)), &wrote, NULL);
    CloseHandle(h);
}

static BOOL file_exists(const wchar_t *p)
{
    DWORD a = GetFileAttributesW(p);
    return a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY);
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR cmdline, int show)
{
    (void)inst; (void)prev; (void)cmdline; (void)show;

    wchar_t dir[MAX_PATH] = L"";
    wchar_t game[MAX_PATH];
    wchar_t ud[MAX_PATH];      /* portable user:// root -> child APPDATA */
    wchar_t ud_app[MAX_PATH];  /* portable user_data_dir */
    wchar_t logfile[MAX_PATH];
    wchar_t tmp[MAX_PATH];
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    wchar_t cmd[4096];
    DWORD code = 0;
    DWORD old_app_len;
    wchar_t old_app[MAX_PATH] = L"";

    /* Godot user_data_dir relative part: Godot\app_userdata\<project name> */
    static const wchar_t *GODOT_APP =
        L"Godot\\app_userdata\\\u54ea\u5412\u00b7\u8f6e\u56de\u6d77\u57df";

    GetModuleFileNameW(NULL, dir, MAX_PATH);
    strip_filename(dir);

    swprintf(game, MAX_PATH, L"%s\\nezha_ch1_playable_r2.exe", dir);
    swprintf(ud, MAX_PATH, L"%s\\userdata", dir);
    swprintf(ud_app, MAX_PATH, L"%s\\%s", ud, GODOT_APP);
    swprintf(logfile, MAX_PATH, L"%s\\launcher.log", ud);
    swprintf(tmp, MAX_PATH, L"%s\\temp", ud);

    ensure_dir(ud);
    ensure_dir(ud_app);
    ensure_dir(tmp);

    if (!file_exists(game)) {
        MessageBoxW(NULL,
                    L"nezha_ch1_playable_r2.exe not found next to this launcher.\n\n"
                    L"Keep this launcher in the same folder as the game exe.",
                    L"Nezha launcher", MB_ICONERROR | MB_OK);
        return 2;
    }

    /* First run: copy (not move) the old save from the default %APPDATA%. */
    old_app_len = GetEnvironmentVariableW(L"APPDATA", old_app, MAX_PATH);
    if (old_app_len > 0 && old_app_len < MAX_PATH) {
        wchar_t old_ud[MAX_PATH], src[MAX_PATH], dst[MAX_PATH];
        swprintf(old_ud, MAX_PATH, L"%s\\%s", old_app, GODOT_APP);
        swprintf(src, MAX_PATH, L"%s\\progress.cfg", old_ud);
        swprintf(dst, MAX_PATH, L"%s\\progress.cfg", ud_app);
        if (file_exists(src) && !file_exists(dst)) {
            if (CopyFileW(src, dst, TRUE))
                append_log(logfile, L"[%lu] save copied: %s -> %s\r\n",
                           (unsigned long)GetTickCount(), src, dst);
            else
                append_log(logfile, L"[%lu] save copy FAILED err=%lu src=%s\r\n",
                           (unsigned long)GetTickCount(), (unsigned long)GetLastError(), src);
        }
    }

    SetEnvironmentVariableW(L"APPDATA", ud);
    SetEnvironmentVariableW(L"TEMP", tmp);
    SetEnvironmentVariableW(L"TMP", tmp);

    append_log(logfile, L"[%lu] launcher dir=%s\r\n", (unsigned long)GetTickCount(), dir);
    append_log(logfile, L"[%lu] APPDATA=%s\r\n", (unsigned long)GetTickCount(), ud);
    append_log(logfile, L"[%lu] launching %s\r\n", (unsigned long)GetTickCount(), game);

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));
    lstrcpynW(cmd, game, 4096);

    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, 0, NULL, dir, &si, &pi)) {
        DWORD err = GetLastError();
        wchar_t msg[1024];
        append_log(logfile, L"[%lu] CreateProcess failed err=%lu\r\n",
                   (unsigned long)GetTickCount(), (unsigned long)err);
        swprintf(msg, 1024, L"Could not start the game (error %lu).\nSee: %s",
                 (unsigned long)err, logfile);
        MessageBoxW(NULL, msg, L"Nezha launcher", MB_ICONERROR | MB_OK);
        return 3;
    }

    append_log(logfile, L"[%lu] game pid=%lu\r\n", (unsigned long)GetTickCount(),
               (unsigned long)pi.dwProcessId);
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &code);
    append_log(logfile, L"[%lu] game exited code=0x%08lx\r\n",
               (unsigned long)GetTickCount(), (unsigned long)code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return (int)code;
}
