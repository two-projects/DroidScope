-- ================= CONFIG =================
local WEBHOOK_URLS = {
	"https://discord.com/api/webhooks/1467670290971492373/epApIOFGz9F5An4yhUl_3sXHSW8dcEvj9D9pC3Q1WFNjhsZlizTVf5TpkVaWs49G_sZL",
}

local PRIVATE_SERVER = "https://www.roblox.com/share?code=aad142168d2e0c419085cc0679eb2ef3&type=Server"

local JESTER_ROLE_IDS = { "1372297015739940864" }
local MARI_ROLE_IDS   = { "1372297109117861888" }

-- ================= SERVICES =================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- ================= HTTP (CRYPTIC) =================
local HttpRequest =
	http and http.request
	or http_request
	or request
	or (syn and syn.request)
assert(HttpRequest, "HTTP request not supported")

-- ================= STATE =================
local macroRunning = false
local sessionStart = 0
local currentBiome = nil
local lastSeenAt = 0
local BIOME_TIMEOUT = 3

local hourlyStats = {}
local allTimeStats = {}
local totalHourly = 0
local totalAllTime = 0
local lastHourTick = os.time()

local merchantCooldown = { Jester = 0, Mari = 0 }
local MERCHANT_CD = 30

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
	HEAVEN = { color=0xE7DC43, thumb="https://maxstellar.github.io/biome_thumb/HEAVEN.png" },

	GLITCHED = { color=0xFFFF00, thumb="https://i.postimg.cc/mDzwFfX1/GLITCHED.png", pingEveryone=true },
	DREAMSPACE = { color=0xFF00FF, thumb="https://maxstellar.github.io/biome_thumb/DREAMSPACE.png", pingEveryone=true },
	CYBERSPACE = { color=0x00FFFF, thumb="https://raw.githubusercontent.com/cresqnt-sys/MultiScope/refs/heads/main/assets/cyberspace.png", pingEveryone=true },

	NORMAL = { never=true }
}

-- ================= HELPERS =================
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

local function formatUptime()
	local s = os.time() - sessionStart
	local h = math.floor(s/3600)
	local m = math.floor((s%3600)/60)
	local sec = s%60
	return string.format("%dh %dm %ds", h, m, sec)
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
			title = started and ":bar_chart: Status Update: DroidScope Started" or ":bar_chart: Status Update: DroidScope Stopped",
			color = 0x3498DB,
			fields = {
				{ name="Session", value="<t:"..sessionStart..":F> (<t:"..sessionStart..":R>)", inline=false }
			},
			footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})
end

-- ================= BIOME =================
local function incStats(biome)
	hourlyStats[biome] = (hourlyStats[biome] or 0) + 1
	allTimeStats[biome] = (allTimeStats[biome] or 0) + 1
	totalHourly += 1
	totalAllTime += 1
end

local function sendBiomeEmbed(biome, data, state)
	local t = os.time()
	local content = nil
	if data.pingEveryone then content = "@everyone" end

	sendWebhook({
		content = content,
		embeds = {{
			title = "Biome "..state.." - "..biome,
			color = data.color,
			fields = {
				{ name="Account", value=player.Name.."\nUptime: "..formatUptime(), inline=false },
				{ name="Time", value="<t:"..t..":F> (<t:"..t..":R>)", inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false },
				{ name="Status", value=state, inline=false }
			},
			thumbnail = { url = data.thumb },
			footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})
end

local function detectBiome()
	if not macroRunning then return end

	local foundBiome = nil
	for _, v in ipairs(player.PlayerGui:GetDescendants()) do
		if v:IsA("TextLabel") then
			local biome = v.Text:match("^%[ ([%w%s]+) %]$")
			if biome and BIOME_DATA[biome] then
				foundBiome = biome
				break
			end
		end
	end

	if foundBiome then
		lastSeenAt = os.time()
		if foundBiome ~= currentBiome then
			currentBiome = foundBiome
			incStats(foundBiome)
			if not BIOME_DATA[foundBiome].never then
				sendBiomeEmbed(foundBiome, BIOME_DATA[foundBiome], "Started")
			end
		end
	else
		if currentBiome and os.time() - lastSeenAt >= BIOME_TIMEOUT then
			if not BIOME_DATA[currentBiome].never then
				sendBiomeEmbed(currentBiome, BIOME_DATA[currentBiome], "Ended")
			end
			currentBiome = nil
		end
	end
end

-- ================= MERCHANT =================
local function sendMerchant(name)
	local now = os.time()
	if now - merchantCooldown[name] < MERCHANT_CD then return end
	merchantCooldown[name] = now

	local title = name=="Mari" and ":shopping_bags: Mari Has Arrived!" or ":black_joker: Jester Has Arrived!"
	local ping = name=="Mari" and rolePing(MARI_ROLE_IDS) or rolePing(JESTER_ROLE_IDS)

	sendWebhook({
		content = ping,
		embeds = {{
			title = title,
			color = name=="Mari" and 0xFF82AB or 0xA352FF,
			fields = {
				{ name="Account", value=player.Name.."\nUptime: "..formatUptime(), inline=false },
				{ name="Time", value="<t:"..now..":F> (<t:"..now..":R>)", inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false }
			},
			footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})
end

TextChatService.OnIncomingMessage = function(msg)
	if not macroRunning or not msg.Text then return end
	local t = msg.Text:lower()
	if t:find("mari") and t:find("arrived") then sendMerchant("Mari") end
	if t:find("jester") and t:find("arrived") then sendMerchant("Jester") end
end

-- ================= HOURLY STATS =================
local function sendHourlyStats()
	local lines = {}
	table.insert(lines, "**Hourly Stats**")
	table.insert(lines, "Uptime: "..formatUptime())
	table.insert(lines, "Total: "..totalHourly)
	for k,v in pairs(hourlyStats) do
		local pct = totalHourly > 0 and math.floor((v/totalHourly)*1000)/10 or 0
		table.insert(lines, k..": "..v.." ("..pct.."%)")
	end

	table.insert(lines, "\n**All-Time Stats**")
	table.insert(lines, "Total: "..totalAllTime)
	for k,v in pairs(allTimeStats) do
		local pct = totalAllTime > 0 and math.floor((v/totalAllTime)*1000)/10 or 0
		table.insert(lines, k..": "..v.." ("..pct.."%)")
	end

	sendWebhook({
		embeds = {{
			title=":bar_chart: Biome Statistics",
			description=table.concat(lines, "\n"),
			color=0x3498DB,
			footer={ text="DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})

	hourlyStats = {}
	totalHourly = 0
end

-- ================= LOOP =================
task.spawn(function()
	while true do
		detectBiome()
		if os.time() - lastHourTick >= 3600 then
			lastHourTick = os.time()
			sendHourlyStats()
		end
		task.wait(1.5)
	end
end)

-- ================= UI (REVERTED SIZE) =================
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "MobileMacroUI"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromScale(0.5,0.2)
frame.Position = UDim2.fromScale(0.25,0.7)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0.15,0)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.fromScale(1,0.3)
title.BackgroundTransparency = 1
title.Text = "DroidScope"
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1,1,1)

local function makeBtn(text,pos,color,cb)
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

makeBtn("START", UDim2.fromScale(0.03,0.5), Color3.fromRGB(46,204,113), function()
	if macroRunning then return end
	macroRunning = true
	sessionStart = os.time()
	sendStatus(true)
end)

makeBtn("STOP", UDim2.fromScale(0.52,0.5), Color3.fromRGB(231,76,60), function()
	if not macroRunning then return end
	macroRunning = false
	sendStatus(false)
end)

-- ================= DRAG =================
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=true; dragStart=i.Position; startPos=frame.Position
	end
end)
frame.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end)

-- ================= ANTI-AFK =================
player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)
