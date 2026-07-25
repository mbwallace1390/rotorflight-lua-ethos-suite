--[[
  Test runner for the Lua-side checks under bin/test/.

  Usage, from the repository root:

      lua5.4 bin/test/run.lua              # run every *_test.lua
      lua5.4 bin/test/run.lua header       # run tests whose name contains "header"

  Exits non-zero if any check fails, so it can gate CI.

  Test files share one interpreter and run in sequence. Each loads its own copy
  of the mock and assertion helpers via dofile (not require, which would cache
  and share counters between files), and package.loaded["rfsuite"] is cleared
  between files so one test cannot leak session state into the next.

  Each test file must return its failure count.
]] --

local TEST_DIR = "bin/test"

-- Fail fast with a useful message rather than a confusing "file not found"
-- twenty frames deep.
local probe = io.open("src/rfsuite/widgets/dashboard/dashboard.lua", "r")
if not probe then
    io.stderr:write("run.lua must be executed from the repository root\n")
    io.stderr:write("  cd <repo> && lua5.4 bin/test/run.lua\n")
    os.exit(2)
end
probe:close()

local filter = ...

--- List *_test.lua in bin/test. Uses `ls` because Lua has no portable
--- directory API and this only ever runs on a dev box or CI, never on a radio.
local function testFiles()
    local files = {}
    local pipe = io.popen("ls " .. TEST_DIR .. "/*_test.lua 2>/dev/null")
    if pipe then
        for line in pipe:lines() do files[#files + 1] = line end
        pipe:close()
    end
    table.sort(files)
    return files
end

local files = testFiles()
if #files == 0 then
    io.stderr:write("no test files found in " .. TEST_DIR .. "\n")
    os.exit(2)
end

local totalFailures = 0
local ran = 0
local skipped = 0
local broken = {}

for _, path in ipairs(files) do
    local name = path:match("([^/]+)%.lua$")
    if filter and not name:find(filter, 1, true) then
        skipped = skipped + 1
    else
        ran = ran + 1
        print("\n=== " .. name .. " ===")

        -- Each file gets a clean global table for the Ethos stubs, and a clean
        -- package.loaded["rfsuite"], so one test cannot leak state into another.
        package.loaded["rfsuite"] = nil

        local chunk, loadErr = loadfile(path)
        if not chunk then
            totalFailures = totalFailures + 1
            broken[#broken + 1] = name
            print("    FAIL  could not load: " .. tostring(loadErr))
        else
            local ok, result = pcall(chunk)
            if not ok then
                totalFailures = totalFailures + 1
                broken[#broken + 1] = name
                print("    FAIL  error during run: " .. tostring(result))
            elseif type(result) == "number" then
                totalFailures = totalFailures + result
            else
                totalFailures = totalFailures + 1
                broken[#broken + 1] = name
                print("    FAIL  test file did not return a failure count")
            end
        end
    end
end

print("")
print(string.rep("-", 60))
local summary = string.format("%d test file(s) run", ran)
if skipped > 0 then summary = summary .. string.format(", %d skipped by filter", skipped) end
print(summary)

if totalFailures == 0 then
    print("PASS - no failures")
    os.exit(0)
else
    print(string.format("FAIL - %d failure(s)", totalFailures))
    if #broken > 0 then
        print("files that errored: " .. table.concat(broken, ", "))
    end
    os.exit(1)
end
