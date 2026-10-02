-- Shared dashboard catalog. Scan once per script session, never per frame.
-- Theme folders are executable Lua: only init metadata is run during discovery;
-- layouts/configuration are loaded by their owners when actually selected.
if package.loaded["rfsuite.lib.dashboard_themes"] then
  return package.loaded["rfsuite.lib.dashboard_themes"]
end

local catalog = {}
local SYSTEM_ROOT = "widgets/dashboard/themes"
local USER_ROOT = "SCRIPTS:/rfsuite.user/dashboard"
local entries, byPath
local normalized = {}
local keys = {}
local PHASES = {"preflight", "inflight", "postflight"}

-- Stock init files can require the dashboard context (and settings store).
-- Keep their small UI descriptors here instead of starting every dashboard
-- subsystem just to show a picker. Add-on themes need no registration here.
local BUILTINS = {
  aerc = {label = "@i18n(app.modules.settings.dashboard_theme_aerc)@", configure = true},
  ["aerc-n"] = {label = "@i18n(app.modules.settings.dashboard_theme_aerc_n)@", configure = true},
  claude = {label = "@i18n(app.modules.settings.dashboard_theme_claude)@", configure = true},
  danielrc = {label = "@i18n(app.modules.settings.dashboard_theme_danielrc)@"},
  default = {label = "@i18n(app.modules.settings.dashboard_theme_default)@", configure = true},
  gismo = {label = "@i18n(app.modules.settings.dashboard_theme_gismo)@", configure = true},
  helihud = {label = "@i18n(app.modules.settings.dashboard_theme_helihud)@"},
  kevd = {label = "@i18n(app.modules.settings.dashboard_theme_kevd)@", configure = true,
    minResolution = {x = 784, y = 294}},
  rfstatus = {label = "@i18n(app.modules.settings.dashboard_theme_rfstatus)@", configure = true},
  ["rt-rc"] = {label = "@i18n(app.modules.settings.dashboard_theme_rt_rc)@", configure = true},
  ["rt-rc-n"] = {label = "@i18n(app.modules.settings.dashboard_theme_rt_rc_n)@", configure = true},
  ["srb-rc"] = {label = "@i18n(app.modules.settings.dashboard_theme_srb_rc)@", configure = true},
  timer = {label = "@i18n(app.modules.settings.dashboard_theme_timer)@"},
}

local function safeName(value)
  return type(value) == "string" and value:match("^[%w][%w _%.%-]*$") ~= nil
    and not value:find("..", 1, true)
end

-- Syntax-only normalization preserves saved selections when an SD folder is
-- temporarily absent. Availability/fallback belongs to get(), not settings.
function catalog.normalize(value)
  if type(value) ~= "string" then return nil end
  local cached = normalized[value]
  if cached ~= nil then return cached or nil end
  local source, folder = value:match("^([^/]+)/(.+)$")
  if not source then source, folder = "system", value end
  if folder:sub(1, 1) == "@" then folder = folder:sub(2) end
  local path
  if (source == "system" or source == "user") and safeName(folder) and folder ~= "nil" then
    -- Retain system/aegis and dashboard.aegis after the physical rename.
    if source == "system" and folder == "bastion" then folder = "aegis" end
    path = source .. "/" .. folder
  end
  normalized[value] = path or false
  return path
end

function catalog.key(value)
  local path = catalog.normalize(value)
  if not path then return nil end
  local key = keys[path]
  if not key then
    key = path:match("^system/(.+)$") or path
    keys[path] = key
  end
  return key
end

local function listFiles(directory)
  if not system or type(system.listFiles) ~= "function" then return nil end
  local ok, files = pcall(system.listFiles, directory)
  if ok and type(files) == "table" then return files end
  return nil
end

local function fileSet(directory)
  local files = listFiles(directory)
  if not files then return nil end
  local present = {}
  for _, name in ipairs(files) do
    if type(name) == "string" then present[name] = true end
  end
  return present
end

local function luaFile(present, filename)
  if not safeName(filename) then return nil end
  if filename:match("%.lua$") then
    if present[filename] then return filename end
    local compiled = filename .. "c"
    if present[compiled] then return compiled end
  elseif filename:match("%.luac$") and present[filename] then
    return filename
  end
  return nil
end

local function minimum(value)
  if type(value) ~= "table" then return nil end
  local x, y = tonumber(value.x), tonumber(value.y)
  if not x or not y or x ~= x or y ~= y or x < 0 or y < 0
    or x == math.huge or y == math.huge then return nil end
  return {x = x, y = y}
end

local function descriptor(source, folder, directory, present)
  local builtin = source == "system" and BUILTINS[folder] or nil
  local metadata = builtin
  if not builtin then
    local initFile = luaFile(present, "init.lua")
    if not initFile then return nil end
    local okLoad, chunk = pcall(loadfile, directory .. "/" .. initFile)
    if not okLoad or type(chunk) ~= "function" then return nil end
    local okRun, result = pcall(chunk)
    if not okRun or type(result) ~= "table" then return nil end
    metadata = result
  end

  local entry = {path = catalog.normalize(source .. "/" .. folder), directory = directory,
    init = directory .. "/" .. luaFile(present, "init.lua"),
    folder = (source == "system" and folder == "bastion") and "aegis" or folder,
    builtin = builtin ~= nil, icon = directory .. "/icon.png"}
  for _, phase in ipairs(PHASES) do
    local filename = metadata[phase] or (phase .. ".lua")
    entry[phase] = luaFile(present, filename)
    if not entry[phase] then return nil end
  end
  local configure = builtin and builtin.configure and "configure.lua" or metadata.configure
  entry.configure = type(configure) == "string" and luaFile(present, configure) or nil
  if entry.configure then entry.configure = directory .. "/" .. entry.configure end
  entry.minResolution = minimum(metadata.minResolution)
  entry.appTheme = type(metadata.appTheme) == "table" and metadata.appTheme or nil
  local label = metadata.label or (entry.appTheme and entry.appTheme.name) or metadata.name
  entry.label = type(label) == "string" and label ~= "" and label or folder
  if source == "user" then entry.label = entry.label .. " (User)" end
  return entry
end

local function add(entry)
  if not entry or not entry.path or byPath[entry.path] then return end
  byPath[entry.path] = entry
  entries[#entries + 1] = entry
end

local function scan(source, root)
  local folders = listFiles(root)
  if not folders then return false end
  -- Try Bastion first, but let a valid legacy folder survive a broken/empty
  -- replacement. add() keeps only the first valid descriptor for a saved ID.
  table.sort(folders, function(a, b)
    -- Use a rank to keep the ordering transitive with all other folder names.
    local rankA = source == "system" and a == "bastion" and 0 or 1
    local rankB = source == "system" and b == "bastion" and 0 or 1
    if rankA ~= rankB then return rankA < rankB end
    return tostring(a) < tostring(b)
  end)
  for _, folder in ipairs(folders) do
    local path = safeName(folder) and catalog.normalize(source .. "/" .. folder) or nil
    if path and not byPath[path] then
      local directory = root .. "/" .. folder
      local present = fileSet(directory)
      if present and luaFile(present, "init.lua") then add(descriptor(source, folder, directory, present)) end
    end
  end
  return true
end

local function defaultEntry()
  return {path = "system/default", folder = "default", directory = SYSTEM_ROOT .. "/default",
    init = SYSTEM_ROOT .. "/default/init.lua",
    label = BUILTINS.default.label, builtin = true, preflight = "preflight.lua",
    inflight = "inflight.lua", postflight = "postflight.lua"}
end

function catalog.list()
  if entries then return entries end
  -- Establish the cache before running optional metadata to prevent recursive
  -- catalog construction by a theme that imports the settings helper.
  entries, byPath = {}, {}
  if not scan("system", SYSTEM_ROOT) then
    -- Older firmware/SD errors still retain the Suite's known stock choices.
    for folder, builtin in pairs(BUILTINS) do
      local entry = defaultEntry()
      entry.path, entry.folder = "system/" .. folder, folder
      entry.directory = SYSTEM_ROOT .. "/" .. folder
      entry.init = entry.directory .. "/init.lua"
      entry.label, entry.minResolution = builtin.label, builtin.minResolution
      entry.icon = entry.directory .. "/icon.png"
      if builtin.configure then entry.configure = entry.directory .. "/configure.lua" end
      add(entry)
    end
  end
  scan("user", USER_ROOT)
  add(defaultEntry())
  table.sort(entries, function(a, b)
    if a.label == b.label then return a.path < b.path end
    return a.label < b.label
  end)
  return entries
end

function catalog.get(value)
  local path = catalog.normalize(value)
  if not path then return nil end
  catalog.list()
  return byPath[path]
end

package.loaded["rfsuite.lib.dashboard_themes"] = catalog
return catalog
