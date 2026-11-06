--!nonstrict
--[[
	Persistencia (servidor) — Fase 7.
	DataStore por jugador: noche alcanzada, finales desbloqueados y cuántos empleados "menos" hay
	(el final REBOBINAR deja un nombre menos en la ficha).

	El servidor arranca en la noche guardada del primer jugador que entra. Si el DataStore no está disponible
	(por ejemplo en Studio sin "Allow Studio Access to API Services") se avisa una vez y se sigue con datos en memoria.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)

local Persistencia = {}

local NOMBRE_ALMACEN = "VideoclubEstrella_v1"
local almacen
local ranking -- OrderedDataStore con la mejor racha de cada jugador en Sin fin
local rankingLocal = {} -- UserId -> { nombre, valor }: lo que se vio en este servidor (también sirve si el almacén no está disponible)
local nombres = {} -- UserId -> nombre
local cacheRanking, cacheRankingT = nil, 0
local perfiles = {} -- Player -> perfil
local cargados = {} -- Player -> true cuando terminó de cargar (con datos o con los de por defecto)
local avisado = false

local function perfilNuevo()
	return { nocheAlcanzada = 1, finales = {}, empleadosMenos = 0, insignias = {}, mejorSinFin = 0, pistas = {}, colorLinterna = 1 }
end

local function tieneFinal(perfil): boolean
	return next(perfil.finales) ~= nil
end

-- Lo que ve el cliente de su perfil. "sinFinDesbloqueado": con cualquier final alcanzado se habilita el modo Sin fin.
local function paquetePerfil(perfil)
	return {
		nocheAlcanzada = perfil.nocheAlcanzada,
		finales = perfil.finales,
		empleadosMenos = perfil.empleadosMenos,
		insignias = perfil.insignias,
		mejorSinFin = perfil.mejorSinFin,
		colorLinterna = perfil.colorLinterna,
		sinFinDesbloqueado = tieneFinal(perfil),
	}
end

local function avisarSinAlmacen(motivo)
	if not avisado then
		avisado = true
		warn("[Persistencia] DataStore no disponible, se usan datos en memoria: " .. tostring(motivo))
	end
end

local function clave(jugador: Player): string
	return "J_" .. jugador.UserId
end

local function cargar(jugador: Player)
	local perfil = perfilNuevo()
	if almacen then
		for intento = 1, 3 do
			local ok, datos = pcall(function()
				return almacen:GetAsync(clave(jugador))
			end)
			if ok then
				if typeof(datos) == "table" then
					perfil.nocheAlcanzada = math.clamp(tonumber(datos.nocheAlcanzada) or 1, 1, Config.Noche.NochesImplementadas)
					perfil.finales = typeof(datos.finales) == "table" and datos.finales or {}
					perfil.empleadosMenos = tonumber(datos.empleadosMenos) or 0
					perfil.insignias = typeof(datos.insignias) == "table" and datos.insignias or {}
					perfil.mejorSinFin = tonumber(datos.mejorSinFin) or 0
					perfil.pistas = typeof(datos.pistas) == "table" and datos.pistas or {}
					perfil.colorLinterna = math.clamp(tonumber(datos.colorLinterna) or 1, 1, #Config.Tienda.ColoresLinterna)
				end
				break
			end
			avisarSinAlmacen(datos)
			task.wait(1)
		end
	end
	perfiles[jugador] = perfil
	cargados[jugador] = true
	Net.obtener("ProfileLoaded"):FireClient(jugador, paquetePerfil(perfil))
end

local function guardar(jugador: Player)
	local perfil = perfiles[jugador]
	if not perfil or not almacen then
		return
	end
	local ok, err = pcall(function()
		almacen:SetAsync(clave(jugador), perfil)
	end)
	if not ok then
		avisarSinAlmacen(err)
	end
end

local function enviarPerfil(jugador: Player)
	local perfil = perfiles[jugador]
	if perfil then
		Net.obtener("ProfileLoaded"):FireClient(jugador, paquetePerfil(perfil))
	end
end

--- Vuelve a mandarle al cliente su perfil (el menú lo pide al abrirse por si el primer envío le llegó antes de estar listo).
function Persistencia.enviarPerfil(jugador: Player)
	enviarPerfil(jugador)
end

--- ¿Alcanzó algún final? Eso habilita el modo Sin fin (el perfil puede no haber cargado todavía: en ese caso, no).
function Persistencia.sinFinDesbloqueado(jugador: Player): boolean
	local perfil = perfiles[jugador]
	return perfil ~= nil and tieneFinal(perfil)
end

--- Mejor racha de noches del modo Sin fin entre los jugadores presentes.
function Persistencia.mejorSinFin(): number
	local mejor = 0
	for _, perfil in perfiles do
		mejor = math.max(mejor, perfil.mejorSinFin)
	end
	return mejor
end

--- Anota la racha de este equipo (noches superadas seguidas) en el perfil de cada presente si supera su récord.
function Persistencia.registrarSinFin(superadas: number)
	for _, jugador in Players:GetPlayers() do
		local perfil = perfiles[jugador]
		if perfil and superadas > perfil.mejorSinFin then
			perfil.mejorSinFin = superadas
			enviarPerfil(jugador)
			task.spawn(guardar, jugador)
			rankingLocal[jugador.UserId] = { nombre = jugador.DisplayName, valor = superadas }
			nombres[jugador.UserId] = jugador.DisplayName
			cacheRanking = nil
			if ranking then
				task.spawn(function()
					pcall(function()
						ranking:SetAsync(tostring(jugador.UserId), superadas)
					end)
				end)
			end
		end
	end
end

local function nombreDe(userId: number): string
	if not nombres[userId] then
		local ok, nombre = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		nombres[userId] = ok and nombre or "???"
	end
	return nombres[userId]
end

--- Las 10 mejores rachas del modo Sin fin: { { nombre, valor } } de mayor a menor. Se guarda 30 s para no pedirlo seguido.
function Persistencia.ranking()
	if cacheRanking and os.clock() - cacheRankingT < 30 then
		return cacheRanking
	end
	local lista = {}
	if ranking then
		local ok, paginas = pcall(function()
			return ranking:GetSortedAsync(false, 10)
		end)
		if ok and paginas then
			local ok2, filas = pcall(function()
				return paginas:GetCurrentPage()
			end)
			if ok2 then
				for _, fila in filas do
					table.insert(lista, { nombre = nombreDe(tonumber(fila.key) or 0), valor = fila.value })
				end
			end
		end
	end
	if #lista == 0 then
		for _, fila in rankingLocal do
			table.insert(lista, fila)
		end
		table.sort(lista, function(a, b)
			return a.valor > b.valor
		end)
		while #lista > 10 do
			table.remove(lista)
		end
	end
	cacheRanking, cacheRankingT = lista, os.clock()
	return lista
end

--- Anota una insignia en el perfil. Devuelve true si era nueva (hay que avisarle al jugador), false si ya la tenía.
function Persistencia.marcarInsignia(jugador: Player, clave: string): boolean
	local perfil = perfiles[jugador]
	if not perfil or perfil.insignias[clave] then
		return false
	end
	perfil.insignias[clave] = true
	enviarPerfil(jugador)
	task.spawn(guardar, jugador)
	return true
end

--- Guarda el color de linterna elegido (índice en Config.Tienda.ColoresLinterna).
function Persistencia.fijarColorLinterna(jugador: Player, indice: number)
	local perfil = perfiles[jugador]
	if perfil and indice >= 1 and indice <= #Config.Tienda.ColoresLinterna then
		perfil.colorLinterna = indice
		enviarPerfil(jugador)
	end
end

--- Anota que ya se le mostró esta pista. Devuelve true si era la primera vez (hay que mostrarla), false si ya la había visto.
function Persistencia.marcarPista(jugador: Player, id: string): boolean
	local perfil = perfiles[jugador]
	if not perfil or perfil.pistas[id] then
		return false
	end
	perfil.pistas[id] = true
	return true -- se guarda con el resto del perfil al salir o al terminar la noche
end

--- Para pruebas: olvida las pistas vistas.
function Persistencia.olvidarPistas(jugador: Player)
	local perfil = perfiles[jugador]
	if perfil then
		perfil.pistas = {}
	end
end

--- Para pruebas: marca un final como alcanzado (habilita el modo Sin fin) sin pasar por el turno.
function Persistencia.marcarFinal(jugador: Player, id: string)
	local perfil = perfiles[jugador]
	if perfil then
		perfil.finales[id] = true
		enviarPerfil(jugador)
	end
end

--- ¿Tiene todos estos finales?
function Persistencia.tieneFinales(jugador: Player, ids: { string }): boolean
	local perfil = perfiles[jugador]
	if not perfil then
		return false
	end
	for _, id in ids do
		if not perfil.finales[id] then
			return false
		end
	end
	return true
end

--- Noche guardada del primer jugador (espera un poco a que termine de cargar).
function Persistencia.nocheInicial(): number?
	local inicio = os.clock()
	while os.clock() - inicio < 6 do
		local primero = Players:GetPlayers()[1]
		if primero and cargados[primero] then
			return perfiles[primero].nocheAlcanzada
		end
		task.wait(0.2)
	end
	return nil
end

--- Un final desbloquea ese final para todos los presentes y reinicia la partida desde la noche 1.
function Persistencia.registrarFinal(id: string)
	for _, jugador in Players:GetPlayers() do
		local perfil = perfiles[jugador]
		if perfil then
			perfil.finales[id] = true
			perfil.nocheAlcanzada = 1
			if id == "REBOBINAR" then
				perfil.empleadosMenos += 1
			end
			enviarPerfil(jugador)
			task.spawn(guardar, jugador)
		end
	end
end

function Persistencia.estadoTexto(): string
	local partes = {}
	for jugador, perfil in perfiles do
		local finales = {}
		for id in perfil.finales do
			table.insert(finales, id)
		end
		local insignias = {}
		for clave in perfil.insignias do
			table.insert(insignias, clave)
		end
		table.insert(partes, string.format("%s: noche %d, empleadosMenos %d, finales [%s], mejor Sin fin %d, insignias [%s]",
			jugador.Name, perfil.nocheAlcanzada, perfil.empleadosMenos, table.concat(finales, ","), perfil.mejorSinFin, table.concat(insignias, ",")))
	end
	return #partes > 0 and table.concat(partes, "\n") or "sin perfiles"
end

function Persistencia.init()
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore(NOMBRE_ALMACEN)
	end)
	if ok then
		almacen = resultado
	else
		avisarSinAlmacen(resultado)
	end

	pcall(function()
		ranking = DataStoreService:GetOrderedDataStore("VideoclubEstrella_SinFin_v1")
	end)
	Net.obtener("Ranking").OnServerEvent:Connect(function(jugador)
		if not Net.limitar(jugador, "ranking", 2) then
			return
		end
		task.spawn(function()
			local perfil = perfiles[jugador]
			Net.obtener("Ranking"):FireClient(jugador, { lista = Persistencia.ranking(), mio = perfil and perfil.mejorSinFin or 0 })
		end)
	end)

	NightManager.registrarNocheInicial(Persistencia.nocheInicial)
	NightManager.registrarRecordSinFin(Persistencia.mejorSinFin)

	Players.PlayerAdded:Connect(function(jugador)
		task.spawn(cargar, jugador)
	end)
	for _, jugador in Players:GetPlayers() do
		task.spawn(cargar, jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		guardar(jugador)
		perfiles[jugador], cargados[jugador] = nil, nil
	end)

	-- Al pasar una noche (sin fracasar ni llegar a un final) se guarda la siguiente.
	NightManager.suscribir("NOCHE_TERMINA", function(datos)
		if datos.fracaso or datos.final then
			return
		end
		if datos.modo == "sinfin" then
			-- Sin fin no avanza la noche guardada de la historia: solo cuenta la racha.
			Persistencia.registrarSinFin(datos.noche)
			return
		end
		local siguiente = math.min(datos.noche + 1, Config.Noche.NochesImplementadas)
		for _, jugador in Players:GetPlayers() do
			local perfil = perfiles[jugador]
			if perfil and siguiente > perfil.nocheAlcanzada then
				perfil.nocheAlcanzada = siguiente
				task.spawn(guardar, jugador)
			end
		end
	end)

	game:BindToClose(function()
		for _, jugador in Players:GetPlayers() do
			guardar(jugador)
		end
	end)
end

return Persistencia
