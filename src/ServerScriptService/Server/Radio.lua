--!nonstrict
--[[
	Radio (servidor): la radio del local, sobre el mostrador (parte con el tag "Radio").
	  E            cambia a la estación siguiente (cada una es un tipo de música: Config.Radio.Estaciones)
	  R (mantener) apaga la radio o la vuelve a prender en la última estación
	El estado vive en el atributo "RadioEstacion" de Workspace (0 = apagada): el cliente lo lee y AudioManager suena
	la música de fondo que corresponde.
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
	local texto = n == 0 and "Radio apagada." or ("Radio: " .. cfg.Estaciones[n].Nombre .. ".")
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
				accion = "Cambiar de estación",
				objeto = "Radio",
				distancia = 6,
				alActivar = function(jugador)
					local actual = estacion()
					-- Apagada: E la prende en la última estación; si no, pasa a la siguiente (y después de la última, a la primera).
					poner(actual == 0 and ultima or (actual % #cfg.Estaciones) + 1, jugador)
				end,
			})
			Prompts.crear(parte, {
				clave = "radioApagar",
				accion = "Apagar / prender",
				objeto = "Radio",
				hold = 0.5,
				distancia = 6,
				tecla = Enum.KeyCode.R,
				offset = Vector2.new(0, -100),
				alActivar = function(jugador)
					poner(estacion() == 0 and ultima or 0, jugador)
				end,
			})
		end
	end
end

return Radio
