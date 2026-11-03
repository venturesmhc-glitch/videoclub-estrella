--!strict
--[[
	Net: definición única de los RemoteEvents y utilidades de red.
	El servidor los crea al arrancar (Net.crearTodos); el cliente los espera (Net.obtener).
	Regla: el servidor valida todo lo que llega del cliente (ver Net.limitar).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local NOMBRE_CARPETA = "Remotes"

-- nombre -> clase. "s>c" = servidor a cliente, "c>s" = cliente a servidor.
local DEFINICIONES: { [string]: string } = {
	NightState = "RemoteEvent", -- s>c: { noche, minuto, fase }
	TaskUpdate = "RemoteEvent", -- s>c: estado de las tareas
	TaskAction = "RemoteEvent", -- c>s: acción pedida sobre una tarea
	TapeAction = "RemoteEvent", -- c>s: recoger / rebobinar / reponer / separar
	AnomalySeed = "RemoteEvent", -- s>c: semilla de anomalías por jugador y noche
	AnomalyReport = "RemoteEvent", -- c>s: anomalía detectada o repuesta por error
	TapePlay = "RemoteEvent", -- c>s: pedir reproducir la cinta
	TapeSession = "RemoteEvent", -- s>c: inicio/fin de reproducción y datos del fantasma
	LookReport = "UnreliableRemoteEvent", -- c>s: cámara del jugador (para la mirada del Socio)
	Danger = "UnreliableRemoteEvent", -- s>c: peligro 0..1 (deforma el tracking)
	Presion = "UnreliableRemoteEvent", -- s>c: progreso del Socio 0..1 (oscurece y enrojece los bordes de la pantalla)
	SocioPresencia ="RemoteEvent", -- s>c: true cuando el Socio aparece, false cuando se va (distorsiona la música)
	Notice = "RemoteEvent", -- s>c: aviso corto en pantalla (texto)
	CustomerDialog = "RemoteEvent", -- s>c: diálogo de cliente { speaker, texto }
	CustomerChoice = "RemoteEvent", -- c>s: respuesta del jugador
	RuleNotes = "RemoteEvent", -- s>c: notas de Darío (reales y falsas)
	PhoneRing = "RemoteEvent", -- s>c: suena un teléfono
	PhoneAnswer = "RemoteEvent", -- c>s: atender / colgar
	PhoneMessage = "RemoteEvent", -- s>c: contestador o audio de la cinta
	WorldEvent = "RemoteEvent", -- s>c: cambios del mundo { id, valor } (corte de luz, teléfono, TV...)
	Scare = "RemoteEvent", -- s>c: el susto fuerte de la noche (máximo uno por noche)
	EndingTrigger = "RemoteEvent", -- s>c: final alcanzado { id, lineas }
	ProfileLoaded = "RemoteEvent", -- s>c: noche y finales guardados
	DropTape = "RemoteEvent", -- c>s: soltar el casete que se lleva en la mano (tecla G)
	MenuAction = "RemoteEvent", -- c>s: { accion = "estado" | "salas" | "solo" | "crear" | "unirse" | "empezar" | "salir", ... } desde el menú
	PartidaState = "RemoteEvent", -- s>c: { fase = "menu" | "lobby" | "jugando", modo, anfitrion, jugadores, codigo, publica, maximo }
	Comprar = "RemoteEvent", -- c>s: { producto = "asustar" | "revivir" } pide abrir la compra con Robux
	Screamer = "RemoteEvent", -- s>c: { variante } screamer a pantalla completa
	SalasState = "RemoteEvent", -- s>c: { tipo = "lista", salas = { { codigo, anfitrion, jugadores, maximo } } } | { tipo = "mensaje", texto, error }
}

--- Solo servidor: crea la carpeta Remotes con todos los remotes definidos.
function Net.crearTodos()
	assert(RunService:IsServer(), "Net.crearTodos solo se llama desde el servidor")
	local carpeta = ReplicatedStorage:FindFirstChild(NOMBRE_CARPETA)
	if not carpeta then
		carpeta = Instance.new("Folder")
		carpeta.Name = NOMBRE_CARPETA
	end
	for nombre, clase in DEFINICIONES do
		if not carpeta:FindFirstChild(nombre) then
			local remoto = Instance.new(clase)
			remoto.Name = nombre
			remoto.Parent = carpeta
		end
	end
	carpeta.Parent = ReplicatedStorage
end

--- Devuelve el remote (espera a que exista). Pensado para el cliente.
function Net.obtener(nombre: string): any
	assert(DEFINICIONES[nombre], "Remote desconocido: " .. nombre)
	local carpeta = ReplicatedStorage:WaitForChild(NOMBRE_CARPETA)
	return carpeta:WaitForChild(nombre)
end

--- Solo servidor: aviso corto en pantalla para un jugador.
function Net.aviso(jugador: Player, texto: string)
	assert(RunService:IsServer(), "Net.aviso solo se llama desde el servidor")
	Net.obtener("Notice"):FireClient(jugador, texto)
end

--- Solo servidor: aviso corto en pantalla para todos.
function Net.avisoATodos(texto: string)
	assert(RunService:IsServer(), "Net.avisoATodos solo se llama desde el servidor")
	Net.obtener("Notice"):FireAllClients(texto)
end

-- Limitador de frecuencia por jugador y clave, para validar remotes en el servidor.
local ultimoUso: { [Player]: { [string]: number } } = {}

--- true si el jugador puede ejecutar la acción ahora; false si llegó demasiado seguido.
function Net.limitar(jugador: Player, clave: string, intervaloSeg: number): boolean
	local ahora = os.clock()
	local porJugador = ultimoUso[jugador]
	if not porJugador then
		porJugador = {}
		ultimoUso[jugador] = porJugador
	end
	local previo = porJugador[clave]
	if previo and ahora - previo < intervaloSeg then
		return false
	end
	porJugador[clave] = ahora
	return true
end

Players.PlayerRemoving:Connect(function(jugador)
	ultimoUso[jugador] = nil
end)

return Net
