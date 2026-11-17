#!/usr/bin/env python3
"""Runs a Lua 5.3 script: python3 tools/lua.py script.lua [args...]

grandMA2 3.9 runs Lua 5.3, so the tests and checks should too. Uses a `lua5.3` (or `lua` 5.3)
binary when one is on the PATH (brew install lua@5.3 / apt install lua5.3), else the liblua5.3
shared library through ctypes. Without 5.3 it falls back to Lua 5.4 (binary or library) and says
so: close enough for the unit tests, but CI runs the real 5.3.
"""
import ctypes, ctypes.util, glob, os, shutil, subprocess, sys

WANT = "5.3"
LIB53 = [
    "/usr/lib/x86_64-linux-gnu/liblua5.3.so.0", "/usr/lib/aarch64-linux-gnu/liblua5.3.so.0",
    "/opt/homebrew/opt/lua@5.3/lib/liblua.5.3.dylib", "/usr/local/opt/lua@5.3/lib/liblua.5.3.dylib",
]
LIB_CANDIDATES = [
    "/usr/lib/x86_64-linux-gnu/liblua5.4.so.0", "/usr/lib/aarch64-linux-gnu/liblua5.4.so.0",
    "/usr/lib/x86_64-linux-gnu/liblua5.4.so", "/opt/homebrew/lib/liblua.5.4.dylib",
    "/opt/homebrew/lib/liblua5.4.dylib", "/usr/local/lib/liblua.5.4.dylib", "/usr/local/lib/liblua5.4.dylib",
]


def find_binary(ver="5.4"):
    names = ("lua5.3", "lua53", "/opt/homebrew/opt/lua@5.3/bin/lua", "/usr/local/opt/lua@5.3/bin/lua", "lua") \
        if ver == "5.3" else ("lua5.4", "lua")
    for name in names:
        exe = shutil.which(name)
        if not exe:
            continue
        try:
            out = subprocess.run([exe, "-v"], capture_output=True, text=True).stdout
        except OSError:
            continue
        if "Lua " + ver in out:
            return exe
    return None


def find_library(ver="5.4"):
    if ver == "5.3":
        for p in LIB53:
            if os.path.exists(p):
                return p
        p = ctypes.util.find_library("lua5.3")
        return p
    for p in LIB_CANDIDATES:
        if os.path.exists(p):
            return p
    for name in ("lua5.4", "lua.5.4", "lua"):
        p = ctypes.util.find_library(name)
        if p:
            return p
    return None


def run_with_library(path, script, args):
    lib = ctypes.CDLL(path)
    lib.luaL_newstate.restype = ctypes.c_void_p
    L = ctypes.c_void_p(lib.luaL_newstate())
    lib.luaL_openlibs(L)
    lib.lua_createtable(L, len(args) + 1, 0)
    for i, a in enumerate([script] + list(args)):
        lib.lua_pushstring(L, a.encode())
        lib.lua_rawseti(L, ctypes.c_int(-2), ctypes.c_longlong(i))
    lib.lua_setglobal(L, b"arg")
    # traceback handler: debug.traceback
    lib.lua_getglobal(L, b"debug")
    lib.lua_getfield(L, ctypes.c_int(-1), b"traceback")
    lib.lua_rotate(L, ctypes.c_int(-2), ctypes.c_int(1))
    lib.lua_settop(L, ctypes.c_int(-2))  # leave traceback at index 1
    lib.lua_tolstring.restype = ctypes.c_char_p
    rc = lib.luaL_loadfilex(L, script.encode(), None)
    if rc == 0:
        for a in args:
            lib.lua_pushstring(L, a.encode())
        rc = lib.lua_pcallk(L, ctypes.c_int(len(args)), ctypes.c_int(0), ctypes.c_int(1), None, None)
    if rc != 0:
        msg = lib.lua_tolstring(L, ctypes.c_int(-1), None)
        sys.stdout.flush()
        sys.stderr.write((msg or b"error").decode(errors="replace") + "\n")
        return 1
    sys.stdout.flush()
    return 0


def main(argv):
    if not argv:
        sys.stderr.write(__doc__)
        return 2
    for ver in (WANT, "5.4"):
        exe = find_binary(ver)
        lib = None if exe else find_library(ver)
        if not (exe or lib):
            continue
        if ver != WANT:
            sys.stderr.write(f"(Lua {WANT} not found, using Lua {ver}: brew install lua@5.3 / apt install lua5.3)\n")
        if exe:
            return subprocess.run([exe] + argv).returncode
        return run_with_library(lib, argv[0], argv[1:])
    sys.stderr.write("Lua 5.3 not found: install it (macOS: brew install lua@5.3, Debian/Ubuntu: apt install lua5.3)\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
