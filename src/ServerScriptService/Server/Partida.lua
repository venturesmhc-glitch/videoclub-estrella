--!nonstrict
--[[
	Partida (servidor): menú de inicio y salas de multijugador.
	El turno no arranca solo: alguien tiene que elegir en el menú.
	  fase "menu"      nadie eligió todavía
	  fase "lobby"     sala de espera: la sala existe (con su código) y el anfitrión aprieta "Iniciar"
	  fase "reuniendo" (servidor de juego) llegó el primero del equipo; se espera a los demás antes de empezar
	  fase "jugando"   el turno está en marcha (quien entra después se suma directo)

	Menú y juego van en servidores distintos (ver Salas.lua):
	  - Servidor de entrada: solo muestra el menú y la sala de espera; nunca corre un turno. Crear o unirse a una sala NO
	    cambia de servidor: la sala es un registro compartido y cada uno la ve desde su servidor. Recién al apretar
	    "Iniciar" se teletransporta a todo el equipo junto a un servidor de juego. "Un jugador" también abre uno.
	  - Servidor de juego (reservado): lo configuran los datos con los que llega el equipo; arranca el turno cuando están
	    todos (o pasado un tiempo).
	  - En Studio no hay teletransporte: el propio servidor hace de sala (modo local) y "Un jugador" arranca de inmediato.

	El estado se manda por PartidaState (en el servidor de entrada cada jugador recibe el suyo: menú o la sala en la que
	está); la lista de salas y los avisos de error llegan por SalasState. El cliente (MenuUI) solo muestra: toda decisión
	se valida acá.

	Acciones de MenuAction: estado | salas | solo | crear { publica, maximo } | unirse { codigo } | empezar | salir
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local Persistencia = require(script.Parent.Persistencia)
local Salas = require(script.Parent.Salas)

local Partida = {}

-- sala = { tipo = "sala" | "solo", codigo, publica, maximo, modo = "historia" | "sinfin", noche, anfitrionId?, esperados? }
-- (servidor de juego y modo local). estado.modo es "solo" | "multi"; estado.modoJuego es "historia" | "sinfin";
-- estado.noche es la noche en la que arranca la historia (1, salvo que quien ya ganó haya elegido otra).
local estado = { fase = "menu", modo = nil, modoJuego = nil, noche = nil, anfitrion = nil, sala = nil }

local nube = Salas.enNube()
local enEntrada = nube and not Salas.esServidorDeSala() -- servidor público: menú y salas de espera
local miSala = {} -- Player -> código de la sala de espera en la que está (solo servidor de entrada)
local cache = {} -- código -> último registro leído
local yaMandados = {} -- Player -> true: ya se lo teletransportó al servidor de juego
local firmas = {} -- código -> resumen del registro, para avisar a los clientes solo cuando cambia
local ultimaRenovacion = {} -- código -> os.clock()

local function nombres(): { string }
	local lista = {}
	for _, j in Players:GetPlayers() do
		table.insert(lista, j.DisplayName)
	end
	return lista
end

-- Estado de un servidor de juego o del modo local.
local function paquete()
	local sala = estado.sala
	return {
		fase = estado.fase,
		modo = estado.modo,
		modoJuego = estado.modoJuego or (sala and sala.modo) or "historia",
		noche = estado.noche or (sala and sala.noche) or 1,
		anfitrion = estado.anfitrion and estado.anfitrion.DisplayName or nil,
		anfitrionId = estado.anfitrion and estado.anfitrion.UserId or nil,
		jugadores = nombres(),
		maximo = sala and sala.maximo or Config.Partida.MaxJugadores,
		codigo = sala and sala.codigo or nil,
		publica = if sala then sala.publica else nil,
		nube = nube, -- true: las salas son servidores aparte; false: modo local de Studio
	}
end

-- Estado que ve un jugador en el servidor de entrada: el menú, o la sala de espera en la que está.
local function paqueteDeEntrada(jugador: Player)
	local codigo = miSala[jugador]
	local registro = codigo and cache[codigo]
	if not registro then
		return { fase = "menu", jugadores = {}, maximo = Config.Partida.MaxJugadores, nube = true }
	end
	local lista = {}
	for _, m in registro.miembros do
		table.insert(lista, m.nombre)
	end
	return {
		fase = "lobby",
		modo = "multi",
		modoJuego = registro.modo or "historia",
		noche = registro.noche or 1,
		anfitrion = registro.anfitrion,
		anfitrionId = registro.anfitrionId,
		jugadores = lista,
		maximo = registro.maximo,
		codigo = codigo,
		publica = registro.publica,
		iniciando = registro.estado == "iniciando",
		nube = true,
	}
end

local function difundir(jugador: Player?)
	local remoto = Net.obtener("PartidaState")
	if enEntrada then
		if jugador then
			remoto:FireClient(jugador, paqueteDeEntrada(jugador))
		else
			for _, j in Players:GetPlayers() do
				remoto:FireClient(j, paqueteDeEntrada(j))
			end
		end
	elseif jugador then
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

-- El modo de juego que pidió el jugador ("historia" por defecto), o nil si pidió Sin fin sin haberlo desbloqueado
-- (se le avisa). Sin fin se desbloquea al alcanzar cualquier final de la historia.
local function modoPedido(jugador: Player, datos): string?
	if typeof(datos) ~= "table" or datos.modo ~= "sinfin" then
		return "historia"
	end
	if Persistencia.sinFinDesbloqueado(jugador) then
		return "sinfin"
	end
	mensaje(jugador, "El modo Sin fin se desbloquea al alcanzar un final de la historia.", true)
	return nil
end

-- La noche por la que empieza la historia: la 1, salvo que el jugador ya haya alcanzado un final (el mismo requisito
-- que Sin fin) y haya elegido otra en el menú. Siempre se valida acá, nunca se confía en el número del cliente.
local function nochePedida(jugador: Player, datos, modoJuego: string): number
	if modoJuego ~= "historia" or typeof(datos) ~= "table" or typeof(datos.noche) ~= "number" then
		return Config.Noche.NocheInicial
	end
	if not Persistencia.sinFinDesbloqueado(jugador) then
		return Config.Noche.NocheInicial
	end
	return math.clamp(math.floor(datos.noche), Config.Noche.NocheInicial, Config.Noche.NochesImplementadas)
end

local function empezar(modo: string, modoJuego: string?, noche: number?)
	if estado.fase == "jugando" then
		return
	end
	estado.fase = "jugando"
	estado.modo = modo
	estado.modoJuego = modoJuego or (estado.sala and estado.sala.modo) or "historia"
	-- Toda partida arranca en la noche 1 salvo que quien ya ganó haya elegido otra; la noche guardada no se usa.
	estado.noche = noche or (estado.sala and estado.sala.noche) or Config.Noche.NocheInicial
	NightManager.fijarModo(estado.modoJuego)
	difundir()
	NightManager.iniciarPartida(estado.noche)
end

function Partida.estado()
	return table.clone(estado)
end

--- Arranca sin pasar por el menú (pruebas y depuración).
function Partida.forzarInicio(modo: string?, modoJuego: string?, noche: number?)
	empezar(modo or "solo", modoJuego, noche)
end

-- ===== Servidor de entrada: salas de espera =====

local function firmaDe(registro): string
	local ids = {}
	for _, m in registro.miembros do
		table.insert(ids, m.id)
	end
	return table.concat(ids, ",") .. "|" .. tostring(registro.anfitrionId) .. "|" .. tostring(registro.estado)
end

--- Teletransporta al servidor de juego a los jugadores de este servidor que están en esa sala.
local function mandarAlJuego(codigo: string, registro)
	local grupo = {}
	for jugador, c in miSala do
		if c == codigo and not yaMandados[jugador] then
			yaMandados[jugador] = true
			table.insert(grupo, jugador)
		end
	end
	if #grupo == 0 then
		return
	end
	if not Salas.teleportar(grupo, codigo, registro) then
		for _, jugador in grupo do
			yaMandados[jugador] = nil
			mensaje(jugador, "No se pudo entrar al servidor de juego. Probá de nuevo.", true)
		end
	end
end

local function salirDeSalaDeEspera(jugador: Player)
	local codigo = miSala[jugador]
	if not codigo then
		return
	end
	miSala[jugador] = nil
	if not yaMandados[jugador] then
		task.spawn(Salas.quitar, jugador, codigo)
	end
end

local function sondearSalas()
	local codigos = {}
	for _, codigo in miSala do
		codigos[codigo] = true
	end
	local cambio = false
	for codigo in codigos do
		local registro, errorDeRed = Salas.leer(codigo)
		if registro then
			local firma = firmaDe(registro)
			if firmas[codigo] ~= firma then
				firmas[codigo] = firma
				cache[codigo] = registro
				cambio = true
			end
			if registro.estado == "iniciando" and registro.accessCode then
				mandarAlJuego(codigo, registro)
			elseif os.clock() - (ultimaRenovacion[codigo] or 0) >= Config.Salas.LatidoSeg then
				ultimaRenovacion[codigo] = os.clock()
				task.spawn(Salas.renovar, codigo)
			end
		elseif not errorDeRed then
			-- La sala ya no existe (la cerraron o venció): se avisa y se vuelve al menú.
			cache[codigo], firmas[codigo], ultimaRenovacion[codigo] = nil, nil, nil
			for jugador, c in table.clone(miSala) do
				if c == codigo then
					miSala[jugador] = nil
					if not yaMandados[jugador] then
						mensaje(jugador, "La sala se cerró.", true)
					end
				end
			end
			cambio = true
		end
	end
	if cambio then
		difundir()
	end
end

-- ===== Acciones del menú =====

local function limpiarCodigo(texto): string
	return (string.upper(tostring(texto or "")):gsub("[^%w]", ""))
end

local function listarSalas(jugador: Player)
	local remoto = Net.obtener("SalasState")
	if nube then
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
	if not Net.limitar(jugador, "crearSala", 3) then
		return
	end
	local publica = datos.publica ~= false
	local maximo = math.clamp(math.floor(tonumber(datos.maximo) or Config.Partida.MaxJugadores), 2, Config.Partida.MaxJugadores)
	local modoJuego = modoPedido(jugador, datos)
	if not modoJuego then
		return
	end
	local noche = nochePedida(jugador, datos, modoJuego)
	if enEntrada then
		if miSala[jugador] then
			return
		end
		mensaje(jugador, "Creando la sala...")
		task.spawn(function()
			local codigo, registro = Salas.crearRegistro(jugador, publica, maximo, modoJuego, noche)
			if not codigo then
				mensaje(jugador, registro or "No se pudo crear la sala.", true)
				return
			end
			if not jugador.Parent then
				Salas.quitar(jugador, codigo)
				return
			end
			-- Sin teletransporte: la sala de espera se ve desde acá hasta que el anfitrión inicie.
			miSala[jugador], cache[codigo], firmas[codigo] = codigo, registro, firmaDe(registro)
			ultimaRenovacion[codigo] = os.clock()
			difundir(jugador)
		end)
		return
	end
	if estado.fase ~= "menu" then
		return
	end
	-- Modo local: este servidor pasa a ser la sala y quien la crea es el anfitrión.
	estado.fase, estado.modo, estado.anfitrion = "lobby", "multi", jugador
	estado.sala = { tipo = "sala", codigo = Salas.codigoNuevo(), publica = publica, maximo = maximo, modo = modoJuego, noche = noche }
	estado.modoJuego = modoJuego
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
	if enEntrada then
		if miSala[jugador] then
			return
		end
		mensaje(jugador, "Buscando la sala...")
		task.spawn(function()
			local registro, err = Salas.agregar(jugador, codigo)
			if not registro then
				mensaje(jugador, err or "No se pudo entrar a la sala.", true)
				return
			end
			if not jugador.Parent then
				Salas.quitar(jugador, codigo)
				return
			end
			miSala[jugador], cache[codigo], firmas[codigo] = codigo, registro, firmaDe(registro)
			difundir() -- el anfitrión (si está en este servidor) y los demás de la sala ven al nuevo jugador enseguida
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

local function iniciarSala(jugador: Player)
	if enEntrada then
		local codigo = miSala[jugador]
		local registro = codigo and cache[codigo]
		if not registro or registro.anfitrionId ~= jugador.UserId or registro.estado ~= "espera" then
			return
		end
		if not Net.limitar(jugador, "iniciarSala", 3) then
			return
		end
		mensaje(jugador, "Preparando el servidor de juego...")
		task.spawn(function()
			local nuevo, err = Salas.iniciar(codigo, jugador)
			if not nuevo then
				mensaje(jugador, err or "No se pudo iniciar la partida.", true)
				return
			end
			cache[codigo], firmas[codigo] = nuevo, firmaDe(nuevo)
			difundir() -- todos los de esta sala ven "Iniciando..."
			mandarAlJuego(codigo, nuevo)
			-- Los demás servidores de entrada ya vieron el cambio; el registro se borra para que no quede en la lista.
			task.delay(Config.Salas.CierreSalaSeg, Salas.retirar, codigo)
		end)
		return
	end
	if estado.fase == "lobby" and jugador == estado.anfitrion then
		empezar("multi")
	end
end

local function iniciarSolo(jugador: Player, datos)
	if estado.fase ~= "menu" and not enEntrada then
		return
	end
	local modoJuego = modoPedido(jugador, datos)
	if not modoJuego then
		return
	end
	local noche = nochePedida(jugador, datos, modoJuego)
	if not nube then
		empezar("solo", modoJuego, noche) -- Studio: no hay otro servidor adonde ir
		return
	end
	if miSala[jugador] or not Net.limitar(jugador, "crearSala", 3) then
		return
	end
	mensaje(jugador, "Preparando tu partida...")
	task.spawn(function()
		local ok, err = Salas.crearSolo(jugador, modoJuego, noche)
		if not ok then
			mensaje(jugador, err or "No se pudo preparar la partida.", true)
		end
	end)
end

local function salirDeLaSala(jugador: Player)
	if enEntrada then
		if miSala[jugador] and not yaMandados[jugador] then
			salirDeSalaDeEspera(jugador)
			difundir(jugador)
		end
	elseif nube then
		Salas.irAlInicio(jugador) -- desde un servidor de juego: de vuelta al servidor de entrada
	elseif jugador == estado.anfitrion and estado.fase == "lobby" then
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
		elseif accion == "perfil" then
			Persistencia.enviarPerfil(jugador) -- el menú lo pide al abrirse (el primer envío puede haber llegado antes de estar listo)
		elseif accion == "solo" then
			iniciarSolo(jugador, datos)
		elseif accion == "crear" then
			crearSala(jugador, datos)
		elseif accion == "unirse" then
			unirseASala(jugador, datos)
		elseif accion == "empezar" then
			iniciarSala(jugador)
		elseif accion == "salir" then
			salirDeLaSala(jugador)
		end
	end)

	-- Cada segundo (modo local y servidor de juego): si el anfitrión no está pasa al primero que haya. En el servidor
	-- de entrada se leen las salas de espera de los jugadores presentes.
	task.spawn(function()
		local desdeSondeo = 0
		while true do
			task.wait(1)
			if enEntrada then
				desdeSondeo += 1
				if desdeSondeo >= Config.Salas.SondeoSeg then
					desdeSondeo = 0
					local ok, err = pcall(sondearSalas) -- un error no puede frenar la lectura de las salas para siempre
					if not ok then
						warn("[Partida] Falló la lectura de las salas: " .. tostring(err))
					end
				end
			elseif estado.fase == "lobby" then
				if not estado.anfitrion or estado.anfitrion.Parent ~= Players then
					local nuevo = Players:GetPlayers()[1]
					if nuevo and nuevo ~= estado.anfitrion then
						estado.anfitrion = nuevo
						difundir()
					end
				end
			end
		end
	end)

	local function alEntrar(jugador: Player)
		local yaEstabaJugando = estado.fase == "jugando" -- (antes de que, en una partida en solitario, arranque por este jugador)
		-- Servidor de juego: lo configuran los datos con los que llegó el primer jugador.
		if not estado.sala and Salas.esServidorDeSala() then
			local d = Salas.datosDeEntrada(jugador)
			if d then
				estado.sala = {
					tipo = d.tipo,
					codigo = d.sala,
					publica = d.publica ~= false,
					modo = d.modo == "sinfin" and "sinfin" or "historia",
					noche = math.clamp(math.floor(tonumber(d.noche) or 1), Config.Noche.NocheInicial, Config.Noche.NochesImplementadas),
					maximo = math.clamp(tonumber(d.maximo) or Config.Partida.MaxJugadores, d.tipo == "solo" and 1 or 2, Config.Partida.MaxJugadores),
					anfitrionId = d.anfitrionId,
					esperados = tonumber(d.esperados) or 1,
				}
				estado.fase, estado.modo = "reuniendo", "multi"
				-- Si alguien del equipo no llega, se empieza igual pasado un rato.
				task.delay(Config.Salas.EsperaEquipoSeg, function()
					if estado.fase == "reuniendo" then
						empezar("multi")
					end
				end)
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
		if estado.sala and estado.fase == "reuniendo" then
			estado.anfitrion = estado.anfitrion or jugador
			-- Partida en solitario o equipo completo: arranca el turno.
			if estado.sala.tipo == "solo" or #Players:GetPlayers() >= estado.sala.esperados then
				empezar(estado.sala.tipo == "solo" and "solo" or "multi")
			end
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
		if estado.fase == "lobby" or estado.fase == "reuniendo" then
			difundir()
		end
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end

	Players.PlayerRemoving:Connect(function(jugador)
		if enEntrada then
			-- Se fue del servidor de entrada: si no lo mandaron al juego, deja la sala de espera.
			salirDeSalaDeEspera(jugador)
			yaMandados[jugador] = nil
			task.defer(difundir)
			return
		end
		if estado.fase ~= "lobby" then
			return
		end
		if estado.anfitrion == jugador then
			-- El anfitrión se fue (modo local): pasa al siguiente.
			estado.anfitrion = nil
			for _, otro in Players:GetPlayers() do
				if otro ~= jugador then
					estado.anfitrion = otro
					break
				end
			end
			if not estado.anfitrion then
				estado.fase, estado.modo, estado.sala = "menu", nil, nil
			end
		end
		task.defer(difundir)
	end)

	if not Config.Partida.MenuActivo and not nube then
		task.spawn(function()
			while #Players:GetPlayers() == 0 do
				task.wait(0.5)
			end
			empezar("solo")
		end)
	end
end

return Partida
