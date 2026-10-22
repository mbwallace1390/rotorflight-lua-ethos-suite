-- Cinder native header. Adapted from the existing bounded dashboard header. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local utils = rfsuite.widgets.dashboard.utils
local C = requireModule("widgets/dashboard/themes/cinder/common.lua").colors
local lcd, type = lcd, type
-- Keep the live craft/model name readable inside its native header slot.
local function paintModelName(x, y, w, h, box)
    local value = rfsuite.session and rfsuite.session.craftName
    if type(value) ~= "string" or value:match("^%s*$") then
        value = model and model.name and model.name() or "--"
    end
    if type(value) ~= "string" or value == "" then value = "--" end
    if box._modelValue ~= value or box._modelWidth ~= w then
        local text = value
        local font = utils.resolveFont("FONT_S", nil)
        lcd.font(font)
        local tw, th = lcd.getTextSize(text)
        if tw > w - 10 then
            font = utils.resolveFont("FONT_XS", nil)
            lcd.font(font)
            tw, th = lcd.getTextSize(text)
        end
        if tw > w - 10 then
            -- Shorten whole UTF-8 characters, only when name or geometry changes.
            local cut = #text
            repeat
                while cut > 1 and text:byte(cut) >= 128 and text:byte(cut) < 192 do cut = cut - 1 end
                cut = cut - 1
                text = value:sub(1, cut)
                tw, th = lcd.getTextSize(text .. "...")
            until tw <= w - 10 or cut == 0
            text = text .. "..."
        end
        box._modelValue, box._modelWidth = value, w
        box._modelText, box._modelFont, box._modelHeight = text, font, th
    end
    utils.drawBoxBackground(x, y, w, h, box.bgcolor)
    lcd.font(box._modelFont)
    lcd.color(box.textcolor)
    lcd.drawText(math.floor(x + 5), math.floor(y + (h - box._modelHeight) / 2), box._modelText)
end
local function create()
local headeropts = utils.getHeaderOptions()
-- This theme owns its header geometry; leave the Suite defaults unchanged.
headeropts.height = math.max(headeropts.height or 0, 44)
-- The Suite caches its native palette; each theme owns its presentation copy.
local colorMode = {}
for key, value in pairs(utils.themeColors()) do colorMode[key] = value end
local header_layout = utils.standardHeaderLayout(headeropts)
local header_boxes_cache = nil
local last_txbatt_type = nil

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)

        -- Replace the stock Rotorflight logo with the MWRC-style title while
        -- keeping the radio's native header surface and battery/RSSI widgets.
        for _, headerBox in ipairs(boxes) do
            if headerBox.subtype == "craftname" then
                headerBox.type, headerBox.subtype = "func", "func"
                headerBox.paint = paintModelName
            end
            if headerBox.type == "image" then
                headerBox.type = "func"
                headerBox.subtype = "func"
                headerBox.bgcolor = "transparent"
                headerBox.paint = function(x, y, w, h)
                    lcd.color(C.panel)
                    lcd.drawFilledRectangle(math.floor(x), math.floor(y), math.floor(w), math.floor(h))
                    local cache = headerBox
                    -- Measure only when the header geometry changes; keep the builder mark smaller.
                    if cache._titleWidth ~= w or cache._titleLayoutHeight ~= h then
                        local titleFont = utils.resolveFont("FONT_L", nil)
                        local markFont = utils.resolveFont("FONT_XS", nil)
                        if type(titleFont) ~= "number" or type(markFont) ~= "number" then return end
                        lcd.font(markFont)
                        local mw, mh = lcd.getTextSize("| MWRC")
                        lcd.font(titleFont)
                        local tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_STD", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_S", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        -- Narrow header slots retain the same hierarchy with the smallest pair.
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_XS", nil) or titleFont
                            markFont = utils.resolveFont("FONT_XXS", nil) or markFont
                            lcd.font(markFont)
                            mw, mh = lcd.getTextSize("| MWRC")
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        cache._titleWidth = w
                        cache._titleLayoutHeight = h
                        cache._titleFont = titleFont
                        cache._titleHeight = th
                        cache._titleTextWidth = tw
                        cache._markFont = markFont
                        cache._markHeight = mh
                        cache._titleGroupWidth = tw + 8 + mw
                    end
                    local screenW = lcd.getWindowSize()
                    local groupX = math.floor((screenW - cache._titleGroupWidth) / 2 + 0.5)
                    lcd.font(cache._titleFont)
                    lcd.color(C.white)
                    lcd.drawText(groupX, math.floor(y + (h - cache._titleHeight) / 2), "Rotorflight // Ethos")
                    lcd.font(cache._markFont)
                    lcd.color(C.muted)
                    lcd.drawText(groupX + cache._titleTextWidth + 8, math.floor(y + (h - cache._markHeight) / 2), "| MWRC")
                end
            end
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

colorMode.bgcolor = C.bg
colorMode.tbbgcolor = C.panel
colorMode.tbtextcolor, colorMode.cntextcolor, colorMode.rssitextcolor = C.white, C.white, C.white
colorMode.rssifillcolor, colorMode.rssifillbgcolor = C.copper, C.line
colorMode.txfillcolor, colorMode.txbgfillcolor = C.green, C.line
return header_layout, header_boxes
end
return {create=create}
