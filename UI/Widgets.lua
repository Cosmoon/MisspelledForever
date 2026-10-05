local _, ns = ...
local UI = {}
ns.UI = UI
UI.ACCENT = { 0.32, 0.78, 0.72 }
UI.ICON = "Interface\\AddOns\\MisspelledForever\\Assets\\MisspelledForeverLogo.tga"

-- Shared controls used by the options window and correction panel.
local function label(parent, text, x, y, template)
	local value = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	value:SetPoint("TOPLEFT", x, y)
	value:SetText(text)
	value:SetJustifyH("LEFT")
	return value
end

local function background(frame)
	frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	frame:SetBackdropColor(0.035, 0.055, 0.07, 0.97)
	frame:SetBackdropBorderColor(0.18, 0.34, 0.36, 1)
end

local function button(parent, text, width, height, action)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, height or 24)
	b:SetText(text)
	b:SetScript("OnClick", action)
	return b
end

local function tip(frame, heading, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(heading)
		GameTooltip:AddLine(text, 0.85, 0.9, 0.9, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function checkbox(parent, heading, text, x, y, get, set)
	local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	b:SetPoint("TOPLEFT", x, y)
	b:SetSize(26, 26)
	b.text = label(b, heading, 29, -5)
	b.text:SetWidth(430)
	b:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	b.Refresh = function(self) self:SetChecked(get()) end
	b:Refresh()
	tip(b, heading, text)
	return b
end

local function editbox(parent, width, height, multiline)
	local b = CreateFrame("EditBox", nil, parent, multiline and "BackdropTemplate" or "InputBoxTemplate")
	b:SetSize(width, height)
	b:SetAutoFocus(false)
	b:SetFontObject("ChatFontNormal")
	if multiline then
		background(b)
		b:SetMultiLine(true)
		b:SetTextInsets(10, 10, 10, 10)
	end
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return b
end

UI.Label, UI.Background, UI.Button = label, background, button
UI.Tooltip, UI.Checkbox, UI.EditBox = tip, checkbox, editbox
