--!nonstrict
--[[
	EndingSystem (servidor) — Fase 7. Los tres finales:
	  REBOBINAR  noche 5, con la cinta en la mano: mantener R en la videocasetera (grabarle encima). Final en bucle.
	  DEVOLVER   noche 5: entregarle la cinta al Socio cuando hace cola en el mostrador. Es el final verdadero.
	  MIRAR      noche 5: reproducir la cinta entera sin cortarla (o llegar a las 04:00 sin resolver nada).
	Al llegar a un final se detiene el turno, se muestra la pantalla del final y, pasado Config.Final.PausaFinalSeg,
	la partida vuelve a empezar desde la noche 1 (Persistencia guarda el final desbloqueado).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local CursedTapeSystem = require(script.Parent.CursedTapeSystem)
local Insignias = require(script.Parent.Insignias)
local NightManager = require(script.Parent.NightManager)
local Persistencia = require(script.Parent.Persistencia)
local Prompts = require(script.Parent.Prompts)
local SocioEntity = require(script.Parent.SocioEntity)
local TapeItem = require(script.Parent.TapeItem)
local TaskSystem = require(script.Parent.TaskSystem)

local EndingSystem = {}

local enCurso = false

function EndingSystem.disparar(id: string)
	local final = Catalogo.Finales[id]
	-- El modo Sin fin no tiene finales: la cinta sigue llegando, pero ver o devolver nada termina nada.
	if enCurso or not final or NightManager.modo() ~= "historia" then
		return
	end
	enCurso = true
	NightManager.detenerTurno()
	SocioEntity.desactivar()
	Persistencia.registrarFinal(id)
	Insignias.alcanzarFinal(id)
	Net.obtener("EndingTrigger"):FireAllClients({ id = id, titulo = final.titulo, lineas = final.lineas })

	task.delay(Config.Final.PausaFinalSeg, function()
		enCurso = false
		NightManager.iniciarNoche(1)
	end)
end

function EndingSystem.enCurso(): boolean
	return enCurso
end

-- Grabar encima (R en la videocasetera):
--   - cinta sin etiqueta en la noche 5 de la historia: final REBOBINAR;
--   - cinta sin etiqueta en cualquier otra noche (y en Sin fin): se destruye y el Socio se calma (ya no se la puede mirar);
--   - cinta anómala: se destruye, cuenta como separada y calma un poco al Socio (no vuelve a circular).
local function grabarEncima(jugador: Player)
	local estado = NightManager.obtenerEstado()
	local casete = TapeItem.enMano(jugador)
	if estado.fase ~= "turno" then
		return
	end
	if not casete then
		Net.aviso(jugador, "Hace falta una cinta en la mano para grabarle encima.")
	elseif casete.sinEtiqueta then
		TapeItem.consumir(casete)
		if estado.noche >= 5 and NightManager.modo() == "historia" then
			EndingSystem.disparar("REBOBINAR")
		else
			SocioEntity.agregarProgreso(Config.Final.ProgresoGrabarSinEtiqueta)
			Net.aviso(jugador, "Le grabaste encima a la cinta sin etiqueta: ya no se puede mirar y el Socio se calma.")
		end
	elseif casete.estado == "anomalo" then
		TapeItem.consumir(casete)
		TaskSystem.registrar("separar")
		SocioEntity.agregarProgreso(Config.Final.ProgresoGrabarAnomala)
		Net.aviso(jugador, "Le grabaste encima a una cinta anómala: ya no puede volver a circular.")
	else
		Net.aviso(jugador, "Esa cinta no necesita que le graben encima.")
	end
end

function EndingSystem.init()
	NightManager.suscribir("FINAL_DEVOLVER", function()
		EndingSystem.disparar("DEVOLVER")
	end)
	CursedTapeSystem.alCompletarFinal(function()
		EndingSystem.disparar("MIRAR")
	end)
	-- A las 04:00 de la noche 5 sin haber resuelto nada, la cinta se queda con todos.
	NightManager.suscribir("NOCHE_TERMINA", function(datos)
		if datos.noche == 5 and not datos.fracaso and not datos.final then
			EndingSystem.disparar("MIRAR")
		end
	end)

	for _, parte in CollectionService:GetTagged("Videocasetera") do
		if parte:IsA("BasePart") then
			Prompts.crear(parte, {
				clave = "grabarencima",
				accion = "Grabar encima",
				objeto = "Videocasetera",
				hold = Config.Final.GrabarEncimaSeg,
				tecla = Enum.KeyCode.R,
				offset = Vector2.new(0, -100),
				alActivar = grabarEncima,
			})
		end
	end
end

return EndingSystem
