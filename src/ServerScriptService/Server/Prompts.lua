--!nonstrict
--[[
	Prompts (servidor): utilidad para crear ProximityPrompts con limitador de frecuencia.
	No es un sistema (no tiene init): lo usan TaskSystem y CustomerSystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Prompts = {}

--- opciones: { clave, accion, objeto?, hold?, distancia?, tecla?, offset?, alActivar(jugador) }
function Prompts.crear(parte: BasePart, opciones)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = opciones.accion
	prompt.ObjectText = opciones.objeto or ""
	prompt.HoldDuration = opciones.hold or 0
	prompt.MaxActivationDistance = opciones.distancia or Config.Tareas.DistanciaPrompt
	prompt.RequiresLineOfSight = false
	if opciones.tecla then
		prompt.KeyboardKeyCode = opciones.tecla -- para una segunda acción en el mismo punto (por ejemplo R)
	end
	if opciones.offset then
		prompt.UIOffset = opciones.offset
	end
	prompt.Triggered:Connect(function(jugador)
		if Net.limitar(jugador, opciones.clave, 0.25) then
			opciones.alActivar(jugador)
		end
	end)
	prompt.Parent = parte
	return prompt
end

return Prompts
