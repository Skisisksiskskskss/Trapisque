--!nocheck
-- Session-locking guarantees, exercised with two simulated servers sharing one fake DataStore.

return function(t)
	local SaveStore = t.require("src/server/Modules/SaveStore")
	SaveStore.LoadAttempts = 3

	local function makeWorld()
		local clock = { now = 1000000 }
		local backend = SaveStore.MemoryBackend()
		local guidCounter = 0
		local function server(jobId)
			return SaveStore.fromBackend(backend, {
				JobId = jobId,
				Guid = function()
					guidCounter += 1
					return jobId .. "-session-" .. guidCounter
				end,
				Now = function()
					return clock.now
				end,
				Wait = function(seconds)
					clock.now += seconds
				end,
				IsMemory = true,
			})
		end
		return clock, backend, server
	end

	t.test("a fresh player loads with no data", function()
		local _, _, server = makeWorld()
		local a = server("A")
		local data, status = a:Load(1)
		t.expect(status == "ok" and data == nil, "fresh load")
	end)

	t.test("a second server cannot load while the first holds the lock", function()
		local _, _, server = makeWorld()
		local a, b = server("A"), server("B")
		a:Load(1)
		a:Save(1, { Cash = 50 }, false)
		local data, status = b:Load(1)
		t.expect(status == "locked" and data == nil, "B must be locked out")
	end)

	t.test("after a release the next server gets the latest data", function()
		local _, _, server = makeWorld()
		local a, b = server("A"), server("B")
		a:Load(1)
		a:Save(1, { Cash = 123 }, true)
		local data, status = b:Load(1)
		t.expect(status == "ok" and data.Cash == 123, "B sees A's final save")
	end)

	t.test("a stale lock from a dead server can be taken over", function()
		local clock, _, server = makeWorld()
		local a, b = server("A"), server("B")
		a:Load(1)
		a:Save(1, { Cash = 7 }, false)
		clock.now += SaveStore.LockStaleSeconds + 1
		local data, status = b:Load(1)
		t.expect(status == "ok" and data.Cash == 7, "stale lock stolen with last saved data")
	end)

	t.test("the old server is told its lock was lost and cannot overwrite", function()
		local clock, backend, server = makeWorld()
		local a, b = server("A"), server("B")
		a:Load(1)
		a:Save(1, { Cash = 7 }, false)
		clock.now += SaveStore.LockStaleSeconds + 1
		b:Load(1)
		b:Save(1, { Cash = 999 }, false)
		local ok, lockLost = a:Save(1, { Cash = 1 }, false)
		t.expect(not ok and lockLost, "A must detect the lost lock")
		local _, record = backend.Update("Player_1", function()
			return nil
		end)
		t.expect(record.Data.Cash == 999, "B's data must survive")
	end)

	t.test("lock time refreshes on every autosave so live servers keep ownership", function()
		local clock, _, server = makeWorld()
		local a, b = server("A"), server("B")
		a:Load(1)
		for _ = 1, 20 do
			clock.now += 60
			a:Save(1, { Cash = 1 }, false)
		end
		local _, status = b:Load(1)
		t.expect(status == "locked", "an actively saving server must keep its lock")
	end)

	t.test("rejoining the same server reclaims its own lock", function()
		local _, _, server = makeWorld()
		local a = server("A")
		a:Load(1)
		a:Save(1, { Cash = 5 }, false)
		local data, status = a:Load(1)
		t.expect(status == "ok" and data.Cash == 5, "same job id may reclaim")
	end)

	t.test("saving without a session is refused", function()
		local _, _, server = makeWorld()
		local a = server("A")
		local ok, lockLost = a:Save(42, { Cash = 1 }, false)
		t.expect(not ok and lockLost, "no session -> refuse")
	end)

	t.test("backend failures are retried", function()
		local failures = 2
		local inner = SaveStore.MemoryBackend()
		local flaky = {
			Update = function(key, transform)
				if failures > 0 then
					failures -= 1
					return false, "throttled"
				end
				return inner.Update(key, transform)
			end,
		}
		local store = SaveStore.fromBackend(flaky, {
			JobId = "A",
			Guid = function()
				return "s"
			end,
			Now = function()
				return 1
			end,
			Wait = function() end,
			IsMemory = true,
		})
		local _, status = store:Load(1)
		t.expect(status == "ok", "load retried past failures")
		failures = 2
		local ok = store:Save(1, { Cash = 3 }, true)
		t.expect(ok, "save retried past failures")
	end)
end
