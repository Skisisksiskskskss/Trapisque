-- Runs every registered test and exits non-zero on failure.
local passed, failed = 0, 0
local filter = nil
for _, name in TESTS do
	local ok, err = pcall(name.fn)
	if ok then
		passed += 1
		print("  ok   " .. name.name)
	else
		failed += 1
		print("  FAIL " .. name.name .. "\n       " .. tostring(err))
	end
end
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
