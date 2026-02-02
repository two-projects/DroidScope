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
local player = Players.LocalPlayer

-- ================= HTTP =================
local HttpRequest =
	http and http.request
	or http_request
	or request
	or (syn and syn.request)
assert(HttpRequest, "Executor does not support http requests")

-- ================= STATE =================
local macroRunning = false
local sessionStart = 0
local lastBiome = nil

local hourlyStats = {}
local alltimeStats = {}
local scriptStart = os.time()
local lastHourlyTick = os.time()

-- ================= BIOME DATA =================
local BIOME_DATA = {
	WINDY = { thumb="https://maxstellar.github.io/biome_thumb/WINDY.png" },
	RAINY = { thumb="https://maxstellar.github.io/biome_thumb/RAINY.png" },
	SNOWY = { thumb="https://maxstellar.github.io/biome_thumb/SNOWY.png" },
	["SAND STORM"] = { thumb="https://maxstellar.github.io/biome_thumb/SAND%20STORM.png" },
	HELL = { thumb="https://maxstellar.github.io/biome_thumb/HELL.png" },
	STARFALL = { thumb="https://maxstellar.github.io/biome_thumb/STARFALL.png" },
	CORRUPTION = { thumb="https://maxstellar.github.io/biome_thumb/CORRUPTION.png" },
	NULL = { thumb="https://maxstellar.github.io/biome_thumb/NULL.png" },
	HEAVEN = { thumb="https://maxstellar.github.io/biome_thumb/HEAVEN.png" },

	GLITCHED = { thumb="https://i.postimg.cc/mDzwFfX1/GLITCHED.png", everyone=true },
	DREAMSPACE = { thumb="https://maxstellar.github.io/biome_thumb/DREAMSPACE.png", everyone=true },
	CYBERSPACE = { thumb="https://raw.githubusercontent.com/cresqnt-sys/MultiScope/refs/heads/main/assets/cyberspace.png", everyone=true },
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

local function formatRoles(ids)
	local t = {}
	for _, id in ipairs(ids) do
		table.insert(t, "<@&"..id..">")
	end
	return table.concat(t, " ")
end

local function uptime()
	local diff = os.time() - scriptStart
	local h = math.floor(diff/3600)
	local m = math.floor((diff%3600)/60)
	return h.."h "..m.."m"
end

local function incStat(tbl, biome)
	tbl[biome] = (tbl[biome] or 0) + 1
end

local function statText(tbl)
	local total = 0
	for _, v in pairs(tbl) do total += v end
	local lines = {}
	for k, v in pairs(tbl) do
		local pct = total > 0 and math.floor((v/total)*100) or 0
		table.insert(lines, k..": "..v.." ("..pct.."%)")
	end
	return table.concat(lines, "\n")
end

-- ================= BIOME WEBHOOK =================
local function sendBiome(biome, state)
	local data = BIOME_DATA[biome]
	if not data then return end

	incStat(hourlyStats, biome)
	incStat(alltimeStats, biome)

	sendWebhook({
		content = data.everyone and "@everyone" or nil,
		embeds = {{
			title = "Biome "..state.." - "..biome,
			fields = {
				{ name="Account", value=player.Name.."\nUptime: "..uptime(), inline=false },
				{ name="Time", value="<t:"..os.time()..":F> (<t:"..os.time()..":R>)", inline=false },
				{ name="Private Server", value=PRIVATE_SERVER, inline=false },
				{ name="Status", value=state, inline=false }
			},
			thumbnail = { url = data.thumb },
			footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})
end

-- ================= HOURLY STATS =================
local function sendHourly()
	sendWebhook({
		embeds = {{
			title = "📊 Hourly Biome Stats",
			description =
				"**Uptime:** "..uptime().."\n\n" ..
				"**Hourly:**\n"..(statText(hourlyStats) ~= "" and statText(hourlyStats) or "No data").."\n\n" ..
				"**All-time:**\n"..(statText(alltimeStats) ~= "" and statText(alltimeStats) or "No data"),
			footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
		}}
	})
	hourlyStats = {}
end

-- ================= BIOME DETECT =================
task.spawn(function()
	while true do
		if macroRunning then
			for _, v in ipairs(player.PlayerGui:GetDescendants()) do
				if v:IsA("TextLabel") then
					local biome = v.Text:match("^%[ ([%w%s]+) %]$")
					if biome and biome ~= lastBiome and BIOME_DATA[biome] then
						if lastBiome then
							sendBiome(lastBiome, "Ended")
						end
						lastBiome = biome
						sendBiome(biome, "Started")
					end
				end
			end
		end

		if os.time() - lastHourlyTick >= 3600 then
			lastHourlyTick = os.time()
			sendHourly()
		end

		task.wait(2)
	end
end)

-- ================= CHAT MERCHANT =================
TextChatService.OnIncomingMessage = function(msg)
	if not macroRunning or not msg.Text then return end
	local t = msg.Text:lower()

	if t:find("jester") and t:find("arrived") then
		sendWebhook({
			content = formatRoles(JESTER_ROLE_IDS),
			embeds = {{
				title = ":black_joker: Jester Has Arrived!",
				fields = {
					{ name="Account", value=player.Name.."\nUptime: "..uptime(), inline=false },
					{ name="Time", value="<t:"..os.time()..":F> (<t:"..os.time()..":R>)", inline=false },
					{ name="Private Server", value=PRIVATE_SERVER, inline=false }
				},
				footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
			}}
		})
	end

	if t:find("mari") and t:find("arrived") then
		sendWebhook({
			content = formatRoles(MARI_ROLE_IDS),
			embeds = {{
				title = ":shopping_bags: Mari Has Arrived!",
				fields = {
					{ name="Account", value=player.Name.."\nUptime: "..uptime(), inline=false },
					{ name="Time", value="<t:"..os.time()..":F> (<t:"..os.time()..":R>)", inline=false },
					{ name="Private Server", value=PRIVATE_SERVER, inline=false }
				},
				footer = { text = "DroidScope | Beta v1.0.3 (bytetwo ver)" }
			}}
		})
	end
end

-- ================= UI (SMALL + DRAGGABLE) =================
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromScale(0.35, 0.14)
frame.Position = UDim2.fromScale(0.33, 0.75)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.Active = true
frame.Draggable = true

local function button(txt, pos, col, cb)
	local b = Instance.new("TextButton", frame)
	b.Size = UDim2.fromScale(0.45, 0.5)
	b.Position = pos
	b.Text = txt
	b.BackgroundColor3 = col
	b.TextScaled = true
	b.TextColor3 = Color3.new(1,1,1)
	b.Activated:Connect(cb)
end

button("START", UDim2.fromScale(0.03,0.25), Color3.fromRGB(46,204,113), function()
	if macroRunning then return end
	macroRunning = true
	sessionStart = os.time()
end)

button("STOP", UDim2.fromScale(0.52,0.25), Color3.fromRGB(231,76,60), function()
	macroRunning = false
end)
