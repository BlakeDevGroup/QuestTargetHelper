-- Run every test file from the repo root: lua tests/run_all.lua
-- Exits non-zero if any test fails (CI relies on this).
package.path = "tests/?.lua;" .. package.path
local files = { "math_test", "quest_test", "rules_test", "snapshot_test" }
local failures = 0
for _, f in ipairs(files) do
  local ok, result = pcall(dofile, "tests/" .. f .. ".lua")
  if not ok then
    print("ERROR in " .. f .. ": " .. tostring(result))
    failures = failures + 1
  else
    failures = failures + (tonumber(result) or 0)
  end
end
if failures > 0 then
  print(failures .. " failure(s)")
  os.exit(1)
end
print("all tests passed")
