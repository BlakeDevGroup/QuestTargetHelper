local _, ns = ...

SLASH_QUESTTARGETHELPER1 = "/qth"
SlashCmdList.QUESTTARGETHELPER = function(msg)
  ns.SafeCall("slash", function()
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    if cmd == "probe" then
      ns.ProbeSnapshot(rest ~= "" and rest or nil)
    elseif cmd == "reset" then
      QuestTargetHelperDB = { probe = { snapshots = {}, events = {} } }
      print("|cff55ff55QuestTargetHelper|r probe data cleared.")
    elseif cmd == "errors" then
      for _, e in ipairs((QuestTargetHelperDB and QuestTargetHelperDB.errors) or {}) do print(e) end
    else
      print("|cff55ff55QuestTargetHelper|r /qth probe <label> | /qth reset | /qth errors")
    end
  end)
end
