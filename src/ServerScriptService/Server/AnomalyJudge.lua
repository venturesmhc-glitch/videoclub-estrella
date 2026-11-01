--!nonstrict
--[[
	AnomalyJudge (servidor) — Fase 3.
	Valida las anomalías que el cliente de cada jugador dice haber detectado.

	Cada noche le manda a cada jugador una semilla (remote AnomalySeed); con la misma semilla, el mismo
	mapa y AnomalyCatalog.generar el servidor reconstruye la lista de anomalías de ese jugador y solo acepta
	reportes de anomalías que existen, que ya están activas y que no se resolvieron.

	  - Detectar una anomalía baja el progreso del Socio; dejarla sin detectar un minuto lo sube.
	  - "Contaminación": reponer en la góndola una cinta anómala (TaskSystem la avisa con AnomalyJudge.contaminar).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnomalyCatalog = require(ReplicatedStorage.Shared.AnomalyCatalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local SocioEntity = require(script.Parent.SocioEntity)

local AnomalyJudge = {}

local rng = Random.new()
local porJugador = {} -- Player -> { lista, resueltas, penalizadas, detectadas, falsos, contaminaciones }
local escena

local function generarPara(jugador: Player, noche: number)
	local semilla = jugador.UserId * 31 + noche * 7919 + rng:NextInteger(1, 1000000)
	local lista = AnomalyCatalog.generar(semilla, noche, escena)
	porJugador[jugador] = {
		semilla = semilla,
		noche = noche,
		lista = lista,
		resueltas = {},
		penalizadas = {},
		detectadas = 0,
		falsos = 0,
		contaminaciones = 0,
	}
	Net.obtener("AnomalySeed"):FireClient(jugador, { accion = "semilla", semilla = semilla, noche = noche })
end

local function buscar(datos, id: string)
	for _, anomalia in datos.lista do
		if anomalia.id == id then
			return anomalia
		end
	end
	return nil
end

local function alReportar(jugador: Player, paquete)
	if typeof(paquete) ~= "table" or not Net.limitar(jugador, "anomalia", 0.4) then
		return
	end
	local datos = porJugador[jugador]
	local estado = NightManager.obtenerEstado()
	if not datos or estado.fase ~= "turno" then
		return
	end
	if paquete.pedir then
		-- El cliente se enteró tarde (entró a mitad de turno o cargó después): se le reenvía la semilla.
		Net.obtener("AnomalySeed"):FireClient(jugador, { accion = "semilla", semilla = datos.semilla, noche = datos.noche })
		return
	end

	local anomalia = typeof(paquete.id) == "string" and buscar(datos, paquete.id) or nil
	if anomalia and estado.minuto >= anomalia.minuto and not datos.resueltas[anomalia.id] then
		datos.resueltas[anomalia.id] = true
		datos.detectadas += 1
		SocioEntity.agregarProgreso(Config.Socio.PorAnomaliaDetectada)
		Net.obtener("AnomalySeed"):FireClient(jugador, { accion = "resolver", id = anomalia.id })
		Net.aviso(jugador, string.format("Anomalía registrada (%d/%d).", datos.detectadas, #datos.lista))
	else
		-- Reporte sin anomalía real: tolerable unas pocas veces por noche.
		datos.falsos += 1
		if datos.falsos > Config.Anomalias.LimiteFalsosReportes then
			SocioEntity.agregarProgreso(0.02)
		end
		Net.aviso(jugador, "No hay nada raro ahí.")
	end
end

--- Procesa un reporte como si lo hubiera mandado el cliente (para pruebas).
function AnomalyJudge.reportar(jugador: Player, paquete)
	alReportar(jugador, paquete)
end

--- Reponer una cinta anómala por error (o dejarla circular): suma progreso al Socio.
function AnomalyJudge.contaminar(jugador: Player)
	local datos = porJugador[jugador]
	if datos then
		datos.contaminaciones += 1
	end
	SocioEntity.agregarProgreso(Config.Socio.PorContaminacion)
end

--- Líneas para el resumen de fin de turno (sumadas entre todos los jugadores).
function AnomalyJudge.lineasResumen(): { string }
	local total, detectadas, contaminaciones = 0, 0, 0
	for _, datos in porJugador do
		total += #datos.lista
		detectadas += datos.detectadas
		contaminaciones += datos.contaminaciones
	end
	local lineas = {}
	if total > 0 then
		table.insert(lineas, string.format("Anomalías detectadas: %d/%d", detectadas, total))
	end
	if contaminaciones > 0 then
		table.insert(lineas, "Cintas anómalas repuestas por error: " .. contaminaciones)
	end
	return lineas
end

function AnomalyJudge.estadoTexto(): string
	local partes = {}
	for jugador, datos in porJugador do
		table.insert(partes, string.format("%s: %d anomalías, %d detectadas, %d falsos, %d contaminaciones",
			jugador.Name, #datos.lista, datos.detectadas, datos.falsos, datos.contaminaciones))
	end
	return #partes > 0 and table.concat(partes, "\n") or "sin datos"
end

--- Para pruebas: lista de anomalías del jugador.
function AnomalyJudge.listaDe(jugador: Player)
	return porJugador[jugador] and porJugador[jugador].lista or {}
end

function AnomalyJudge.init()
	escena = AnomalyCatalog.escena()
	local escala = Config.Noche.DuracionMinutosJuego / Config.Noche.DuracionRealSegundos

	NightManager.suscribir("NOCHE_INICIA", function(datos)
		table.clear(porJugador)
		for _, jugador in Players:GetPlayers() do
			generarPara(jugador, datos.noche)
		end
	end)
	Players.PlayerAdded:Connect(function(jugador)
		local estado = NightManager.obtenerEstado()
		if estado.fase == "turno" then
			task.delay(2, generarPara, jugador, estado.noche)
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		porJugador[jugador] = nil
	end)
	Net.obtener("AnomalyReport").OnServerEvent:Connect(alReportar)

	-- Una anomalía que lleva un minuto (real) activa sin detectarse sube el progreso del Socio.
	task.spawn(function()
		while true do
			task.wait(5)
			local estado = NightManager.obtenerEstado()
			if estado.fase == "turno" then
				for _, datos in porJugador do
					for _, anomalia in datos.lista do
						if not datos.resueltas[anomalia.id] and not datos.penalizadas[anomalia.id]
							and estado.minuto >= anomalia.minuto + 60 * escala then
							datos.penalizadas[anomalia.id] = true
							SocioEntity.agregarProgreso(Config.Socio.PorAnomaliaNoDetectada)
						end
					end
				end
			end
		end
	end)
end

return AnomalyJudge
