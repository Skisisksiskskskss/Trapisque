--[[
	QuickChat
	Ready-made lines anyone can say, whatever their Roblox chat settings (they're fixed
	text, so they need no filtering). Typing your own lines is the Chat pass.
]]

local QuickChat = {}

QuickChat.list = {
	{ id = "ahoy", text = "Ahoy!" },
	{ id = "luck", text = "Good luck!" },
	{ id = "nice", text = "Nice move!" },
	{ id = "arr", text = "Arrr!" },
	{ id = "oops", text = "Oops!" },
	{ id = "watch", text = "Watch your step!" },
	{ id = "gotcha", text = "Gotcha!" },
	{ id = "close", text = "So close!" },
	{ id = "yoho", text = "Yo ho ho!" },
	{ id = "hurry", text = "Hurry up, matey!" },
	{ id = "thanks", text = "Thanks!" },
	{ id = "sorry", text = "Sorry!" },
	{ id = "nofair", text = "Not fair!" },
	{ id = "landho", text = "Land ho!" },
	{ id = "wp", text = "Well played!" },
	{ id = "gg", text = "GG!" },
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
