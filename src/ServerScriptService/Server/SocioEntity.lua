--!nonstrict
--[[
	SocioEntity (servidor) — Fase 5.
	El Socio N° 0000. No corre ni persigue: solo se mueve cuando ningún jugador lo está mirando.

	"Mirar" lo decide el servidor: cada cliente informa hacia dónde apunta su cámara (remote LookReport)
	y acá se valida (la cámara debe estar cerca de la cabeza del personaje) y se comprueba el cono de visión
	y la línea de visión con un raycast. Un reporte viejo no cuenta: quien deja de informar no "mira".

	Se mueve entre los Waypoints del local (tag "Waypoint"; los vecinos se calculan con raycasts).
	Su velocidad depende del "progreso": sube con la cinta, la contaminación y romper reglas; baja al detectar anomalías.
	Si llega a tocar a un jugador sin que nadie lo mire, lo "graba": susto (uno por noche como máximo),
	el jugador vuelve al mostrador aturdido y el Socio retrocede. Con CapturasMax capturas la noche fracasa.

	El peligro (0..1) por jugador se manda por el remote Danger y deforma el tracking del filtro VHS.

	API para los demás sistemas:
	  SocioEntity.activar(posicion?)            -- aparece (por defecto, lejos de todos los jugadores)
	  SocioEntity.desactivar()
	  SocioEntity.presentarseEn(posicion)       -- aparece ahí en cuanto nadie lo esté mirando
	  SocioEntity.agregarProgreso(delta)        -- ver Config.Socio.Por*
	  SocioEntity.ignorarMirada(jugador, bool)  -- quien mira una cinta no cuenta como "mirando"
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Personajes = require(ReplicatedStorage.Shared.Personajes)
local NightManager = require(script.Parent.NightManager)
local TapeItem = require(script.Parent.TapeItem)

local SocioEntity = {}

local cfg = Config.Socio
local rng = Random.new()

local modelo
local animacion
local alturaRaiz = 3 -- altura de la raíz del cuerpo sobre el piso (se mide al construirlo)
local ultimaPosicion = Vector3.zero
local ultimoPaso = 0
local activo = false
local posicion = Vector3.new(0, 0, -16) -- a nivel del piso
local rotacion = 0
local progreso = 0
local capturas = 0
local sustoUsado = false
local nodos = {} -- { pos, vecinos = {indices} }
local ruta = {}
local objetivo
local proximaRuta = 0
local miradas = {} -- Player -> { cf, t }
local ignorados = {} -- Player -> true
local ultimoPeligro = {} -- Player -> { valor, t }
local ultimoObservado = false

local ALTURA_CENTRO = 4.2 -- altura del torso respecto del piso

-- ===== Modelo =====

local function construirModelo()
	if modelo then
		return
	end
	-- Cuerpo humano, alto y oscuro, sin cara ni Humanoid: la raíz anclada se mueve con PivotTo y las animaciones siguen andando.
	modelo = Personajes.crear({
		piel = cfg.Color,
		ropa = cfg.Color,
		pantalon = cfg.Color,
		sinCara = true,
		escala = cfg.Escala,
	})
	assert(modelo, "[SocioEntity] no se pudo crear el cuerpo")
	modelo.Name = "Socio0000"
	Personajes.convertirEnTitere(modelo, cfg.Color)
	animacion = Personajes.animar(modelo)
	-- Altura de la raíz sobre el piso, para apoyar los pies en y = 0.
	alturaRaiz = modelo:GetAttribute("AlturaRaiz") or alturaRaiz
end

local function colocar()
	if not modelo then
		return
	end
	modelo:PivotTo(CFrame.new(posicion.X, alturaRaiz, posicion.Z) * CFrame.Angles(0, rotacion, 0))
	-- Camina mientras cambia de lugar; si no, queda quieto.
	if animacion then
		local ahora = os.clock()
		if (posicion - ultimaPosicion).Magnitude > 0.01 then
			ultimaPosicion = posicion
			ultimoPaso = ahora
			animacion.caminar(true)
		elseif ahora - ultimoPaso > 0.25 then
			animacion.caminar(false)
		end
	end
end

-- ===== Grafo de waypoints =====

local function construirGrafo()
	table.clear(nodos)
	for _, p in CollectionService:GetTagged("Waypoint") do
		table.insert(nodos, { pos = p.Position, vecinos = {} })
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for i = 1, #nodos do
		for j = i + 1, #nodos do
			local a, b = nodos[i], nodos[j]
			if (a.pos - b.pos).Magnitude <= 13 and not workspace:Raycast(a.pos, b.pos - a.pos, params) then
				table.insert(a.vecinos, j)
				table.insert(b.vecinos, i)
			end
		end
	end
end

local function nodoMasCercano(punto: Vector3): number?
	local mejor, distancia = nil, math.huge
	for i, n in nodos do
		local d = (Vector3.new(n.pos.X, 0, n.pos.Z) - Vector3.new(punto.X, 0, punto.Z)).Magnitude
		if d < distancia then
			mejor, distancia = i, d
		end
	end
	return mejor
end

-- Dijkstra sobre el grafo (son pocas decenas de nodos).
local function calcularRuta(desde: Vector3, hasta: Vector3)
	local inicio, fin = nodoMasCercano(desde), nodoMasCercano(hasta)
	if not inicio or not fin then
		return { hasta }
	end
	local dist, previo, pendientes = {}, {}, {}
	for i = 1, #nodos do
		dist[i] = math.huge
		pendientes[i] = true
	end
	dist[inicio] = 0
	while true do
		local actual, mejor = nil, math.huge
		for i in pendientes do
			if dist[i] < mejor then
				actual, mejor = i, dist[i]
			end
		end
		if not actual or actual == fin then
			break
		end
		pendientes[actual] = nil
		for _, v in nodos[actual].vecinos do
			local nuevo = dist[actual] + (nodos[actual].pos - nodos[v].pos).Magnitude
			if nuevo < dist[v] then
				dist[v], previo[v] = nuevo, actual
			end
		end
	end
	local camino = { Vector3.new(hasta.X, 0, hasta.Z) }
	local i = fin
	while i do
		table.insert(camino, 1, Vector3.new(nodos[i].pos.X, 0, nodos[i].pos.Z))
		i = previo[i]
	end
	-- Si desde acá se ve el segundo nodo, no hace falta volver al primero (evita ir y venir al recalcular).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { modelo }
	local origen = Vector3.new(desde.X, 3, desde.Z)
	while #camino >= 2 do
		local siguiente = Vector3.new(camino[2].X, 3, camino[2].Z)
		if workspace:Raycast(origen, siguiente - origen, params) then
			break
		end
		table.remove(camino, 1)
	end
	return camino
end

-- ===== Mirada =====

local function personajes(): { Instance }
	local lista = { modelo }
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(lista, j.Character)
		end
	end
	return lista
end

local function observadoPor(jugador: Player, params: RaycastParams): boolean
	local info = miradas[jugador]
	if ignorados[jugador] or not info or os.clock() - info.t > cfg.LookVencimientoSeg then
		return false
	end
	local camara = info.cf
	local blanco = Vector3.new(posicion.X, ALTURA_CENTRO, posicion.Z)
	local hacia = blanco - camara.Position
	if hacia.Magnitude < 0.1 then
		return true
	end
	if camara.LookVector:Dot(hacia.Unit) < math.cos(math.rad(cfg.AnguloVision)) then
		return false
	end
	return workspace:Raycast(camara.Position, hacia, params) == nil
end

local function alguienLoMira(): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = personajes()
	for _, jugador in Players:GetPlayers() do
		if observadoPor(jugador, params) then
			return true
		end
	end
	return false
end

-- ===== Utilidades =====

local function raizDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.Health > 0 then
		return personaje:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

local function distanciaPlana(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function nodoMasLejanoDeTodos(): Vector3
	local mejor, mejorDist = nodos[1] and nodos[1].pos or Vector3.new(0, 0, -16), -1
	for _, n in nodos do
		local minimo = math.huge
		for _, j in Players:GetPlayers() do
			local raiz = raizDe(j)
			if raiz then
				minimo = math.min(minimo, distanciaPlana(n.pos, raiz.Position))
			end
		end
		if minimo ~= math.huge and minimo > mejorDist then
			mejor, mejorDist = n.pos, minimo
		end
	end
	return Vector3.new(mejor.X, 0, mejor.Z)
end

local function velocidad(): number
	return cfg.VelocidadBase + cfg.VelocidadPorProgreso * math.clamp(progreso, 0, cfg.ProgresoMax) / cfg.ProgresoMax
end

-- ===== API =====

function SocioEntity.estaActivo(): boolean
	return activo
end

function SocioEntity.posicion(): Vector3
	return posicion
end

function SocioEntity.progreso(): number
	return progreso
end

function SocioEntity.capturas(): number
	return capturas
end

function SocioEntity.agregarProgreso(delta: number)
	progreso = math.clamp(progreso + delta, 0, cfg.ProgresoMax)
end

function SocioEntity.ignorarMirada(jugador: Player, valor: boolean)
	ignorados[jugador] = valor or nil
end

function SocioEntity.activar(donde: Vector3?)
	construirModelo()
	posicion = donde and Vector3.new(donde.X, 0, donde.Z) or nodoMasLejanoDeTodos()
	ruta = {}
	activo = true
	colocar()
	modelo.Parent = workspace
end

function SocioEntity.desactivar()
	activo = false
	ruta = {}
	objetivo = nil
	if modelo then
		modelo.Parent = nil
	end
	for _, jugador in Players:GetPlayers() do
		Net.obtener("Danger"):FireClient(jugador, 0)
	end
end

--- Aparece en ese punto en cuanto ningún jugador lo esté mirando (no se "teletransporta" a la vista de nadie).
function SocioEntity.presentarseEn(donde: Vector3)
	task.spawn(function()
		local generacion = NightManager.obtenerEstado().noche
		for _ = 1, 100 do
			if NightManager.obtenerEstado().fase ~= "turno" or NightManager.obtenerEstado().noche ~= generacion then
				return
			end
			if not activo or not alguienLoMira() then
				break
			end
			task.wait(0.3)
		end
		SocioEntity.activar(donde)
	end)
end

local function capturar(jugador: Player)
	capturas += 1
	local raiz = raizDe(jugador)
	local personaje = jugador.Character

	if not sustoUsado then
		sustoUsado = true
		Net.obtener("Scare"):FireClient(jugador)
	end

	-- La cinta que llevaba vuelve al mostrador (no se pierde).
	local casete = TapeItem.enMano(jugador)
	if casete then
		TapeItem.colocar(casete, CFrame.new(Config.Casetes.PosicionMostrador) * CFrame.Angles(math.rad(90), 0, 0))
	end

	local inicio = workspace:FindFirstChild("SpawnLocation")
	if personaje and inicio then
		personaje:PivotTo(CFrame.new(inicio.Position + Vector3.new(0, 3, 0)))
	end
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.WalkSpeed = 0
		humanoide.JumpHeight = 0
		task.delay(cfg.AturdimientoSeg, function()
			if humanoide.Parent then
				humanoide.WalkSpeed = Config.Jugador.VelocidadCaminar
				humanoide.JumpHeight = Config.Jugador.AlturaSalto
			end
		end)
	end
	Net.avisoATodos(string.format("%s fue grabado.", jugador.DisplayName))

	-- El Socio retrocede lejos y baja un poco la presión.
	SocioEntity.agregarProgreso(cfg.PorCaptura)
	posicion = nodoMasLejanoDeTodos()
	ruta = {}
	colocar()

	if capturas >= cfg.CapturasMax then
		NightManager.fracasar()
	end
end

-- ===== Bucle =====

local function actualizarRuta()
	local mejor, distancia = nil, math.huge
	for _, jugador in Players:GetPlayers() do
		local raiz = raizDe(jugador)
		if raiz then
			local d = distanciaPlana(raiz.Position, posicion)
			if d < distancia then
				mejor, distancia = jugador, d
			end
		end
	end
	objetivo = mejor
	if not mejor then
		ruta = {}
		return
	end
	local destino = raizDe(mejor).Position
	if distancia < 9 then
		ruta = { Vector3.new(destino.X, 0, destino.Z) }
	else
		ruta = calcularRuta(posicion, destino)
	end
end

local function mover(dt: number)
	local restante = velocidad() * dt
	while restante > 0 and #ruta > 0 do
		local delta = ruta[1] - posicion
		local largo = delta.Magnitude
		if largo <= restante then
			posicion = ruta[1]
			table.remove(ruta, 1)
			restante -= largo
		else
			posicion += delta.Unit * restante
			restante = 0
		end
		if largo > 0.05 then
			rotacion = math.atan2(-delta.X, -delta.Z)
		end
	end
	colocar()
end

local function enviarPeligro(observado: boolean)
	local ahora = os.clock()
	for _, jugador in Players:GetPlayers() do
		local valor = 0
		local raiz = raizDe(jugador)
		if activo and raiz then
			local d = distanciaPlana(raiz.Position, posicion)
			valor = math.clamp(1 - d / cfg.DistanciaPeligro, 0, 1) ^ 1.4
			if not observado and d < 25 then
				valor = math.min(1, valor + 0.15)
			end
		end
		local previo = ultimoPeligro[jugador]
		if not previo or math.abs(previo.valor - valor) > 0.02 or ahora - previo.t > 1 then
			ultimoPeligro[jugador] = { valor = valor, t = ahora }
			Net.obtener("Danger"):FireClient(jugador, valor)
		end
	end
end

function SocioEntity.estadoTexto(): string
	return string.format(
		"socio activo=%s pos=(%.1f, %.1f) progreso=%.2f capturas=%d velocidad=%.2f observado=%s ruta=%d",
		tostring(activo), posicion.X, posicion.Z, progreso, capturas, velocidad(), tostring(ultimoObservado), #ruta
	)
end

function SocioEntity.init()
	construirGrafo()

	NightManager.suscribir("NOCHE_INICIA", function(datos)
		SocioEntity.desactivar()
		progreso = cfg.PorNoche[datos.noche] or cfg.PorNoche[#cfg.PorNoche]
		capturas = 0
		sustoUsado = false
	end)
	NightManager.suscribir("NOCHE_TERMINA", SocioEntity.desactivar)
	NightManager.suscribir("SOCIO_ACTIVA", function()
		if not activo then
			SocioEntity.activar()
		end
	end)

	-- Lo que informa cada cliente: hacia dónde apunta su cámara.
	Net.obtener("LookReport").OnServerEvent:Connect(function(jugador, camara)
		if typeof(camara) ~= "CFrame" or not Net.limitar(jugador, "mirada", 0.08) then
			return
		end
		local personaje = jugador.Character
		local cabeza = personaje and personaje:FindFirstChild("Head")
		if cabeza and (cabeza.Position - camara.Position).Magnitude <= cfg.LookToleranciaCamara then
			miradas[jugador] = { cf = camara, t = os.clock() }
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		miradas[jugador], ignorados[jugador], ultimoPeligro[jugador] = nil, nil, nil
	end)

	task.spawn(function()
		local ultimoPeligroEnvio = 0
		while true do
			task.wait(cfg.TickSeg)
			local enTurno = NightManager.obtenerEstado().fase == "turno"
			local observado = enTurno and activo and alguienLoMira()
			ultimoObservado = observado

			if enTurno and activo and not observado then
				if os.clock() >= proximaRuta then
					proximaRuta = os.clock() + cfg.RecalcularRutaSeg
					actualizarRuta()
				end
				mover(cfg.TickSeg)
				for _, jugador in Players:GetPlayers() do
					local raiz = raizDe(jugador)
					if raiz and distanciaPlana(raiz.Position, posicion) < cfg.DistanciaCaptura then
						capturar(jugador)
						break
					end
				end
			end

			if os.clock() - ultimoPeligroEnvio >= Config.Socio.PeligroEnvioSeg then
				ultimoPeligroEnvio = os.clock()
				enviarPeligro(observado)
			end
		end
	end)
end

return SocioEntity
