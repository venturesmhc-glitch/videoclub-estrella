--!nonstrict
--[[
	TaskSystem (servidor) — Fase 2.
	Tareas del turno, compartidas por todo el equipo: atender clientes, rebobinar, reponer por género
	y separar cintas dañadas. También maneja las estaciones del local:
	  - Góndolas (tag "PuntoGondola", atributo Genero): sacar un casete que pidió un cliente o reponer uno.
	  - Videocasetera (tag "Videocasetera"): rebobinar (hay que mantener apretado).
	  - Caja de dañadas (tag "CajaDanadas"): separar cintas arrugadas.
	Cada estación tiene un solo prompt que actúa según lo que el jugador lleva en la mano.

	Cada cambio se manda a los clientes con TaskUpdate (ficha de socio).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightData = require(ReplicatedStorage.Shared.NightData)
local NightManager = require(script.Parent.NightManager)
local AnomalyJudge = require(script.Parent.AnomalyJudge)
local CursedTapeSystem = require(script.Parent.CursedTapeSystem)
local Prompts = require(script.Parent.Prompts)
local RulesSystem = require(script.Parent.RulesSystem)
local TapeItem = require(script.Parent.TapeItem)

local TaskSystem = {}

local rng = Random.new()
local tareas = {} -- lista ordenada de { id, texto, actual, meta }
local porId = {}
local perdidos = 0
local fuentePedido = nil -- función registrada por CustomerSystem
local pendiente = false
local avisadoCompleta = false

local function nombreGenero(genero)
	return Catalogo.Nombres[genero] or genero
end

--- CustomerSystem registra una función que devuelve el pedido actual del mostrador (o nil).
function TaskSystem.registrarFuentePedido(fn)
	fuentePedido = fn
end

function TaskSystem.pedidoActual()
	return fuentePedido and fuentePedido() or nil
end

local function tareasPublicas()
	local lista = {}
	for _, t in tareas do
		table.insert(lista, { id = t.id, texto = t.texto, actual = t.actual, meta = t.meta })
	end
	return lista
end

--- Manda el estado a todos los clientes (agrupa varios cambios seguidos en un solo envío).
function TaskSystem.sincronizar()
	if pendiente then
		return
	end
	pendiente = true
	task.defer(function()
		pendiente = false
		local remoto = Net.obtener("TaskUpdate")
		local pedido = TaskSystem.pedidoActual()
		local pedidoPublico = pedido and { tipo = pedido.tipo, genero = pedido.genero } or false
		local lista = tareasPublicas()
		for _, jugador in Players:GetPlayers() do
			local casete = TapeItem.enMano(jugador)
			remoto:FireClient(jugador, {
				tareas = lista,
				enMano = casete and {
					titulo = casete.titulo,
					genero = casete.genero,
					estado = casete.estado,
					rebobinado = casete.rebobinado,
					sinEtiqueta = casete.sinEtiqueta,
				} or false,
				pedido = pedidoPublico,
			})
		end
	end)
end

function TaskSystem.iniciarNoche(noche: number)
	table.clear(tareas)
	table.clear(porId)
	perdidos = 0
	avisadoCompleta = false
	local datos = NightManager.datosNoche() -- trae las tareas extra según la cantidad de jugadores
	for _, objetivo in (datos and datos.objetivos or {}) do
		local tarea = { id = objetivo.id, texto = objetivo.texto, actual = 0, meta = objetivo.meta }
		table.insert(tareas, tarea)
		porId[tarea.id] = tarea
	end
	TaskSystem.sincronizar()
end

function TaskSystem.registrar(id: string)
	local tarea = porId[id]
	if not tarea then
		return
	end
	tarea.actual += 1
	TaskSystem.sincronizar()

	if not avisadoCompleta then
		for _, t in tareas do
			if t.actual < t.meta then
				return
			end
		end
		avisadoCompleta = true
		Net.avisoATodos("Ficha completa. Aguantá hasta las 04:00.")
	end
end

function TaskSystem.registrarPerdido()
	perdidos += 1
end

function TaskSystem.resumen(): { string }
	local lineas = {}
	for _, t in tareas do
		table.insert(lineas, string.format("%s: %d/%d", t.texto, math.min(t.actual, t.meta), t.meta))
	end
	table.insert(lineas, "Clientes que se fueron sin atender: " .. perdidos)
	for _, linea in AnomalyJudge.lineasResumen() do
		table.insert(lineas, linea)
	end
	for _, linea in RulesSystem.lineasResumen() do
		table.insert(lineas, linea)
	end
	if TapeItem.llegoCintaSinEtiqueta() then
		table.insert(lineas, "Quedó un casete sin etiqueta en el local.")
	end
	return lineas
end

-- ===== Estaciones =====

--- Góndola de un género: repone el casete de la mano o saca uno que pidió el cliente del mostrador.
function TaskSystem.usarGondola(jugador: Player, genero: string)
	local casete = TapeItem.enMano(jugador)
	if casete then
		if casete.sinEtiqueta then
			Net.aviso(jugador, "No sabés en qué góndola va esta cinta.")
		elseif casete.estado == "danado" then
			Net.aviso(jugador, "Esa cinta está arrugada: va en la caja de dañadas.")
		elseif not casete.rebobinado then
			Net.aviso(jugador, "Primero hay que rebobinarla.")
		elseif casete.genero ~= genero then
			Net.aviso(jugador, string.format("Eso no es %s. Fijate el género de la carátula.", nombreGenero(genero)))
		else
			TapeItem.consumir(casete)
			if casete.estado == "anomalo" then
				-- Una cinta anómala vuelve a circular: contaminación. Nadie le avisa al jugador.
				AnomalyJudge.contaminar(jugador)
				NightManager.emitir("REPUSO_ANOMALA", { jugador = jugador })
			elseif not casete.alquiler then
				TaskSystem.registrar("reponer")
			end
			Net.aviso(jugador, "Repuesto: " .. casete.titulo)
		end
		return
	end

	local pedido = TaskSystem.pedidoActual()
	if pedido and pedido.tipo == "alquiler" then
		if pedido.genero ~= genero then
			Net.aviso(jugador, string.format("El cliente pidió %s, no %s.", nombreGenero(pedido.genero), nombreGenero(genero)))
		elseif pedido.casete and pedido.casete.vivo then
			Net.aviso(jugador, "Ya sacaste el casete que pidió el cliente.")
		else
			local nuevo = TapeItem.crear({
				titulo = Catalogo.tituloAleatorio(genero, rng),
				genero = genero,
				estado = "normal",
				rebobinado = true,
			})
			TapeItem.tomar(jugador, nuevo)
			pedido.asignarCasete(nuevo)
			Net.aviso(jugador, "Sacaste: " .. nuevo.titulo .. ". Llevaselo al cliente.")
		end
	else
		Net.aviso(jugador, "No tenés nada para reponer y nadie te pidió nada de este género.")
	end
end

--- Videocasetera: rebobina el casete de la mano.
function TaskSystem.usarVideocasetera(jugador: Player)
	local casete = TapeItem.enMano(jugador)
	if not casete then
		Net.aviso(jugador, "No tenés ningún casete en la mano.")
	elseif casete.sinEtiqueta then
		-- La cinta sin etiqueta no se rebobina: se reproduce.
		if not CursedTapeSystem.reproducir(jugador) then
			Net.aviso(jugador, "La cinta no responde.")
		end
	elseif casete.estado == "danado" then
		Net.aviso(jugador, "La cinta está arrugada: no se puede rebobinar. A la caja de dañadas.")
	elseif casete.rebobinado then
		Net.aviso(jugador, "Ya está rebobinado.")
	else
		casete.rebobinado = true
		TapeItem.actualizarEtiqueta(casete)
		if casete.estado == "normal" then
			TaskSystem.registrar("rebobinar")
		end
		Net.aviso(jugador, "Rebobinado: " .. casete.titulo)
	end
end

--- Caja de dañadas: separa una cinta arrugada.
function TaskSystem.usarCajaDanadas(jugador: Player)
	local casete = TapeItem.enMano(jugador)
	if not casete then
		Net.aviso(jugador, "No tenés ningún casete en la mano.")
	elseif casete.sinEtiqueta or casete.estado == "normal" then
		Net.aviso(jugador, "Esa cinta está bien: no va en la caja de dañadas.")
	else
		TapeItem.consumir(casete)
		TaskSystem.registrar("separar")
		Net.aviso(jugador, "Separada: " .. casete.titulo)
	end
end

local function puntoDe(parte: Instance): BasePart?
	return if parte:IsA("BasePart") then parte else nil
end

function TaskSystem.init()
	NightManager.suscribir("NOCHE_INICIA", function(datos)
		TaskSystem.iniciarNoche(datos.noche)
	end)
	NightManager.registrarResumen(TaskSystem.resumen)
	TapeItem.alCambiar(TaskSystem.sincronizar)

	for _, instancia in CollectionService:GetTagged("PuntoGondola") do
		local parte = puntoDe(instancia)
		local genero = instancia:GetAttribute("Genero")
		if parte and genero then
			Prompts.crear(parte, {
				clave = "gondola" .. genero,
				accion = "Usar góndola",
				objeto = nombreGenero(genero),
				alActivar = function(jugador)
					TaskSystem.usarGondola(jugador, genero)
				end,
			})
		end
	end

	for _, instancia in CollectionService:GetTagged("Videocasetera") do
		local parte = puntoDe(instancia)
		if parte then
			Prompts.crear(parte, {
				clave = "videocasetera",
				accion = "Rebobinar",
				objeto = "Videocasetera (rebobinar / reproducir)",
				hold = Config.Tareas.RebobinadoSeg,
				distancia = 4.5,
				alActivar = TaskSystem.usarVideocasetera,
			})
		end
	end

	for _, instancia in CollectionService:GetTagged("CajaDanadas") do
		local parte = puntoDe(instancia)
		if parte then
			Prompts.crear(parte, {
				clave = "danadas",
				accion = "Separar cinta",
				objeto = "Caja de dañadas",
				alActivar = TaskSystem.usarCajaDanadas,
			})
		end
	end

	-- Reenvío periódico: cubre a los jugadores que entran tarde.
	task.spawn(function()
		while true do
			task.wait(Config.Tareas.SincronizacionSeg)
			TaskSystem.sincronizar()
		end
	end)
end

return TaskSystem
