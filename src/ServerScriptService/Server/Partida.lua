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

local estado = { fase = "menu", modo = nil, anfitrion = nil, conteo = nil }
local desdeMenu = nil -- desde cuándo hay 2 o más jugadores mirando el menú
local desdeLobby = nil -- desde cuándo hay 2 o más jugadores en la sala

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
		conteo = estado.conteo, -- segundos que faltan para que la sala arranque sola (nil si no hay cuenta)
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
	estado.conteo = nil
	desdeMenu, desdeLobby = nil, nil
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

	-- Entrada rápida: si hay 2 o más jugadores y nadie elige, se abre la sala sola; y en la sala, el turno arranca
	-- con una cuenta regresiva (el anfitrión puede adelantarla). Así nadie queda esperando a que alguien apriete un botón.
	task.spawn(function()
		while true do
			task.wait(1)
			local cantidad = #Players:GetPlayers()
			local ahora = os.clock()
			if estado.fase == "menu" then
				if cantidad >= 2 then
					desdeMenu = desdeMenu or ahora
					if ahora - desdeMenu >= Config.Partida.MenuAParejaSeg then
						estado.fase, estado.modo, estado.anfitrion = "lobby", "multi", Players:GetPlayers()[1]
						desdeMenu = nil
						difundir()
					end
				else
					desdeMenu = nil
				end
			elseif estado.fase == "lobby" then
				if cantidad >= 2 then
					desdeLobby = desdeLobby or ahora
					local restante = math.max(0, math.ceil(Config.Partida.LobbyAutoSeg - (ahora - desdeLobby)))
					estado.conteo = restante
					if restante <= 0 then
						empezar("multi")
					else
						difundir()
					end
				elseif estado.conteo then
					estado.conteo, desdeLobby = nil, nil
					difundir()
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(jugador)
		task.delay(1, difundir, jugador)
		if estado.fase == "jugando" then
			-- Quien llega con el turno en marcha entra directo: se le avisa en qué noche está y dónde mirar.
			task.delay(4, function()
				if jugador.Parent then
					Net.aviso(jugador, string.format("Te sumaste a la noche %d. Tu ficha (Tab) dice qué falta; el equipo ya está en el local.", NightManager.obtenerEstado().noche))
				end
			end)
		end
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
