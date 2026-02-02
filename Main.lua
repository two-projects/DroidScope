-- ======================================================
-- DroidScope | Beta v1.0.3 (bytetwo ver)
-- ======================================================

---------------- CONFIG ----------------
local WEBHOOK_URL = "https://discord.com/api/webhooks/1440713503295148104/eTKQ8_1mYq0f42WwduNoo7F5d2WEWZGj4ei8joz1il--JpIlWjRUsnJ0PPRaRBAwPP5r"
local PRIVATE_SERVER = "https://www.roblox.com/share?code=aad142168d2e0c419085cc0679eb2ef3&type=Server"

local JESTER_ROLE_ID = "1451885446937182380"
local MARI_ROLE_ID   = "1451885483939463229"

--------------------------------------

---------------- SERVICES ----------------
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

---------------- HTTP ----------------
local HttpRequest =
	http and http.request or
	http_request or
	request or
	(syn and syn.request)

assert(HttpRequest, "HTTP request not supported")

---------------- STATE ----------------
local macroRunning = false
local sessionStart = nil
local lastBiome = nil

local startTick = tick()

local statsHourly = {}
local statsAllTime = {}

---------------- BIOMES ----------------
local BIOME_DATA = {
	WINDY = { color = 0xFFFFFF, thumb = "https://maxstellar.github.io/biome_thumb/WINDY.png" },
	RAINY = { color = 0x55925F, thumb = "https://maxstellar.github.io/biome_thumb/RAINY.png" },
	SNOWY = { color = 0xFFFFFF, thumb = "https://maxstellar.github.io/biome_thumb/SNOWY.png" },
	["SAND STORM"] = { color = 0xFFA500, thumb = "https://maxstellar.github.io/biome_thumb/SAND%20STORM.png" },
	HELL = { color = 0xFB4F29, thumb = "https://maxstellar.github.io/biome_thumb/HELL.png" },
	STARFALL = { color = 0xFFFFFF, thumb = "https://maxstellar.github.io/biome_thumb/STARFALL.png" },
	CORRUPTION = { color = 0x800080, thumb = "https://maxstellar.github.io/biome_thumb/CORRUPTION.png" },
	NULL = { color = 0x808080, thumb = "https://maxstellar.github.io/biome_thumb/NULL.png" },

	HEAVEN = {
		color = 0xE7DC43, -- #e7dc43
		thumb = "https://maxstellar.github.io/biome_thumb/HEAVEN.png"
	},

	GLITCH = { color = 0xFF00FF, thumb = "https://maxstellar.github.io/biome_thumb/GLITCH.png", ping = "@everyone" },
	DREAMSPACE = { color = 0x00FFFF, thumb = "https://maxstellar.github.io/biome_thumb/DREAMSPACE.png", ping = "@everyone" },
	CYBERSPACE = { color = 0x00FF00, thumb = "https://maxstellar.github.io/biome_thumb/CYBERSPACE.png", ping = "@everyone" },

	NORMAL = { never = true }
}

---------------- UTIL ----------------
local function sendWebhook(payload)
	HttpRequest({
		Url = WEBHOOK_URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode(payload)
	})
end

local function fmtTime(t)
	return "<t:" .. t .. ":F> (<t:" .. t .. ":R>)"
end

local function getUptime()
	local sec = math.floor(tick() - startTick)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	return h .. "h " .. m .. "m"
end

---------------- STATUS ----------------
local function sendStatus(started)
	sendWebhook({
		embeds = {{
			title = started and "Status Update: DroidScope Started" or "Status Update: DroidScope Stopped",
			color = 0x3498DB,
			fields = {{
				name = "Session",
				value = fmtTime(sessionStart),
				inline = false
			}},
			footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})
end

---------------- BIOME ----------------
local function sendBiome(biome, data, state)
	local now = os.time()

	sendWebhook({
		content = data.ping,
		embeds = {{
			title = "Biome " .. state .. " - " .. biome,
			color = data.color,
			fields = {
				{ name = "Account", value = player.Name, inline = false },
				{ name = "Timestamp", value = fmtTime(now), inline = false },
				{ name = "Private Server", value = PRIVATE_SERVER, inline = false },
				{ name = "Status", value = state, inline = false }
			},
			thumbnail = { url = data.thumb },
			footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})
end

---------------- DETECTION ----------------
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

				statsHourly[biome] = (statsHourly[biome] or 0) + 1
				statsAllTime[biome] = (statsAllTime[biome] or 0) + 1

				if not data.never then
					sendBiome(biome, data, "Started")
				end
			end
		end
	end
end

---------------- HOURLY REPORT ----------------
task.spawn(function()
	while true do
		task.wait(3600)
		if not macroRunning then continue end

		local total = 0
		for _, v in pairs(statsHourly) do total += v end

		local lines = {}
		for biome, count in pairs(statsHourly) do
			local pct = math.floor((count / total) * 100)
			table.insert(lines, biome .. ": " .. count .. " (" .. pct .. "%)")
		end

		sendWebhook({
			embeds = {{
				title = "Hourly Biome Statistics",
				color = 0x95A5A6,
				fields = {
					{ name = "This Hour", value = table.concat(lines, "\n"), inline = false },
					{ name = "Uptime", value = getUptime(), inline = false }
				},
				footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
			}}
		)

		statsHourly = {}
	end
end)

---------------- LOOP ----------------
task.spawn(function()
	while true do
		detectBiome()
		task.wait(1.5)
	end
end)

---------------- ANTI AFK ----------------
local vu = game:GetService("VirtualUser")
player.Idled:Connect(function()
	vu:CaptureController()
	vu:ClickButton2(Vector2.new())
end)

---------------- UI ----------------
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromScale(0.35, 0.16)
frame.Position = UDim2.fromScale(0.33, 0.75)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0.15,0)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.fromScale(1,0.35)
title.BackgroundTransparency = 1
title.Text = "DroidScope"
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1,1,1)

local function btn(text, pos, col, cb)
	local b = Instance.new("TextButton", frame)
	b.Size = UDim2.fromScale(0.45,0.4)
	b.Position = pos
	b.Text = text
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.BackgroundColor3 = col
	b.TextColor3 = Color3.new(1,1,1)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0.2,0)
	b.Activated:Connect(cb)
end

btn("START", UDim2.fromScale(0.03,0.5), Color3.fromRGB(46,204,113), function()
	if macroRunning then return end
	macroRunning = true
	sessionStart = os.time()
	sendStatus(true)
end)

btn("STOP", UDim2.fromScale(0.52,0.5), Color3.fromRGB(231,76,60), function()
	if not macroRunning then return end
	macroRunning = false
	sendStatus(false)
end)

---------------- DRAG ----------------
local dragging, dragStart, startPos

frame.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = i.Position
		startPos = frame.Position
	end
end)

frame.InputChanged:Connect(function(i)
	if dragging then
		local d = i.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
