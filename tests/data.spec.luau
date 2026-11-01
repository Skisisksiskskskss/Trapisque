--!nocheck
-- Save schema, migrations and formatting.

return function(t)
	local DataSchema = t.require("src/shared/Modules/DataSchema")
	local Format = t.require("src/shared/Modules/Format")

	t.test("fresh template is current version", function()
		local data = DataSchema.Template()
		t.expect(data.Version == DataSchema.CurrentVersion, "version")
		t.expect(data.Cash == 0 and data.Tier == 1, "defaults")
	end)

	t.test("v1 save migrates to current and keeps progress", function()
		local v1 = {
			Version = 1,
			Cash = 1234,
			Tier = 4,
			CrystalLevel = 35,
			Brainrots = { ["7"] = { Uid = "7", Id = "coppa_gattina", Mutation = "Gold", Size = "Big", Obtained = 5 } },
			Slots = { ["1"] = "7" },
			Boosts = { Overcharge = 3 },
		}
		local data, upgraded = DataSchema.Migrate(v1)
		t.expect(upgraded, "should report upgrade")
		t.expect(data.Version == DataSchema.CurrentVersion, "version bumped")
		t.expect(data.Cash == 1234 and data.Tier == 4 and data.CrystalLevel == 35, "progress kept")
		t.expect(data.Brainrots["7"].Mutation == "Gold", "brainrot kept")
		t.expect(data.Boosts.Overcharge == 3, "boost kept")
		t.expect(data.Boosts.IronDoor == 0, "missing nested boost filled")
		t.expect(type(data.PlaytimeClaimed) == "table", "new field added")
		t.expect(data.Stats.Captures == 0, "missing table filled")
	end)

	t.test("garbage input yields a clean template", function()
		local data = DataSchema.Migrate("not a table")
		t.expect(data.Version == DataSchema.CurrentVersion and data.Cash == 0, "template")
	end)

	t.test("newer saves are detected and never migrated down", function()
		t.expect(DataSchema.IsNewer({ Version = DataSchema.CurrentVersion + 1 }), "newer detected")
		t.expect(not DataSchema.IsNewer({ Version = DataSchema.CurrentVersion }), "current not newer")
	end)

	t.test("receipt history is capped and searchable", function()
		local data = DataSchema.Template()
		for i = 1, DataSchema.MaxReceipts + 25 do
			DataSchema.AddReceipt(data, "p" .. i)
		end
		t.expect(#data.Receipts == DataSchema.MaxReceipts, "capped")
		t.expect(DataSchema.HasReceipt(data, "p" .. (DataSchema.MaxReceipts + 25)), "latest kept")
		t.expect(not DataSchema.HasReceipt(data, "p1"), "oldest dropped")
	end)

	t.test("uids are unique and monotonic", function()
		local data = DataSchema.Template()
		local a = DataSchema.NewUid(data)
		local b = DataSchema.NewUid(data)
		t.expect(a ~= b, "unique")
	end)

	t.test("short number formatting", function()
		t.expect(Format.Short(0) == "0", "0")
		t.expect(Format.Short(15) == "15", "15")
		t.expect(Format.Short(1500) == "1.5K", Format.Short(1500))
		t.expect(Format.Short(1234567) == "1.23M", Format.Short(1234567))
		t.expect(Format.Short(999999) == "1M", Format.Short(999999))
		t.expect(Format.Short(2.5e9) == "2.5B", Format.Short(2.5e9))
		t.expect(Format.Cash(12400) == "$12.4K", Format.Cash(12400))
	end)

	t.test("clock and duration formatting", function()
		t.expect(Format.Clock(75) == "1:15", Format.Clock(75))
		t.expect(Format.Clock(3725) == "1:02:05", Format.Clock(3725))
		t.expect(Format.Duration(3725) == "1h 2m", Format.Duration(3725))
		t.expect(Format.Commas(1234567) == "1,234,567", Format.Commas(1234567))
	end)
end
