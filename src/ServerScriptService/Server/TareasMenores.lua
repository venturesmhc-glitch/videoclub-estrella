--!nonstrict
--[[
	TareasMenores (servidor): pequeñas tareas del local para que las primeras noches no tengan tiempo muerto.
	Las crea el evento TAREA_MENOR de NightData ({ ids = { "PLANTA", ... } }) y cada una se hace manteniendo E sobre su
	objeto (que se marca con un contorno hasta que se hace). Suman al objetivo "menores" de la ficha.

	Los objetos son partes del local con el tag "TareaMenor" y el atributo "TareaId" (las pone build/videoclub.lua).
	Si el mismo id se pide dos veces antes de que alguien haga la tarea, queda en cola: se vuelve a pedir al terminarla.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local Prompts = require(script.Parent.Prompts)
local TaskSystem = require(script.Parent.TaskSystem)

local TareasMenores = {}

local DEFINICIONES = {
	PLANTA = { accion = "Regar la planta", objeto = "Planta", hold = 2.5, aviso = "La planta está seca: regala (mantené E)." },
	FICHAS = { accion = "Ordenar las fichas", objeto = "Fichas de socios", hold = 2.5, aviso = "Las fichas de socios están desordenadas." },
	CARTEL = { accion = "Enderezar el cartel", objeto = "Cartel de oferta", hold = 1.5, aviso = "El cartel de oferta quedó torcido." },
	VIDRIO = { accion = "Limpiar el vidrio", objeto = "Ventana", hold = 3, aviso = "La ventana del frente está sucia." },
	CAJA = { accion = "Contar la caja", objeto = "Caja registradora", hold = 3, aviso = "Hay que contar la caja registradora." },
}

local tareas = {} -- id -> { parte, prompt, activa, cola, contorno }

local function desactivar(t)
	t.activa, t.cola = false, 0
	t.prompt.Enabled = false
	if t.contorno then
		t.contorno:Destroy()
		t.contorno = nil
	end
end

local function activar(id: string)
	local t = tareas[id]
	if not t then
		warn("[TareasMenores] No hay objeto para la tarea " .. tostring(id))
		return
	end
	if t.activa then
		t.cola += 1 -- ya estaba pendiente: se vuelve a pedir cuando la hagan
		return
	end
	t.activa = true
	t.prompt.Enabled = true
	local contorno = Instance.new("Highlight")
	contorno.FillTransparency = 1
	contorno.OutlineColor = Color3.fromRGB(235, 225, 190)
	contorno.OutlineTransparency = 0.45
	contorno.DepthMode = Enum.HighlightDepthMode.Occluded
	contorno.Parent = t.parte
	t.contorno = contorno
	Net.avisoATodos(DEFINICIONES[id].aviso)
end

local function completar(id: string, jugador: Player)
	local t = tareas[id]
	if not t or not t.activa then
		return
	end
	TaskSystem.registrar("menores")
	Net.aviso(jugador, "Listo.")
	if t.cola > 0 then
		t.cola -= 1
		Net.avisoATodos(DEFINICIONES[id].aviso)
	else
		desactivar(t)
	end
end

function TareasMenores.init()
	for _, parte in CollectionService:GetTagged("TareaMenor") do
		local id = parte:GetAttribute("TareaId")
		local def = DEFINICIONES[id]
		if parte:IsA("BasePart") and def and not tareas[id] then
			local t = { parte = parte, activa = false, cola = 0 }
			t.prompt = Prompts.crear(parte, {
				clave = "menor_" .. id,
				accion = def.accion,
				objeto = def.objeto,
				hold = def.hold,
				distancia = 7,
				alActivar = function(jugador)
					completar(id, jugador)
				end,
			})
			t.prompt.Enabled = false
			tareas[id] = t
		end
	end
	NightManager.suscribir("NOCHE_INICIA", function()
		for _, t in tareas do
			desactivar(t)
		end
	end)
	NightManager.suscribir("TAREA_MENOR", function(datos)
		for _, id in datos.ids or {} do
			activar(id)
		end
	end)
end

--- Para pruebas: pide una tarea sin esperar al evento.
function TareasMenores.pedir(id: string)
	activar(id)
end

return TareasMenores
