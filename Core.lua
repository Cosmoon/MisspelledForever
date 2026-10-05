local ADDON, ns = ...
local driver = CreateFrame("Frame")

-- Modules are loaded by the TOC before this entry point. Initialize saved
-- settings first, then dictionaries, UI and chat hooks in that order.
driver:SetScript("OnUpdate", function()
	ns.Chat:Update()
end)

driver:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		ns.InitializeSettings()
		ns.Engine:Initialize(ns.db.personalWords, ns.db.languages)
		ns.UI:CreateCorrectionPanel()
		ns.UI:CreateOptions()
		ns.UI:CreateMinimap()
		ns.Chat:Initialize()
		ns.RegisterCommands()
		driver:UnregisterEvent("ADDON_LOADED")
	elseif ns.db then
		ns.Chat:HandleEvent(event)
	end
end)

for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "UPDATE_CHAT_WINDOWS", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "GLOBAL_MOUSE_DOWN"}) do
	driver:RegisterEvent(event)
end
