--[[
	ServerInfo
	What kind of server this is.

	lobby  a normal public server: menus, parties, matchmaking, practice and private
	       matches (those run right here, no teleport needed)
	match  a reserved server created by the matchmaker for one public match
]]

local RunService = game:GetService("RunService")

local ServerInfo = {}

ServerInfo.isStudio = RunService:IsStudio()
ServerInfo.isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
ServerInfo.role = if ServerInfo.isReserved then "match" else "lobby"
-- Teleports never work inside Studio playtests.
ServerInfo.canTeleport = not ServerInfo.isStudio

return ServerInfo
