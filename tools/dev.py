#!/usr/bin/env python3
"""The repo's checks, run before every commit (all must pass):

  python3 tools/dev.py test    unit tests: tests/*_test.lua (Lua 5.3, grandMA2 stand-in in tests/ma2_stub.lua)
  python3 tools/dev.py check   Lua 5.3 compile of every plugin file, plugin XMLs <-> files,
                               repo rules (names, commit messages)
  python3 tools/dev.py smoke   builds the show against the grandMA2 stand-in (8 groups, 1 group, a rebuild)
  python3 tools/dev.py         all three

Needs Python 3 and Lua 5.3, the Lua of grandMA2 3.9 (macOS: brew install lua@5.3; Debian/Ubuntu:
apt install lua5.3); see tools/lua.py.
"""
import codecs, glob, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = [sys.executable, os.path.join(ROOT, "tools", "lua.py")]

# Names that must not appear in the repo, its commit messages or branch names, and trailers that
# must not appear in commit messages (stored rot13 so this file doesn't contain them either).
# Matched case-insensitively.
def _words(*rot):
    return re.compile("|".join(re.escape(codecs.decode(w, "rot13")) for w in rot), re.I)


BANNED_RE = _words("pynhqr", "nagutebcvp")
TRAILER_RE = _words("pb-nhguberq-ol", "trarengrq jvgu")
# Generated data that is never hand-written (base64 images can contain any letters).
SKIP_SCAN = set()
TEXT_EXT = {".lua", ".py", ".md", ".xml", ".yml", ".yaml", ".html", ".css", ".js", ".json", ".txt", ".sh", ""}


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT).returncode == 0


def git(*args):
    r = subprocess.run(["git"] + list(args), cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def rel_glob(pattern):
    # relative paths (glob's root_dir needs Python 3.10; macOS's python3 can be 3.9)
    return sorted(os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, pattern)))


def plugin_files():
    return rel_glob(os.path.join("plugins", "*.lua"))


def cmd_test():
    tests = rel_glob(os.path.join("tests", "*_test.lua"))
    print("== test")
    return run(LUA + ["tests/run.lua"] + tests)


def cmd_smoke():
    print("== smoke")
    return run(LUA + ["tests/smoke.lua"])


def check_xml():
    # every plugin XML names an existing .lua (luafile="..."), and every .lua has an XML
    ok = True
    named = set()
    for x in glob.glob(os.path.join(ROOT, "plugins", "*.xml")):
        text = open(x, encoding="utf-8").read()
        files = re.findall(r'luafile="([^"]+)"', text)
        if not files:
            print(f"plugins/{os.path.basename(x)} names no luafile")
            ok = False
        for f in files:
            named.add(f)
            if not os.path.exists(os.path.join(ROOT, "plugins", f)):
                print(f"plugins/{os.path.basename(x)} names {f}, which is not in plugins/")
                ok = False
    for p in glob.glob(os.path.join(ROOT, "plugins", "*.lua")):
        if os.path.basename(p) not in named:
            print(f"plugins/{os.path.basename(p)} has no plugin XML")
            ok = False
    return ok


def check_repo_rules():
    ok = True
    tracked = git("ls-files")
    files = tracked.split("\n") if tracked else []
    for f in files:
        if not f or f in SKIP_SCAN or os.path.splitext(f)[1].lower() not in TEXT_EXT:
            continue
        if BANNED_RE.search(f):
            print(f"repo rule: file name {f}")
            ok = False
        try:
            text = open(os.path.join(ROOT, f), encoding="utf-8").read()
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
        for n, line in enumerate(text.split("\n"), 1):
            if BANNED_RE.search(line):
                print(f"repo rule: {f}:{n}: {line.strip()[:100]}")
                ok = False
    branch = (git("branch", "--show-current") or "").strip()
    if branch and BANNED_RE.search(branch):
        print(f"repo rule: branch name {branch}")
        ok = False
    # this branch's own commits (the ones not on main yet)
    base = "origin/main" if git("rev-parse", "--verify", "-q", "origin/main") else None
    if base and branch != "main":
        log = git("log", "--format=%H%x00%an <%ae>%x00%B%x01", base + "..HEAD") or ""
        for entry in log.split("\x01"):
            entry = entry.strip()
            if not entry:
                continue
            sha, author, body = (entry.split("\x00") + ["", ""])[:3]
            if BANNED_RE.search(author) or BANNED_RE.search(body) or TRAILER_RE.search(body):
                print(f"repo rule: commit {sha[:9]} ({author}) has a banned name or trailer")
                ok = False
    return ok


def cmd_check():
    print("== check")
    files = plugin_files()
    ok = run(LUA + ["tests/syntax.lua"] + files)
    ok = check_xml() and ok
    ok = check_repo_rules() and ok
    print("check: " + ("ok" if ok else "FAILED"))
    return ok


COMMANDS = {"test": cmd_test, "check": cmd_check, "smoke": cmd_smoke}


def main(argv):
    names = argv or ["test", "check", "smoke"]
    for n in names:
        if n not in COMMANDS:
            print(__doc__)
            return 2
    results = [COMMANDS[n]() for n in names]
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
