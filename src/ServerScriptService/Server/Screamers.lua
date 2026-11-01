--!nonstrict
--[[
	Screamers (servidor): sustos fuertes a pantalla completa (la cara de la criatura y un grito). Los pinta el cliente
	(Client/Screamers); acá se decide cuándo y a quién:
	  - los automáticos de la noche: evento SCREAMER de NightData;
	  - el botón "Asustar a todos" de la tienda (lo dispara Tienda).
	Los espectadores no reciben screamers (ya ven el mundo distorsionado).

	  Screamers.disparar(filtro?)   -- filtro(jugador) -> boolean; sin filtro, a todos los que siguen en la noche
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Fantasmas = require(script.Parent.Fantasmas)
local NightManager = require(script.Parent.NightManager)

local Screamers = {}

local rng = Random.new()
local ultimoAutomatico = -math.huge

function Screamers.disparar(filtro: ((Player) -> boolean)?)
	local variante = rng:NextInteger(1, #Config.Screamer.Sonidos)
	for _, jugador in Players:GetPlayers() do
		if not Fantasmas.esFantasma(jugador) and (not filtro or filtro(jugador)) then
			Net.obtener("Screamer"):FireClient(jugador, { variante = variante })
		end
	end
end

function Screamers.init()
	NightManager.suscribir("SCREAMER", function()
		if NightManager.obtenerEstado().fase ~= "turno" then
			return
		end
		if os.clock() - ultimoAutomatico < Config.Screamer.EntreAutomaticosSeg then
			return
		end
		ultimoAutomatico = os.clock()
		Screamers.disparar()
	end)
end

return Screamers
