-- /qth feedback: a copyable link to the issue tracker plus a ready-made bug
-- report (version, client, class, errors), since links can't be clicked in game.
local ADDON, ns = ...

ns.FEEDBACK_URL = "https://github.com/BlakeDevGroup/QuestTargetHelper/issues"

local frame

local function report()
  local version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
  local build, buildNum, _, iface = GetBuildInfo()
  local lines = {
    "QuestTargetHelper " .. tostring(version),
    "Client " .. tostring(build) .. "." .. tostring(buildNum) .. " (" .. tostring(iface) .. ")",
    "Class " .. tostring(select(2, UnitClass("player"))) .. ", level " .. tostring(UnitLevel("player")),
    "Plater " .. ((C_AddOns and C_AddOns.IsAddOnLoaded("Plater")) and "on" or "off"),
  }
  local errors = (QuestTargetHelperDB and QuestTargetHelperDB.errors) or {}
  if #errors == 0 then
    lines[#lines + 1] = "No errors logged"
  else
    for i = 1, math.min(#errors, 5) do lines[#lines + 1] = "Error: " .. errors[i] end
  end
  return table.concat(lines, "\n")
end

local function selectAll(box)
  box:SetFocus()
  box:HighlightText()
end

local function build()
  local f = CreateFrame("Frame", "QuestTargetHelperFeedback", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(480, 280)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  table.insert(UISpecialFrames, f:GetName()) -- Escape closes it

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -6)
  title:SetText("QuestTargetHelper feedback")

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  hint:SetPoint("TOPLEFT", 16, -36)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText("Press Ctrl+C to copy the link, open it in your browser, and paste the report below into your issue.")

  local url = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  url:SetSize(440, 24)
  url:SetPoint("TOPLEFT", 22, -76)
  url:SetAutoFocus(false)
  url:SetScript("OnEditFocusGained", selectAll)
  url:SetScript("OnMouseUp", selectAll)
  url:SetScript("OnEscapePressed", function() f:Hide() end)
  url:SetScript("OnTextChanged", function(self, user) if user then self:SetText(ns.FEEDBACK_URL) end end)

  local bg = CreateFrame("Frame", nil, f, "TooltipBackdropTemplate")
  bg:SetPoint("TOPLEFT", 16, -110)
  bg:SetPoint("BOTTOMRIGHT", -16, 16)
  local text = CreateFrame("EditBox", nil, bg)
  text:SetMultiLine(true)
  text:SetFontObject(ChatFontNormal)
  text:SetPoint("TOPLEFT", 8, -8)
  text:SetPoint("BOTTOMRIGHT", -8, 8)
  text:SetAutoFocus(false)
  text:SetScript("OnMouseUp", selectAll)
  text:SetScript("OnEscapePressed", function() f:Hide() end)
  text:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.report) end end)

  f.url, f.text = url, text
  return f
end

function ns.ShowFeedback()
  frame = frame or build()
  frame.report = report()
  frame.url:SetText(ns.FEEDBACK_URL)
  frame.text:SetText(frame.report)
  frame:Show()
  selectAll(frame.url)
end
