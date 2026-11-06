-- Test helpers. Loads addon files into one shared namespace table the way WoW
-- does (each file gets `...` = addonName, ns), and counts failures.
local H = {}

function H.addon(files, ns)
  ns = ns or {}
  for _, f in ipairs(files) do
    local chunk = assert(loadfile("QuestTargetHelper/" .. f .. ".lua"))
    chunk("QuestTargetHelper", ns)
  end
  return ns
end

function H.suite(name)
  local t = { name = name, failures = 0, count = 0 }
  function t.eq(label, got, want)
    t.count = t.count + 1
    local ok
    if type(want) == "number" and type(got) == "number" then
      ok = math.abs(got - want) < 1e-6
    else
      ok = got == want
    end
    if not ok then
      t.failures = t.failures + 1
      print(string.format("FAIL [%s] %s: got %s, want %s", name, label, tostring(got), tostring(want)))
    end
  end
  function t.done()
    print(string.format("%s: %d/%d passed", name, t.count - t.failures, t.count))
    return t.failures
  end
  return t
end

return H
