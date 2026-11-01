--!nonstrict
--[[
	Salas (servidor): salas de multijugador entre servidores de Roblox.

	El juego y el menú viven en servidores distintos, para que los jugadores de un servidor público (hasta 60) no
	compartan una misma partida:
	  - el de entrada (público): SOLO muestra el menú, lista las salas públicas y crea o une salas. Nunca corre un turno;
	  - el de juego (reservado, lo crea ReserveServer): corre el turno de una sala o de una partida en solitario.
	    Mientras una sala espera jugadores (fase "lobby") publica su ficha en un MemoryStore con el código, la cantidad
	    de jugadores y el código de acceso del servidor reservado.

	  Solo:   se reserva un servidor de un solo lugar y se teletransporta al jugador; arranca el turno al llegar.
	  Crear:  se reserva un servidor (ReserveServer), se anota la ficha y se teletransporta al anfitrión con los datos
	          de la sala; ese servidor arranca directamente en la sala de espera.
	  Unirse: por la lista (salas públicas) o por código (públicas y privadas): se busca la ficha y se teletransporta.

	En Studio no hay teletransporte ni siempre hay acceso a MemoryStore: ahí (o con Config.Salas.ForzarLocal) la sala es
	el propio servidor ("modo local"): sirve para probar la interfaz y el flujo con "Start Server" + varios clientes.

	API (los métodos de red devuelven ok, textoDeError):
	  Salas.enNube() -> boolean
	  Salas.esServidorDeSala() -> boolean
	  Salas.datosDeEntrada(jugador) -> datos de la sala con la que llegó el jugador, o nil
	  Salas.codigoNuevo() -> string
	  Salas.listar() -> { { codigo, anfitrion, jugadores, maximo } } | nil, error   (solo salas públicas)
	  Salas.crearSolo(jugador) -> ok, error                  (reserva un servidor para una partida en solitario)
	  Salas.crear(jugador, publica, maximo) -> ok, error     (reserva, anota y teletransporta)
	  Salas.unirse(jugador, codigo) -> ok, error             (busca y teletransporta)
	  Salas.publicar(sala)   -- sala = { codigo, accessCode, publica, maximo, anfitrion, anfitrionId, jugadores }
	  Salas.retirar(codigo)
	  Salas.irAlInicio(jugador)   -- vuelve a un servidor público
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Salas = {}

local cfg = Config.Salas
local ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- sin 0/O ni 1/I para que no se confundan al dictar el código

function Salas.enNube(): boolean
	return not cfg.ForzarLocal and not RunService:IsStudio()
end

function Salas.esServidorDeSala(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function Salas.datosDeEntrada(jugador: Player)
	local ok, entrada = pcall(function()
		return jugador:GetJoinData()
	end)
	local datos = ok and entrada and entrada.TeleportData
	if typeof(datos) == "table" and typeof(datos.tipo) == "string" then
		return datos
	end
	return nil
end

function Salas.codigoNuevo(): string
	local rng = Random.new()
	local letras = {}
	for i = 1, cfg.LargoCodigo do
		local n = rng:NextInteger(1, #ALFABETO)
		letras[i] = ALFABETO:sub(n, n)
	end
	return table.concat(letras)
end

local function mapa()
	return MemoryStoreService:GetSortedMap(cfg.Mapa)
end

local function ficha(sala)
	return {
		accessCode = sala.accessCode,
		publica = sala.publica,
		maximo = sala.maximo,
		anfitrion = sala.anfitrion,
		anfitrionId = sala.anfitrionId,
		jugadores = sala.jugadores,
	}
end

function Salas.listar()
	local ok, filas = pcall(function()
		return mapa():GetRangeAsync(Enum.SortDirection.Ascending, cfg.MaxListadas)
	end)
	if not ok then
		warn("[Salas] No se pudo leer la lista: " .. tostring(filas))
		return nil, "No se pudo conectar con los servidores. Probá de nuevo en un momento."
	end
	local lista = {}
	for _, fila in filas do
		local v = fila.value
		if typeof(v) == "table" and v.publica and (v.jugadores or 0) < (v.maximo or 0) then
			table.insert(lista, { codigo = fila.key, anfitrion = v.anfitrion, jugadores = v.jugadores or 1, maximo = v.maximo })
		end
	end
	return lista
end

--- Anota (o renueva) la ficha de una sala que espera jugadores. Vence sola si el servidor deja de renovarla.
function Salas.publicar(sala)
	local ok, err = pcall(function()
		mapa():SetAsync(sala.codigo, ficha(sala), cfg.VencimientoSeg)
	end)
	if not ok then
		warn("[Salas] No se pudo publicar la sala " .. tostring(sala.codigo) .. ": " .. tostring(err))
	end
	return ok
end

function Salas.retirar(codigo: string)
	pcall(function()
		mapa():RemoveAsync(codigo)
	end)
end

local function teleportar(jugador: Player, codigo: string, v)
	local datos = {
		tipo = "sala",
		sala = codigo,
		accessCode = v.accessCode,
		publica = v.publica,
		maximo = v.maximo,
		anfitrionId = v.anfitrionId,
	}
	local ok, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, v.accessCode, { jugador }, nil, datos)
	end)
	if not ok then
		warn("[Salas] Falló el teletransporte: " .. tostring(err))
		return false, "No se pudo entrar a la sala. Probá de nuevo."
	end
	return true
end

function Salas.crearSolo(jugador: Player)
	local ok, accessCode = pcall(function()
		return (TeleportService:ReserveServer(game.PlaceId))
	end)
	if not ok or typeof(accessCode) ~= "string" then
		warn("[Salas] ReserveServer falló: " .. tostring(accessCode))
		return false, "No se pudo preparar la partida. Probá de nuevo."
	end
	local datos = { tipo = "solo", sala = "SOLO", publica = false, maximo = 1, anfitrionId = jugador.UserId }
	local okTp, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, { jugador }, nil, datos)
	end)
	if not okTp then
		warn("[Salas] Falló el teletransporte: " .. tostring(err))
		return false, "No se pudo preparar la partida. Probá de nuevo."
	end
	return true
end

function Salas.crear(jugador: Player, publica: boolean, maximo: number)
	local okReserva, accessCode = pcall(function()
		return (TeleportService:ReserveServer(game.PlaceId))
	end)
	if not okReserva or typeof(accessCode) ~= "string" then
		warn("[Salas] ReserveServer falló: " .. tostring(accessCode))
		return false, "No se pudo crear la sala. Probá de nuevo."
	end
	local codigo
	for _ = 1, 8 do
		local candidato = Salas.codigoNuevo()
		local okLeer, existente = pcall(function()
			return mapa():GetAsync(candidato)
		end)
		if okLeer and existente == nil then
			codigo = candidato
			break
		end
		if not okLeer then
			return false, "No se pudo conectar con los servidores. Probá de nuevo en un momento."
		end
	end
	if not codigo then
		return false, "No se pudo crear la sala. Probá de nuevo."
	end
	local v = {
		codigo = codigo, accessCode = accessCode, publica = publica, maximo = maximo,
		anfitrion = jugador.DisplayName, anfitrionId = jugador.UserId, jugadores = 1,
	}
	if not Salas.publicar(v) then
		return false, "No se pudo crear la sala. Probá de nuevo."
	end
	return teleportar(jugador, codigo, v)
end

function Salas.unirse(jugador: Player, codigo: string)
	local ok, v = pcall(function()
		return mapa():GetAsync(codigo)
	end)
	if not ok then
		warn("[Salas] No se pudo buscar la sala: " .. tostring(v))
		return false, "No se pudo conectar con los servidores. Probá de nuevo en un momento."
	end
	if typeof(v) ~= "table" then
		return false, "No existe ninguna sala con ese código (o ya empezó)."
	end
	if (v.jugadores or 0) >= (v.maximo or 0) then
		return false, "La sala está llena."
	end
	return teleportar(jugador, codigo, v)
end

function Salas.irAlInicio(jugador: Player)
	local ok, err = pcall(function()
		TeleportService:Teleport(game.PlaceId, jugador)
	end)
	if not ok then
		warn("[Salas] No se pudo volver al inicio: " .. tostring(err))
	end
end

return Salas
