--!nonstrict
--[[
	Insignias (servidor): logros del juego. Se anotan en el perfil (Persistencia) y, si la insignia ya está creada en
	Roblox (Config.Insignias.Ids), se le otorga al jugador con BadgeService.
	  - PRIMER_TURNO       sobrevivir la noche 1 (modo Historia)
	  - NOCHE_5            llegar a la noche 5
	  - FINAL_REBOBINAR / FINAL_DEVOLVER / FINAL_MIRAR   uno por cada final
	  - TODOS_LOS_FINALES  los tres finales
	  - SIN_FIN_5 / SIN_FIN_10   sobrevivir 5 / 10 noches seguidas en el modo Sin fin

	Los que están en la partida cuando pasa el hecho la reciben todos (el equipo juega junto).
	  Insignias.otorgar(jugador, clave) -> true si era nueva
	  Insignias.otorgarATodos(clave)
	  Insignias.alcanzarFinal(id)       los finales: llamado por EndingSystem después de Persistencia.registrarFinal
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local NightManager = require(script.Parent.NightManager)
local Persistencia = require(script.Parent.Persistencia)

local Insignias = {}

local FINALES = { "REBOBINAR", "DEVOLVER", "MIRAR" }
local porClave = {}
for _, insignia in Catalogo.Insignias do
	porClave[insignia.clave] = insignia
end

-- Pide la insignia de Roblox (no frena nada si falla: en Studio o sin permisos solo avisa una vez).
local function otorgarEnRoblox(jugador: Player, id: number)
	local ok, err = pcall(function()
		BadgeService:AwardBadge(jugador.UserId, id)
	end)
	if not ok then
		warn("[Insignias] No se pudo otorgar la insignia " .. id .. ": " .. tostring(err))
	end
end

function Insignias.otorgar(jugador: Player, clave: string): boolean
	local insignia = porClave[clave]
	if not insignia then
		warn("[Insignias] Insignia desconocida: " .. tostring(clave))
		return false
	end
	if not Persistencia.marcarInsignia(jugador, clave) then
		return false -- ya la tenía (o su perfil todavía no cargó)
	end
	-- El aviso en pantalla lo muestra Roblox con el emblema (BadgeService); acá no se escribe ningún texto.
	local id = Config.Insignias.Ids[clave]
	if id and id ~= 0 then
		task.spawn(otorgarEnRoblox, jugador, id)
	end
	return true
end

function Insignias.otorgarATodos(clave: string)
	for _, jugador in Players:GetPlayers() do
		Insignias.otorgar(jugador, clave)
	end
end

function Insignias.alcanzarFinal(id: string)
	for _, jugador in Players:GetPlayers() do
		Insignias.otorgar(jugador, "FINAL_" .. id)
		if Persistencia.tieneFinales(jugador, FINALES) then
			Insignias.otorgar(jugador, "TODOS_LOS_FINALES")
		end
	end
end

function Insignias.init()
	NightManager.suscribir("NOCHE_INICIA", function(datos)
		if NightManager.modo() == "historia" and datos.noche == 5 then
			Insignias.otorgarATodos("NOCHE_5")
		end
	end)
	NightManager.suscribir("NOCHE_TERMINA", function(datos)
		if datos.fracaso or datos.final then
			return
		end
		if datos.modo == "sinfin" then
			if datos.noche >= 5 then
				Insignias.otorgarATodos("SIN_FIN_5")
			end
			if datos.noche >= 10 then
				Insignias.otorgarATodos("SIN_FIN_10")
			end
		elseif datos.noche == 1 then
			Insignias.otorgarATodos("PRIMER_TURNO")
		end
	end)
end

return Insignias
