-- Secret-value guards. Nothing in this addon may do math, comparisons or
-- tostring on a value that could be secret; route it through these first.
local _, ns = ...

local issecretvalue = issecretvalue

function ns.IsSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Human-readable, never throws: secrets become "SECRET(<type>)".
function ns.Describe(v)
  if ns.IsSecret(v) then return "SECRET(" .. type(v) .. ")" end
  local t = type(v)
  if t == "nil" or t == "number" or t == "boolean" or t == "string" then
    return tostring(v)
  end
  return t
end

-- pcall that returns a description of the outcome instead of raising.
function ns.Try(fn, ...)
  local ok, a, b, c = pcall(fn, ...)
  if not ok then return "ERROR: " .. ns.Describe(a) end
  return a, b, c
end

-- Wrap a handler so a Lua error is recorded once per site and never spams.
local reported = {}
function ns.SafeCall(site, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and not reported[site] then
    reported[site] = true
    QuestTargetHelperDB = QuestTargetHelperDB or {}
    QuestTargetHelperDB.errors = QuestTargetHelperDB.errors or {}
    local log = QuestTargetHelperDB.errors
    table.insert(log, site .. ": " .. ns.Describe(err))
    while #log > 20 do table.remove(log, 1) end -- newest 20
    print("|cffff5555QuestTargetHelper|r error in " .. site .. " (logged; /qth errors)")
  end
end
