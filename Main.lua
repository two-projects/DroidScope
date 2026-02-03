-- ================= CONFIG =================
local WEBHOOK_URLS = {
	"https://discord.com/api/webhooks/1467670290971492373/epApIOFGz9F5An4yhUl_3sXHSW8dcEvj9D9pC3Q1WFNjhsZlizTVf5TpkVaWs49G_sZL"
}

-- Webhook for BOTH Jester and Mari
local MERCHANT_WEBHOOK = "https://discord.com/api/webhooks/1467851474397561018/-XyREI978MEsyhKqnhEtPyRAsd-hOcB1OQmVyjIZ0FyV758JFv79ZTe3qL9RY129mbm_"

local PRIVATE_SERVER = "https://www.roblox.com/share?code=aad142168d2e0c419085cc0679eb2ef3&type=Server"

local JESTER_ROLES = { "1467788391075545254" }
local MARI_ROLES   = { "1467788352462913669" } 

local VERSION = "DroidScope | Beta v1.1.2 (bytetwo ver)"
local DEFAULT_THUMB = "https://i.ibb.co/S7X9mR6X/image-041fa2.png"

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
local sessionStart = 0
local hourStart = 0

local merchantCooldown = { Jester = 0, Mari = 0 }
local MERCHANT_CD = 25

-- hourly stats
local biomeStats = {}
local totalBiomes = 0

-- ================= BIOME DATA =================
local BIOME_DATA = {
	WINDY = { color=0xFFFFFF, thumb="https://maxstellar.github.io/biome_thumb/WINDY.png" },
	RAINY = { color=0x55925F, thumb="https://maxstellar.github.io/biome_thumb/RAINY.png" },
	SNOWY = { color=0xFFFFFF, thumb="https://maxstellar.github.io/biome_thumb/SNOWY.png" },
	["SAND STORM"] = { color=0xFFA500, thumb="https://maxstellar.github.io/biome_thumb/SAND%20STORM.png" },
	HELL = { color=0xFB4F29, thumb="https://maxstellar.github.io/biome_thumb/HELL.png" },
	STARFALL = { color=0xFFFFFF, thumb="https://maxstellar.github.io/biome_thumb/STARFALL.png" },
	CORRUPTION = { color=0x800080, thumb="https://maxstellar.github.io/biome_thumb/CORRUPTION.png" },
	NULL = { color=0x808080, thumb="https://maxstellar.github.io/biome_thumb/NULL.png" },
	HEAVEN = { color=0xADD8E6, thumb="https://maxstellar.github.io/biome_thumb/HEAVEN.png" },

	GLITCHED = { color=0xFFFF00, thumb="https://i.postimg.cc/mDzwFfX1/GLITCHED.png", everyone=true },
	DREAMSPACE = { color=0xFF00FF, thumb="https://maxstellar.github.io/biome_thumb/DREAMSPACE.png", everyone=true },
	CYBERSPACE = { color=0x00FFFF, thumb="https://raw.githubusercontent.com/cresqnt-sys/MultiScope/main/assets/cyberspace.png", everyone=true },

	NORMAL = { never=true }
}

-- ================= UTILS =================
local function getPlainUptime()
	local diff = os.time() - sessionStart
	local days = math.floor(diff / 86400)
	local hours = math.floor((diff % 86400) / 3600)
	local minutes = math.floor((diff % 3600) / 60)
	local seconds = diff % 60
	
	local str = ""
	if days > 0 then str = str .. days .. "d " end
	if hours > 0 or days > 0 then str = str .. hours .. "hr " end
	if minutes > 0 or hours > 0 or days > 0 then str = str .. minutes .. "m " end
	str = str .. seconds .. "s"
	
	return str
end

-- ================= WEBHOOK =================
local function sendWebhook(payload, customUrl)
	local urls = customUrl and {customUrl} or WEBHOOK_URLS
	for _, url in ipairs(urls) do
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

-- ================= STATUS =================
local function sendStatus(started)
	sendWebhook({
		embeds = {{
			title = started
				and ":bar_chart: Status Update: DroidScope Started"
				or  ":bar_chart: Status Update: DroidScope Stopped",
			color = 0x3498DB,
			thumbnail = { url = DEFAULT_THUMB },
			fields = {
				{ name="Session Start", value="<t:"..sessionStart..":F>", inline=false },
				{ name="Uptime", value=getPlainUptime(), inline=false }
			},
			footer = { text = VERSION }
		}}
	})
end

-- ================= BIOME EMBED =================
local function sendBiome(biome, data, state)
	local now = os.time()
	sendWebhook({
		content = data.everyone and "@everyone" or nil,
		embeds = {{
			title = "Biome "..state.." - "..biome,
			color = data.color,
			thumbnail = { url = data.thumb or DEFAULT_THUMB },
			fields = {
				{ name="Account", value=player.Name, inline=false },
				{ name="Time", value="<t:"..now..":F> (<t:"..now..":R>)", inline=false },
				{ name="Uptime", value=getPlainUptime(), inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false },
				{ name="Status", value=state, inline=false }
			},
			footer = { text = VERSION }
		}}
	})
end

-- ================= HOURLY REPORT =================
local function sendHourlyStats()
	if totalBiomes == 0 then return end

	local lines = {}
	for biome, count in pairs(biomeStats) do
		local percent = math.floor((count / totalBiomes) * 1000) / 10
		table.insert(lines, biome..": "..count.." ("..percent.."%)")
	end

	sendWebhook({
		embeds = {{
			title = "📊 Hourly Biome Report",
			color = 0x1ABC9C,
			thumbnail = { url = DEFAULT_THUMB },
			description =
				"**Uptime:** "..getPlainUptime().."\n" ..
				"**Total Biomes:** "..totalBiomes.."\n\n" ..
				table.concat(lines, "\n"),
			footer = { text = VERSION }
		}}
	})

	biomeStats = {}
	totalBiomes = 0
	hourStart = os.time()
end

-- ================= MERCHANT =================
local function sendMerchant(name)
	local now = os.time()
	if now - merchantCooldown[name] < MERCHANT_CD then return end
	merchantCooldown[name] = now

	local title, color, ping, thumb

	if name == "Jester" then
		title = ":black_joker: Jester Has Arrived!"
		color = 0xA352FF
		ping = rolePing(JESTER_ROLES)
		thumb = "https://keylens-website.web.app/merchants/Jester.png"
	else
		title = ":shopping_bags: Mari Has Arrived!"
		color = 0xFF82AB
		ping = rolePing(MARI_ROLES)
		thumb = "https://keylens-website.web.app/merchants/Mari.png"
	end

	sendWebhook({
		content = ping,
		embeds = {{
			title = title,
			color = color,
			thumbnail = { url = thumb },
			fields = {
				{ name="Account", value=player.Name, inline=false },
				{ name="Time", value="<t:"..now..":F> (<t:"..now..":R>)", inline=false },
				{ name="Uptime", value=getPlainUptime(), inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false }
			},
			footer = { text = VERSION }
		}}
	}, MERCHANT_WEBHOOK)
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
					biomeStats[biome] = (biomeStats[biome] or 0) + 1
					totalBiomes += 1
				end
			end
		end
	end
end

TextChatService.OnIncomingMessage = function(msg)
	if not macroRunning or not msg.Text then return end
	local t = msg.Text:lower()
	if t:find("jester") and t:find("arrived") then sendMerchant("Jester") end
	if t:find("mari") and t:find("arrived") then sendMerchant("Mari") end
end

-- ================= LOOP =================
task.spawn(function()
	while true do
		if macroRunning then
			detectBiome()
			if os.time() - hourStart >= 3600 then
				sendHourlyStats()
			end
		end
		task.wait(1.5)
	end
end)

-- ================= ANTI AFK =================
player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

-- ================= UI =================
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
	hourStart = sessionStart
	biomeStats = {}
	totalBiomes = 0
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
	if dragging then
		local d=i.Position-dragStart
		frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end)
