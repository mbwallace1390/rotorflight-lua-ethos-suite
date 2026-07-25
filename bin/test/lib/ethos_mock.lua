--[[
  Minimal Ethos + rfsuite mock, enough to load a real module out of
  src/rfsuite/ and drive it from a desktop Lua 5.4 interpreter.

  This is deliberately shallow. It stubs the Ethos API surface the dashboard
  touches (lcd/system/model plus the font and colour constants) and the slice
  of the rfsuite global the module reads at load time. It does NOT emulate
  rendering: every lcd draw call is a no-op. Tests built on it can assert
  about geometry, caching and control flow, not about pixels.
]] --

local mock = {}

local REPO_SRC = "src/rfsuite/"

-- Counters for work the module does that tests want to observe.
mock.counts = {sort = 0, loadAllObjects = 0, getWindowSize = 0}

function mock.resetCounts()
    for k in pairs(mock.counts) do mock.counts[k] = 0 end
end

local winW, winH = 800, 480

--- Change the reported screen size. Tests use this to exercise the
--- resolution-change invalidation paths.
function mock.setWindowSize(w, h)
    winW, winH = w, h
end

function mock.windowSize() return winW, winH end

--- Install the Ethos globals plus package.loaded.rfsuite.
--- Call once, before loading any module under test.
function mock.install()
    lcd = {
        getWindowSize = function()
            mock.counts.getWindowSize = mock.counts.getWindowSize + 1
            return winW, winH
        end,
        RGB = function(r, g, b, a) return {r, g, b, a} end,
        color = function() end,
        pen = function() end,
        font = function() end,
        drawText = function() end,
        drawLine = function() end,
        drawRectangle = function() end,
        drawFilledRectangle = function() end,
        drawBitmap = function() end,
        getTextSize = function() return 10, 12 end,
        invalidate = function() end,
        darkMode = function() return false end,
        themeColor = function() return 0 end,
        loadMask = function() return {} end,
        loadBitmap = function() return {} end,
        isVisible = function() return true end,
        hasFocus = function() return false end,
    }

    system = {
        getVersion = function()
            return {simulation = true, lcdWidth = 800, lcdHeight = 480, major = 1, minor = 6, revision = 0}
        end,
        getSource = function() return nil end,
    }

    model = {path = function() return "/model/1" end, name = function() return "heli" end}

    FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_M = 1, 2, 3, 4, 5
    FONT_L, FONT_XL, FONT_XXL, FONT_S_BOLD = 6, 7, 8, 9
    CENTERED, SOLID, TEXT_LEFT = 1, 1, 1
    COLOR_BLACK, COLOR_WHITE = 0, 1
    THEME_DEFAULT_COLOR, THEME_DEFAULT_BGCOLOR = 0, 0
    THEME_FOCUS_COLOR, THEME_FOCUS_BGCOLOR = 0, 0

    -- buildBoxTypeSig() sorts a scratch array once per rebuild; counting sorts
    -- is how the caching tests observe whether that rebuild was skipped.
    --
    -- The runner executes several test files in one interpreter and each calls
    -- install(), so stash the genuine table.sort the first time and always wrap
    -- that -- otherwise each file wraps the previous file's wrapper and the
    -- chain grows.
    _G.__ethos_mock_real_sort = _G.__ethos_mock_real_sort or table.sort
    local realsort = _G.__ethos_mock_real_sort
    table.sort = function(t, cmp)
        mock.counts.sort = mock.counts.sort + 1
        return realsort(t, cmp)
    end

    package.loaded["rfsuite"] = {
        config = {baseDir = "rfsuite", preferences = "rfsuite.user"},
        session = {},
        flightmode = {current = "preflight"},
        preferences = {
            developer = {
                overlaygrid = false, overlaystats = false, overlaystatsadmin = false,
                memstats = false, taskprofiler = false, dashboardlogpanel = false,
            },
            general = {txbatt_type = 0, iconsize = 2},
            dashboard = {},
        },
        performance = {},
        utils = {
            log = function() end,
            round = function(v) return math.floor((v or 0) + 0.5) end,
            muteSensorLost = function() end,
            clearImageCaches = function() end,
        },
        tasks = {msp = {mspQueue = {isProcessed = function() return true end}}, telemetry = {}},
        ini = {getvalue = function() return nil end},
        bus = {registerAction = function() end, dispatchAction = function() end},
        i18n = {get = function(k) return k end},
    }

    -- Modules resolve siblings through Ethos "SCRIPTS:/rfsuite/..." paths and
    -- capture loadfile at their own load time, so the global must be shimmed
    -- before the module under test is loaded.
    local realloadfile = loadfile
    mock.realloadfile = realloadfile
    loadfile = function(path, ...)
        if type(path) == "string" then
            path = path:gsub("^SCRIPTS:/rfsuite/", REPO_SRC):gsub("^SCRIPTS:/", REPO_SRC)
        end
        local f = realloadfile(path, ...)
        if not f then
            -- Optional sibling that this mock does not provide: yield an empty
            -- table rather than aborting the whole test run.
            return function() return {} end
        end
        return f
    end
end

--- Load widgets/dashboard/dashboard.lua with its utils dependency stubbed and
--- object loading replaced by a counting no-op.
--- Returns the dashboard table.
function mock.loadDashboard()
    local dashboard = assert(mock.realloadfile(REPO_SRC .. "widgets/dashboard/dashboard.lua"))()

    dashboard.utils = {
        isFullScreen = function(w, h) return w >= 800 and h >= 480 end,
        setBackgroundColourBasedOnTheme = function() end,
        setScreenBorderStyle = function() end,
        drawScreenBorder = function() end,
        resolveColor = function() return 0 end,
        getThemeSignature = function() return "sig" end,
        resetImageCache = function() end,
        clearProgressDialog = function() end,
        screenError = function() end,
        applyOffset = function(x, y) return x, y end,
        getParam = function(box, k) return box[k] end,
    }

    local stubObject = {paint = function() end, wakeup = function() end, scheduler = 1.0}
    dashboard.loadAllObjects = function()
        mock.counts.loadAllObjects = mock.counts.loadAllObjects + 1
    end
    setmetatable(dashboard.objectsByType, {__index = function() return stubObject end})

    -- renderLayout() draws a loading spinner and returns early until the first
    -- wakeup pass has run. Tests want the full layout path, so step past it.
    dashboard._loader_min_duration = 0
    dashboard._loader_start_time = -1000
    dashboard._hg_cycles = 0
    dashboard._hg_cycles_required = 0

    return dashboard
end

--- Build a plain grid of body boxes.
function mock.gridBoxes(n, cols)
    cols = cols or 4
    local t = {}
    for i = 1, n do
        t[i] = {
            col = ((i - 1) % cols) + 1,
            row = math.floor((i - 1) / cols) + 1,
            type = "text",
            subtype = "telemetry",
        }
    end
    return t
end

return mock
