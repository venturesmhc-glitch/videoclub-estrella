--!strict
--[[
	Jugadores (servidor): parámetros del personaje (velocidad, salto) tomados de Config.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Jugadores = {}

local function configurarPersonaje(personaje: Model)
	local humanoide = personaje:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoide then
		return
	end
	humanoide.WalkSpeed = Config.Jugador.VelocidadCaminar
	humanoide.UseJumpPower = false
	humanoide.JumpHeight = Config.Jugador.AlturaSalto
end

local function alEntrar(jugador: Player)
	jugador.CharacterAdded:Connect(configurarPersonaje)
	if jugador.Character then
		task.spawn(configurarPersonaje, jugador.Character)
	end
end

function Jugadores.init()
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
end

return Jugadores
