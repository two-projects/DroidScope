-- ================= CONFIG =================
local WEBHOOK_URLS = {
	"https://discord.com/api/webhooks/1467670290971492373/epApIOFGz9F5An4yhUl_3sXHSW8dcEvj9D9pC3Q1WFNjhsZlizTVf5TpkVaWs49G_sZL"
}

local PRIVATE_SERVER = "https://www.roblox.com/share?code=aad142168d2e0c419085cc0679eb2ef3&type=Server"

local JESTER_ROLES = {
	"1372297015739940864"
}

local MARI_ROLES = {
	"1372297109117861888"
}

local VERSION = "DroidScope | Beta v1.0.3 (bytetwo ver)"

-- ================= SERVICES =================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- ================= HTTP =================
local HttpRequest =
	http and http.request
	or http_request
	or request
	or (syn and syn.request)

assert(HttpRequest, "HTTP not supported")

-- ================= STATE =================
local macroRunning = false
local lastBiome = nil
local sessionStart = nil
local merchantCooldown = { Jester = 0, Mari = 0 }
local MERCHANT_CD = 25

-- ================= BIOME DATA =================
local BIOME_DATA = {
	WINDY = { color=0xFFFFFF },
	RAINY = { color=0x55925F },
	SNOWY = { color=0xFFFFFF },
	["SAND STORM"] = { color=0xFFA500 },
	HELL = { color=0xFB4F29 },
	STARFALL = { color=0xFFFFFF },
	CORRUPTION = { color=0x800080 },
	NULL = { color=0x808080 },

	HEAVEN = { color=0xE7DC43 },

	GLITCHED = { color=0xFFFF00, everyone=true },
	DREAMSPACE = { color=0xFF00FF, everyone=true },
	CYBERSPACE = { color=0x00FFFF, everyone=true },

	NORMAL = { never=true }
}

-- ================= WEBHOOK CORE =================
local function sendWebhook(payload)
	for _, url in ipairs(WEBHOOK_URLS) do
		HttpRequest({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload)
		})
	end
end

local function rolePing(ids)
	local t = {}
	for _, id in ipairs(ids) do
		table.insert(t, "<@&"..id..">")
	end
	return table.concat(t, " ")
end

-- ================= STATUS EMBED =================
local function sendStatus(started)
	sendWebhook({
		embeds = {{
			title = started
				and ":bar_chart: Status Update: DroidScope Started"
				or  ":bar_chart: Status Update: DroidScope Stopped",
			color = 0x3498DB,
			fields = {{
				name = "Session",
				value = "<t:"..sessionStart..":F> (<t:"..sessionStart..":R>)",
				inline = false
			}},
			footer = { text = VERSION }
		}}
	})
end

-- ================= BIOME EMBED =================
local function sendBiome(biome, data, state)
	local t = os.time()
	sendWebhook({
		content = data.everyone and "@everyone" or nil,
		embeds = {{
			title = "Biome "..state.." - "..biome,
			color = data.color,
			fields = {
				{ name="Account", value=player.Name, inline=false },
				{ name="\u{200B}", value="<t:"..t..":F> (<t:"..t..":R>)", inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false },
				{ name="Status", value=state, inline=false }
			},
			footer = { text = VERSION }
		}}
	})
end

-- ================= MERCHANT EMBED =================
local function sendMerchant(name)
	local now = os.time()
	if now - merchantCooldown[name] < MERCHANT_CD then return end
	merchantCooldown[name] = now

	local title, color, ping
	if name == "Jester" then
		title = ":black_joker: Jester Has Arrived!"
		color = 0xA352FF
		ping = rolePing(JESTER_ROLES)
	else
		title = ":shopping_bags: Mari Has Arrived!"
		color = 0xFF82AB
		ping = rolePing(MARI_ROLES)
	end

	sendWebhook({
		content = ping,
		embeds = {{
			title = title,
			color = color,
			fields = {
				{ name="Account", value=player.Name, inline=false },
				{ name="\u{200B}", value="<t:"..now..":F> (<t:"..now..":R>)", inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false }
			},
			footer = { text = VERSION }
		}}
	})
end

-- ================= BIOME DETECTION =================
local function detectBiome()
	if not macroRunning then return end
	for _, v in ipairs(player.PlayerGui:GetDescendants()) do
		if v:IsA("TextLabel") then
			local biome = v.Text:match("^%[ ([%w%s]+) %]$")
			local data = BIOME_DATA[biome]
			if biome and data and biome ~= lastBiome then
				if lastBiome and BIOME_DATA[lastBiome] and not BIOME_DATA[lastBiome].never then
					sendBiome(lastBiome, BIOME_DATA[lastBiome], "Ended")
				end
				lastBiome = biome
				if not data.never then
					sendBiome(biome, data, "Started")
				end
			end
		end
	end
end

-- ================= CHAT =================
TextChatService.OnIncomingMessage = function(msg)
	if not macroRunning or not msg.Text then return end
	local t = msg.Text:lower()
	if t:find("jester") and t:find("arrived") then
		sendMerchant("Jester")
	elseif t:find("mari") and t:find("arrived") then
		sendMerchant("Mari")
	end
end

-- ================= LOOP =================
task.spawn(function()
	while true do
		detectBiome()
		task.wait(1.5)
	end
end)

-- ================= ANTI AFK =================
player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

-- ================= UI (SMALL + DRAGGABLE) =================
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromScale(0.42,0.16)
frame.Position = UDim2.fromScale(0.29,0.75)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
Instance.new("UICorner", frame).CornerRadius = UDim.new(0.15,0)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.fromScale(1,0.35)
title.BackgroundTransparency = 1
title.Text = "DroidScope"
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1,1,1)

local function btn(text,pos,color,cb)
	local b = Instance.new("TextButton", frame)
	b.Size = UDim2.fromScale(0.45,0.4)
	b.Position = pos
	b.Text = text
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1,1,1)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0.2,0)
	b.Activated:Connect(cb)
end

btn("START", UDim2.fromScale(0.03,0.5), Color3.fromRGB(46,204,113), function()
	if macroRunning then return end
	macroRunning = true
	lastBiome = nil
	sessionStart = os.time()
	sendStatus(true)
end)

btn("STOP", UDim2.fromScale(0.52,0.5), Color3.fromRGB(231,76,60), function()
	if not macroRunning then return end
	macroRunning = false
	sendStatus(false)
end)

-- drag
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging=true; dragStart=i.Position; startPos=frame.Position
	end
end)
frame.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
		local d=i.Position-dragStart
		frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end)
