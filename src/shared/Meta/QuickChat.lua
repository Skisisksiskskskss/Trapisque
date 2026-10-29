--[[
	QuickChat
	Ready-made lines anyone can say, whatever their Roblox chat settings (they're fixed
	text, so they need no filtering): the way to talk for players Roblox doesn't let
	type. Saying anything else is the Chat pass.
]]

local QuickChat = {}

QuickChat.list = {
	{ id = "ahoy", text = "Ahoy!" },
	{ id = "luck", text = "Good luck!" },
	{ id = "nice", text = "Nice move!" },
	{ id = "oops", text = "Oops!" },
	{ id = "thanks", text = "Thanks!" },
	{ id = "gg", text = "GG!" },
	{ id = "wp", text = "Well played!" },
	{ id = "close", text = "So close!" },
	{ id = "watch", text = "Watch out!" },
	{ id = "trap", text = "Arr, a trap!" },
	{ id = "yoho", text = "Yo ho ho!" },
	{ id = "again", text = "Rematch?" },
}

QuickChat.byId = {}
for i, q in QuickChat.list do
	q.order = i
	QuickChat.byId[q.id] = q
end

function QuickChat.get(id: any)
	return if type(id) == "string" then QuickChat.byId[id] else nil
end

return QuickChat
