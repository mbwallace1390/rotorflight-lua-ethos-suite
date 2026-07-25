--[[
  Tiny assertion helper. No dependencies, no test framework.

  Each test file requires this, calls t.group()/t.check(), and returns
  t.failures() so the runner can total them up.
]] --

local t = {}

local failures = 0
local checks = 0

function t.group(name)
    print("  " .. name)
end

--- Record a check. `detail` is only printed on failure, so make it the actual
--- observed value rather than a restatement of the label.
function t.check(label, cond, detail)
    checks = checks + 1
    if cond then
        print("    pass  " .. label)
    else
        failures = failures + 1
        print("    FAIL  " .. label .. "  ->  " .. tostring(detail))
    end
end

function t.eq(label, got, want)
    t.check(label, got == want, string.format("got %s, want %s", tostring(got), tostring(want)))
end

function t.failures() return failures end
function t.checks() return checks end

function t.reset()
    failures = 0
    checks = 0
end

return t
