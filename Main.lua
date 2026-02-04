-- ================= CONFIG =================
local WEBHOOK_URLS = {
	"https://discord.com/api/webhooks/1467670290971492373/epApIOFGz9F5An4yhUl_3sXHSW8dcEvj9D9pC3Q1WFNjhsZlizTVf5TpkVaWs49G_sZL"
}
local MERCHANT_WEBHOOK = "https://discord.com/api/webhooks/1467851474397561018/-XyREI978MEsyhKqnhEtPyRAsd-hOcB1OQmVyjIZ0FyV758JFv79ZTe3qL9RY129mbm_"
local PRIVATE_SERVER = "https://www.roblox.com/share?code=aad142168d2e0c419085cc0679eb2ef3&type=Server"
local JESTER_ROLES = { "1467788391075545254" }
local MARI_ROLES   = { "1467788352462913669" } 
local VERSION = "DroidScope | Beta v1.1.2 (Ultra FPS)"
local DEFAULT_THUMB = "https://i.ibb.co/S7X9mR6X/image-041fa2.png"

-- ================= SERVICES =================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- ================= ULTRA FPS BOOSTER =================
local function boostFPS()
    local decalsyeeted = true 
    local w = Workspace
    local l = Lighting
    local t = w.Terrain

    pcall(function()
        sethiddenproperty(l,"Technology",2)
        sethiddenproperty(t,"Decoration",false)
    end)
    
    t.WaterWaveSize = 0
    t.WaterWaveSpeed = 0
    t.WaterReflectance = 0
    t.WaterTransparency = 0
    l.GlobalShadows = false
    l.FogEnd = 9e9
    l.Brightness = 0
    settings().Rendering.QualityLevel = "Level01"

    local function stripObject(v)
        if v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = "Plastic"
            v.Reflectance = 0
        elseif (v:IsA("Decal") or v:IsA("Texture")) and decalsyeeted then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Lifetime = NumberRange.new(0)
        elseif v:IsA("Explosion") then
            v.BlastPressure = 1
            v.BlastRadius = 1
        elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("MeshPart") and decalsyeeted then
            v.Material = "Plastic"
            v.Reflectance = 0
            v.TextureID = "rbxassetid://10385902758728957"
        elseif v:IsA("SpecialMesh") and decalsyeeted then
            v.TextureId = 0
        elseif v:IsA("ShirtGraphic") and decalsyeeted then
            v.Graphic = 0
        elseif (v:IsA("Shirt") or v:IsA("Pants")) and decalsyeeted then
            v[v.ClassName.."Template"] = 0
        end
    end

    for _, v in pairs(w:GetDescendants()) do stripObject(v) end
    for _, e in pairs(l:GetChildren()) do
        if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
            e.Enabled = false
        end
    end

    w.DescendantAdded:Connect(function(v)
        task.wait()
        stripObject(v)
    end)
end

-- ================= STATE & UTILS =================
local macroRunning = false
local lastBiome = nil
local sessionStart = 0
local hourStart = 0
local merchantCooldown = { Jester = 0, Mari = 0 }
local MERCHANT_CD = 25

local HttpRequest = http and http.request or http_request or request or (syn and syn.request)

local function getPlainUptime()
	local diff = os.time() - sessionStart
	local d = math.floor(diff / 86400)
	local h = math.floor((diff % 86400) / 3600)
	local m = math.floor((diff % 3600) / 60)
	local s = diff % 60
	return string.format("%s%s%s%ss", d>0 and d.."d " or "", (h>0 or d>0) and h.."hr " or "", (m>0 or h>0 or d>0) and m.."m " or "", s)
end

-- ================= WEBHOOKS =================
local function sendWebhook(payload, customUrl)
	local urls = customUrl and {customUrl} or WEBHOOK_URLS
	for _, url in ipairs(urls) do
		HttpRequest({Url = url, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode(payload)})
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

-- ================= BIOME EMBED =================
local function sendBiomeEmbed(biome, data, state)
    local now = os.time()
    sendWebhook({
        content = data.everyone and "@everyone" or nil,
        embeds = {{
            title = "Biome " .. state .. " - " .. biome,
            color = data.color,
            thumbnail = { url = data.thumb or DEFAULT_THUMB },
            fields = {
                { name = "Account", value = player.Name, inline = false },
                { name = "Time", value = "<t:"..now..":F> (<t:"..now..":R>)", inline = false },
                { name = "Uptime", value = getPlainUptime(), inline = false },
                { name = "Private Server", value = PRIVATE_SERVER, inline = false },
                { name = "Status", value = state, inline = false }
            },
            footer = { text = VERSION }
        }}
    })
end

-- ================= DETECTION =================
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
				end
			end
		end
	end
end

TextChatService.OnIncomingMessage = function(msg)
	if not macroRunning or not msg.Text then return end
	local t = msg.Text:lower()
	local name = t:find("jester") and "Jester" or t:find("mari") and "Mari"
	if name and t:find("arrived") then
		local now = os.time()
		if now - merchantCooldown[name] < MERCHANT_CD then return end
		merchantCooldown[name] = now
		sendWebhook({
            content = name=="Jester" and "<@&"..JESTER_ROLES[1]..">" or "<@&"..MARI_ROLES[1]..">", 
            embeds = {{
                title = name .. " Has Arrived!", 
                color = 0xA352FF, 
                thumbnail = {url = "https://keylens-website.web.app/merchants/"..name..".png"}, 
                fields = {
                    { name = "Account", value = player.Name, inline = false },
                    { name = "Time", value = "<t:"..now..":F>", inline = false },
                    { name = "Uptime", value = getPlainUptime(), inline = false },
                    { name = "Private Server", value = PRIVATE_SERVER, inline = false }
                },
                footer = { text = VERSION }
            }}
        }, MERCHANT_WEBHOOK)
	end
end

task.spawn(function() while true do if macroRunning then detectBiome() end task.wait(1.5) end end)
player.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)

-- ================= UI =================
local gui = Instance.new("ScreenGui", player.PlayerGui); gui.ResetOnSpawn = false
local frame = Instance.new("Frame", gui); frame.Size = UDim2.fromScale(0.42,0.16); frame.Position = UDim2.fromScale(0.29,0.75); frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
Instance.new("UICorner", frame).CornerRadius = UDim.new(0.15,0)
local title = Instance.new("TextLabel", frame); title.Size = UDim2.fromScale(1,0.35); title.BackgroundTransparency = 1; title.Text = "DroidScope Ultra"; title.TextScaled = true; title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.new(1,1,1)

local function btn(text,pos,color,cb)
	local b = Instance.new("TextButton", frame); b.Size = UDim2.fromScale(0.45,0.4); b.Position = pos; b.Text = text; b.TextScaled = true; b.Font = Enum.Font.GothamBold; b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1,1,1)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0.2,0); b.Activated:Connect(cb)
end

btn("START", UDim2.fromScale(0.03,0.5), Color3.fromRGB(46,204,113), function()
	if macroRunning then return end
	macroRunning = true
	boostFPS()
	sessionStart = os.time(); lastBiome = nil
	sendWebhook({
        embeds = {{
            title = ":bar_chart: DroidScope Started", 
            color = 0x3498DB, 
            fields = {
                { name = "Session Start", value = "<t:"..sessionStart..":F>", inline = false },
                { name = "Uptime", value = "0s", inline = false }
            }, 
            footer = { text = VERSION }
        }}
    })
end)

btn("STOP", UDim2.fromScale(0.52,0.5), Color3.fromRGB(231,76,60), function()
	macroRunning = false
end)

local dragging, dragStart, startPos
frame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging=true; dragStart=i.Position; startPos=frame.Position end end)
frame.InputChanged:Connect(function(i) if dragging then local d=i.Position-dragStart; frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
