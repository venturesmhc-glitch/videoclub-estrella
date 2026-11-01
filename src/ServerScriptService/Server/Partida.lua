--!nonstrict
--[[
	Partida (servidor): menú de inicio y salas de multijugador.
	El turno no arranca solo: alguien tiene que elegir en el menú.
	  fase "menu"    nadie eligió todavía (servidor de entrada: se puede jugar solo, crear una sala o unirse a una)
	  fase "lobby"   sala de espera: la sala ya existe (con su código) y el anfitrión aprieta "Iniciar"
	  fase "jugando" el turno está en marcha (quien entra después se suma directo)
	Menú y juego van en servidores distintos (ver Salas.lua): el servidor de entrada solo muestra el menú; "Un jugador" y
	las salas abren un servidor reservado y teletransportan ahí, y recién ese servidor corre el turno. (En Studio no hay
	teletransporte: el propio servidor hace de sala y "Un jugador" arranca de inmediato.)
	El estado se manda a todos por el remote PartidaState; la lista de salas y los avisos de error llegan por SalasState.
	El cliente (MenuUI) solo muestra: toda decisión se valida acá.

	Acciones de MenuAction: estado | salas | solo | crear { publica, maximo } | unirse { codigo } | empezar | salir
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local Salas = require(script.Parent.Salas)

local Partida = {}

-- sala = { tipo = "sala" | "solo", codigo, accessCode?, publica, maximo, anfitrionId? } cuando la sala existe
local estado = { fase = "menu", modo = nil, anfitrion = nil, sala = nil }
local ultimaPublicacion = 0

local function nombres(): { string }
	local lista = {}
	for _, j in Players:GetPlayers() do
		table.insert(lista, j.DisplayName)
	end
	return lista
end

local function paquete()
	local sala = estado.sala
	return {
		fase = estado.fase,
		modo = estado.modo,
		anfitrion = estado.anfitrion and estado.anfitrion.DisplayName or nil,
		anfitrionId = estado.anfitrion and estado.anfitrion.UserId or nil,
		jugadores = nombres(),
		maximo = sala and sala.maximo or Config.Partida.MaxJugadores,
		codigo = sala and sala.codigo or nil,
		publica = if sala then sala.publica else nil,
		nube = Salas.enNube(), -- true: las salas son servidores aparte (se puede salir de la sala); false: modo local de Studio
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

local function responder(jugador: Player, datos)
	Net.obtener("SalasState"):FireClient(jugador, datos)
end

local function mensaje(jugador: Player, texto: string, esError: boolean?)
	responder(jugador, { tipo = "mensaje", texto = texto, error = esError == true })
end

local function empezar(modo: string)
	if estado.fase == "jugando" then
		return
	end
	local sala = estado.sala
	estado.fase = "jugando"
	estado.modo = modo
	difundir()
	if sala and sala.tipo ~= "solo" and Salas.enNube() then
		task.spawn(Salas.retirar, sala.codigo) -- ya empezó: deja de aparecer en la lista y de aceptar códigos
	end
	NightManager.iniciarPartida()
end

local function publicarSala()
	local sala = estado.sala
	if not sala or sala.tipo == "solo" or not Salas.enNube() or estado.fase ~= "lobby" then
		return
	end
	ultimaPublicacion = os.clock()
	Salas.publicar({
		codigo = sala.codigo,
		accessCode = sala.accessCode,
		publica = sala.publica,
		maximo = sala.maximo,
		anfitrion = estado.anfitrion and estado.anfitrion.DisplayName or "—",
		anfitrionId = estado.anfitrion and estado.anfitrion.UserId or sala.anfitrionId,
		jugadores = #Players:GetPlayers(),
	})
end

function Partida.estado()
	return table.clone(estado)
end

--- Arranca sin pasar por el menú (pruebas y depuración).
function Partida.forzarInicio(modo: string?)
	empezar(modo or "solo")
end

-- ===== Acciones del menú =====

local function limpiarCodigo(texto): string
	return (string.upper(tostring(texto or "")):gsub("[^%w]", ""))
end

local function listarSalas(jugador: Player)
	local remoto = Net.obtener("SalasState")
	if Salas.enNube() then
		if not Net.limitar(jugador, "listarSalas", 1.5) then
			return
		end
		task.spawn(function()
			local lista, err = Salas.listar()
			remoto:FireClient(jugador, { tipo = "lista", salas = lista or {}, error = err })
		end)
		return
	end
	-- Modo local: la única sala posible es la de este servidor.
	local lista = {}
	if estado.fase == "lobby" and estado.sala and estado.sala.publica then
		table.insert(lista, {
			codigo = estado.sala.codigo,
			anfitrion = estado.anfitrion and estado.anfitrion.DisplayName or "—",
			jugadores = #Players:GetPlayers(),
			maximo = estado.sala.maximo,
		})
	end
	remoto:FireClient(jugador, { tipo = "lista", salas = lista })
end

local function crearSala(jugador: Player, datos)
	if estado.fase ~= "menu" then
		return
	end
	if not Net.limitar(jugador, "crearSala", 3) then
		return
	end
	local publica = datos.publica ~= false
	local maximo = math.clamp(math.floor(tonumber(datos.maximo) or Config.Partida.MaxJugadores), 2, Config.Partida.MaxJugadores)
	if Salas.enNube() then
		mensaje(jugador, "Creando la sala...")
		task.spawn(function()
			local ok, err = Salas.crear(jugador, publica, maximo)
			if not ok then
				mensaje(jugador, err or "No se pudo crear la sala.", true)
			end
		end)
		return
	end
	-- Modo local: este servidor pasa a ser la sala y quien la crea es el anfitrión.
	estado.fase, estado.modo, estado.anfitrion = "lobby", "multi", jugador
	estado.sala = { codigo = Salas.codigoNuevo(), publica = publica, maximo = maximo }
	difundir()
end

local function unirseASala(jugador: Player, datos)
	if not Net.limitar(jugador, "unirseSala", 2) then
		return
	end
	local codigo = limpiarCodigo(datos.codigo)
	if #codigo ~= Config.Salas.LargoCodigo then
		mensaje(jugador, string.format("El código tiene %d caracteres.", Config.Salas.LargoCodigo), true)
		return
	end
	if Salas.enNube() then
		if estado.fase ~= "menu" then
			return
		end
		mensaje(jugador, "Buscando la sala...")
		task.spawn(function()
			local ok, err = Salas.unirse(jugador, codigo)
			if not ok then
				mensaje(jugador, err or "No se pudo entrar a la sala.", true)
			end
		end)
		return
	end
	-- Modo local: solo existe la sala de este servidor.
	local sala = estado.sala
	if estado.fase == "lobby" and sala and sala.codigo == codigo then
		if #Players:GetPlayers() > sala.maximo then
			mensaje(jugador, "La sala está llena.", true)
		else
			difundir(jugador)
		end
	else
		mensaje(jugador, "No existe ninguna sala con ese código (o ya empezó).", true)
	end
end

local function iniciarSolo(jugador: Player)
	if estado.fase ~= "menu" then
		return
	end
	if not Salas.enNube() then
		empezar("solo") -- Studio: no hay otro servidor adonde ir
		return
	end
	if not Net.limitar(jugador, "crearSala", 3) then
		return
	end
	mensaje(jugador, "Preparando tu partida...")
	task.spawn(function()
		local ok, err = Salas.crearSolo(jugador)
		if not ok then
			mensaje(jugador, err or "No se pudo preparar la partida.", true)
		end
	end)
end

local function salirDeLaSala(jugador: Player)
	if Salas.enNube() then
		Salas.irAlInicio(jugador)
	elseif jugador == estado.anfitrion then
		-- Modo local: el anfitrión cierra la sala y todos vuelven al menú.
		estado.fase, estado.modo, estado.anfitrion, estado.sala = "menu", nil, nil, nil
		difundir()
	end
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
		elseif accion == "salas" then
			listarSalas(jugador)
		elseif accion == "solo" then
			iniciarSolo(jugador)
		elseif accion == "crear" then
			crearSala(jugador, datos)
		elseif accion == "unirse" then
			unirseASala(jugador, datos)
		elseif accion == "empezar" then
			if estado.fase == "lobby" and jugador == estado.anfitrion then
				empezar("multi")
			end
		elseif accion == "salir" then
			if estado.fase == "lobby" or Salas.enNube() then
				salirDeLaSala(jugador) -- en servidores aparte se puede volver al menú aun con el turno en marcha
			end
		end
	end)

	-- Cada segundo: si el anfitrión no está (todavía no llegó o se fue) pasa al primero que haya, y la sala renueva su
	-- ficha para seguir apareciendo en la lista.
	task.spawn(function()
		while true do
			task.wait(1)
			if estado.fase == "lobby" then
				if not estado.anfitrion or estado.anfitrion.Parent ~= Players then
					local nuevo = Players:GetPlayers()[1]
					if nuevo and nuevo ~= estado.anfitrion then
						estado.anfitrion = nuevo
						difundir()
					end
				end
				if os.clock() - ultimaPublicacion >= Config.Salas.LatidoSeg then
					publicarSala()
				end
			end
		end
	end)

	local function alEntrar(jugador: Player)
		local yaEstabaJugando = estado.fase == "jugando" -- (antes de que, en una partida en solitario, arranque por este jugador)
		-- Servidor reservado para una sala: la configuran los datos con los que llegó el primer jugador.
		if not estado.sala and Salas.esServidorDeSala() then
			local d = Salas.datosDeEntrada(jugador)
			if d then
				estado.sala = {
					tipo = d.tipo,
					codigo = d.sala,
					accessCode = d.accessCode,
					publica = d.publica ~= false,
					maximo = math.clamp(tonumber(d.maximo) or Config.Partida.MaxJugadores, d.tipo == "solo" and 1 or 2, Config.Partida.MaxJugadores),
					anfitrionId = d.anfitrionId,
				}
				estado.fase, estado.modo = "lobby", "multi"
			end
		end
		-- Un servidor de juego solo se pisa teletransportado desde el menú: quien llegue sin datos vuelve al inicio.
		if Salas.esServidorDeSala() and not estado.sala then
			Salas.irAlInicio(jugador)
			return
		end
		if estado.sala and estado.sala.anfitrionId == jugador.UserId then
			estado.anfitrion = jugador
		end
		-- Sala llena: no entra nadie más.
		if estado.sala and #Players:GetPlayers() > estado.sala.maximo then
			jugador:Kick("La sala está llena.")
			return
		end
		-- Partida en solitario: el turno arranca apenas llega el jugador.
		if estado.sala and estado.sala.tipo == "solo" and estado.fase ~= "jugando" then
			estado.anfitrion = jugador
			empezar("solo")
		end
		task.delay(1, difundir, jugador)
		if yaEstabaJugando then
			-- Quien llega con el turno en marcha entra directo: se le avisa en qué noche está y dónde mirar.
			task.delay(4, function()
				if jugador.Parent then
					Net.aviso(jugador, string.format("Te sumaste a la noche %d. Tu ficha (Tab) dice qué falta; el equipo ya está en el local.", NightManager.obtenerEstado().noche))
				end
			end)
		end
		if estado.fase == "lobby" then
			difundir()
			publicarSala() -- que el contador de jugadores de la lista se actualice enseguida
		end
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end

	Players.PlayerRemoving:Connect(function(jugador)
		if estado.fase ~= "lobby" then
			return
		end
		if estado.anfitrion == jugador then
			-- El anfitrión se fue: pasa al siguiente.
			estado.anfitrion = nil
			for _, otro in Players:GetPlayers() do
				if otro ~= jugador then
					estado.anfitrion = otro
					break
				end
			end
			if not estado.anfitrion then
				if estado.sala and Salas.enNube() then
					task.spawn(Salas.retirar, estado.sala.codigo) -- la sala quedó vacía
				end
				estado.fase, estado.modo, estado.sala = "menu", nil, nil
			end
		end
		task.defer(function()
			difundir()
			publicarSala()
		end)
	end)

	if not Config.Partida.MenuActivo and not Salas.enNube() then
		task.spawn(function()
			while #Players:GetPlayers() == 0 do
				task.wait(0.5)
			end
			empezar("solo")
		end)
	end
end

return Partida
