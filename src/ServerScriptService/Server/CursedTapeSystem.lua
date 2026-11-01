--!nonstrict
--[[
	CursedTapeSystem (servidor) — Fase 4.
	La cinta sin etiqueta. Al reproducirla (videocasetera, con la cinta en la mano) el jugador ve el local
	desde arriba de las estanterías, un lugar donde no hay cámara. La cinta muestra información, pero cada
	reproducción hace avanzar al Socio.

	El servidor decide qué muestra la cinta (la "predicción": un punto del local y cuándo se cumple) y la
	hace realidad: pasado el retardo, el Socio se presenta en ese punto. La vista la arma el cliente.

	Mientras mira la cinta el jugador queda quieto y no cuenta como "mirando" al Socio.
	En la noche 5 la cinta dura más: verla entera sin cortarla es el final "Mirar" (callback registrado por EndingSystem).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local SocioEntity = require(script.Parent.SocioEntity)

local CursedTapeSystem = {}

local cfg = Config.Cinta
local rng = Random.new()
local viendo = {} -- Player -> { token }
local espectadores = 0
local alCompletarFinal = nil
local pantallas = {} -- partes con el tag "TV"
local reproducciones = 0 -- en la noche

local function actualizarTV()
	for _, pantalla in pantallas do
		pantalla:SetAttribute("Modo", espectadores > 0 and "CINTA" or "")
	end
end

local function elegirPrediccion()
	local puntos = CollectionService:GetTagged("PuntoFigura")
	if #puntos == 0 then
		return nil
	end
	table.sort(puntos, function(a, b)
		return a:GetAttribute("FiguraId") < b:GetAttribute("FiguraId")
	end)
	local punto = puntos[rng:NextInteger(1, #puntos)]
	local estado = NightManager.obtenerEstado()
	local escala = Config.Noche.DuracionMinutosJuego / Config.Noche.DuracionRealSegundos
	return {
		figuraId = punto:GetAttribute("FiguraId"),
		zona = punto:GetAttribute("Zona"),
		posicion = Vector3.new(punto.Position.X, 0, punto.Position.Z),
		retardoSeg = cfg.RetardoPrediccionSeg,
		minutoFuturo = math.min(estado.minuto + cfg.RetardoPrediccionSeg * escala, Config.Noche.DuracionMinutosJuego),
	}
end

local function liberar(jugador: Player, completa: boolean)
	local sesion = viendo[jugador]
	if not sesion then
		return
	end
	viendo[jugador] = nil
	espectadores = math.max(0, espectadores - 1)
	actualizarTV()
	SocioEntity.ignorarMirada(jugador, false)

	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.WalkSpeed = Config.Jugador.VelocidadCaminar
		humanoide.JumpHeight = Config.Jugador.AlturaSalto
	end
	if jugador.Parent then
		Net.obtener("TapeSession"):FireClient(jugador, { accion = "fin", completa = completa })
	end
	if completa and sesion.final and alCompletarFinal then
		alCompletarFinal(jugador)
	end
end

--- Un jugador reproduce la cinta. Devuelve false si ya la está viendo.
function CursedTapeSystem.reproducir(jugador: Player): boolean
	if viendo[jugador] then
		return false
	end
	local estado = NightManager.obtenerEstado()
	if estado.fase ~= "turno" then
		return false
	end

	local final = estado.noche == 5
	local duracion = final and cfg.DuracionFinalSeg or cfg.DuracionSeg
	local prediccion = elegirPrediccion()
	local token = {}
	viendo[jugador] = { token = token, final = final }
	espectadores += 1
	reproducciones += 1
	actualizarTV()
	SocioEntity.ignorarMirada(jugador, true)

	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.WalkSpeed = 0
		humanoide.JumpHeight = 0
	end

	Net.obtener("TapeSession"):FireClient(jugador, {
		accion = "inicio",
		duracion = duracion,
		noche = estado.noche,
		minuto = estado.minuto,
		prediccion = prediccion,
		final = final,
	})

	-- Cada reproducción hace avanzar al Socio, y lo que mostró la cinta se cumple pasado el retardo.
	SocioEntity.agregarProgreso(Config.Socio.PorCinta)
	if prediccion then
		local noche = estado.noche
		task.delay(prediccion.retardoSeg, function()
			if NightManager.obtenerEstado().noche == noche and NightManager.obtenerEstado().fase == "turno" then
				SocioEntity.presentarseEn(prediccion.posicion)
				Net.avisoATodos("Algo se movió " .. prediccion.zona .. ".")
			end
		end)
	end

	task.delay(duracion, function()
		local sesion = viendo[jugador]
		if sesion and sesion.token == token then
			liberar(jugador, true)
		end
	end)
	return true
end

function CursedTapeSystem.alCompletarFinal(fn)
	alCompletarFinal = fn
end

function CursedTapeSystem.reproducciones(): number
	return reproducciones
end

function CursedTapeSystem.init()
	for _, pantalla in CollectionService:GetTagged("TV") do
		table.insert(pantallas, pantalla)
	end

	Net.obtener("TapeSession").OnServerEvent:Connect(function(jugador, datos)
		if typeof(datos) == "table" and datos.accion == "detener" and viendo[jugador] then
			liberar(jugador, false)
		end
	end)

	NightManager.suscribir("NOCHE_INICIA", function()
		reproducciones = 0
	end)
	NightManager.suscribir("NOCHE_TERMINA", function()
		for jugador in viendo do
			liberar(jugador, false)
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		liberar(jugador, false)
	end)
end

return CursedTapeSystem
