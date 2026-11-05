local _, ns = ...

SLASH_WILLITDIE1 = "/wid"
SlashCmdList.WILLITDIE = function(msg)
  ns.SafeCall("slash", function()
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    if cmd == "probe" then
      ns.ProbeSnapshot(rest ~= "" and rest or nil)
    elseif cmd == "reset" then
      WillItDieDB = { probe = { snapshots = {}, events = {} } }
      print("|cff55ff55WillItDie|r probe data cleared.")
    elseif cmd == "errors" then
      for _, e in ipairs((WillItDieDB and WillItDieDB.errors) or {}) do print(e) end
    else
      print("|cff55ff55WillItDie|r /wid probe <label> | /wid reset | /wid errors")
    end
  end)
end
