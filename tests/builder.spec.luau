--!nocheck
-- Builds every brainrot (and every mutation) headlessly through Lune's Roblox instance model.

return function(t)
	local Brainrots = t.require("src/shared/Config/Brainrots")
	local Mutations = t.require("src/shared/Config/Mutations")
	local BrainrotBuilder = t.require("src/shared/Modules/BrainrotBuilder")

	t.test("every catalog entry references existing kits", function()
		for _, def in Brainrots.List do
			local ok, missing = BrainrotBuilder.HasKits(def)
			t.expect(ok, def.Id .. " missing " .. tostring(missing))
		end
	end)

	t.test("every brainrot builds with every mutation", function()
		for _, def in Brainrots.List do
			for _, mutation in Mutations.List do
				local model = BrainrotBuilder.Build(def.Id, { Mutation = mutation.Name, Scale = 1.35 })
				t.expect(model.PrimaryPart ~= nil, def.Id .. " has no root")
				t.expect(#model:GetChildren() > 8, def.Id .. " is suspiciously small")
				t.expect(model:GetAttribute("BrainrotId") == def.Id, "attribute")
				model:Destroy()
			end
		end
	end)

	t.test("fit scale keeps pedestal brainrots inside the slot", function()
		for _, def in Brainrots.List do
			local scale = BrainrotBuilder.FitScale(def.Id, 5, 4.5)
			local dims = BrainrotBuilder.Dimensions(def.Id)
			t.expect(dims.Y * scale <= 5.0001 and dims.X * scale <= 4.5001, def.Id .. " does not fit")
		end
	end)
end
