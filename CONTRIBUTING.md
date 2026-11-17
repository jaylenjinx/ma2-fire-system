# FireSystem MA2: project rules

These rules apply to every change in this repo.

## Test-driven development

- Every feature or fix starts with a test that fails, then the code that makes it pass.
- Tests go in `tests/*_test.lua` and run with Lua 5.3, the Lua of grandMA2 3.9:
  `python3 tools/dev.py test`. A test file calls `test("name", function() ... end)` and uses
  `t.eq`, `t.ok`, `t.near`, `t.err` (see `tests/run.lua`).
- A plugin is loaded outside MA2 through `tests/ma2_stub.lua`, a stand-in for MA2's `gma` API:
  `local stub, Start = require("ma2_stub").load({1, 2})` (groups 1 and 2 exist). `Start()` runs
  a build, `stub.cmds` lists every command sent, `stub.objects` says which objects exist (by
  name, with their labels), `stub.confirm` answers the build dialog, and
  `require("ma2_stub").find(Start, "seq_no")` reaches one of the plugin's local helpers.
- Test logic that doesn't need MA2 directly. For show behaviour (macros, cues, layouts), pull the
  decision into a small pure function (no `gma.*`) and test that, or check the commands a build
  sends.
- Bugs found in real show files get a small synthetic reproduction in the suite (the stand-in's
  objects and variables set up to match), never the show file itself.
- Run `python3 tools/dev.py` before every commit; it runs all three and they must pass:
  - `test`: the unit tests;
  - `check`: every plugin compiles with Lua 5.3, each plugin XML names an existing `.lua` (and
    every `.lua` has an XML), and the repo rules below (file contents, branch name, this branch's
    commit messages);
  - `smoke`: builds the show against the stand-in (8 groups with forms and gels, 1 group with
    nothing found, a rebuild); any Lua error fails.
- Needs Python 3 and Lua 5.3 (macOS: `brew install lua@5.3`, Debian/Ubuntu: `apt install lua5.3`).
  Without 5.3, `tools/lua.py` falls back to Lua 5.4 and says so; CI always runs 5.3.
- Changes MA2 shows (executors, macros, layouts, cues) get checked live in grandMA2 onPC too, not
  only by tests: import the plugin in the Plugins pool and build.

## Repo rules

- No mentions of the AI assistant or its maker anywhere in the repo: code, comments, commits,
  branch names, README, PRs, release notes. (`tools/dev.py check` scans for them.)
- Commits: no Co-Authored-By trailers, no "Generated with" lines. Author is Jay:
  `git -c user.name=Jay -c user.email=jaylen@sulfurdesign.com commit`
- Branches are `feature/<slug>`; merge to main through a PR (rebase merge, so the commits land
  as written).
- No venue names in the repo.
- Versions: bump the version in the plugin's README line / header when a change is merged
  (there is no release workflow yet).
