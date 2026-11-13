--!nonstrict
--[[
	Criatura (servidor): la criatura de patas largas de las anomalías, UNA sola para todo el equipo.
	Camina por el techo y las paredes (Shared/Cascara) y persigue al jugador vivo más cercano, a ráfagas: repta, arremete y se
	congela un instante (Config.Anomalias.Reptar). Los clientes solo la dibujan (Client/CriaturaVista): ven todos lo mismo.

	  - Aparece Config.Anomalias.CriaturasPorNoche[noche] veces por noche, repartidas; si el Socio anda suelto espera a que se vaya
	    (una amenaza a la vez), y mientras la criatura está en juego el Socio no reaparece.
	  - Cualquier jugador cerca puede marcarla con Q (remote Criatura { marcar = true }): desaparece para todos, baja el progreso del Socio.
	  - Si nadie la marca, al alcanzar a alguien (o pasados VidaFiguraSeg) salta sobre el más cercano y le hace el jumpscare.

	  Criatura.activa() -> boolean       Criatura.forzar() -> hace aparecer una ahora (pruebas)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnomalyCatalog = require(ReplicatedStorage.Shared.AnomalyCatalog)
local Cascara = require(ReplicatedStorage.Shared.Cascara)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Fantasmas = require(script.Parent.Fantasmas)
local NightManager = require(script.Parent.NightManager)
local SocioEntity = require(script.Parent.SocioEntity)

local Criatura = {}

local cfg = Config.Anomalias.Reptar
local rng = Random.new()
local agenda = {} -- minutos de la noche en que le toca aparecer
local viva = nil -- estado de la criatura en juego (o nil)
local envioAcumulado = 0

local ENVIO_SEG = 1 / 20 -- posición hacia los clientes: 20 veces por segundo

local function raizDe(jugador: Player): BasePart?
	if Fantasmas.esFantasma(jugador) then
		return nil -- quien quedó fuera de la noche no es blanco
	end
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.Health > 0 then
		return personaje:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

local function cabezaDe(raiz: BasePart): Vector3
	return raiz.Position + Vector3.new(0, 1.5, 0)
end

-- Dónde está el cuerpo (el torso flota sobre la superficie en la dirección de su "arriba").
local function centroDe(c): Vector3
	return c.pos + Cascara.NORMAL[c.tramoSup] * Config.Anomalias.Aracnido.AlturaCuerpo
end

local function jugadorMasCercano(desde: Vector3): (Player?, BasePart?)
	local mejor, mejorRaiz, distancia = nil, nil, math.huge
	for _, jugador in Players:GetPlayers() do
		local raiz = raizDe(jugador)
		if raiz then
			local d = (cabezaDe(raiz) - desde).Magnitude
			if d < distancia then
				mejor, mejorRaiz, distancia = jugador, raiz, d
			end
		end
	end
	return mejor, mejorRaiz
end

local function hayJugadoresVivos(): boolean
	for _, jugador in Players:GetPlayers() do
		if raizDe(jugador) then
			return true
		end
	end
	return false
end

local function terminar(motivo: string)
	if not viva then
		return
	end
	viva = nil
	Net.obtener("Criatura"):FireAllClients({ accion = "fin", motivo = motivo })
end

local function aparecer()
	local escena = AnomalyCatalog.escena()
	local punto = Vector3.new(0, cfg.Techo, 0)
	if #escena.figuras > 0 then
		local instancia = escena.instancias[escena.figuras[rng:NextInteger(1, #escena.figuras)]]
		if instancia and instancia:IsA("BasePart") then
			punto = instancia.Position
		end
	end
	local pos = Cascara.puntoEn("T", Cascara.limitar(Vector3.new(punto.X, cfg.Techo, punto.Z)))
	local adelante = Vector3.new(0, 0, -1)
	local cf = Cascara.orientacion(pos, Cascara.NORMAL.T, adelante)
	viva = {
		pos = pos,
		cf = cf,
		superficie = "T",
		tramoSup = "T",
		camino = {},
		adelante = adelante,
		modo = "pausa",
		modoHasta = 0,
		siguienteCalculo = 0,
		comienzo = os.clock(),
		ataque = nil,
	}
	envioAcumulado = 0
	Net.obtener("Criatura"):FireAllClients({ accion = "aparece", cf = cf.Rotation + pos })
end

local function rango(r)
	return rng:NextNumber(r[1], r[2])
end

-- Salta sobre el jugador (rápido, con la cabeza por delante) y, al llegar, le dispara el jumpscare.
local function pasoAtaque(c, dt: number)
	local ahora = os.clock()
	local jugador = c.ataque.jugador
	local raiz = jugador and raizDe(jugador)
	if not raiz then
		terminar("sin objetivo")
		return
	end
	local arriba = Vector3.new(0, 1, 0)
	local mira = raiz.CFrame.LookVector
	local meta = cabezaDe(raiz) + mira * 3.0 - arriba * Config.Anomalias.Aracnido.AlturaCuerpo
	local falta = meta - c.pos
	local paso = cfg.VelocidadSalto * dt
	local llego = falta.Magnitude <= paso or ahora - c.ataque.t0 > 0.7
	if llego then
		c.pos = meta
	else
		c.pos += falta.Unit * paso
	end
	local hacia = Vector3.new(-mira.X, 0, -mira.Z)
	local objetivoCf = Cascara.orientacion(c.pos, arriba, if hacia.Magnitude > 0.01 then hacia else Vector3.new(0, 0, -1))
	c.cf = c.cf:Lerp(objetivoCf, 1 - math.exp(-24 * dt))
	if llego then
		Net.obtener("Screamer"):FireClient(jugador, { criatura = "aracnido" })
		terminar("ataque")
	end
end

local function paso(dt: number)
	local c = viva
	if not c then
		return
	end
	if c.ataque then
		pasoAtaque(c, dt)
	else
		local ahora = os.clock()
		local jugador, raiz = jugadorMasCercano(c.pos)
		local objetivo = raiz and cabezaDe(raiz) or nil

		-- Cada tanto vuelve a pensar el camino hacia el punto de la cáscara más cercano al jugador.
		if objetivo and ahora >= c.siguienteCalculo then
			c.siguienteCalculo = ahora + cfg.RecalculoSeg
			local dentro = Cascara.limitar(objetivo)
			local meta = Cascara.elegirSuperficie(dentro, c.superficie)
			c.camino = Cascara.armarCamino(c.superficie, c.pos, meta, Cascara.puntoEn(meta, dentro))
		end

		-- Se queda colgada un momento antes de empezar a andar; después, ráfagas.
		local puedeAndar = ahora - c.comienzo >= cfg.EsperaInicialSeg
		if puedeAndar and ahora >= c.modoHasta then
			if c.modo == "pausa" then
				if rng:NextNumber() < cfg.ProbArremetida then
					c.modo, c.modoHasta = "arremete", ahora + rango(cfg.ArremetidaSeg)
				else
					c.modo, c.modoHasta = "repta", ahora + rango(cfg.ReptarSeg)
				end
			else
				c.modo, c.modoHasta = "pausa", ahora + rango(cfg.PausaSeg)
			end
		end
		local velocidad = if c.modo == "arremete" then cfg.VelocidadArremetida elseif c.modo == "repta" then cfg.Velocidad else 0
		local tramo = c.camino[1]
		if puedeAndar and tramo and velocidad > 0 then
			local falta = tramo.hasta - c.pos
			local avance = velocidad * dt
			c.tramoSup = tramo.sup
			if falta.Magnitude <= avance then
				c.pos = tramo.hasta
				c.superficie = tramo.sup
				table.remove(c.camino, 1)
			else
				c.adelante = falta.Unit
				c.pos += c.adelante * avance
				c.superficie = tramo.sup
			end
		elseif objetivo then
			c.adelante = objetivo - c.pos -- quieta: mira hacia el jugador
		end

		-- La orientación sigue a la superficie y a la dirección con suavidad (en las esquinas "da la vuelta").
		local meta = Cascara.orientacion(c.pos, Cascara.NORMAL[c.tramoSup] or Cascara.NORMAL.T, c.adelante)
		c.cf = c.cf:Lerp(meta, 1 - math.exp(-cfg.Suavizado * dt))

		-- Si no se la marcó con Q: al alcanzar a alguien (o pasado su tiempo de vida) salta sobre el más cercano.
		if jugador and raiz then
			local cerca = (centroDe(c) - cabezaDe(raiz)).Magnitude < Config.Anomalias.Efecto.DistanciaToque
			if cerca or ahora - c.comienzo > Config.Anomalias.VidaFiguraSeg then
				c.ataque = { t0 = ahora, jugador = jugador }
				Net.obtener("Criatura"):FireAllClients({ accion = "ataca", objetivo = jugador.UserId })
			end
		elseif ahora - c.comienzo > Config.Anomalias.VidaFiguraSeg + 5 then
			terminar("sin objetivo") -- no queda nadie en pie
		end
	end

	if viva then
		envioAcumulado += dt
		if envioAcumulado >= ENVIO_SEG then
			envioAcumulado = 0
			Net.obtener("CriaturaPos"):FireAllClients(c.cf.Rotation + c.pos)
		end
	end
end

function Criatura.activa(): boolean
	return viva ~= nil
end

--- Para pruebas: hace aparecer una criatura ahora mismo (si no hay otra).
function Criatura.forzar()
	if not viva then
		aparecer()
	end
end

local function armarAgenda(noche: number)
	local lista = Config.Anomalias.CriaturasPorNoche
	local cantidad = lista[noche] or lista[#lista] or 0
	table.clear(agenda)
	local desde, hasta = Config.Anomalias.MinutoDesde + 10, Config.Anomalias.MinutoHasta
	for i = 1, cantidad do
		local tramo = (hasta - desde) / cantidad
		table.insert(agenda, desde + tramo * (i - 1) + tramo * rng:NextNumber(0.1, 0.9))
	end
end

function Criatura.estadoTexto(): string
	return string.format("criatura viva=%s agenda=%d", tostring(viva ~= nil), #agenda)
end

function Criatura.init()
	SocioEntity.agregarBloqueo(Criatura.activa) -- una amenaza a la vez: el Socio no reaparece mientras ella está en juego

	NightManager.suscribir("NOCHE_INICIA", function(datos)
		terminar("noche")
		armarAgenda(datos.noche)
	end)
	NightManager.suscribir("NOCHE_TERMINA", function()
		terminar("noche")
		table.clear(agenda)
	end)

	-- Marcarla con Q: la ven todos, así que la puede marcar cualquiera que la tenga cerca.
	Net.obtener("Criatura").OnServerEvent:Connect(function(jugador, paquete)
		if typeof(paquete) ~= "table" or paquete.marcar ~= true or not Net.limitar(jugador, "criaturaMarcar", 0.4) then
			return
		end
		local c = viva
		local raiz = raizDe(jugador)
		if not c or c.ataque or not raiz then
			return
		end
		if (centroDe(c) - cabezaDe(raiz)).Magnitude > Config.Anomalias.DistanciaMarcarCriatura then
			Net.aviso(jugador, "No hay nada raro ahí.")
			return
		end
		terminar("marcada")
		SocioEntity.agregarProgreso(Config.Socio.PorAnomaliaDetectada)
		Net.avisoATodos(jugador.DisplayName .. " marcó a la criatura.")
	end)

	-- Le toca aparecer cuando llega su minuto, si el Socio no anda suelto y queda alguien en pie.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local estado = NightManager.obtenerEstado()
			if estado.fase ~= "turno" then
				terminar("noche")
			elseif not viva and agenda[1] and estado.minuto >= agenda[1] and not SocioEntity.estaActivo() and hayJugadoresVivos() then
				table.remove(agenda, 1)
				aparecer()
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		paso(math.min(dt, 0.1))
	end)
end

return Criatura
