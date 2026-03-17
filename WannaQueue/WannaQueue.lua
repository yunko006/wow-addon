-- WannaQueue: Auto-accept LFG role checks
-- Equivalent of WeakAura: https://wago.io/HyHjIHeKm

WannaQueueDB = WannaQueueDB or {}

local defaults = {
    enabled = true,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LFG_ROLE_CHECK_SHOW")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WannaQueue" then
            for k, v in pairs(defaults) do
                if WannaQueueDB[k] == nil then
                    WannaQueueDB[k] = v
                end
            end
            print("|cff00ccffWannaQueue|r loaded. Type /wq to toggle.")
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "LFG_ROLE_CHECK_SHOW" then
        if WannaQueueDB.enabled then
            CompleteLFGRoleCheck(true)
            print("|cff00ccffWannaQueue|r: Role check auto-accepted!")
        end
    end
end)

SLASH_WANNAQUEUE1 = "/wq"
SLASH_WANNAQUEUE2 = "/wannaqueue"
SlashCmdList["WANNAQUEUE"] = function(msg)
    WannaQueueDB.enabled = not WannaQueueDB.enabled
    if WannaQueueDB.enabled then
        print("|cff00ccffWannaQueue|r: Enabled - role checks will be auto-accepted.")
    else
        print("|cff00ccffWannaQueue|r: Disabled - role checks will NOT be auto-accepted.")
    end
end
