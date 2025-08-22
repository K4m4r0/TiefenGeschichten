-- TiefenGeschichten – Persistente Markierung (Magenta) + Auto-Reset + „Geschichten des …“-Erkennung

local ADDON, NS = ...

------------------------------------------------------------
-- Debug
------------------------------------------------------------
local DEBUG = false
local function dprint(...) if DEBUG then print("|cff00aaff[TG]|r", ...) end end

------------------------------------------------------------
-- Utils
------------------------------------------------------------
local function trim(s) if not s then return s end return s:gsub("^%s+",""):gsub("%s+$","") end
local function stripMarkup(s)
    if not s then return s end
    s = s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    s = s:gsub("|H.-|h(.-)|h","%1")
    s = s:gsub("|T.-|t",""):gsub("|A.-|a","")
    return s
end

local function normalize(s)
    if not s then return s end
    s = stripMarkup(s)
    s = s:gsub("\194\160", " ")          -- NBSP → normales Leerzeichen
    s = s:gsub("%s+"," ")
    s = s:gsub("[“”„«»]","")             -- typografische Quotes raus
    s = s:gsub("[–—]","-")               -- Gedanken-/Em-Dash vereinheitlichen
    s = trim(s)
    s = s:gsub("[%p%s]+$","")            -- Endzeichen & Leerraum am Ende weg
    return s:lower()
end


-- Tiefen-„Geschichten“-Erfolge erkennen
local function isGeschichtenAchievement(name)
    if not name then return false end
    name = normalize(name)  -- alles vereinheitlicht, kleingeschrieben

    -- a) Endet auf (optional Space) + (:-/—/：) + (optional Space) + "geschichten"
    if name:match("%s*[%-%:：]%s*geschichten$") then
        return true
    end

    -- b) Formen wie "geschichten des/der/von …"
    if name:find("geschichten des ", 1, true)
    or name:find("geschichten der ", 1, true)
    or name:find("geschichten von ", 1, true) then
        return true
    end

    return false
end


-- "Geschichtsvariation: XXX" aus Text
local function extractVariation(text)
    if not text or text == "" then return nil end
    text = stripMarkup(text)
    local v = text:match("[Gg]eschichtsvariation%s*[:：]%s*(.+)")
    if not v then return nil end
    v = trim(v):gsub("%s*%b()",""):gsub("%s+$","")
    return v ~= "" and v or nil
end

------------------------------------------------------------
-- SavedVariables (persistente Markierungen & Reset)
------------------------------------------------------------
local function now() return (GetServerTime and GetServerTime()) or time() end
local function getResetSeconds()
    local sec = (GetQuestResetTime and GetQuestResetTime()) or 0
    if not sec or sec <= 0 or sec > 172800 then sec = 24*3600 end
    return sec
end
local function nextDailyResetEpoch() return now() + getResetSeconds() end

local function ensureDB()
    _G.TiefenGeschichtenDB = _G.TiefenGeschichtenDB or {}
    local DB = _G.TiefenGeschichtenDB
    DB.seen    = DB.seen    or {}   -- [normalizedName] = true
    DB.resetAt = DB.resetAt or nextDailyResetEpoch()
    return DB
end

local function maybeDailyReset()
    local DB = ensureDB()
    if now() >= (DB.resetAt or 0) then
        DB.seen = {}
        DB.resetAt = nextDailyResetEpoch()
        dprint("Daily Reset → Markierungen gelöscht.")
    end
end

local resetTimer
local function scheduleResetTimer()
    local DB = ensureDB()
    if resetTimer then resetTimer:Cancel(); resetTimer = nil end
    local secs = (DB.resetAt or nextDailyResetEpoch()) - now()
    if secs < 5 then secs = 5 end
    if secs > 172800 then secs = 172800 end
    resetTimer = C_Timer.NewTimer(secs + 2, function()
        maybeDailyReset()
        if NS.ApplyColors then NS.ApplyColors() end
        scheduleResetTimer()
    end)
end

------------------------------------------------------------
-- UI / State
------------------------------------------------------------
NS.missing, NS.lines, NS.index = {}, {}, {}
NS.currentVariation = nil

local f = CreateFrame("Frame", "TG_StoriesFrame", UIParent, "BackdropTemplate")
f:SetSize(480, 540)
f:SetPoint("CENTER")
f:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 }
})
f:SetBackdropColor(0, 0, 0, 0.85)
f:EnableMouse(true); f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("Fehlende Geschichten (Tiefen)")

local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
hint:SetPoint("TOPRIGHT", -12, -16)
hint:SetText("Hover über Tiefeneingang…")

local scroll = CreateFrame("ScrollFrame","TG_StoriesScroll",f,"UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",12,-38); scroll:SetPoint("BOTTOMRIGHT",-28,12)
local content = CreateFrame("Frame",nil,scroll); content:SetSize(1,1); scroll:SetScrollChild(content)

local function ClearContent()
    for _,l in ipairs(NS.lines) do if l.font then l.font:Hide() end end
    wipe(NS.lines); wipe(NS.index)
    local regs = { content:GetRegions() }
    for _,r in ipairs(regs) do if r and r:GetObjectType()=="FontString" then r:Hide(); r:SetText("") end end
end

-- Farben
local MAGENTA = {1.00, 0.10, 0.95}
local WHITE   = {1,1,1}

-- globale Färbe-Logik
function NS.ApplyColors()
    local DB = ensureDB(); maybeDailyReset()
    for _,line in ipairs(NS.lines) do
        if line.font and line.variationName then
            local key = normalize(line.variationName)
            if DB.seen[key] then
                line.font:SetTextColor(unpack(MAGENTA))
            else
                line.font:SetTextColor(unpack(WHITE))
            end
        end
    end
end

local function UpdateUI()
    ClearContent()
    local y, maxW = -2, 0
    for _,entry in ipairs(NS.missing) do
        local header = content:CreateFontString(nil,"ARTWORK","GameFontNormal")
        header:SetPoint("TOPLEFT",0,y); header:SetJustifyH("LEFT")
        header:SetText(entry.achName); header:Show()
        table.insert(NS.lines,{font=header,variationName=nil})
        y = y - ((header:GetStringHeight() or 14) + 4)
        maxW = math.max(maxW, header:GetStringWidth() or 0)

        for _,varName in ipairs(entry.missingNames) do
            local fs = content:CreateFontString(nil,"ARTWORK","GameFontHighlight")
            fs:SetPoint("TOPLEFT",10,y); fs:SetJustifyH("LEFT")
            fs:SetText("• "..varName); fs:Show()
            table.insert(NS.lines,{font=fs,variationName=varName})
            local key = normalize(varName); NS.index[key]=NS.index[key] or {}; table.insert(NS.index[key],fs)
            y = y - ((fs:GetStringHeight() or 12) + 2)
            maxW = math.max(maxW, (fs:GetStringWidth() or 0) + 10)
        end
        y = y - 6
    end
    content:SetSize(math.max(300, maxW+6), -y+12)
    NS.ApplyColors()
end

-- Keys für erkannten Namen (Index + fuzzy)
local function FindVariationKeys(variation)
    local nv = normalize(variation or "")
    local keys, seen = {}, {}
    if NS.index[nv] then keys[#keys+1]=nv; seen[nv]=true end
    for _,line in ipairs(NS.lines) do
        if line.variationName then
            local n = normalize(line.variationName)
            if n == nv or n:find(nv,1,true) or nv:find(n,1,true) then
                if not seen[n] then keys[#keys+1]=n; seen[n]=true end
            end
        end
    end
    if #keys==0 and nv~="" then keys={nv} end
    return keys
end

-- Speichern + färben
local function MarkSeenAndRecolor(variation)
    local DB = ensureDB(); maybeDailyReset()
    for _,k in ipairs(FindVariationKeys(variation)) do DB.seen[k] = true end
    NS.ApplyColors()
end

-- Anzeige-Update (persistiert)
local function HighlightVariation(variation)
    NS.currentVariation = variation
    hint:SetText(variation and variation~="" and ("Erkannt: "..variation) or "Hover über Tiefeneingang…")
    if variation and variation~="" then
        MarkSeenAndRecolor(variation)
    else
        NS.ApplyColors()
    end
end

------------------------------------------------------------
-- Achievement-Scan (lazy + chunked)
------------------------------------------------------------
local scanner = { running=false, done=false, results={}, cats=nil, catIdx=1, achIdx=1, TIME_BUDGET_MS=12 }
local function ScanTick()
    if not scanner.running then return end
    local start = debugprofilestop()
    while true do
        if not scanner.cats then
            scanner.cats = GetCategoryList and GetCategoryList() or {}
            if not scanner.cats or #scanner.cats==0 then scanner.running=false; C_Timer.After(2.0,function() scanner.running=true; ScanTick() end); return end
            scanner.catIdx, scanner.achIdx = 1,1
        end
        local catID = scanner.cats[scanner.catIdx]
        if not catID then
            NS.missing = scanner.results
            table.sort(NS.missing,function(a,b) return a.achName<b.achName end)
            UpdateUI(); HighlightVariation(NS.currentVariation)
            scanner.running=false; scanner.done=true
            return
        end
        local num = GetCategoryNumAchievements(catID,true) or 0
        if scanner.achIdx > num then scanner.catIdx = scanner.catIdx + 1; scanner.achIdx = 1
        else
            local id,name = GetAchievementInfo(catID, scanner.achIdx); scanner.achIdx = scanner.achIdx + 1
            if id and name and isGeschichtenAchievement(name) then
                local missing = {}
                for ci=1,(GetAchievementNumCriteria(id) or 0) do
                    local cname,_,done = GetAchievementCriteriaInfo(id,ci)
                    cname = trim(stripMarkup(cname))
                    if cname and cname~="" and not done then table.insert(missing,cname) end
                end
                if #missing>0 then table.insert(scanner.results,{achID=id, achName=name, missingNames=missing}) end
            end
        end
        if debugprofilestop() - start >= scanner.TIME_BUDGET_MS then C_Timer.After(0, ScanTick); return end
    end
end
local function StartScan() if scanner.running then return end scanner.running=true; scanner.done=false; scanner.results={}; scanner.cats=nil; ScanTick() end
f:HookScript("OnShow", function() if not scanner.done then StartScan() end end)
local function RescanSoon() if scanner.running then return end scanner.done=false C_Timer.After(0.8, StartScan) end

------------------------------------------------------------
-- Tooltip → Variation auslesen (rekursiv über Unterframes)
------------------------------------------------------------
local function collectTextsRecursive(frame, out, seen)
    if not frame or type(frame)~="table" then return end
    seen = seen or {}; if seen[frame] then return end; seen[frame]=true
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _,r in ipairs(regions) do
            if r and r.GetObjectType and r:GetObjectType()=="FontString" then
                local t = r:GetText()
                if t and t~="" then table.insert(out, t) end
            end
        end
    end
    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _,c in ipairs(children) do collectTextsRecursive(c, out, seen) end
    end
end
local function ExtractVariationFromTooltipDeep(tt)
    if not tt or not tt:IsShown() then return nil end
    local texts = {}; collectTextsRecursive(tt, texts, {})
    for _,txt in ipairs(texts) do
        local clean = stripMarkup(txt); if DEBUG and clean~="" then dprint("TTL:", clean) end
        local v = extractVariation(clean); if v then return v end
    end
    return nil
end

local THROTTLE = 0.20
local tpCache = { ts=0, lastFP="", lastVar=nil }
local function fingerprintTooltip(tt)
    local texts = {}; collectTextsRecursive(tt, texts, {})
    for i=1,#texts do texts[i] = stripMarkup(texts[i] or "") end
    return table.concat(texts, "\n")
end
local function TooltipPump(tt)
    if not (tt and tt:IsShown()) then return end
    local t = GetTime(); if (t - (tpCache.ts or 0)) < THROTTLE then return end
    tpCache.ts = t
    local fp = fingerprintTooltip(tt); if fp == tpCache.lastFP then return end
    tpCache.lastFP = fp
    local var = ExtractVariationFromTooltipDeep(tt)
    if var and var ~= tpCache.lastVar then
        tpCache.lastVar = var
        if not scanner.done and not scanner.running then C_Timer.After(0.05, StartScan) end
        HighlightVariation(var)
    end
end
local function SafeHook(obj, script, fn)
    if not obj or not obj.HookScript then return end
    if obj.HasScript and not obj:HasScript(script) then return end
    pcall(function() obj:HookScript(script, fn) end)
end
local function HookTooltip(tt)
    if not tt or tt._TG_Hooked then return end
    tt._TG_Hooked = true
    SafeHook(tt,"OnShow",function(self) tpCache.lastFP=""; tpCache.lastVar=nil; tpCache.ts=0; TooltipPump(self) end)
    SafeHook(tt,"OnUpdate",function(self) TooltipPump(self) end)
    SafeHook(tt,"OnTooltipCleared",function(self) tpCache.lastFP=""; tpCache.lastVar=nil; tpCache.ts=0; HighlightVariation(nil) end)
end

------------------------------------------------------------
-- Events & Slash
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("ACHIEVEMENT_EARNED")
ev:RegisterEvent("CRITERIA_UPDATE")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event=="ADDON_LOADED" and arg1==ADDON then
        ensureDB(); maybeDailyReset(); scheduleResetTimer()
        C_Timer.After(0, function() if NS.ApplyColors then NS.ApplyColors() end end)

    elseif event=="PLAYER_LOGIN" then
        HookTooltip(GameTooltip)
        if _G.WorldMapTooltip then HookTooltip(_G.WorldMapTooltip) end

    elseif event=="PLAYER_ENTERING_WORLD" then
        maybeDailyReset(); scheduleResetTimer()

    elseif event=="PLAYER_LOGOUT" then
        local DB = ensureDB()
        if not DB.resetAt or DB.resetAt - now() > 172800 then
            DB.resetAt = nextDailyResetEpoch()
        end

    elseif event=="ACHIEVEMENT_EARNED" or event=="CRITERIA_UPDATE" then
        RescanSoon()
    end
end)

SLASH_TIEFENGESCH1="/tgs"; SLASH_TIEFENGESCH2="/tiefenstories"
SlashCmdList["TIEFENGESCH"] = function(msg)
    msg = (msg and msg:lower() or "")
    if msg=="refresh" then StartScan(); return end
    if msg=="debug"   then DEBUG=not DEBUG; print("|cff00aaff[TG]|r Debug:", DEBUG and "ON" or "OFF"); return end
    if msg=="clear"   then local DB=ensureDB(); DB.seen={}; NS.ApplyColors(); print("|cff00aaff[TG]|r Markierungen gelöscht."); return end
    if msg=="reset"   then local DB=ensureDB(); DB.resetAt = nextDailyResetEpoch(); scheduleResetTimer(); print("|cff00aaff[TG]|r Reset-Uhr neu gesetzt."); return end
    if msg=="dump"    then local DB=ensureDB(); local n=0; for _ in pairs(DB.seen) do n=n+1 end; print("|cff00aaff[TG]|r gespeicherte Markierungen:", n, "Reset in", getResetSeconds(), "Sek."); return end
    if f:IsShown() then f:Hide() else f:Show(); if not scanner.done then StartScan() end end
end
