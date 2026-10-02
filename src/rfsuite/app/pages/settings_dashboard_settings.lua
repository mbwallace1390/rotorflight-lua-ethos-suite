-- Settings -> Dashboard -> Settings.
--
-- Mirrors the original suite's dashboard-settings page shape: a tile grid
-- of dashboard themes that expose a configure.lua, with each tile opening
-- that theme's own configuration form.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local tileGrid = requireModule("app/tile_grid.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local themeCatalog = requireModule("lib/dashboard_themes.lua")
local dashboardContext = requireModule("widgets/dashboard/context.lua")
local themeBridge = requireModule("app/theme_bridge.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.dashboard)@ / @i18n(app.modules.settings.dashboard_settings)@"
local NO_THEMES = "@i18n(app.modules.settings.no_themes_available_to_configure)@"
local LOAD_FAILED = "@i18n(app.msg_load_failed_title)@"


local lastSelected


local function themeVisible(theme)
  local minRes = theme and theme.minResolution
  if type(minRes) ~= "table" then return true end
  local w, h = lcd.getWindowSize()
  return not (w and h and (w < (minRes.x or 0) or h < (minRes.y or 0)))
end

-- Cache the small visible tile list for this window; the shared catalog has
-- already checked file availability without compiling every configure.lua.
local function configuredThemes()
  local w, h = lcd.getWindowSize()
  local session = dashboardContext.session
  if session.dashboardConfiguredThemes and session.dashboardConfiguredWidth == w
    and session.dashboardConfiguredHeight == h then return session.dashboardConfiguredThemes end

  local themes = {}
  for _, theme in ipairs(themeCatalog.list()) do
    if theme.configure and themeVisible(theme) then
      themes[#themes + 1] = {
        label = theme.label, folder = themeCatalog.key(theme.path),
        configure = theme.configure, icon = theme.icon,
      }
    end
  end
  session.dashboardConfiguredThemes = themes
  session.dashboardConfiguredWidth, session.dashboardConfiguredHeight = w, h
  return themes
end

local function saveThemePrefs(settings, themeModule, folder)
  if themeModule and themeModule.write then themeModule.write() end
  settingsStore.setDashboardTheme(settings, folder, dashboardContext.widgets.dashboard.preferences())
  settingsStore.save(settings)
  bus.publish("settings.update", settingsStore.clone(settings))
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local settings = settingsStore.load()
  local headerHandle

  local function clearHandlers()
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    clearHandlers()
    dashboardContext.widgets.dashboard.setPreferences(nil)
    if opts.onBack then opts.onBack() end
  end

  local openThemeGrid
  local function openTheme(theme)
    local okLoad, chunk = pcall(loadfile, theme.configure)
    local okRun, themeModule
    if okLoad and type(chunk) == "function" then okRun, themeModule = pcall(chunk) end
    if not okRun or type(themeModule) ~= "table"
      or (themeModule.configure ~= nil and type(themeModule.configure) ~= "function") then
      openThemeGrid(true)
      return
    end

    form.clear()
    dashboardContext.widgets.dashboard.setPreferences(settingsStore.dashboardTheme(settings, theme.folder))

    headerHandle = header.build(theme.label, {
      onBack = function()
        open(opts)
      end,
      onSave = function()
        saveThemePrefs(settings, themeModule, theme.folder)
        if headerHandle then headerHandle.focusSave() end
      end,
      onReload = function()
        openTheme(theme)
        if headerHandle then headerHandle.focusReload() end
      end,
    })

    if opts.setEventHandler then
      opts.setEventHandler(function(category, value)
        if not closeKey.shouldHandleClose(category, value) then return false end
        open(opts)
        return true
      end)
    end
    clearHandlers()
    if opts.setCleanupHandler then
      opts.setCleanupHandler(function()
        dashboardContext.widgets.dashboard.setPreferences(nil)
      end)
    end

    if themeModule.configure then
      local configured = pcall(themeModule.configure)
      if not configured then
        -- Discard a partially built form and its page handlers/preferences.
        openThemeGrid(true)
        return
      end
    end
    if headerHandle then
      headerHandle.setSaveEnabled(true)
      headerHandle.setReloadEnabled(true)
      headerHandle.focusMenu()
    end
  end

  openThemeGrid = function(loadFailed)
    form.clear()
    clearHandlers()
    dashboardContext.widgets.dashboard.setPreferences(nil)

    if opts.setEventHandler then
      opts.setEventHandler(function(category, value)
        if not closeKey.shouldHandleClose(category, value) then return false end
        goBack()
        return true
      end)
    end
    if opts.setCleanupHandler then opts.setCleanupHandler(goBack) end

    local gridHeader = header.build(PAGE_TITLE, {onBack = goBack})
    local themes = configuredThemes()
    local windowWidth, windowHeight = lcd.getWindowSize()
    local numPerRow, tileW, tileH, tilePadding, tileFont = tileGrid.metrics(windowWidth, windowHeight)
    local x, y = 0, form.height() + tilePadding
    if loadFailed then
      form.addStaticText(nil, {x = tilePadding, y = y, w = windowWidth - (2 * tilePadding), h = 32}, LOAD_FAILED, CENTERED)
      y = y + 36
    end
    local col = 0
    local buttons = {}

    local iconCache = dashboardContext.session.dashboardThemeIconCache
    if not iconCache then
      iconCache = {}
      dashboardContext.session.dashboardThemeIconCache = iconCache
    end

    for i, theme in ipairs(themes) do
      local icon = iconCache[theme.icon]
      if icon == nil then
        icon = lcd.loadMask(theme.icon) or false
        iconCache[theme.icon] = icon
      end
      local label = tileGrid.fitLabel(theme.label, tileW, tileFont)
      local tileRect = {x = x, y = y, w = tileW, h = tileH}
      buttons[i] = form.addButton(nil, tileRect, {
        text = label,
        icon = icon or nil,
        options = tileFont,
        press = function()
          lastSelected = i
          openTheme(theme)
        end,
      })
      themeBridge.registerChromeRect(tileRect, "tile")

      col = col + 1
      if col >= numPerRow then
        col = 0
        x = 0
        y = y + tileH + tilePadding
      else
        x = x + tileW + tilePadding
      end
    end

    if #themes == 0 then
      form.addStaticText(nil, {x = tilePadding, y = form.height() + tilePadding, w = windowWidth - (2 * tilePadding), h = 32}, NO_THEMES, CENTERED)
      gridHeader.focusMenu()
      return
    end

    local selected = lastSelected and buttons[lastSelected]
    if selected then selected:focus() else gridHeader.focusMenu() end
  end

  openThemeGrid()
end

return {open = open}
