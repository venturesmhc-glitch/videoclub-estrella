--!nonstrict
--[[
	Radio (servidor): la radio del local, sobre el mostrador (parte con el tag "Radio"). Solo apaga o prende la música de
	fondo (la distorsionada de siempre): E la apaga y vuelve a prenderla.
	El estado vive en el atributo "RadioEstacion" de Workspace (0 = apagada, 1 = suena): el cliente lo lee y AudioManager
	sube o baja la capa de música.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Prompts = require(script.Parent.Prompts)

local Radio = {}

local cfg = Config.Radio
local ultima = cfg.Inicial -- última estación encendida (a la que vuelve al prender)

local function estacion(): number
	return workspace:GetAttribute("RadioEstacion") or 0
end

local function poner(n: number, quien: Player?)
	workspace:SetAttribute("RadioEstacion", n)
	if n > 0 then
		ultima = n
	end
	local texto = n == 0 and "Radio apagada." or "Radio prendida."
	if quien then
		Net.avisoATodos(quien.DisplayName .. " — " .. texto)
	end
end

function Radio.init()
	workspace:SetAttribute("RadioEstacion", cfg.Inicial)
	for _, parte in CollectionService:GetTagged("Radio") do
		if parte:IsA("BasePart") then
			Prompts.crear(parte, {
				clave = "radio",
				accion = "Apagar / prender",
				objeto = "Radio",
				distancia = 6,
				alActivar = function(jugador)
					poner(estacion() == 0 and ultima or 0, jugador)
				end,
			})
		end
	end
end

return Radio
