--!nonstrict
--[[
	JugadorLocal (cliente): cámara en primera persona y limpieza de la interfaz de Roblox
	(el juego usa interfaz diegética: sin lista de jugadores, mochila ni barra de vida).
	El chat se deja activo para coordinarse en cooperativo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local JugadorLocal = {}

local function ocultarInterfazRoblox()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
			-- No se puede reiniciar el personaje (menú de Roblox, tecla de reset): el jugador que cae queda fuera de la noche.
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

-- Le avisa al servidor hacia dónde apunta la cámara: así decide si el Socio está siendo mirado.
local function informarMirada()
	local remoto = Net.obtener("LookReport")
	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado < 1 / Config.Socio.LookReportHz then
			return
		end
		acumulado = 0
		local camara = workspace.CurrentCamera
		if camara then
			remoto:FireServer(camara.CFrame)
		end
	end)
end

function JugadorLocal.init()
	local jugador = Players.LocalPlayer
	informarMirada()
	if Config.Jugador.PrimeraPersona then
		jugador.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	local camara = workspace.CurrentCamera
	if camara then
		camara.FieldOfView = Config.Jugador.CamaraFOV
	end
	task.spawn(ocultarInterfazRoblox)
end

return JugadorLocal
