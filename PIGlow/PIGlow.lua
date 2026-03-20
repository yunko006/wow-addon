-- PIGlow v3: PI Timer Calculator
-- Zero dependency — single ticker, secure PI button with CD tracking

local ADDON_NAME = "PIGlow"
local PI_CD = 120
local PI_SPELL_ID = 10060
local PI_ICON = 135939

PIGlowDB = PIGlowDB or {}
local defaults = {
    enabled = true,
    alertDuration = 5,
    targetName = nil,
    targetSpecID = nil,
    manualTimings = {},
    useManual = false,
}

-- State
local ticker = nil
local timingsList = nil
local nextPIIndex = 1
local inCombat = false
local inEncounter = false
local combatStart = 0
local lastPICast = 0
local alertHideAt = 0
local targetUnit = nil
local piButtonGlowing = false

-- ============================================================
-- Timer calculation
-- ============================================================
local function CalcAutoTimings(targetCD)
    local timings = {0}
    local t = 0
    for i = 2, 20 do
        local earliest = t + PI_CD
        local n = math.ceil(earliest / targetCD)
        t = n * targetCD
        if t > 1200 then break end
        timings[i] = t
    end
    return timings
end

local function FormatTime(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function FindUnitForPlayer(playerName)
    local prefix = IsInRaid() and "raid" or "party"
    local max = IsInRaid() and GetNumGroupMembers() or (GetNumGroupMembers() - 1)
    for i = 1, max do
        local unit = prefix .. i
        if UnitName(unit) == playerName then return unit end
    end
    return nil
end

-- ============================================================
-- Secure PI button with CD overlay
-- ============================================================
local piButton

local function CreatePIButton()
    if piButton then return end

    piButton = CreateFrame("Button", "PIGlowCastButton", UIParent, "SecureUnitButtonTemplate, BackdropTemplate")
    piButton:SetSize(50, 50)
    piButton:SetPoint("CENTER", UIParent, "CENTER", 0, 130)
    piButton:SetFrameStrata("TOOLTIP")
    piButton:RegisterForClicks("AnyUp", "AnyDown")

    piButton:SetBackdrop({
        bgFile = "Interface/BUTTONS/WHITE8X8",
        edgeFile = "Interface/BUTTONS/WHITE8X8",
        edgeSize = 2,
    })
    piButton:SetBackdropColor(0, 0, 0, 0.9)
    piButton:SetBackdropBorderColor(1, 0.8, 0, 1)

    local icon = piButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(42, 42)
    icon:SetPoint("CENTER")
    icon:SetTexture(PI_ICON)
    piButton.icon = icon

    local cd = CreateFrame("Cooldown", "PIGlowCastButtonCD", piButton, "CooldownFrameTemplate")
    cd:SetAllPoints(piButton)
    cd:SetDrawEdge(true)
    cd:SetDrawSwipe(true)
    cd:SetSwipeColor(0, 0, 0, 0.7)
    piButton.cooldown = cd

    local cdText = piButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cdText:SetPoint("CENTER", piButton, "CENTER", 0, 0)
    cdText:SetTextColor(1, 1, 1, 1)
    piButton.cdText = cdText

    local name = piButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("TOP", piButton, "BOTTOM", 0, -2)
    name:SetTextColor(1, 0.8, 0, 1)
    piButton.nameText = name

    piButton:SetMovable(true)
    piButton:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    piButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    piButton:RegisterForDrag("RightButton")

    piButton:Hide()
end

local function UpdatePIButtonTarget()
    if not piButton or InCombatLockdown() then return end
    if not targetUnit then
        piButton:SetAttribute("unit", nil)
        piButton.nameText:SetText("")
        return
    end
    piButton:SetAttribute("unit", targetUnit)
    piButton:SetAttribute("type", "target")
    piButton.nameText:SetText(PIGlowDB.targetName or "")
end

local function ShowPIButton()
    CreatePIButton()
    if piButton and not piButton:IsShown() then
        piButton:Show()
    end
end

local function HidePIButton()
    if piButton and piButton:IsShown() and not InCombatLockdown() then
        piButton:Hide()
    end
end

-- ============================================================
-- PI button glow (simple border color flash, no lib needed)
-- ============================================================
local glowTicker = nil

local function StopPIButtonGlow()
    if glowTicker then
        glowTicker:Cancel()
        glowTicker = nil
    end
    piButtonGlowing = false
    if piButton then
        piButton:SetBackdropBorderColor(1, 0.8, 0, 1)
    end
end

local function StartPIButtonGlow()
    if piButtonGlowing or not piButton then return end
    piButtonGlowing = true
    PlaySound(8959)

    -- Pulsing border glow
    local t = 0
    glowTicker = C_Timer.NewTicker(0.05, function()
        if not piButton or not piButtonGlowing then return end
        t = t + 0.05
        local pulse = 0.5 + 0.5 * math.sin(t * 6)
        piButton:SetBackdropBorderColor(1, 0.8 * pulse, 0, 1)
        piButton:SetBackdropColor(0.3 * pulse, 0.2 * pulse, 0, 0.9)
    end)
end

-- ============================================================
-- Alert frame (icon + text, center screen)
-- ============================================================
local alertFrame

local function CreateAlertFrame()
    if alertFrame then return end

    alertFrame = CreateFrame("Frame", "PIGlowAlert", UIParent, "BackdropTemplate")
    alertFrame:SetSize(260, 60)
    alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    alertFrame:SetFrameStrata("TOOLTIP")
    alertFrame:SetBackdrop({
        bgFile = "Interface/BUTTONS/WHITE8X8",
        edgeFile = "Interface/BUTTONS/WHITE8X8",
        edgeSize = 1,
    })
    alertFrame:SetBackdropColor(0, 0, 0, 0.8)
    alertFrame:SetBackdropBorderColor(1, 0.8, 0, 1)
    alertFrame:Hide()

    local icon = alertFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", alertFrame, "LEFT", 10, 0)
    icon:SetTexture(PI_ICON)
    alertFrame.icon = icon

    local text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    text:SetPoint("RIGHT", alertFrame, "RIGHT", -10, 0)
    text:SetTextColor(1, 0.8, 0, 1)
    text:SetJustifyH("LEFT")
    alertFrame.text = text

    local ag = alertFrame:CreateAnimationGroup()
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.2)
    fadeIn:SetOrder(1)
    local hold = ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(4)
    hold:SetOrder(2)
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.8)
    fadeOut:SetOrder(3)
    ag:SetScript("OnFinished", function() alertFrame:Hide() end)
    alertFrame.anim = ag
end

local function IsPIOnCooldown()
    return lastPICast > 0 and (GetTime() - lastPICast) < PI_CD
end

local function ShowAlert(targetName, timingStr)
    if IsPIOnCooldown() then return end

    CreateAlertFrame()
    alertFrame.text:SetText("PI → " .. targetName .. "! (" .. timingStr .. ")")
    alertFrame:Show()
    alertFrame:SetAlpha(1)
    alertFrame.anim:Stop()
    alertFrame.anim:Play()
    alertHideAt = GetTime() + (PIGlowDB.alertDuration or 5)
end

-- ============================================================
-- Single ticker — checks timings + updates PI button CD
-- ============================================================
local function OnTick()
    local now = GetTime()
    local elapsed = now - combatStart

    -- Auto-hide alert after duration
    if alertHideAt > 0 and now >= alertHideAt then
        alertHideAt = 0
    end

    -- Check if next PI timing has been reached
    if timingsList and nextPIIndex <= #timingsList then
        local nextTime = timingsList[nextPIIndex]
        if elapsed >= nextTime then
            ShowAlert(PIGlowDB.targetName, FormatTime(nextTime))
            nextPIIndex = nextPIIndex + 1
        end
    end

    -- Update PI button cooldown overlay
    if piButton and piButton:IsShown() then
        local piRemaining = 0
        if lastPICast > 0 then
            piRemaining = PI_CD - (now - lastPICast)
            if piRemaining < 0 then piRemaining = 0 end
        end

        if piRemaining > 0 then
            if not piButton.cooldown.active then
                piButton.cooldown:SetCooldown(lastPICast, PI_CD)
                piButton.cooldown.active = true
            end
            piButton.cdText:SetText(math.ceil(piRemaining))
            piButton.icon:SetDesaturated(true)
            StopPIButtonGlow()
        else
            piButton.cooldown:Clear()
            piButton.cooldown.active = false
            piButton.cdText:SetText("")
            piButton.icon:SetDesaturated(false)
            StartPIButtonGlow()
        end
    end
end

-- ============================================================
-- Combat timer system
-- ============================================================
local function CancelTimers()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    timingsList = nil
    nextPIIndex = 1
    alertHideAt = 0
    inCombat = false
    StopPIButtonGlow()
    if alertFrame then
        alertFrame.anim:Stop()
        alertFrame:Hide()
    end
end

local function StartTimers()
    CancelTimers()

    if not PIGlowDB.enabled or not PIGlowDB.targetName then return end

    if PIGlowDB.useManual and PIGlowDB.manualTimings and #PIGlowDB.manualTimings > 0 then
        timingsList = PIGlowDB.manualTimings
    else
        local specData = PIGlow_SpellDB[PIGlowDB.targetSpecID]
        if not specData then
            print("|cffFFCC00PIGlow|r: pas de spec configuree, utilisez /pig")
            return
        end
        timingsList = CalcAutoTimings(specData.cd)
    end

    inCombat = true
    combatStart = GetTime()
    nextPIIndex = 1

    targetUnit = FindUnitForPlayer(PIGlowDB.targetName)
    UpdatePIButtonTarget()

    ticker = C_Timer.NewTicker(0.5, OnTick)
    OnTick()

    print("|cffFFCC00PIGlow|r: timers started — " .. #timingsList .. " PIs planned on " .. PIGlowDB.targetName)
end

-- ============================================================
-- Config UI (2 tabs: Auto / Manuel)
-- ============================================================
local configFrame

local function BuildPlayerDropdown(parent)
    local dropdown = CreateFrame("Frame", "PIGlowPlayerDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -50)
    UIDropDownMenu_SetWidth(dropdown, 160)

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local numMembers = GetNumGroupMembers()
        if numMembers == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Pas en groupe"
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            return
        end

        local prefix = IsInRaid() and "raid" or "party"
        local max = IsInRaid() and numMembers or (numMembers - 1)

        for i = 1, max do
            local unit = prefix .. i
            local name = UnitName(unit)
            if name then
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = unit
                info.func = function(self)
                    PIGlowDB.targetName = name
                    targetUnit = unit
                    UIDropDownMenu_SetText(dropdown, name)
                    CloseDropDownMenus()
                    UpdatePIButtonTarget()
                    if CanInspect(unit) then
                        NotifyInspect(unit)
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)

    if PIGlowDB.targetName then
        UIDropDownMenu_SetText(dropdown, PIGlowDB.targetName)
    end

    return dropdown
end

local function CreateConfigUI()
    if configFrame then
        if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
        return
    end

    configFrame = CreateFrame("Frame", "PIGlowConfig", UIParent, "BackdropTemplate")
    configFrame:SetSize(340, 420)
    configFrame:SetPoint("CENTER")
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetBackdrop({
        bgFile = "Interface/BUTTONS/WHITE8X8",
        edgeFile = "Interface/BUTTONS/WHITE8X8",
        edgeSize = 2,
    })
    configFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    configFrame:SetBackdropBorderColor(1, 0.8, 0, 1)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetClampedToScreen(true)

    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffFFCC00PIGlow|r")

    local close = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- Tab buttons
    local tabAuto = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
    tabAuto:SetSize(140, 28)
    tabAuto:SetPoint("TOPLEFT", 20, -35)
    tabAuto:SetBackdrop({bgFile = "Interface/BUTTONS/WHITE8X8", edgeFile = "Interface/BUTTONS/WHITE8X8", edgeSize = 1})
    local tabAutoText = tabAuto:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabAutoText:SetPoint("CENTER")
    tabAutoText:SetText("Auto")

    local tabManual = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
    tabManual:SetSize(140, 28)
    tabManual:SetPoint("TOPLEFT", tabAuto, "TOPRIGHT", 10, 0)
    tabManual:SetBackdrop({bgFile = "Interface/BUTTONS/WHITE8X8", edgeFile = "Interface/BUTTONS/WHITE8X8", edgeSize = 1})
    local tabManualText = tabManual:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabManualText:SetPoint("CENTER")
    tabManualText:SetText("Manuel")

    -- Content containers
    local autoPanel = CreateFrame("Frame", nil, configFrame)
    autoPanel:SetPoint("TOPLEFT", 20, -70)
    autoPanel:SetPoint("BOTTOMRIGHT", -20, 50)

    local manualPanel = CreateFrame("Frame", nil, configFrame)
    manualPanel:SetPoint("TOPLEFT", 20, -70)
    manualPanel:SetPoint("BOTTOMRIGHT", -20, 50)
    manualPanel:Hide()

    -- AUTO TAB
    local cibleLabel = autoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cibleLabel:SetPoint("TOPLEFT", 5, 0)
    cibleLabel:SetText("Cible :")

    local dropdown = BuildPlayerDropdown(autoPanel)

    local specLabel = autoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specLabel:SetPoint("TOPLEFT", 5, -80)
    specLabel:SetText("Spec : --")
    autoPanel.specLabel = specLabel

    local spellLabel = autoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", 5, -100)
    spellLabel:SetText("Spell : --")
    autoPanel.spellLabel = spellLabel

    local planLabel = autoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    planLabel:SetPoint("TOPLEFT", 5, -130)
    planLabel:SetJustifyH("LEFT")
    planLabel:SetText("Selectionnez un joueur")
    autoPanel.planLabel = planLabel

    -- Inspect handler
    local inspectFrame = CreateFrame("Frame")
    inspectFrame:RegisterEvent("INSPECT_READY")
    inspectFrame:SetScript("OnEvent", function(_, _, guid)
        if not PIGlowDB.targetName then return end
        local unit = FindUnitForPlayer(PIGlowDB.targetName)
        if not unit then return end

        local specID = GetInspectSpecialization(unit)
        ClearInspectPlayer()
        if specID and specID > 0 then
            PIGlowDB.targetSpecID = specID
            local specData = PIGlow_SpellDB[specID]
            if specData then
                autoPanel.specLabel:SetText("Spec : " .. specData.spec)
                autoPanel.spellLabel:SetText("Spell : " .. specData.spell .. " (" .. specData.cd .. "s)")
                local timings = CalcAutoTimings(specData.cd)
                local lines = "Planning :\n"
                for i, t in ipairs(timings) do
                    lines = lines .. "  PI #" .. i .. " → " .. FormatTime(t)
                    if i == 1 then lines = lines .. "  (pull)" end
                    lines = lines .. "\n"
                end
                autoPanel.planLabel:SetText(lines)
            else
                autoPanel.specLabel:SetText("Spec : ID " .. specID .. " (non reconnu)")
                autoPanel.spellLabel:SetText("Spell : --")
                autoPanel.planLabel:SetText("Spec non dans la base de donnees")
            end
        end
    end)

    -- Restore saved config
    if PIGlowDB.targetSpecID and PIGlow_SpellDB[PIGlowDB.targetSpecID] then
        local specData = PIGlow_SpellDB[PIGlowDB.targetSpecID]
        autoPanel.specLabel:SetText("Spec : " .. specData.spec)
        autoPanel.spellLabel:SetText("Spell : " .. specData.spell .. " (" .. specData.cd .. "s)")
        local timings = CalcAutoTimings(specData.cd)
        local lines = "Planning :\n"
        for i, t in ipairs(timings) do
            lines = lines .. "  PI #" .. i .. " → " .. FormatTime(t)
            if i == 1 then lines = lines .. "  (pull)" end
            lines = lines .. "\n"
        end
        autoPanel.planLabel:SetText(lines)
    end

    -- MANUAL TAB
    local manCibleLabel = manualPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manCibleLabel:SetPoint("TOPLEFT", 5, 0)
    manCibleLabel:SetText("Cible :")

    local manDropdown = BuildPlayerDropdown(manualPanel)

    local timingsLabel = manualPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timingsLabel:SetPoint("TOPLEFT", 5, -80)
    timingsLabel:SetText("Timings PI (M:SS) :")

    local editBoxes = {}
    manualPanel.editBoxes = editBoxes

    local function AddTimingRow(index, value)
        local y = -100 - (index - 1) * 30
        local row = CreateFrame("Frame", nil, manualPanel)
        row:SetSize(280, 25)
        row:SetPoint("TOPLEFT", 5, y)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 0, 0)
        label:SetText("#" .. index)

        local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        eb:SetSize(70, 25)
        eb:SetPoint("LEFT", label, "RIGHT", 10, 0)
        eb:SetAutoFocus(false)
        eb:SetText(value or "")
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        editBoxes[index] = eb

        if index > 1 then
            local removeBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            removeBtn:SetSize(20, 20)
            removeBtn:SetPoint("LEFT", eb, "RIGHT", 5, 0)
            removeBtn:SetBackdrop({bgFile = "Interface/BUTTONS/WHITE8X8"})
            removeBtn:SetBackdropColor(0.6, 0.1, 0.1, 0.8)
            local x = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            x:SetPoint("CENTER")
            x:SetText("X")
            removeBtn:SetScript("OnClick", function()
                row:Hide()
                editBoxes[index] = nil
            end)
        end

        return row
    end

    local initTimings = PIGlowDB.manualTimings or {}
    if #initTimings == 0 then initTimings = {0} end
    local rowCount = #initTimings
    for i, t in ipairs(initTimings) do
        AddTimingRow(i, FormatTime(t))
    end

    local addBtn = CreateFrame("Button", nil, manualPanel, "BackdropTemplate")
    addBtn:SetSize(90, 22)
    addBtn:SetPoint("TOPLEFT", 5, -100 - rowCount * 30)
    addBtn:SetBackdrop({bgFile = "Interface/BUTTONS/WHITE8X8", edgeFile = "Interface/BUTTONS/WHITE8X8", edgeSize = 1})
    addBtn:SetBackdropColor(0.2, 0.4, 0.2, 0.8)
    addBtn:SetBackdropBorderColor(0.4, 0.6, 0.4, 1)
    local addText = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addText:SetPoint("CENTER")
    addText:SetText("+ Ajouter")
    addBtn:SetScript("OnClick", function()
        rowCount = rowCount + 1
        AddTimingRow(rowCount, "")
        addBtn:SetPoint("TOPLEFT", 5, -100 - rowCount * 30)
    end)

    -- TAB SWITCHING
    local function SetTab(tab)
        if tab == "auto" then
            autoPanel:Show()
            manualPanel:Hide()
            PIGlowDB.useManual = false
            tabAuto:SetBackdropColor(1, 0.8, 0, 0.3)
            tabAuto:SetBackdropBorderColor(1, 0.8, 0, 1)
            tabManual:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
            tabManual:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        else
            autoPanel:Hide()
            manualPanel:Show()
            PIGlowDB.useManual = true
            tabManual:SetBackdropColor(1, 0.8, 0, 0.3)
            tabManual:SetBackdropBorderColor(1, 0.8, 0, 1)
            tabAuto:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
            tabAuto:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end
    end

    tabAuto:SetScript("OnClick", function() SetTab("auto") end)
    tabManual:SetScript("OnClick", function() SetTab("manual") end)
    SetTab(PIGlowDB.useManual and "manual" or "auto")

    -- VALIDATE BUTTON
    local validateBtn = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
    validateBtn:SetSize(130, 30)
    validateBtn:SetPoint("BOTTOM", 0, 12)
    validateBtn:SetBackdrop({bgFile = "Interface/BUTTONS/WHITE8X8", edgeFile = "Interface/BUTTONS/WHITE8X8", edgeSize = 1})
    validateBtn:SetBackdropColor(0.1, 0.5, 0.1, 0.8)
    validateBtn:SetBackdropBorderColor(0.2, 0.7, 0.2, 1)
    local valText = validateBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valText:SetPoint("CENTER")
    valText:SetText("Valider")
    validateBtn:SetScript("OnClick", function()
        if PIGlowDB.useManual then
            local parsed = {}
            for _, eb in pairs(editBoxes) do
                if eb and eb:IsShown() then
                    local txt = eb:GetText():trim()
                    if txt ~= "" then
                        local min, sec = txt:match("^(%d+):(%d+)$")
                        if min and sec then
                            table.insert(parsed, tonumber(min) * 60 + tonumber(sec))
                        elseif tonumber(txt) then
                            table.insert(parsed, tonumber(txt))
                        end
                    end
                end
            end
            table.sort(parsed)
            PIGlowDB.manualTimings = parsed
            print("|cffFFCC00PIGlow|r: " .. #parsed .. " timings manuels sauvegardes pour " .. (PIGlowDB.targetName or "?"))
        else
            if PIGlowDB.targetSpecID and PIGlow_SpellDB[PIGlowDB.targetSpecID] then
                print("|cffFFCC00PIGlow|r: config sauvegardee — " .. PIGlow_SpellDB[PIGlowDB.targetSpecID].spec .. " (" .. (PIGlowDB.targetName or "?") .. ")")
            else
                print("|cffFFCC00PIGlow|r: selectionnez un joueur et attendez la detection de spec")
            end
        end
        configFrame:Hide()
    end)
end

-- ============================================================
-- Event handling
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon ~= ADDON_NAME then return end
        for k, v in pairs(defaults) do
            if PIGlowDB[k] == nil then
                PIGlowDB[k] = v
            end
        end
        self:UnregisterEvent("ADDON_LOADED")
        CreatePIButton()
        print("|cffFFCC00PIGlow|r v3 loaded. /pig to configure.")

    elseif event == "ENCOUNTER_START" then
        inEncounter = true
        StartTimers()

    elseif event == "ENCOUNTER_END" then
        inEncounter = false
        CancelTimers()

    elseif event == "PLAYER_REGEN_DISABLED" then
        if PIGlowDB.enabled and PIGlowDB.targetName then
            targetUnit = FindUnitForPlayer(PIGlowDB.targetName)
            UpdatePIButtonTarget()
            ShowPIButton()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        HidePIButton()
        StopPIButtonGlow()
        if inCombat and not inEncounter then
            CancelTimers()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID == PI_SPELL_ID then
            lastPICast = GetTime()
            alertHideAt = 0
            StopPIButtonGlow()
            if alertFrame and alertFrame:IsShown() then
                alertFrame.anim:Stop()
                alertFrame:Hide()
            end
        end
    end
end)

-- ============================================================
-- Slash commands
-- ============================================================
SLASH_PIGLOW1 = "/piglow"
SLASH_PIGLOW2 = "/pig"
SlashCmdList["PIGLOW"] = function(msg)
    local cmd = msg:trim():lower()

    if cmd == "" then
        CreateConfigUI()
    elseif cmd == "start" then
        StartTimers()
    elseif cmd == "stop" then
        CancelTimers()
        print("|cffFFCC00PIGlow|r: timers stopped")
    elseif cmd == "test" then
        if PIGlowDB.targetName then
            targetUnit = FindUnitForPlayer(PIGlowDB.targetName)
            UpdatePIButtonTarget()
        end
        ShowPIButton()
        ShowAlert(PIGlowDB.targetName or "TestPlayer", "0:00")
    elseif cmd == "clear" then
        PIGlowDB.targetName = nil
        PIGlowDB.targetSpecID = nil
        PIGlowDB.manualTimings = {}
        CancelTimers()
        print("|cffFFCC00PIGlow|r: config cleared")
    elseif cmd == "status" then
        print("|cffFFCC00PIGlow|r status:")
        print("  Target: " .. (PIGlowDB.targetName or "none"))
        if PIGlowDB.targetSpecID and PIGlow_SpellDB[PIGlowDB.targetSpecID] then
            local d = PIGlow_SpellDB[PIGlowDB.targetSpecID]
            print("  Spec: " .. d.spec .. " (" .. d.spell .. " " .. d.cd .. "s)")
        end
        print("  Mode: " .. (PIGlowDB.useManual and "Manuel" or "Auto"))
        print("  In combat: " .. tostring(inCombat))
    else
        print("|cffFFCC00PIGlow|r commands:")
        print("  /pig — ouvrir le menu")
        print("  /pig start — demarrer les timers manuellement")
        print("  /pig stop — arreter les timers")
        print("  /pig test — tester l'alerte")
        print("  /pig clear — reset config")
        print("  /pig status — voir la config actuelle")
    end
end
