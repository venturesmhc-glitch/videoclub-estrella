--!nonstrict
--[[
	Salas (servidor): salas de multijugador entre servidores de Roblox.

	El menú y el juego viven en servidores distintos, para que los jugadores de un servidor público (hasta 60) no
	compartan una misma partida:
	  - el servidor de entrada (público) solo muestra el menú, lista las salas y arma la sala de espera. Nunca corre
	    un turno;
	  - el servidor de juego (reservado, lo crea ReserveServer) corre el turno.

	La sala de espera NO es un servidor: es un registro en un MemoryStore (código, anfitrión, miembros, estado). Cada
	jugador se queda en su servidor de entrada viendo la sala (se lee el registro cada tanto). Recién cuando el
	anfitrión aprieta "Iniciar" se reserva el servidor de juego, se anota su código de acceso en el registro y se
	teletransporta a todos los miembros juntos; cada servidor de entrada manda a los suyos al leer ese cambio.

	En Studio no hay teletransporte ni siempre hay acceso a MemoryStore: ahí (o con Config.Salas.ForzarLocal) la sala es
	el propio servidor ("modo local"): sirve para probar la interfaz y el flujo con "Start Server" + varios clientes.
	Con Config.Salas.SimularNube = true, Studio se comporta como servidor de entrada pero con un MemoryStore en memoria y
	un teletransporte que solo se anota (Salas.teleportesSimulados): sirve para probar el flujo de la sala de espera.

	Registro de una sala (MemoryStore, clave = código):
	  { publica, maximo, modo = "historia" | "sinfin", anfitrionId, anfitrion, miembros = { { id, nombre } }, estado = "espera" | "iniciando", accessCode? }

	API (devuelven el resultado o nil + texto del error):
	  Salas.enNube() -> boolean
	  Salas.esServidorDeSala() -> boolean            true en un servidor de juego (reservado)
	  Salas.datosDeEntrada(jugador) -> datos con los que llegó el jugador a un servidor de juego, o nil
	  Salas.codigoNuevo() -> string
	  Salas.listar() -> { { codigo, anfitrion, jugadores, maximo } } | nil, error     (solo salas públicas en espera)
	  Salas.crearRegistro(jugador, publica, maximo, modo?) -> codigo, registro | nil, error
	  Salas.leer(codigo) -> registro | nil, esErrorDeRed
	  Salas.agregar(jugador, codigo) -> registro | nil, error
	  Salas.quitar(jugador, codigo)
	  Salas.renovar(codigo)
	  Salas.iniciar(codigo, anfitrion) -> registro | nil, error     (reserva el servidor de juego y marca "iniciando")
	  Salas.teleportar(jugadores, codigo, registro) -> boolean
	  Salas.retirar(codigo)
	  Salas.crearSolo(jugador, modo?) -> ok, error         (partida en solitario: servidor de un solo lugar)
	  Salas.irAlInicio(jugador)                      (vuelve a un servidor público)
]]

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Salas = {}

local cfg = Config.Salas
local ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- sin 0/O ni 1/I para que no se confundan al dictar el código
local ERROR_RED = "No se pudo conectar con los servidores. Probá de nuevo en un momento."
local VENCIMIENTO_INICIO_SEG = 60 -- una sala "iniciando" dura lo justo para que todos los servidores vean el cambio

local simulado = cfg.SimularNube == true

function Salas.enNube(): boolean
	return simulado or (not cfg.ForzarLocal and not RunService:IsStudio())
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

-- ----- Simulación (solo pruebas) -----
Salas.teleportesSimulados = {}
local simDatos = {} -- clave -> { v, vence }

local function copiar(valor)
	if typeof(valor) ~= "table" then
		return valor
	end
	local nuevo = {}
	for k, v in valor do
		nuevo[k] = copiar(v)
	end
	return nuevo
end

local mapaSimulado = {}
function mapaSimulado:GetAsync(clave)
	local e = simDatos[clave]
	if e and e.vence > os.clock() then
		return copiar(e.v)
	end
	simDatos[clave] = nil
	return nil
end
function mapaSimulado:SetAsync(clave, valor, vencimiento)
	simDatos[clave] = { v = copiar(valor), vence = os.clock() + vencimiento }
	return true
end
function mapaSimulado:UpdateAsync(clave, transformar, vencimiento)
	local nuevo = transformar(self:GetAsync(clave))
	if nuevo == nil then
		return nil
	end
	self:SetAsync(clave, nuevo, vencimiento)
	return copiar(nuevo)
end
function mapaSimulado:RemoveAsync(clave)
	simDatos[clave] = nil
end
function mapaSimulado:GetRangeAsync(_, cantidad)
	local filas = {}
	for clave, e in simDatos do
		if e.vence > os.clock() and #filas < cantidad then
			table.insert(filas, { key = clave, value = copiar(e.v) })
		end
	end
	return filas
end

local function mapa()
	if simulado then
		return mapaSimulado
	end
	return MemoryStoreService:GetSortedMap(cfg.Mapa)
end

local function reservarServidor(): string
	if simulado then
		return "SIM-" .. HttpService:GenerateGUID(false)
	end
	return (TeleportService:ReserveServer(game.PlaceId))
end

local function teletransportar(jugadores: { Player }, accessCode: string, datos)
	if simulado then
		table.insert(Salas.teleportesSimulados, { jugadores = jugadores, accessCode = accessCode, datos = datos })
		return
	end
	TeleportService:TeleportToPrivateServer(game.PlaceId, accessCode, jugadores, nil, datos)
end

local function miembroDe(jugador: Player)
	return { id = jugador.UserId, nombre = jugador.DisplayName }
end

function Salas.listar()
	local ok, filas = pcall(function()
		return mapa():GetRangeAsync(Enum.SortDirection.Ascending, cfg.MaxListadas)
	end)
	if not ok then
		warn("[Salas] No se pudo leer la lista: " .. tostring(filas))
		return nil, ERROR_RED
	end
	local lista = {}
	for _, fila in filas do
		local v = fila.value
		if typeof(v) == "table" and v.publica and v.estado == "espera" and #v.miembros < v.maximo then
			table.insert(lista, { codigo = fila.key, anfitrion = v.anfitrion, jugadores = #v.miembros, maximo = v.maximo })
		end
	end
	return lista
end

function Salas.crearRegistro(jugador: Player, publica: boolean, maximo: number, modo: string?)
	for _ = 1, 8 do
		local codigo = Salas.codigoNuevo()
		local okLeer, existente = pcall(function()
			return mapa():GetAsync(codigo)
		end)
		if not okLeer then
			return nil, ERROR_RED
		end
		if existente == nil then
			local registro = {
				publica = publica,
				maximo = maximo,
				modo = modo == "sinfin" and "sinfin" or "historia",
				anfitrionId = jugador.UserId,
				anfitrion = jugador.DisplayName,
				miembros = { miembroDe(jugador) },
				estado = "espera",
			}
			local ok, err = pcall(function()
				mapa():SetAsync(codigo, registro, cfg.VencimientoSeg)
			end)
			if not ok then
				warn("[Salas] No se pudo crear el registro: " .. tostring(err))
				return nil, ERROR_RED
			end
			return codigo, registro
		end
	end
	return nil, "No se pudo crear la sala. Probá de nuevo."
end

--- Lee el registro. Devuelve nil + false si la sala no existe, y nil + true si falló la red (no hay que darla por cerrada).
function Salas.leer(codigo: string)
	local ok, v = pcall(function()
		return mapa():GetAsync(codigo)
	end)
	if not ok then
		return nil, true
	end
	if typeof(v) ~= "table" then
		return nil, false
	end
	return v, false
end

function Salas.agregar(jugador: Player, codigo: string)
	local motivo
	local ok, resultado = pcall(function()
		return mapa():UpdateAsync(codigo, function(v)
			motivo = nil
			if typeof(v) ~= "table" then
				motivo = "No existe ninguna sala con ese código (o ya empezó)."
				return nil
			end
			if v.estado ~= "espera" then
				motivo = "La sala ya empezó."
				return nil
			end
			for _, m in v.miembros do
				if m.id == jugador.UserId then
					return v
				end
			end
			if #v.miembros >= v.maximo then
				motivo = "La sala está llena."
				return nil
			end
			table.insert(v.miembros, miembroDe(jugador))
			return v
		end, cfg.VencimientoSeg)
	end)
	if not ok then
		warn("[Salas] No se pudo entrar a la sala: " .. tostring(resultado))
		return nil, ERROR_RED
	end
	if typeof(resultado) ~= "table" then
		return nil, motivo or "No existe ninguna sala con ese código (o ya empezó)."
	end
	return resultado
end

function Salas.quitar(jugador: Player, codigo: string)
	local ok, err = pcall(function()
		local quedoVacia = false
		mapa():UpdateAsync(codigo, function(v)
			quedoVacia = false
			if typeof(v) ~= "table" or v.estado ~= "espera" then
				return nil
			end
			local quedan = {}
			for _, m in v.miembros do
				if m.id ~= jugador.UserId then
					table.insert(quedan, m)
				end
			end
			if #quedan == 0 then
				quedoVacia = true
				return nil
			end
			v.miembros = quedan
			if v.anfitrionId == jugador.UserId then
				v.anfitrionId, v.anfitrion = quedan[1].id, quedan[1].nombre -- el anfitrión pasa al siguiente
			end
			return v
		end, cfg.VencimientoSeg)
		if quedoVacia then
			mapa():RemoveAsync(codigo)
		end
	end)
	if not ok then
		warn("[Salas] No se pudo salir de la sala: " .. tostring(err))
	end
end

--- Alarga la vida del registro (vence solo si ningún servidor lo renueva).
function Salas.renovar(codigo: string)
	pcall(function()
		mapa():UpdateAsync(codigo, function(v)
			return typeof(v) == "table" and v or nil
		end, cfg.VencimientoSeg)
	end)
end

function Salas.retirar(codigo: string)
	pcall(function()
		mapa():RemoveAsync(codigo)
	end)
end

--- El anfitrión inicia: se reserva el servidor de juego y el registro pasa a "iniciando" con su código de acceso.
function Salas.iniciar(codigo: string, anfitrion: Player)
	local okReserva, accessCode = pcall(reservarServidor)
	if not okReserva or typeof(accessCode) ~= "string" then
		warn("[Salas] ReserveServer falló: " .. tostring(accessCode))
		return nil, "No se pudo preparar el servidor de juego. Probá de nuevo."
	end
	local motivo
	local ok, resultado = pcall(function()
		return mapa():UpdateAsync(codigo, function(v)
			motivo = nil
			if typeof(v) ~= "table" then
				motivo = "La sala ya no existe."
				return nil
			end
			if v.estado ~= "espera" or v.anfitrionId ~= anfitrion.UserId then
				motivo = "Solo el anfitrión puede iniciar la partida."
				return nil
			end
			v.estado = "iniciando"
			v.accessCode = accessCode
			return v
		end, VENCIMIENTO_INICIO_SEG)
	end)
	if not ok then
		warn("[Salas] No se pudo marcar la sala como iniciada: " .. tostring(resultado))
		return nil, ERROR_RED
	end
	if typeof(resultado) ~= "table" then
		return nil, motivo or "No se pudo iniciar la partida."
	end
	return resultado
end

--- Teletransporta a estos jugadores (todos de este servidor) al servidor de juego de la sala.
function Salas.teleportar(jugadores: { Player }, codigo: string, registro): boolean
	if #jugadores == 0 then
		return true
	end
	local datos = {
		tipo = "sala",
		sala = codigo,
		publica = registro.publica,
		maximo = registro.maximo,
		modo = registro.modo or "historia",
		anfitrionId = registro.anfitrionId,
		esperados = #registro.miembros, -- el servidor de juego espera a este equipo antes de empezar
	}
	local ok, err = pcall(teletransportar, jugadores, registro.accessCode, datos)
	if not ok then
		warn("[Salas] Falló el teletransporte: " .. tostring(err))
	end
	return ok
end

function Salas.crearSolo(jugador: Player, modo: string?)
	local ok, accessCode = pcall(reservarServidor)
	if not ok or typeof(accessCode) ~= "string" then
		warn("[Salas] ReserveServer falló: " .. tostring(accessCode))
		return false, "No se pudo preparar la partida. Probá de nuevo."
	end
	local datos = {
		tipo = "solo", sala = "SOLO", publica = false, maximo = 1, anfitrionId = jugador.UserId, esperados = 1,
		modo = modo == "sinfin" and "sinfin" or "historia",
	}
	local okTp, err = pcall(teletransportar, { jugador }, accessCode, datos)
	if not okTp then
		warn("[Salas] Falló el teletransporte: " .. tostring(err))
		return false, "No se pudo preparar la partida. Probá de nuevo."
	end
	return true
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
