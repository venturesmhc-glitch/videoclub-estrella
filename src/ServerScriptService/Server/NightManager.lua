--!strict
--[[
	NightManager (servidor) — Fase 2.
	Controla la noche actual, el reloj del juego, los eventos por horario y el inicio y fin de turno.

	El resto de los sistemas no lo llama: se suscriben a los eventos.
	  NightManager.suscribir("NOCHE_INICIA", function(datos) ... end)   -- datos = { noche }
	  NightManager.suscribir("NOCHE_TERMINA", function(datos) ... end)
	  NightManager.suscribir("CLIENTE" | "BUZON" | "CINTA_LLEGA", ...)   -- los define NightData

	El estado se manda a los clientes por el remote NightState, una vez por segundo y en cada cambio de fase.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local NightData = require(ReplicatedStorage.Shared.NightData)
local Net = require(ReplicatedStorage.Shared.Net)

local NightManager = {}

local estado = { noche = 1, minuto = 0, fase = "espera" }
local datosNocheActual: NightData.Noche? = nil -- la noche en curso, con las tareas extra según la cantidad de jugadores
local suscriptores: { [string]: { (any) -> () } } = {}
local eventos: { NightData.Evento } = {}
local siguienteEvento = 1
local proveedorResumen: (() -> { string })? = nil
local resumenActual: { string }? = nil
local proveedorNocheInicial: (() -> number?)? = nil
local generacion = 0 -- invalida los temporizadores de una noche anterior

local function emitir(id: string, datos: any)
	local lista = suscriptores[id]
	if not lista then
		return
	end
	for _, fn in lista do
		task.spawn(fn, datos)
	end
end

local function sincronizar(jugador: Player?)
	local noche = NightData[estado.noche]
	local paquete = {
		noche = estado.noche,
		minuto = estado.minuto,
		fase = estado.fase,
		titulo = noche and noche.titulo or nil,
		resumen = resumenActual,
	}
	local remoto = Net.obtener("NightState")
	if jugador then
		remoto:FireClient(jugador, paquete)
	else
		remoto:FireAllClients(paquete)
	end
end

local function terminarNoche(fracaso: boolean?)
	local miGeneracion = generacion -- antes de emitir: un final puede cancelar el reinicio (detenerTurno)
	estado.minuto = Config.Noche.DuracionMinutosJuego
	estado.fase = "fin"
	if fracaso then
		resumenActual = { "TE GRABARON.", "", "El turno se repite desde las 22:00." }
	else
		resumenActual = if proveedorResumen then proveedorResumen() else {}
	end
	emitir("NOCHE_TERMINA", { noche = estado.noche, fracaso = fracaso == true })
	sincronizar()

	task.delay(Config.Noche.PausaFinSeg, function()
		if generacion == miGeneracion then
			-- Si el equipo fracasó la noche se repite; si no, pasa a la siguiente (hasta la última implementada).
			local siguiente = if fracaso then estado.noche else math.min(estado.noche + 1, Config.Noche.NochesImplementadas)
			NightManager.iniciarNoche(siguiente)
		end
	end)
end

--- El equipo fracasó (por ejemplo, demasiadas capturas del Socio): la noche se repite.
function NightManager.fracasar()
	if estado.fase == "turno" then
		terminarNoche(true)
	end
end

--- Cierra el turno sin programar otra noche (lo usa EndingSystem al llegar a un final).
function NightManager.detenerTurno()
	generacion += 1
	if estado.fase == "turno" then
		estado.fase = "final"
		emitir("NOCHE_TERMINA", { noche = estado.noche, final = true })
	end
	estado.fase = "final"
	sincronizar()
end

--- Suscribe una función a un evento (ver la lista arriba).
function NightManager.suscribir(id: string, fn: (any) -> ())
	suscriptores[id] = suscriptores[id] or {}
	table.insert(suscriptores[id], fn)
end

--- Cualquier sistema puede emitir un evento propio (por ejemplo "REPUSO_ANOMALA") para que otros reaccionen.
function NightManager.emitir(id: string, datos: any)
	emitir(id, datos)
end

--- Un sistema registra cómo armar las líneas del resumen de fin de turno.
function NightManager.registrarResumen(fn: () -> { string })
	proveedorResumen = fn
end

--- La noche en curso (NightData ajustado a la cantidad de jugadores que había al empezar).
function NightManager.datosNoche()
	return datosNocheActual or NightData[estado.noche]
end

function NightManager.obtenerEstado()
	return table.clone(estado)
end

function NightManager.iniciarNoche(noche: number)
	generacion += 1
	estado.noche = noche
	estado.minuto = 0
	estado.fase = "turno"
	resumenActual = nil

	local datos = NightData.paraJugadores(noche, #Players:GetPlayers())
	datosNocheActual = datos
	eventos = datos and table.clone(datos.eventos) or {}
	table.sort(eventos, function(a, b)
		return a.minuto < b.minuto
	end)
	siguienteEvento = 1

	emitir("NOCHE_INICIA", { noche = noche })
	sincronizar()
end

--- Solo para pruebas: avanza el reloj hasta ese minuto (dispara los eventos que se saltea).
function NightManager.saltarA(minuto: number)
	if estado.fase == "turno" and minuto > estado.minuto then
		estado.minuto = minuto
	end
end

--- Persistencia registra de dónde sale la noche con la que arranca el servidor (la noche guardada).
function NightManager.registrarNocheInicial(fn: () -> number?)
	proveedorNocheInicial = fn
end

function NightManager.init()
	NightManager.suscribir("AVISO", function(datos)
		Net.avisoATodos(datos.texto)
	end)
	local escala = Config.Noche.DuracionMinutosJuego / Config.Noche.DuracionRealSegundos
	local acumulado = 0

	RunService.Heartbeat:Connect(function(dt)
		if estado.fase ~= "turno" then
			return
		end
		estado.minuto += dt * escala
		while eventos[siguienteEvento] and eventos[siguienteEvento].minuto <= estado.minuto do
			local evento = eventos[siguienteEvento]
			siguienteEvento += 1
			emitir(evento.id, evento.datos)
		end
		acumulado += dt
		if acumulado >= Config.Noche.IntervaloSincronizacionSeg then
			acumulado = 0
			sincronizar()
		end
		if estado.minuto >= Config.Noche.DuracionMinutosJuego then
			terminarNoche()
		end
	end)

	-- Un jugador que entra a mitad del turno recibe el estado enseguida.
	Players.PlayerAdded:Connect(function(jugador)
		task.delay(1, sincronizar, jugador)
	end)

	-- El turno no arranca solo: lo dispara Partida (menú de inicio) con NightManager.iniciarPartida().
end

--- Arranca el primer turno después de una breve espera: el de la noche indicada, o si no, el de la noche guardada del
--- primer jugador (o la primera). Una partida multijugador pasa la noche 1 para empezar de cero.
function NightManager.iniciarPartida(nocheForzada: number?)
	if estado.fase ~= "espera" then
		return
	end
	task.spawn(function()
		task.wait(Config.Noche.RetardoInicioSeg)
		local guardada = if nocheForzada then nocheForzada elseif proveedorNocheInicial then proveedorNocheInicial() else nil
		NightManager.iniciarNoche(guardada or Config.Noche.NocheInicial)
	end)
end

return NightManager
