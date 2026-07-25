# Lua tests

Desktop tests for logic in `src/rfsuite/`, run against a mock Ethos API.

```bash
lua5.4 bin/test/run.lua           # everything
lua5.4 bin/test/run.lua header    # only files whose name contains "header"
```

Run from the repository root. Requires a Lua 5.4 interpreter
(`apt-get install lua5.4`, `brew install lua`) — nothing else, no LuaRocks
packages, no test framework.

Exits `0` when every check passes and `1` otherwise, so it is usable as a CI
gate.

## What this can and cannot test

`lib/ethos_mock.lua` stubs the Ethos API surface a module touches: `lcd`,
`system`, `model`, the font and colour constants, and the slice of the global
`rfsuite` table read at load time. It also shims `loadfile` so the
`SCRIPTS:/rfsuite/...` paths modules use to reach siblings resolve into
`src/rfsuite/`.

**Every `lcd` draw call is a no-op.** These tests can assert about geometry,
caching, invalidation and control flow. They cannot tell you whether anything
renders correctly, and passing here is not a substitute for trying a change on
a radio or in the simulator.

They also do not cover the transmitter-side scheduler, MSP, or telemetry — only
what has been written so far.

## Files

| Path | Purpose |
| --- | --- |
| `run.lua` | Runner. Discovers `*_test.lua`, reports, sets the exit code. |
| `lib/ethos_mock.lua` | Ethos + rfsuite mock, and a loader for `dashboard.lua`. |
| `lib/t.lua` | Assertion helpers (`t.check`, `t.eq`, `t.group`). |
| `dashboard_layout_cache_test.lua` | `renderLayout()` caches hold across paints *and* drop when their inputs change. |
| `dashboard_header_geometry_test.lua` | Header box rects match the header grid, so hit-testing and partial invalidation line up with what is drawn. |

Both dashboard tests were written against real defects and fail on the commits
that preceded the fixes — the header one reported 141px-tall boxes inside a
40px header and a negative width, the cache one reported a `table.sort` on
every paint.

## Adding a test

Create `bin/test/<name>_test.lua`. Load the helpers with `dofile` rather than
`require` — the runner shares one interpreter across files, and `require` would
cache them so counters leaked between tests.

```lua
local mock = dofile("bin/test/lib/ethos_mock.lua")
local t = dofile("bin/test/lib/t.lua")

mock.install()
local dashboard = mock.loadDashboard()

t.group("some behaviour")
t.eq("a count", actual, expected)
t.check("a condition", cond, actualValueForTheFailureMessage)

return t.failures()   -- the runner requires this
```

The `detail` argument to `t.check` is only printed on failure, so make it the
observed value rather than a restatement of the label. `t.eq` does this for you.

If you stub something the module under test needs and the mock does not provide,
add it to `lib/ethos_mock.lua` rather than to the individual test, so the next
test gets it too.

## Running in CI

Not currently wired into any workflow. To gate PRs on it, add to
`.github/workflows/pr.yml`:

```yaml
      - name: Install Lua
        run: sudo apt-get update && sudo apt-get install -y lua5.4

      - name: Run Lua tests
        run: lua5.4 bin/test/run.lua
```

That belongs in a single job rather than the per-locale `create-zip` matrix,
which would otherwise run it twelve times over.
