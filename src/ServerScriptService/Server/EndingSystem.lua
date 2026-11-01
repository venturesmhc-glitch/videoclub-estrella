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
local NightManager = require(script.Parent.NightManager)
local Persistencia = require(script.Parent.Persistencia)
local Prompts = require(script.Parent.Prompts)
local SocioEntity = require(script.Parent.SocioEntity)
local TapeItem = require(script.Parent.TapeItem)

local EndingSystem = {}

local enCurso = false

function EndingSystem.disparar(id: string)
	local final = Catalogo.Finales[id]
	if enCurso or not final then
		return
	end
	enCurso = true
	NightManager.detenerTurno()
	SocioEntity.desactivar()
	Persistencia.registrarFinal(id)
	Net.obtener("EndingTrigger"):FireAllClients({ id = id, titulo = final.titulo, lineas = final.lineas })

	task.delay(Config.Final.PausaFinalSeg, function()
		enCurso = false
		NightManager.iniciarNoche(1)
	end)
end

function EndingSystem.enCurso(): boolean
	return enCurso
end

local function grabarEncima(jugador: Player)
	local estado = NightManager.obtenerEstado()
	local casete = TapeItem.enMano(jugador)
	if estado.fase ~= "turno" or estado.noche < 5 then
		Net.aviso(jugador, "Todavía no. Esta cinta no se deja grabar tan fácil.")
	elseif not casete or not casete.sinEtiqueta then
		Net.aviso(jugador, "Hace falta la cinta sin etiqueta en la mano.")
	else
		TapeItem.consumir(casete)
		EndingSystem.disparar("REBOBINAR")
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
				offset = Vector2.new(0, -70),
				alActivar = grabarEncima,
			})
		end
	end
end

return EndingSystem
