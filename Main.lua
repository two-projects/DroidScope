-- ================= CONFIG =================
local WEBHOOK_URLS = {
	"https://discord.com/api/webhooks/1467670290971492373/epApIOFGz9F5An4yhUl_3sXHSW8dcEvj9D9pC3Q1WFNjhsZlizTVf5TpkVaWs49G_sZL"
}
local BIOME_ONLY_WEBHOOK = "https://discord.com/api/webhooks/1469715436273930323/e8TOg34wN3SKFafh1J6hyPVdhawdXw2VhCmLaLLMVI6ZsotSt1TFZCgxcfpbu1DOXRhd"
local MERCHANT_WEBHOOK = "https://discord.com/api/webhooks/1470426996289831014/sisMXXUCmNo8hglEyuz8REqmOlTHhuatq_ga9InF-NYHHKtje0roebpYaLir8muF5255"

local PRIVATE_SERVER = "https://www.roblox.com/share?code=aad142168d2e0c419085cc0679eb2ef3&type=Server"
local JESTER_ROLES = { "1467788391075545254" }
local MARI_ROLES   = { "1467788352462913669" } 
local VERSION = "Mobile Macro"
local DEFAULT_THUMB = "https://i.ibb.co/S7X9mR6X/image-041fa2.png"

-- ================= SERVICES =================
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local HttpRequest = http and http.request or http_request or request or (syn and syn.request)

-- ================= ANTI-AFK =================
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    task.wait(0.1)
    VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
end)

-- ================= ULTRA FPS BOOSTER =================
local function boostFPS()
    local w, l, t = Workspace, Lighting, Workspace.Terrain
    pcall(function()
        sethiddenproperty(l,"Technology",2)
        sethiddenproperty(t,"Decoration",false)
    end)
    t.WaterWaveSize = 0; t.WaterWaveSpeed = 0; t.WaterReflectance = 0; t.WaterTransparency = 0
    l.GlobalShadows = false; l.FogEnd = 9e9; l.Brightness = 0
    settings().Rendering.QualityLevel = "Level01"
end

-- ================= STATE & STATS =================
local macroRunning = false
local lastBiome = nil
local sessionStart = 0
local hourStart = 0
local biomeCounts = {} 
local totalSpecialBiomesInHour = 0
local merchantCooldown = { Jester = 0, Mari = 0 }
local MERCHANT_CD = 25

local function getPlainUptime()
	local diff = os.time() - sessionStart
	local d = math.floor(diff / 86400); local h = math.floor((diff % 86400) / 3600)
	local m = math.floor((diff % 3600) / 60); local s = diff % 60
	return string.format("%s%s%s%ss", d>0 and d.."d " or "", (h>0 or d>0) and h.."hr " or "", (m>0 or h>0 or d>0) and m.."m " or "", s)
end

-- ================= WEBHOOK ROUTER =================
local function sendWebhook(payload, mode)
    local targets = {}
    if mode == "BIOME" then
        for _, url in ipairs(WEBHOOK_URLS) do table.insert(targets, url) end
        table.insert(targets, BIOME_ONLY_WEBHOOK)
    elseif mode == "MERCHANT" then
        table.insert(targets, MERCHANT_WEBHOOK)
    else
        targets = WEBHOOK_URLS
    end

	for _, url in ipairs(targets) do
		pcall(function() HttpRequest({Url = url, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode(payload)}) end)
	end
end

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

-- ================= BIOME DETECTION =================
LogService.MessageOut:Connect(function(message)
    if not macroRunning then return end
    local biome = message:match('\"largeImage\":{.-%\"hoverText\":%\"(.-)%\"')
    
    if biome then
        biome = biome:upper()
        local data = BIOME_DATA[biome]
        if data and biome ~= lastBiome then
            if lastBiome and BIOME_DATA[lastBiome] and not BIOME_DATA[lastBiome].never then
                sendWebhook({embeds={{title="Biome Ended - "..lastBiome, color=BIOME_DATA[lastBiome].color, thumbnail={url=BIOME_DATA[lastBiome].thumb or DEFAULT_THUMB}, fields={{name="Account", value=player.Name, inline=false}, {name="Uptime", value=getPlainUptime(), inline=false}}, footer={text=VERSION}}}}, "BIOME")
            end
            lastBiome = biome
            if not data.never then
                biomeCounts[biome] = (biomeCounts[biome] or 0) + 1
                totalSpecialBiomesInHour = totalSpecialBiomesInHour + 1
                local now = os.time()
                sendWebhook({content=data.everyone and "@everyone" or nil, embeds={{title="Biome Started - "..biome, color=data.color, thumbnail={url=data.thumb or DEFAULT_THUMB}, fields={{name="Account", value=player.Name, inline=false}, {name="Time", value="<t:"..now..":F> (<t:"..now..":R>)", inline=false}, {name="Private Server", value=PRIVATE_SERVER, inline=false}}, footer={text=VERSION}}}}, "BIOME")
            end
        end
    end
end)

-- ================= CHAT LISTENER (RESTORED MERCHANT) =================
TextChatService.OnIncomingMessage = function(msg)
	if not macroRunning or not msg.Text then return end
    if msg.TextSource ~= nil then return end 

	local t = msg.Text:lower()
	local name = t:find("jester") and "Jester" or t:find("mari") and "Mari"
	if name and t:find("arrived") then
		local now = os.time()
		if now - merchantCooldown[name] < MERCHANT_CD then return end
		merchantCooldown[name] = now
        
        -- Formatting and Icons restored from older version
		local shortcode = name == "Jester" and ":black_joker:" or ":shopping_bags:"
		local img = name == "Jester" and "https://i.ibb.co/DDQTH1zj/image.png" or "https://i.ibb.co/QFVGQ4r3/image.png"

		sendWebhook({
            content = name=="Jester" and "<@&"..JESTER_ROLES[1]..">" or "<@&"..MARI_ROLES[1]..">", 
            embeds = {{
                title = shortcode .. " " .. name .. " Has Arrived!", 
                color = name == "Jester" and 0xA352FF or 0xFF82AB, 
                thumbnail = {url = img}, 
                fields = {
                    { name = "Account", value = player.Name, inline = false },
                    { name = "Time", value = "<t:"..now..":F> (<t:"..now..":R>)", inline = false },
                    { name = "Uptime", value = getPlainUptime(), inline = false },
                    { name = "Private Server", value = PRIVATE_SERVER, inline = false }
                },
                footer = { text = VERSION }
            }}
        }, "MERCHANT")
	end
end

-- ================= STATS LOOP =================
task.spawn(function()
	while true do
		if macroRunning and os.time() - hourStart >= 3600 then
			hourStart = os.time()
            local report = ""
            if totalSpecialBiomesInHour > 0 then
                for bName, count in pairs(biomeCounts) do
                    local perc = math.floor((count / totalSpecialBiomesInHour) * 100)
                    report = report .. string.format("**%s**: %d (%d%%)\n", bName, count, perc)
                end
            else
                report = "No special biomes detected this hour."
            end

            sendWebhook({embeds={{title=":bar_chart: Hourly Biome Statistics", color=0x3498DB, description = report, fields={{name="Uptime", value=getPlainUptime(), inline=true}}, footer={text=VERSION}}}})
            biomeCounts = {}; totalSpecialBiomesInHour = 0
		end
		task.wait(5)
	end
end)

-- ================= UI =================
local gui = Instance.new("ScreenGui", player.PlayerGui); gui.ResetOnSpawn = false; gui.Name = "DroidScope"
local frame = Instance.new("Frame", gui); frame.Size = UDim2.fromScale(0.42, 0.16); frame.Position = UDim2.fromScale(0.29, 0.75); frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Instance.new("UICorner", frame).CornerRadius = UDim.new(0.15, 0)
local title = Instance.new("TextLabel", frame); title.Size = UDim2.fromScale(1, 0.35); title.BackgroundTransparency = 1; title.Text = "DroidScope"; title.TextScaled = true; title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.new(1, 1, 1)

local function btn(text, pos, color, cb)
    local b = Instance.new("TextButton", frame); b.Size = UDim2.fromScale(0.45, 0.4); b.Position = pos; b.Text = text; b.TextScaled = true; b.Font = Enum.Font.GothamBold; b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0.2, 0); b.Activated:Connect(cb)
end

btn("START", UDim2.fromScale(0.03, 0.5), Color3.fromRGB(46, 204, 113), function()
    if macroRunning then return end
    macroRunning = true; boostFPS(); sessionStart = os.time(); hourStart = sessionStart; lastBiome = nil; biomeCounts = {}; totalSpecialBiomesInHour = 0
	sendWebhook({embeds={{title="DroidScope Started", color=0x3498DB, fields={{name="Account", value=player.Name, inline=false}}, footer={text=VERSION}}}})
end)

btn("STOP", UDim2.fromScale(0.52, 0.5), Color3.fromRGB(231, 76, 60), function() macroRunning = false end)

-- Draggable Logic
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging=true; dragStart=i.Position; startPos=frame.Position end end)
frame.InputChanged:Connect(function(i) if dragging then local d=i.Position-dragStart; frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
