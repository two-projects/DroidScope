-- ================= CONFIG =================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1440713503295148104/eTKQ8_1mYq0f42WwduNoo7F5d2WEWZGj4ei8joz1il--JpIlWjRUsnJ0PPRaRBAwPP5r"
local PRIVATE_SERVER = "https://www.roblox.com/share?code=aad142168d2e0c419085cc0679eb2ef3&type=Server"

local JESTER_ROLE = "1451885446937182380"
local MARI_ROLE   = "1451885483939463229"

local SAVE_FILE = "DroidScope_BiomeStats.json"

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
local sessionTime = nil
local hourStart = nil

-- session stats (hourly)
local biomeStats = {}
local totalBiomes = 0

-- lifetime stats (saved)
local lifetimeStats = {}

-- ================= SAVE / LOAD =================
local function loadStats()
	if readfile and isfile and isfile(SAVE_FILE) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(SAVE_FILE))
		end)
		if ok and type(data) == "table" then
			lifetimeStats = data
		end
	end
end

local function saveStats()
	if writefile then
		writefile(SAVE_FILE, HttpService:JSONEncode(lifetimeStats))
	end
end

loadStats()

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

-- ================= WEBHOOK =================
local function sendWebhook(payload)
	HttpRequest({
		Url = WEBHOOK_URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode(payload)
	})
end

-- ================= STATUS EMBED =================
local function sendStatusEmbed(started)
	local title = started
		and ":bar_chart: Status Update: DroidScope Started"
		or  ":bar_chart: Status Update: DroidScope Stopped"

	sendWebhook({
		embeds = {{
			title = title,
			color = 0x3498DB,
			fields = {{
				name = "Session",
				value = "<t:"..sessionTime..":F> (<t:"..sessionTime..":R>)",
				inline = false
			}},
			footer = { text = "DroidScope | Beta v1.0.1 (bytetwo ver)" }
		}}
	})
end

-- ================= BIOME EMBED =================
local function sendBiomeEmbed(biome, data, state)
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
			thumbnail = { url = data.thumb },
			footer = { text = "DroidScope | Beta v1.0.1 (bytetwo ver)" }
		}}
	})
end

-- ================= HOURLY STATS =================
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
			description =
				"Total Biomes: **"..totalBiomes.."**\n\n"..table.concat(lines, "\n"),
			footer = { text = "DroidScope | Beta v1.0.1 (bytetwo ver)" }
		}}
	})

	biomeStats = {}
	totalBiomes = 0
	hourStart = os.time()
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
					sendBiomeEmbed(lastBiome, BIOME_DATA[lastBiome], "Ended")
				end

				lastBiome = biome

				if not data.never then
					sendBiomeEmbed(biome, data, "Started")

					-- hourly stats
					biomeStats[biome] = (biomeStats[biome] or 0) + 1
					totalBiomes += 1

					-- lifetime stats
					lifetimeStats[biome] = (lifetimeStats[biome] or 0) + 1
					saveStats()
				end
			end
		end
	end
end

-- ================= MERCHANT =================
local function sendMerchant(name)
	local now = os.time()
	local title, role, color =
		name=="Jester"
		and ":black_joker: Jester Has Arrived!"
		or  ":shopping_bags: Mari Has Arrived!",
		name=="Jester" and JESTER_ROLE or MARI_ROLE,
		name=="Jester" and 0xA352FF or 0xFF82AB

	sendWebhook({
		content = "<@&"..role..">",
		embeds = {{
			title = title,
			color = color,
			fields = {
				{ name="Account", value=player.Name, inline=false },
				{ name="\u{200B}", value="<t:"..now..":F> (<t:"..now..":R>)", inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false }
			},
			footer = { text = "DroidScope | Beta v1.0.1 (bytetwo ver)" }
		}}
	})
end

TextChatService.OnIncomingMessage = function(msg)
	if not macroRunning or not msg.Text then return end
	local t = msg.Text:lower()
	if t:find("jester") and t:find("arrived") then sendMerchant("Jester") end
	if t:find("mari") and t:find("arrived") then sendMerchant("Mari") end
end

-- ================= LOOPS =================
task.spawn(function()
	while true do
		if macroRunning then
			detectBiome()
			if os.time() - hourStart >= 3600 then
				sendHourlyStats()
				saveStats()
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
frame.Size = UDim2.fromScale(0.5,0.2)
frame.Position = UDim2.fromScale(0.25,0.7)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
Instance.new("UICorner", frame).CornerRadius = UDim.new(0.15,0)

local dragging, dragStart, startPos

frame.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=true
		dragStart=i.Position
		startPos=frame.Position
	end
end)

frame.InputChanged:Connect(function(i)
	if dragging then
		local delta=i.Position-dragStart
		frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=false
	end
end)

local function button(txt,pos,col,cb)
	local b=Instance.new("TextButton",frame)
	b.Size=UDim2.fromScale(0.45,0.4)
	b.Position=pos
	b.Text=txt
	b.TextScaled=true
	b.Font=Enum.Font.GothamBold
	b.BackgroundColor3=col
	b.TextColor3=Color3.new(1,1,1)
	Instance.new("UICorner",b).CornerRadius=UDim.new(0.2,0)
	b.Activated:Connect(cb)
end

button("START",UDim2.fromScale(0.03,0.5),Color3.fromRGB(46,204,113),function()
	if macroRunning then return end
	macroRunning=true
	sessionTime=os.time()
	hourStart=sessionTime
	biomeStats={}
	totalBiomes=0
	sendStatusEmbed(true)
end)

button("STOP",UDim2.fromScale(0.52,0.5),Color3.fromRGB(231,76,60),function()
	if not macroRunning then return end
	macroRunning=false
	saveStats()
	sendStatusEmbed(false)
end)
