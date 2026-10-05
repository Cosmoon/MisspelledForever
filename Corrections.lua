local _, ns = ...
local UI = ns.UI
local background, button = UI.Background, UI.Button
local label, tip, ACCENT = UI.Label, UI.Tooltip, UI.ACCENT

function UI:CreateCorrectionPanel()
	local panel = CreateFrame("Frame", "MisspelledForeverCorrectionPanel", UIParent, "BackdropTemplate")
	panel:SetSize(440, 64)
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	background(panel)
	panel:Hide()
	panel.title = label(panel, "MisspelledForever", 12, -10, "GameFontNormalSmall")
	panel.title:SetTextColor(unpack(ACCENT))
	panel.status = label(panel, "", 12, -36, "GameFontDisableSmall")
	local settings = button(panel, "...", 25, 22, function() ns.OpenSettings() end)
	settings:SetPoint("TOPRIGHT", -10, -8)
	tip(settings, "Settings", "Open spelling options and your personal dictionary.")
	local close = button(panel, "x", 25, 22, function() ns.DismissPanel() end)
	close:SetPoint("TOPRIGHT", -40, -8)
	tip(close, "Close suggestions", "Click an colored word to open suggestions again.")
	panel.suggestions = {}
	for i = 1, 8 do
		local b = button(panel, "", 197, 22, function(self) ns.ApplyCorrection(self.word) end)
		b:SetPoint("TOPLEFT", 12 + ((i - 1) % 2) * 207, -57 - math.floor((i - 1) / 2) * 26)
		b:Hide()
		panel.suggestions[i] = b
	end
	panel.learn = button(panel, "Learn word", 110, 23, function() ns.LearnSelected() end)
	panel.ignore = button(panel, "Ignore for session", 144, 23, function() ns.IgnoreSelected() end)
	panel.learn:SetPoint("BOTTOMLEFT", 12, 10)
	panel.ignore:SetPoint("BOTTOMLEFT", 130, 10)
	panel.learn:Hide(); panel.ignore:Hide()
	self.panel = panel
end

function UI:OpenSuggestions(editBox, issue)
	local panel = self.panel
	panel:ClearAllPoints()
	panel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 8)
	panel:SetScale(ns.db.panelScale)
	panel.title:SetText(issue.word)
	panel.title:SetTextColor(unpack(ns.db.highlightColor))
	for _, b in ipairs(panel.suggestions) do b:Hide() end
	panel:Show()
end

function UI:ShowSuggestions(word, suggestions, pending)
	local panel = self.panel
	local rows = pending and 1 or math.max(1, math.ceil(#suggestions / 2))
	panel:SetHeight(97 + rows * 26)
	panel.status:SetText(pending and ("Finding corrections for " .. word .. "...")
		or (#suggestions == 0 and "No close match. You can learn or ignore this word." or "Click a correction to replace only this word."))
	for i, b in ipairs(panel.suggestions) do
		if suggestions[i] and not pending then
			b.word = suggestions[i]
			b:SetText(suggestions[i]); b:Show()
		else b:Hide() end
	end
	panel.learn:Show(); panel.ignore:Show()
	panel:Show()
end
