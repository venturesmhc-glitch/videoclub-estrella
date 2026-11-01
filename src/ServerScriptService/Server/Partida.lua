--!nonstrict
--[[
	Partida (servidor): menú de inicio y sala de espera.
	El turno no arranca solo: alguien tiene que elegir en el menú.
	  fase "menu"    nadie eligió todavía
	  fase "lobby"   se eligió multijugador: se espera a los compañeros; el anfitrión aprieta "Empezar turno"
	  fase "jugando" el turno está en marcha (quien entra después se suma directo)
	"Un jugador" arranca de inmediato. El estado se manda a todos por el remote PartidaState.
	El cliente (MenuUI) solo muestra: toda decisión se valida acá.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)

local Partida = {}

local estado = { fase = "menu", modo = nil, anfitrion = nil }

local function nombres(): { string }
	local lista = {}
	for _, j in Players:GetPlayers() do
		table.insert(lista, j.DisplayName)
	end
	return lista
end

local function paquete()
	return {
		fase = estado.fase,
		modo = estado.modo,
		anfitrion = estado.anfitrion and estado.anfitrion.DisplayName or nil,
		anfitrionId = estado.anfitrion and estado.anfitrion.UserId or nil,
		jugadores = nombres(),
		maximo = Config.Partida.MaxJugadores,
	}
end

local function difundir(jugador: Player?)
	local remoto = Net.obtener("PartidaState")
	if jugador then
		remoto:FireClient(jugador, paquete())
	else
		remoto:FireAllClients(paquete())
	end
end

local function empezar(modo: string)
	if estado.fase == "jugando" then
		return
	end
	estado.fase = "jugando"
	estado.modo = modo
	difundir()
	NightManager.iniciarPartida()
end

function Partida.estado()
	return table.clone(estado)
end

--- Arranca sin pasar por el menú (pruebas y depuración).
function Partida.forzarInicio(modo: string?)
	empezar(modo or "solo")
end

function Partida.init()
	Net.obtener("MenuAction").OnServerEvent:Connect(function(jugador, datos)
		if typeof(datos) ~= "table" or typeof(datos.accion) ~= "string" then
			return
		end
		if not Net.limitar(jugador, "menu", 0.3) then
			return
		end
		local accion = datos.accion
		if accion == "estado" then
			difundir(jugador) -- el menú del cliente pide el estado actual al abrirse
			return
		end
		if estado.fase == "menu" then
			if accion == "solo" then
				empezar("solo")
			elseif accion == "multi" then
				estado.fase = "lobby"
				estado.modo = "multi"
				estado.anfitrion = jugador
				difundir()
			end
		elseif estado.fase == "lobby" then
			if accion == "empezar" and jugador == estado.anfitrion then
				empezar("multi")
			elseif accion == "cancelar" and jugador == estado.anfitrion then
				estado.fase, estado.modo, estado.anfitrion = "menu", nil, nil
				difundir()
			end
		end
	end)

	Players.PlayerAdded:Connect(function(jugador)
		task.delay(1, difundir, jugador)
		if estado.fase == "lobby" then
			difundir()
			-- Con la sala llena, arranca sola.
			if #Players:GetPlayers() >= Config.Partida.MaxJugadores then
				task.delay(2, function()
					if estado.fase == "lobby" then
						empezar("multi")
					end
				end)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(jugador)
		if estado.fase == "lobby" then
			if estado.anfitrion == jugador then
				-- El anfitrión se fue: pasa al siguiente (o vuelve al menú si no queda nadie).
				estado.anfitrion = nil
				for _, otro in Players:GetPlayers() do
					if otro ~= jugador then
						estado.anfitrion = otro
						break
					end
				end
				if not estado.anfitrion then
					estado.fase, estado.modo = "menu", nil
				end
			end
			task.defer(difundir)
		end
	end)

	if not Config.Partida.MenuActivo then
		task.spawn(function()
			while #Players:GetPlayers() == 0 do
				task.wait(0.5)
			end
			empezar("solo")
		end)
	end
end

return Partida
