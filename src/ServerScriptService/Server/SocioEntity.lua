--!nonstrict
--[[
	SocioEntity (servidor) — Fase 5.
	El Socio N° 0000. Lleva la lógica (ruta, velocidad, capturas) y publica su posición y giro en atributos del modelo: el esqueleto lo anima cada cliente (Client/SocioAnimacion, porque Bone.Transform no se replica); cuando algún jugador lo mira con la linterna prendida apuntándole se arrastra a una fracción de su velocidad (Config.Socio.VelocidadMirado); mirarlo sin luz no lo frena.

	"Mirar" lo decide el servidor: cada cliente informa hacia dónde apunta su cámara (remote LookReport)
	y acá se valida (la cámara debe estar cerca de la cabeza del personaje) y se comprueba el cono de visión
	y la línea de visión con un raycast. Un reporte viejo no cuenta: quien deja de informar no "mira".

	Se mueve entre los Waypoints del local (tag "Waypoint"; los vecinos se calculan con raycasts).
	Su velocidad depende del "progreso": sube con la cinta, la contaminación y romper reglas; baja al detectar anomalías.
	Si llega a tocar a un jugador sin que nadie lo mire, lo "graba": susto (uno por noche como máximo),
	el jugador vuelve al mostrador aturdido y el Socio retrocede. A la segunda captura (Config.Socio.CapturasPorJugador) ese jugador queda fuera de la noche y aparece como fantasma en
	el motel (Fantasmas); cuando caen todos, la noche fracasa.

	Rework (IA de caza): cada aparición pasa por fases. ACECHO (te sigue desde lejos, se queda quieto si lo mirás y reaparece más cerca cuando
	mirás para otro lado), CAZA (ruge, corre con embestidas; solo la linterna lo frena) y BUSQUEDA (si te pierde, va al último lugar donde te
	vio u oyó: correr sin necesidad te delata). Valores en Config.Socio.

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
local Fantasmas = require(script.Parent.Fantasmas)
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
local esMalla = false -- true si el cuerpo es la criatura generada con IA
local conHuesos = false -- el cuerpo trae esqueleto: lo anima cada cliente (Client/SocioAnimacion), porque Bone.Transform no se replica
local temblor = CFrame.new()
local pasoAcumulado = 0
local activo = false
local posicion = Vector3.new(0, 0, -16) -- a nivel del piso
local rotacion = 0
local progreso = 0
local capturas = 0 -- total de la noche (para el estado de depuración)
local capturasDe = {} -- Player -> veces que lo agarró esta noche
local amuletos = {} -- Player -> true si lleva un amuleto (absorbe la próxima captura; se compra en la tienda)
local pausadoHasta = 0 -- mientras os.clock() sea menor, el Socio queda congelado (pausa de cinta de la tienda)
local activoDesde = 0 -- cuándo empezó la aparición actual (cada una dura Config.Socio.PersecucionSeg)
local ciclo = false -- la noche ya lo activó: después de irse vuelve a aparecer cada tanto
local reaparecerEn: number? = nil
local sinCapturaHasta = 0 -- mientras os.clock() sea menor, el Socio no puede capturar a nadie
local sustoUsado = false
local nodos = {} -- { pos, vecinos = {indices} }
local ruta = {}
local objetivo
local proximaRuta = 0
local miradas = {} -- Player -> { cf, t }
local ignorados = {} -- Player -> true
local ultimoPeligro = {} -- Player -> { valor, t }
local ultimoObservado = false
local fase = "acecho" -- "acecho" | "caza" | "busqueda"
local faseDesde = 0
local faseHasta = 0
local aparicionDesde = 0
local ultimaVista: Vector3? = nil -- dónde sintió (vio u oyó) por última vez a un jugador
local sinSentirDesde = 0
local proximaReposicion = 0
local proximaEmbestida = 0
local embestida = nil -- { fase = "aviso" | "carga", hasta }
local miradoDesde: number? = nil -- desde cuándo lo está mirando alguien (acecho)
local visitasBusqueda = 0
local pausaBusquedaHasta = 0
local ultimoSentido = 0
local destinoBusqueda: Vector3? = nil
local huboMirada = false
local proximaRutaIA = 0

local ALTURA_CENTRO = 4.2 -- altura del torso respecto del piso

-- ===== Modelo =====

local function construirModelo()
	if modelo then
		return
	end
	-- Primero la criatura generada con IA (una sola malla, sin animaciones: se mueve a tirones y se congela cuando la miran).
	local malla = Personajes.crearSocioMalla(cfg)
	if modelo then
		return -- otra llamada lo terminó de armar mientras se cargaba la malla
	end
	if malla then
		modelo = malla
		modelo.Name = "Socio0000"
		esMalla = true
		alturaRaiz = 0.02
		if malla:GetAttribute("ConHuesos") then
			conHuesos = true
		end
		return
	end
	-- Respaldo: cuerpo humano, alto y oscuro, sin cara ni Humanoid: la raíz anclada se mueve con PivotTo y las animaciones siguen andando.
	modelo = Personajes.crear({
		piel = cfg.Color,
		ropa = cfg.Color,
		pantalon = cfg.Color,
		sinCara = true,
		escala = cfg.Escala,
		ancho = cfg.Ancho,
		cabeza = cfg.Cabeza,
		proporcion = cfg.Proporcion,
		ojos = cfg.ColorOjos,
	})
	assert(modelo, "[SocioEntity] no se pudo crear el cuerpo")
	modelo.Name = "Socio0000"
	Personajes.convertirEnTitere(modelo, cfg.Color)
	animacion = Personajes.animar(modelo)
	-- Altura de la raíz sobre el piso, para apoyar los pies en y = 0.
	alturaRaiz = modelo:GetAttribute("AlturaRaiz") or alturaRaiz
end

-- salto: aparece de golpe en `posicion` (no se desliza desde donde estaba).
local function colocar(salto: boolean?)
	if not modelo then
		return
	end
	if esMalla then
		-- Cada paso lo sacude un poco (tiritón).
		if (posicion - ultimaPosicion).Magnitude > 0.01 then
			ultimaPosicion = posicion
			temblor = CFrame.Angles(math.rad(rng:NextNumber(-1.5, 1.5)), math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-1.5, 1.5)))
		end
		if conHuesos then
			-- Cada cliente dibuja el cuerpo suavizado hacia estos atributos (posición y giro lógicos); un salto lo planta ya mismo.
			modelo:PivotTo(CFrame.new(posicion.X, alturaRaiz, posicion.Z) * CFrame.Angles(0, rotacion, 0))
			modelo:SetAttribute("SocioPos", Vector3.new(posicion.X, alturaRaiz, posicion.Z))
			modelo:SetAttribute("SocioRot", rotacion)
			if salto then
				modelo:SetAttribute("SocioSalto", (modelo:GetAttribute("SocioSalto") or 0) + 1)
			end
		else
			modelo:PivotTo(CFrame.new(posicion.X, alturaRaiz, posicion.Z) * CFrame.Angles(0, rotacion, 0) * temblor)
		end
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
		elseif ahora - ultimoPaso > cfg.PasoSeg * 1.6 then
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
			-- Se conectan si un cuerpo de ~2,6 de ancho pasa de uno al otro (una esfera, no un rayo fino que se cuela entre las góndolas).
			if (a.pos - b.pos).Magnitude <= 9.5 and not workspace:Spherecast(a.pos, 1.3, b.pos - a.pos, params) then
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

-- conLuz: además de mirarlo, lo tiene que estar alumbrando con la linterna prendida (centrado en el haz y al alcance de la luz).
local function observadoPor(jugador: Player, params: RaycastParams, conLuz: boolean?): boolean
	local info = miradas[jugador]
	if ignorados[jugador] or not info or os.clock() - info.t > cfg.LookVencimientoSeg then
		return false
	end
	if conLuz and not info.luz then
		return false
	end
	local camara = info.cf
	local blanco = Vector3.new(posicion.X, ALTURA_CENTRO, posicion.Z)
	local hacia = blanco - camara.Position
	if hacia.Magnitude < 0.1 then
		return true
	end
	local angulo = conLuz and cfg.LinternaAngulo or cfg.AnguloVision
	if camara.LookVector:Dot(hacia.Unit) < math.cos(math.rad(angulo)) then
		return false
	end
	if conLuz and hacia.Magnitude > cfg.LinternaAlcance then
		return false
	end
	return workspace:Raycast(camara.Position, hacia, params) == nil
end

local function alguienLoMira(conLuz: boolean?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = personajes()
	for _, jugador in Players:GetPlayers() do
		if not Fantasmas.esFantasma(jugador) and observadoPor(jugador, params, conLuz) then
			return true
		end
	end
	return false
end

-- ===== Utilidades =====

local function raizDe(jugador: Player): BasePart?
	if Fantasmas.esFantasma(jugador) then
		return nil -- fuera de la noche: no es blanco del Socio, no cuenta como "mirando" ni recibe aviso de peligro
	end
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

local function presion(): number
	return math.clamp(progreso / cfg.ProgresoMax, 0, 1)
end

local function velocidad(): number
	local caza = cfg.VelocidadBase + cfg.VelocidadPorProgreso * presion()
	if fase == "acecho" then
		return caza * cfg.AcechoVelocidad
	elseif fase == "busqueda" then
		return caza * 0.6
	end
	return caza
end

-- ===== IA: sentidos, emboscadas y fases =====

local function raicesVivas(): { BasePart }
	local lista = {}
	for _, j in Players:GetPlayers() do
		local r = raizDe(j)
		if r then
			table.insert(lista, r)
		end
	end
	return lista
end

local function paramsVista(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = personajes()
	return params
end

-- ¿Algún jugador vivo tendría línea de visión hasta ese punto (sin importar hacia dónde mire)?
local function aVistaDeAlguien(punto: Vector3, params: RaycastParams): boolean
	local alto = Vector3.new(punto.X, 4, punto.Z)
	for _, raiz in raicesVivas() do
		local ojos = raiz.Position + Vector3.new(0, 1.5, 0)
		if (ojos - alto).Magnitude < 75 and not workspace:Raycast(ojos, alto - ojos, params) then
			return true
		end
	end
	return false
end

-- Jugador vivo más cercano (en el plano).
local function masCercano(): (Player?, BasePart?, number)
	local mejor, mejorRaiz, d = nil, nil, math.huge
	for _, j in Players:GetPlayers() do
		local r = raizDe(j)
		if r then
			local dj = distanciaPlana(r.Position, posicion)
			if dj < d then
				mejor, mejorRaiz, d = j, r, dj
			end
		end
	end
	return mejor, mejorRaiz, d
end

-- Un lugar donde aparecer: fuera de la vista de todos, a una distancia razonable del jugador de referencia (o de todos), y de
-- preferencia a la espalda de quien está mirando. Sin candidatos, relaja las condiciones y al final cae en el punto más lejano.
local function puntoEmboscada(referencia: BasePart?, desde: number?, hasta: number?): Vector3
	local lo, hi = desde or cfg.EmboscadaDist[1], hasta or cfg.EmboscadaDist[2]
	local params = paramsVista()
	local raices = raicesVivas()
	for intento = 1, 3 do
		local candidatos = {}
		for _, n in nodos do
			local p = Vector3.new(n.pos.X, 0, n.pos.Z)
			local dmin = math.huge
			if referencia then
				dmin = distanciaPlana(p, referencia.Position)
			else
				for _, r in raices do
					dmin = math.min(dmin, distanciaPlana(p, r.Position))
				end
			end
			local rango = intento == 1 and 1 or (intento == 2 and 0.6 or 0.3)
			if dmin ~= math.huge and dmin >= lo * rango and dmin <= hi / rango then
				if not aVistaDeAlguien(p, params) then
					local puntaje = rng:NextNumber()
					for jugador, info in miradas do
						local raiz = raizDe(jugador)
						if raiz and os.clock() - info.t < 2 then
							local hacia = Vector3.new(p.X - raiz.Position.X, 0, p.Z - raiz.Position.Z)
							local mira = Vector3.new(info.cf.LookVector.X, 0, info.cf.LookVector.Z)
							if hacia.Magnitude > 0.1 and mira.Magnitude > 0.1 and hacia.Unit:Dot(mira.Unit) < -0.2 then
								puntaje += 0.6 -- a la espalda
							end
						end
					end
					table.insert(candidatos, { p = p, puntaje = puntaje })
				end
			end
		end
		if #candidatos > 0 then
			table.sort(candidatos, function(a, b)
				return a.puntaje > b.puntaje
			end)
			return candidatos[math.min(#candidatos, rng:NextInteger(1, 3))].p
		end
	end
	return nodoMasLejanoDeTodos()
end

-- Lo que siente del jugador más cercano: lo ve (línea de visión a menos de VisionSocio) o lo oye (pasos, más lejos si corre).
local function sentir(): (Player?, Vector3?, boolean)
	local params = paramsVista()
	local origen = Vector3.new(posicion.X, 6, posicion.Z)
	local mejor, mejorPos, mejorVe, mejorD = nil, nil, false, math.huge
	for _, j in Players:GetPlayers() do
		local r = raizDe(j)
		if r then
			local d = distanciaPlana(r.Position, posicion)
			local v = r.AssemblyLinearVelocity
			local rapido = Vector3.new(v.X, 0, v.Z).Magnitude > 15
			local ve = d <= cfg.VisionSocio and not workspace:Raycast(origen, (r.Position + Vector3.new(0, 1, 0)) - origen, params)
			local oye = d <= (rapido and cfg.OidoCorriendo or cfg.OidoCaminando)
			if (ve or oye) and d < mejorD then
				mejor, mejorPos, mejorVe, mejorD = j, r.Position, ve, d
			end
		end
	end
	return mejor, mejorPos, mejorVe
end

local function entrarFase(nueva: string, suave: boolean?)
	local ahora = os.clock()
	fase = nueva
	faseDesde = ahora
	embestida = nil
	local p = presion()
	if nueva == "acecho" then
		faseHasta = ahora + rng:NextNumber(cfg.AcechoSeg[1], cfg.AcechoSeg[2]) * (1 - (1 - cfg.TensionAcecho) * p)
		proximaReposicion = ahora + rng:NextNumber(cfg.AcechoReposicionSeg[1], cfg.AcechoReposicionSeg[2])
		miradoDesde = nil
	elseif nueva == "caza" then
		faseHasta = ahora + rng:NextNumber(cfg.CazaSeg[1], cfg.CazaSeg[2]) * (1 + (cfg.TensionCaza - 1) * p)
		proximaEmbestida = ahora + rng:NextNumber(3, 5)
		ultimoSentido = ahora
		sinCapturaHasta = math.max(sinCapturaHasta, ahora + 0.8)
		Net.obtener("SocioEvento"):FireAllClients(suave and "hallazgo" or "rugido")
	elseif nueva == "busqueda" then
		faseHasta = ahora + cfg.BusquedaSeg
		visitasBusqueda = 0
		pausaBusquedaHasta = 0
		destinoBusqueda = ultimaVista
		ruta = {}
	end
	if modelo then
		modelo:SetAttribute("SocioFase", fase)
	end
end

-- Camino hacia un punto: recto si se ve, por los waypoints si no.
local function rutaHacia(destino: Vector3)
	local d = distanciaPlana(destino, posicion)
	local de = Vector3.new(posicion.X, 3, posicion.Z)
	local a = Vector3.new(destino.X, 3, destino.Z)
	if d < 9 and not workspace:Raycast(de, a - de, paramsVista()) then
		ruta = { Vector3.new(destino.X, 0, destino.Z) }
	else
		ruta = calcularRuta(posicion, destino)
	end
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
	posicion = donde and Vector3.new(donde.X, 0, donde.Z) or puntoEmboscada()
	ruta = {}
	local yaEstaba = activo
	activo = true
	activoDesde = os.clock()
	aparicionDesde = activoDesde
	ultimaVista = nil
	huboMirada = false
	entrarFase("acecho")
	sinCapturaHasta = math.max(sinCapturaHasta, os.clock() + cfg.GraciaAparicionSeg)
	ciclo = true -- desde ahora, durante la noche, va y viene: 30 s presente y un rato afuera
	reaparecerEn = nil
	colocar(true)
	modelo.Parent = workspace
	if not yaEstaba then
		Net.obtener("SocioPresencia"):FireAllClients(true)
	end
end

function SocioEntity.desactivar()
	local estaba = activo
	activo = false
	ciclo = false
	fase = "acecho"
	reaparecerEn = nil
	ruta = {}
	objetivo = nil
	if modelo then
		modelo.Parent = nil
	end
	for _, jugador in Players:GetPlayers() do
		Net.obtener("Danger"):FireClient(jugador, 0)
	end
	if estaba then
		Net.obtener("SocioPresencia"):FireAllClients(false)
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

-- Después de agarrar a alguien se esfuma: reaparece pasado un rato (PostCapturaSeg), lejos y fuera de la vista (nunca pegado al que acaba de volver).
local function irseTrasCaptura()
	SocioEntity.desactivar()
	ciclo = true
	sinCapturaHasta = os.clock() + cfg.GraciaCapturaSeg
	reaparecerEn = os.clock() + rng:NextNumber(cfg.PostCapturaSeg[1], cfg.PostCapturaSeg[2])
end

local function capturar(jugador: Player)
	if amuletos[jugador] then
		-- El amuleto se rompe y se lleva la captura: no cuenta, el Socio retrocede y el jugador sigue donde estaba.
		amuletos[jugador] = nil
		jugador:SetAttribute("Amuleto", nil)
		Net.avisoATodos(string.format("El amuleto de %s se rompió.", jugador.DisplayName))
		SocioEntity.agregarProgreso(cfg.PorCaptura)
		irseTrasCaptura()
		return
	end
	capturas += 1
	local veces = (capturasDe[jugador] or 0) + 1
	capturasDe[jugador] = veces
	local fuera = veces >= cfg.CapturasPorJugador
	local personaje = jugador.Character

	if not sustoUsado then
		sustoUsado = true
		Net.obtener("Scare"):FireClient(jugador)
	end
	-- Screamer de la captura: el Socio te abre la cara en la cara (animado en Client/Screamers).
	Net.obtener("Screamer"):FireClient(jugador, { captura = true })

	-- La cinta que llevaba vuelve al mostrador (no se pierde).
	local casete = TapeItem.enMano(jugador)
	if casete then
		TapeItem.colocar(casete, CFrame.new(Config.Casetes.PosicionMostrador) * CFrame.Angles(math.rad(90), 0, 0))
	end

	if fuera then
		-- Segunda captura: queda fuera de la noche. Suelta lo que lleve y pasa a ser un fantasma en el motel.
		NightManager.emitir("JUGADOR_FUERA", { jugador = jugador })
		Fantasmas.convertir(jugador)
		Net.avisoATodos(string.format("%s fue grabado (%d/%d) y quedó atrapado en la cinta.", jugador.DisplayName, veces, cfg.CapturasPorJugador))
	else
		local inicio = workspace:FindFirstChild("SpawnLocation")
		if personaje and inicio then
			personaje:PivotTo(CFrame.new(inicio.Position + Vector3.new(0, 3, 0)))
		end
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if humanoide then
			humanoide.WalkSpeed = 0
			humanoide.JumpHeight = 0
			task.delay(cfg.AturdimientoSeg, function()
				if humanoide.Parent and not Fantasmas.esFantasma(jugador) then
					humanoide.WalkSpeed = Config.Jugador.VelocidadCaminar
					humanoide.JumpHeight = Config.Jugador.AlturaSalto
				end
			end)
		end
		Net.avisoATodos(string.format("%s fue grabado (%d/%d).", jugador.DisplayName, veces, cfg.CapturasPorJugador))
	end

	-- El Socio retrocede lejos y baja un poco la presión.
	SocioEntity.agregarProgreso(cfg.PorCaptura)
	irseTrasCaptura()

	-- Si ya no queda nadie en pie, la noche fracasa.
	for _, otro in Players:GetPlayers() do
		if not Fantasmas.esFantasma(otro) then
			return
		end
	end
	NightManager.fracasar()
end

--- Le da un amuleto a un jugador (dura hasta que absorbe una captura o termina la noche). Devuelve false si ya lo tenía.
function SocioEntity.darAmuleto(jugador: Player): boolean
	if amuletos[jugador] then
		return false
	end
	amuletos[jugador] = true
	jugador:SetAttribute("Amuleto", true)
	return true
end

function SocioEntity.tieneAmuleto(jugador: Player): boolean
	return amuletos[jugador] == true
end

--- Congela al Socio ese tiempo (no se mueve ni captura). Sirve aunque todavía no esté en el local: no pasa nada.
function SocioEntity.pausar(segundos: number)
	pausadoHasta = math.max(pausadoHasta, os.clock() + segundos)
end

--- Vuelve a jugar un espectador (compró el revivir): sus capturas de la noche empiezan de nuevo.
function SocioEntity.revivirJugador(jugador: Player)
	capturasDe[jugador] = nil
	Fantasmas.revivir(jugador)
end

--- Para pruebas: cuenta una captura de ese jugador como si el Socio lo hubiera agarrado.
function SocioEntity.capturarJugador(jugador: Player)
	capturar(jugador)
end

-- ===== Bucle =====

-- Gira hacia un punto (cuando está quieto te mira de frente).
local function encarar(punto: Vector3)
	local d = Vector3.new(punto.X - posicion.X, 0, punto.Z - posicion.Z)
	if d.Magnitude > 0.1 then
		rotacion = math.atan2(-d.X, -d.Z)
	end
end

-- Un "pensamiento" de la IA (cada TickSeg). Devuelve el factor de movimiento (0 = se queda parado) y si la aparición terminó.
local function pensar(observado: boolean, alumbrado: boolean): (number, boolean)
	local ahora = os.clock()
	local jugadorSentido, posSentida, ve = sentir()
	if posSentida then
		ultimaVista = posSentida
		ultimoSentido = ahora
	end
	local _, raizCercana, distancia = masCercano()
	if not raizCercana then
		ruta = {}
		return 0, false
	end

	if fase == "acecho" then
		-- Mirarlo lo deja clavado en el lugar (y te mira). Cuando dejás de mirarlo, pronto reaparece más cerca.
		local mirado = alguienLoMira()
		if mirado then
			huboMirada = true
			miradoDesde = miradoDesde or ahora
			ruta = {}
		else
			if huboMirada then
				huboMirada = false
				proximaReposicion = math.min(proximaReposicion, ahora + rng:NextNumber(0.9, 2.4))
			end
			miradoDesde = nil
		end
		if ahora >= faseHasta or (not mirado and distancia <= cfg.AcechoPasaACazaDist) then
			entrarFase("caza")
			return 0, false
		end
		if mirado then
			encarar(raizCercana.Position)
			return 0, false
		end
		if ahora >= proximaReposicion and distancia > cfg.AcechoPasaACazaDist + 3 then
			proximaReposicion = ahora + rng:NextNumber(cfg.AcechoReposicionSeg[1], cfg.AcechoReposicionSeg[2])
			posicion = puntoEmboscada(raizCercana, math.max(cfg.AcechoPasaACazaDist + 1.5, distancia - 12), distancia - 4)
			ruta = {}
			colocar(true)
			return 0, false
		end
		if ahora >= proximaRutaIA then
			proximaRutaIA = ahora + cfg.RecalcularRutaSeg
			rutaHacia(raizCercana.Position)
		end
		if distancia > cfg.AcechoDistancia[2] then
			return 1, false
		elseif distancia > cfg.AcechoDistancia[1] then
			return 0.5, false
		end
		encarar(raizCercana.Position)
		return 0.2, false

	elseif fase == "caza" then
		if ahora - ultimoSentido > cfg.PerdidaSeg and ultimaVista then
			entrarFase("busqueda")
			return 0, false
		end
		if ahora >= proximaRutaIA then
			proximaRutaIA = ahora + 0.6
			if jugadorSentido and posSentida then
				rutaHacia(posSentida)
			elseif ultimaVista then
				rutaHacia(ultimaVista)
			end
		end
		-- Embestida: se queda quieto un instante (aviso: la cabeza salta hacia vos) y se lanza.
		local factor = 1
		if embestida then
			if ahora >= embestida.hasta then
				if embestida.fase == "aviso" then
					embestida = { fase = "carga", hasta = ahora + cfg.EmbestidaSeg }
					Net.obtener("SocioEvento"):FireAllClients("embiste")
				else
					embestida = nil
					proximaEmbestida = ahora + rng:NextNumber(cfg.EmbestidaCada[1], cfg.EmbestidaCada[2])
				end
			end
			if embestida then
				factor = embestida.fase == "aviso" and 0 or cfg.EmbestidaFactor
				if embestida.fase == "aviso" then
					encarar(raizCercana.Position)
				end
				if embestida.fase == "carga" and ve and posSentida then
					rutaHacia(posSentida)
				end
			end
		elseif ahora >= proximaEmbestida and ve and distancia >= cfg.EmbestidaDist[1] and distancia <= cfg.EmbestidaDist[2] and not alumbrado then
			embestida = { fase = "aviso", hasta = ahora + cfg.EmbestidaAvisoSeg }
			Net.obtener("SocioEvento"):FireAllClients("aviso")
		end
		-- Fin de la caza: se va, salvo que alguien siga muy cerca (entonces sigue un rato más).
		if ahora >= faseHasta then
			if distancia <= cfg.CazaExtiendeDist and ahora < faseHasta + 12 then
				return factor, false
			end
			return factor, true
		end
		return factor, false

	else -- busqueda
		if jugadorSentido then
			entrarFase("caza", true)
			return 0, false
		end
		if ahora >= faseHasta then
			entrarFase("acecho")
			return 0, false
		end
		if ahora < pausaBusquedaHasta then
			ruta = {}
			return 0, false
		end
		if destinoBusqueda and distanciaPlana(destinoBusqueda, posicion) < 3 then
			-- Llegó: olfatea un rato y elige otro lugar cerca de donde te sintió por última vez.
			pausaBusquedaHasta = ahora + rng:NextNumber(1.4, 2.6)
			visitasBusqueda += 1
			local origen = ultimaVista or posicion
			local candidatos = {}
			for _, n in nodos do
				local p = Vector3.new(n.pos.X, 0, n.pos.Z)
				if distanciaPlana(p, origen) < 26 and distanciaPlana(p, posicion) > 6 then
					table.insert(candidatos, p)
				end
			end
			destinoBusqueda = #candidatos > 0 and candidatos[rng:NextInteger(1, #candidatos)] or origen
			ruta = {}
			proximaRutaIA = 0
			return 0, false
		end
		if ahora >= proximaRutaIA and destinoBusqueda then
			proximaRutaIA = ahora + 1
			rutaHacia(destinoBusqueda)
		end
		return 1, false
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
			if fase == "caza" then
				valor = math.min(1, valor + 0.2) -- en plena caza el cuerpo ya lo sabe
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
		"socio activo=%s fase=%s pos=(%.1f, %.1f) progreso=%.2f capturas=%d velocidad=%.2f observado=%s ruta=%d",
		tostring(activo), fase, posicion.X, posicion.Z, progreso, capturas, velocidad(), tostring(ultimoObservado), #ruta
	)
end

function SocioEntity.init()
	Fantasmas.init()
	construirGrafo()
	task.spawn(construirModelo) -- precarga la malla (tarda un poco) para que activar() no espere

	NightManager.suscribir("NOCHE_INICIA", function(datos)
		SocioEntity.desactivar()
		-- Pasada la última noche de la historia (modo Sin fin) el Socio arranca un poco más rápido cada noche.
		local pasadas = math.max(0, datos.noche - #cfg.PorNoche)
		progreso = math.min(cfg.ProgresoMax, (cfg.PorNoche[datos.noche] or cfg.PorNoche[#cfg.PorNoche]) + pasadas * Config.SinFin.ProgresoSocioPorNoche)
		capturas = 0
		table.clear(capturasDe)
		for jugador in amuletos do
			jugador:SetAttribute("Amuleto", nil)
		end
		table.clear(amuletos)
		pausadoHasta = 0
		sustoUsado = false
		sinCapturaHasta = 0
	end)
	-- Llega la cinta sin etiqueta: un buen rato sin capturas para que el equipo la agarre y la mire.
	NightManager.suscribir("CINTA_LLEGA", function()
		sinCapturaHasta = math.max(sinCapturaHasta, os.clock() + cfg.GraciaCintaSeg)
	end)
	NightManager.suscribir("NOCHE_TERMINA", function(datos)
		SocioEntity.desactivar()
		-- Los que quedaron fuera siguen de espectadores en la noche siguiente (se vuelve con Robux); solo si el equipo
		-- entero cayó y la noche se repite, todos empiezan de nuevo.
		if datos and datos.fracaso then
			Fantasmas.reviverTodos()
		end
	end)
	NightManager.suscribir("SOCIO_ACTIVA", function()
		if not activo then
			SocioEntity.activar()
		end
	end)

	-- Lo que informa cada cliente: hacia dónde apunta su cámara.
	Net.obtener("LookReport").OnServerEvent:Connect(function(jugador, camara, linterna)
		if typeof(camara) ~= "CFrame" or not Net.limitar(jugador, "mirada", 0.08) then
			return
		end
		local personaje = jugador.Character
		local cabeza = personaje and personaje:FindFirstChild("Head")
		if cabeza and (cabeza.Position - camara.Position).Magnitude <= cfg.LookToleranciaCamara then
			miradas[jugador] = { cf = camara, t = os.clock(), luz = linterna == true }
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		miradas[jugador], ignorados[jugador], ultimoPeligro[jugador], capturasDe[jugador] = nil, nil, nil, nil
		amuletos[jugador] = nil
	end)

	task.spawn(function()
		local ultimoPeligroEnvio = 0
		local ultimoPresionEnvio = 0
		while true do
			task.wait(cfg.TickSeg)
			local enTurno = NightManager.obtenerEstado().fase == "turno"
			-- Cada aparición pasa por fases (acecho, caza, búsqueda); al terminar se va y vuelve a aparecer pasado un rato, más corto con la presión.
			local terminar = false
			local factorFase = 0
			if enTurno and activo then
				factorFase, terminar = pensar(false, false)
			end
			if enTurno and activo and (terminar or os.clock() - aparicionDesde >= cfg.AparicionMaxSeg) then
				SocioEntity.desactivar()
				ciclo = true
				reaparecerEn = os.clock() + rng:NextNumber(cfg.EntreApariciones[1], cfg.EntreApariciones[2]) * (1 - (1 - cfg.TensionEntreMin) * presion())
			elseif enTurno and not activo and ciclo and reaparecerEn and os.clock() >= reaparecerEn then
				SocioEntity.activar()
			end
			local observado = enTurno and activo and (alguienLoMira() or os.clock() < pausadoHasta)
			ultimoObservado = observado
			-- Solo lo frena la linterna: mirarlo sin luz no sirve. Alumbrado, se arrastra más lento (y sus pasos también) y se paraliza de cara.
			local alumbrado = observado and alguienLoMira(true)
			local factor = alumbrado and cfg.VelocidadMirado or 1
			if animacion then
				animacion.ralentizar(factor)
			end

			if enTurno and activo then
				-- La pausa de cinta de la tienda lo congela por completo (no se mueve ni captura).
				local pausado = os.clock() < pausadoHasta
				if pausado then
					factorFase = 0
				end
				-- Avanza a tirones: acumula el tiempo y da un paso de golpe, no se desliza.
				pasoAcumulado += cfg.TickSeg
				if pasoAcumulado >= cfg.PasoSeg then
					mover(pasoAcumulado * factor * factorFase)
					pasoAcumulado = 0
				end
				for _, jugador in Players:GetPlayers() do
					local raiz = raizDe(jugador)
					if raiz and not pausado and os.clock() >= sinCapturaHasta and distanciaPlana(raiz.Position, posicion) < cfg.DistanciaCaptura then
						capturar(jugador)
						break
					end
				end
			end

			if conHuesos and modelo then
				-- Lo único que le hace falta al cliente para animarlo (lo demás lo calcula él): si lo están alumbrando, se queda de cara.
				modelo:SetAttribute("SocioAlumbrado", alumbrado == true)
			end

			-- La presión (el progreso, sin número) alimenta los bordes de la pantalla: una vez por segundo alcanza.
			if enTurno and os.clock() - ultimoPresionEnvio >= 1 then
				ultimoPresionEnvio = os.clock()
				Net.obtener("Presion"):FireAllClients(math.clamp(progreso / cfg.ProgresoMax, 0, 1))
			end

			if os.clock() - ultimoPeligroEnvio >= Config.Socio.PeligroEnvioSeg then
				ultimoPeligroEnvio = os.clock()
				enviarPeligro(observado)
			end
		end
	end)
end

return SocioEntity
