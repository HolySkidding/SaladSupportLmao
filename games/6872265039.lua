local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end
	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

for _, v in vape.Modules do
	if v.Category == 'Combat' or v.Category == 'Minigames' then
		vape:Remove(i)
	end
end

run(function()
	local Sprint
	local old
	local SprintSpeed = {Value = 21}
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				shared.sprintconn = true 
				task.spawn(function()
					while task.wait() do 
						repeat task.wait() until game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
						if shared.sprintconn then 
							game.Players.LocalPlayer:SetAttribute("Sprinting", true)
							game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = SprintSpeed.Value
							game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {FieldOfView = 120}):Play()
						end 
					end 
			    end)
			else 
				shared.sprintconn = false 
				game.Players.LocalPlayer:SetAttribute("Sprinting", false)
				game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = SprintSpeed.Value 
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {FieldOfView = 80}):Play()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
	SprintSpeed = Sprint:CreateSlider({
		Name = 'Sprint Speed',
		Function = function(val) end,
		Default = 21,
		Min = 1,
		Max = 30,
		Decimal = 10
	})
end)