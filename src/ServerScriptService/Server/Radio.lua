--!nonstrict
--[[
	Radio (servidor): la radio del local, sobre el mostrador (parte con el tag "Radio"). Solo apaga o prende la música de
	fondo (la distorsionada de siempre): E la apaga y vuelve a prenderla. R cambia de estación: las estaciones premium
	(Config.Radio.Estaciones con Premium = true) las puede poner quien compró el Pase de Radio en la tienda.
	El estado vive en el atributo "RadioEstacion" de Workspace (0 = apagada, 1 = suena): el cliente lo lee y AudioManager
	sube o baja la capa de música.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Persistencia = require(script.Parent.Persistencia)
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
	local texto = n == 0 and "Radio apagada." or (#cfg.Estaciones > 1 and "Radio: " .. cfg.Estaciones[n].Nombre .. "." or "Radio prendida.")
	if quien then
		Net.avisoATodos(quien.DisplayName .. " — " .. texto)
	end
end

-- R: pasa a la estación siguiente. Las premium solo las puede elegir quien compró el pase; el cambio lo escucha todo el servidor.
local function cambiarEstacion(jugador: Player)
	if not Persistencia.tieneCompra(jugador, "paseradio") then
		Net.aviso(jugador, "Las estaciones extra son del Pase de Radio (tienda: tecla B).")
		return
	end
	local base = estacion() == 0 and ultima or estacion()
	poner(base % #cfg.Estaciones + 1, jugador)
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
			Prompts.crear(parte, {
				clave = "radioEstacion",
				accion = "Cambiar estación",
				objeto = "Radio",
				distancia = 6,
				tecla = Enum.KeyCode.R,
				offset = Vector2.new(0, 70),
				alActivar = cambiarEstacion,
			})
		end
	end
end

return Radio
