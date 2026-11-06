--!nonstrict
--[[
	Pistas (servidor): consejos cortos en pantalla, justo cuando hace falta, una sola vez por perfil (se guardan en el perfil).
	Reemplazan al tutorial en bloque: el jugador aprende cada cosa cuando aparece por primera vez.

	  Pistas.dar(jugador, id)      -- se la muestra si nunca la vio
	  Pistas.darATodos(id)
	  Pistas.TEXTOS[id]            -- el texto (en español; el cliente lo traduce)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local Persistencia = require(script.Parent.Persistencia)
local TapeItem = require(script.Parent.TapeItem)

local Pistas = {}

Pistas.TEXTOS = {
	CASETE = "Llevás un casete. Entregáselo al cliente en el mostrador (E) o dejalo con G.",
	BASURA = "Una bolsa de basura: llevala al contenedor del patio (puerta del fondo, a la derecha). Con la bolsa en las manos no podés tomar casetes.",
	MANCHA = "Una mancha en el piso: tomá la escoba apoyada en la pared del baño (E) y mantené E sobre la mancha. Con G soltás la escoba.",
	LOCAL = "Cuidar el local: lo que tiene contorno se hace manteniendo E.",
	SOCIO = "El Socio solo se frena si lo mirás con la linterna prendida (F). Mirarlo sin luz no sirve, y la batería se gasta.",
	CORRER = "Mantené Shift para correr. Te cansás: la barrita de abajo muestra tu energía.",
	MARCAR = "Una anomalía: apuntale y apretá Q antes de que se te tire encima.",
	LUZ = "Se cortó la luz. Usá la linterna (F) y no la gastes: tiene batería.",
	MOUSE = "Para tocar botones (comprar, menús) soltá el mouse con Ctrl.",
}

function Pistas.dar(jugador: Player, id: string)
	local texto = Pistas.TEXTOS[id]
	if texto and Persistencia.marcarPista(jugador, id) then
		Net.obtener("Pista"):FireClient(jugador, { id = id, texto = texto })
	end
end

function Pistas.darATodos(id: string)
	for _, jugador in Players:GetPlayers() do
		Pistas.dar(jugador, id)
	end
end

function Pistas.init()
	-- Pistas pedidas por el cliente (las que solo él puede notar, como que le apareció una anomalía).
	Net.obtener("Pista").OnServerEvent:Connect(function(jugador, paquete)
		if typeof(paquete) == "table" and typeof(paquete.pedir) == "string" and Net.limitar(jugador, "pista", 1) then
			Pistas.dar(jugador, paquete.pedir)
		end
	end)

	-- Al llevar el primer casete.
	TapeItem.alCambiar(function()
		for _, jugador in Players:GetPlayers() do
			if TapeItem.enMano(jugador) then
				Pistas.dar(jugador, "CASETE")
			end
		end
	end)

	-- Las tareas se enseñan cuando aparecen por primera vez (antes de eso el jugador no las necesita).
	NightManager.suscribir("BASURA", function()
		task.delay(1, Pistas.darATodos, "BASURA")
	end)
	NightManager.suscribir("DERRAME", function()
		task.delay(1, Pistas.darATodos, "MANCHA")
	end)
	NightManager.suscribir("TAREA_MENOR", function()
		task.delay(1, Pistas.darATodos, "LOCAL")
	end)
	NightManager.suscribir("CORTE_LUZ", function(datos)
		if datos and datos.valor then
			Pistas.darATodos("LUZ")
		end
	end)
	-- La primera vez que el Socio anda suelto: cómo frenarlo y cómo escapar.
	NightManager.suscribir("SOCIO_ACTIVA", function()
		Pistas.darATodos("SOCIO")
		task.delay(9, Pistas.darATodos, "CORRER")
	end)
end

return Pistas
