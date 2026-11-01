--!strict
-- Map layout math shared by the server (building, outcomes) and clients (animating waves and escapes).

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local MapGeometry = {}

function MapGeometry.PlotAngle(index: number): number
	return (index - 1) * (2 * math.pi / GameConfig.MaxPlots)
end

function MapGeometry.PlotCFrame(index: number): CFrame
	local angle = MapGeometry.PlotAngle(index)
	local radius = GameConfig.BaseFrontRadius + GameConfig.BaseSize / 2
	local center = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	return CFrame.lookAt(center, Vector3.new(0, 0, 0))
end

-- Where a plot's wave brainrot stops for the showdown (in front of the door).
function MapGeometry.StopPosition(index: number): Vector3
	local angle = MapGeometry.PlotAngle(index)
	local r = GameConfig.BaseFrontRadius - GameConfig.BeamStopDistance
	return Vector3.new(math.cos(angle) * r, 0.3, math.sin(angle) * r)
end

function MapGeometry.PortalEdge(index: number): Vector3
	local angle = MapGeometry.PlotAngle(index)
	local r = GameConfig.PortalRadius
	return Vector3.new(math.cos(angle) * r, 0.3, math.sin(angle) * r)
end

function MapGeometry.RingPosition(angle: number, radius: number): Vector3
	return Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
end

function MapGeometry.DoorPosition(index: number): Vector3
	local angle = MapGeometry.PlotAngle(index)
	local r = GameConfig.BaseFrontRadius
	return Vector3.new(math.cos(angle) * r, 0.3, math.sin(angle) * r)
end

return MapGeometry
