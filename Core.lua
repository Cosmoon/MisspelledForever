local ADDON, ns = ...
local driver = CreateFrame("Frame")

-- Modules are loaded by the TOC before this entry point. Initialize saved
-- settings first, then dictionaries, UI and chat hooks in that order.
local function update()
	ns.Chat:Update()
	if not ns.Chat:HasWork() then driver:SetScript("OnUpdate", nil) end
end
function ns.WakeChat()
	if ns.Chat:IsOpen() then driver:SetScript("OnUpdate", update) end
end

-- Gameplay notifications are useful only while a chat input is visible.
function ns.SetChatActive(active)
	for _, event in ipairs({"GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "GLOBAL_MOUSE_DOWN"}) do
		if active then driver:RegisterEvent(event) else driver:UnregisterEvent(event) end
	end
	if not active then driver:SetScript("OnUpdate", nil) end
end

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
		if event == "PLAYER_LOGIN" then driver:UnregisterEvent(event) end
	end
end)

for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "UPDATE_CHAT_WINDOWS"}) do
	driver:RegisterEvent(event)
end
