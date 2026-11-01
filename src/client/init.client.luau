--!strict
-- Client bootstrap: initialises and starts every controller in order.

local Controllers = script:WaitForChild("Controllers")

type Controller = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local order = {
	"StateController",
	"SoundController",
	"EffectsController",
	"WaveController",
	"WorldController",
	"RaidController",
	"UIController",
}

local loaded: { Controller } = {}
for _, name in order do
	local module = Controllers:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		table.insert(loaded, (require :: any)(module) :: Controller)
	else
		warn("[Client] missing controller " .. name)
	end
end

for _, controller in loaded do
	if controller.Init then
		controller.Init()
	end
end
for _, controller in loaded do
	if controller.Start then
		task.spawn(controller.Start)
	end
end
