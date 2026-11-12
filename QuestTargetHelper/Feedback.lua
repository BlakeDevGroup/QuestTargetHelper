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
    for i = math.max(1, #errors - 4), #errors do lines[#lines + 1] = "Error: " .. errors[i] end -- newest 5
  end
  return table.concat(lines, "\n")
end

local function selectAll(box)
  box:SetFocus()
  box:HighlightText()
end

local function build()
  local f = CreateFrame("Frame", "QuestTargetHelperFeedback", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(480, 360)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(360, 240, 1000, 900) end
  f:SetClampedToScreen(true)
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
  url:SetHeight(24)
  url:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -8) -- under the hint however it wraps
  url:SetPoint("RIGHT", -22, 0)
  url:SetAutoFocus(false)
  url:SetScript("OnEditFocusGained", selectAll)
  url:SetScript("OnMouseUp", selectAll)
  url:SetScript("OnEscapePressed", function() f:Hide() end)
  url:SetScript("OnTextChanged", function(self, user) if user then self:SetText(ns.FEEDBACK_URL) end end)

  local bg = CreateFrame("Frame", nil, f, "TooltipBackdropTemplate")
  bg:SetPoint("TOPLEFT", url, "BOTTOMLEFT", -6, -10)
  bg:SetPoint("BOTTOMRIGHT", -16, 22)
  -- The report scrolls: the edit box is the scroll child, as wide as the view
  -- (so long error lines wrap) and as tall as its text.
  local scroll = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local text = CreateFrame("EditBox", nil, scroll)
  text:SetMultiLine(true)
  text:SetFontObject(ChatFontNormal)
  text:SetWidth(400)
  text:SetAutoFocus(false)
  scroll:SetScrollChild(text)
  scroll:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then text:SetWidth(w) end end)
  scroll:EnableMouse(true)
  scroll:SetScript("OnMouseDown", function() text:SetFocus() end)
  -- Keep the caret in view while selecting with the keyboard.
  text:SetScript("OnCursorChanged", function(_, _, y, _, h)
    local top, view = scroll:GetVerticalScroll(), scroll:GetHeight()
    y = -y
    if y < top then scroll:SetVerticalScroll(y)
    elseif y + h > top + view then scroll:SetVerticalScroll(y + h - view) end
  end)

  -- Drag the bottom-right corner to resize.
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
  text:SetScript("OnMouseUp", selectAll)
  text:SetScript("OnEscapePressed", function() f:Hide() end)
  text:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.report) end end)

  f.url, f.text, f.scroll = url, text, scroll
  return f
end

function ns.ShowFeedback()
  frame = frame or build()
  frame.report = report()
  frame.url:SetText(ns.FEEDBACK_URL)
  frame.text:SetText(frame.report)
  frame:Show()
  selectAll(frame.url)
  -- Grow to fit the report (up to most of the screen); the rest scrolls.
  C_Timer.After(0, function()
    local f, view = frame, frame.scroll:GetHeight()
    if not view or view <= 0 then return end
    local want = f:GetHeight() - view + frame.text:GetHeight() + 8
    f:SetHeight(math.max(240, math.min(want, UIParent:GetHeight() * 0.8)))
  end)
end
