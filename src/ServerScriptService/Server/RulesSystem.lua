--!nonstrict
--[[
	RulesSystem (servidor) — Fase 6.
	Las notas de Darío pegadas en las paredes. Algunas son reglas verdaderas (romperlas tiene consecuencias)
	y otras son trampas (seguirlas tiene consecuencias). Las notas se agregan durante la noche (evento NOTAS)
	y el cliente las dibuja en los lugares marcados del local (tag "NotaSlot").

	Consecuencia: sube el progreso del Socio y las luces parpadean fuerte. Nadie le avisa al jugador cuál fue la regla.
	  R_TITULO   reponer una cinta anómala                       (evento REPUSO_ANOMALA)
	  R_INTERNO  atender el teléfono del depósito pasadas las 2:00 (evento INTERNO_ATENDIDO)
	  F_TV       apagar la tele del mostrador                     (evento TV_APAGADA)
	  R_NUMERO / F_SIEMPRE: atender al Socio disfrazado de cliente (evento SERVIDO_SOCIO; el progreso ya lo suma el mostrador)
	  R_FINAL / F_FINAL: pistas de los finales (no tienen consecuencia propia)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local SocioEntity = require(script.Parent.SocioEntity)

local RulesSystem = {}

local MINUTO_TELEFONO_INTERNO = 240 -- 02:00
local activas = {} -- id -> slot
local orden = {}
local rotas = 0
local slots = {} -- ids de los NotaSlot, ordenados

local function paquete()
	local lista = {}
	for _, id in orden do
		table.insert(lista, { id = id, slot = activas[id], texto = Catalogo.Reglas[id].texto })
	end
	return lista
end

local function enviar(accion: string, notas, jugador: Player?)
	local remoto = Net.obtener("RuleNotes")
	local datos = { accion = accion, notas = notas }
	if jugador then
		remoto:FireClient(jugador, datos)
	else
		remoto:FireAllClients(datos)
	end
end

function RulesSystem.activa(id: string): boolean
	return activas[id] ~= nil
end

--- Rompiste una regla verdadera o seguiste una falsa: el Socio se acerca y las luces parpadean.
local function consecuencia(jugador: Player?, id: string)
	rotas += 1
	SocioEntity.agregarProgreso(Config.Socio.PorRegla)
	Net.obtener("WorldEvent"):FireAllClients({ id = "FLICKER", valor = true })
end

function RulesSystem.lineasResumen(): { string }
	if rotas > 0 then
		return { "Notas de Darío mal interpretadas: " .. rotas }
	end
	return {}
end

function RulesSystem.estadoTexto(): string
	local ids = {}
	for _, id in orden do
		table.insert(ids, id)
	end
	return string.format("notas=[%s] rotas=%d", table.concat(ids, ","), rotas)
end

local function agregar(ids)
	local nuevas = {}
	for _, id in ids do
		if Catalogo.Reglas[id] and not activas[id] then
			local slot = slots[#orden + 1] or slots[(#orden % #slots) + 1]
			activas[id] = slot
			table.insert(orden, id)
			table.insert(nuevas, { id = id, slot = slot, texto = Catalogo.Reglas[id].texto, nueva = true })
		end
	end
	if #nuevas > 0 then
		enviar("agregar", nuevas)
		Net.avisoATodos("Hay una nota nueva pegada en el local.")
	end
end

function RulesSystem.init()
	for _, parte in CollectionService:GetTagged("NotaSlot") do
		table.insert(slots, parte:GetAttribute("SlotId"))
	end
	table.sort(slots)

	NightManager.suscribir("NOCHE_INICIA", function()
		table.clear(activas)
		table.clear(orden)
		rotas = 0
		enviar("limpiar", {})
	end)
	NightManager.suscribir("NOCHE_TERMINA", function()
		table.clear(activas)
		table.clear(orden)
		enviar("limpiar", {})
	end)
	NightManager.suscribir("NOTAS", function(datos)
		agregar(datos.ids)
	end)

	NightManager.suscribir("REPUSO_ANOMALA", function(datos)
		if activas.R_TITULO then
			consecuencia(datos.jugador, "R_TITULO")
		end
	end)
	NightManager.suscribir("INTERNO_ATENDIDO", function(datos)
		if activas.R_INTERNO and NightManager.obtenerEstado().minuto >= MINUTO_TELEFONO_INTERNO then
			consecuencia(datos.jugador, "R_INTERNO")
		end
	end)
	NightManager.suscribir("TV_APAGADA", function(datos)
		if activas.F_TV then
			consecuencia(datos.jugador, "F_TV")
		end
	end)
	NightManager.suscribir("SERVIDO_SOCIO", function(datos)
		if activas.R_NUMERO or activas.F_SIEMPRE then
			rotas += 1
			Net.obtener("WorldEvent"):FireAllClients({ id = "FLICKER", valor = true })
		end
	end)

	-- Quien entra a mitad del turno ve las notas que ya estaban.
	Players.PlayerAdded:Connect(function(jugador)
		task.delay(3, function()
			if #orden > 0 then
				enviar("agregar", paquete(), jugador)
			end
		end)
	end)
end

return RulesSystem
