--!nonstrict
--[[
	OSD (cliente): interfaz estilo videocasetera de los 90.
	  arriba derecha: estado ("▶ PLAY", "❚❚ PAUSE") y debajo el contador de cinta
	  abajo izquierda: fecha y hora del reloj de la caja ("NOV 14 1997  23:47")

	Hasta que el servidor mande el remote "NightState" (Fase 2), el reloj corre en modo demo
	con la escala de Config.Noche, para poder ver la interfaz funcionando.

	API:
	  OSD.setEstado("PLAY" | "PAUSE" | "REW" | "FF" | "REC")
	  OSD.setHora(noche, minutoDesdeInicio, fase)   -- lo llama el remote NightState
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local OSD = {}

local cfg = Config.OSD
local TEXTOS_ESTADO = {
	PLAY = "▶ PLAY",
	PAUSE = "❚❚ PAUSE",
	REW = "◀◀ REW",
	FF = "▶▶ FF",
	REC = "● REC",
}

local estado = { modo = "PLAY", noche = 1, minuto = 0, demo = true, contadorSeg = 0 }
local etiquetas = {}

local function formatearHora(minuto)
	local total = (Config.Noche.InicioHora * 60 + math.floor(minuto)) % 1440
	return string.format("%02d:%02d", total // 60, total % 60)
end

local function formatearFecha(noche, minuto)
	local f = Config.Noche.Fecha
	local dia = f.Dia + (noche - 1)
	-- Pasada la medianoche, la videocasetera cambia de día.
	if Config.Noche.InicioHora * 60 + math.floor(minuto) >= 1440 then
		dia += 1
	end
	return string.format("%s %02d %d", f.Mes, dia, f.Anio)
end

local function crearEtiqueta(nombre, alineacion, anclaje, posicion, padre)
	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = nombre
	etiqueta.BackgroundTransparency = 1
	etiqueta.Font = cfg.Fuente
	etiqueta.TextColor3 = cfg.Color
	etiqueta.TextXAlignment = alineacion
	etiqueta.TextYAlignment = Enum.TextYAlignment.Center
	etiqueta.AnchorPoint = anclaje
	etiqueta.Position = posicion
	etiqueta.Size = UDim2.fromScale(0.4, 0.06)
	etiqueta.Text = ""
	local trazo = Instance.new("UIStroke")
	trazo.Thickness = cfg.ContornoGrosor
	trazo.Color = Color3.new(0, 0, 0)
	trazo.Parent = etiqueta
	etiqueta.Parent = padre
	return etiqueta
end

local function ajustarTamano()
	local camara = workspace.CurrentCamera
	local alto = camara and camara.ViewportSize.Y or 720
	local tamano = math.clamp(math.floor(alto * cfg.TamanoRelativo), 14, 52)
	for _, etiqueta in etiquetas do
		etiqueta.TextSize = tamano
	end
end

local function refrescar()
	local parpadeoVisible = (os.clock() % (cfg.ParpadeoSeg * 2)) < cfg.ParpadeoSeg
	etiquetas.estado.Text = TEXTOS_ESTADO[estado.modo] or estado.modo
	etiquetas.estado.Visible = estado.modo ~= "PAUSE" or parpadeoVisible

	local s = math.floor(estado.contadorSeg)
	etiquetas.contador.Text = string.format("CTR %d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
	etiquetas.fecha.Text = estado.sobrescribir
		or string.format("%s  %s", formatearFecha(estado.noche, estado.minuto), formatearHora(estado.minuto))
end

--- Texto fijo en lugar de la fecha y hora (la cinta muestra una fecha del futuro). nil = vuelve al reloj normal.
function OSD.sobrescribirFecha(texto: string?)
	estado.sobrescribir = texto
end

--- La fecha y hora del reloj para un minuto dado de la noche actual (por ejemplo "NOV 15 1997  03:12").
function OSD.textoFecha(noche: number, minuto: number): string
	return string.format("%s  %s", formatearFecha(noche, minuto), formatearHora(minuto))
end

function OSD.setEstado(modo: string)
	estado.modo = modo
end

function OSD.setHora(noche: number, minuto: number, fase: string?)
	estado.demo = false
	estado.noche = noche
	estado.minuto = minuto
	estado.sincro = { minuto = minuto, t = os.clock(), fase = fase or "turno" }
end

function OSD.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "OSD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 110
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Estado y contador van arriba a la derecha: arriba a la izquierda están los botones de Roblox y el chat.
	local x = 1 - cfg.MargenLateral
	local ySup = cfg.MargenSuperior
	etiquetas.estado = crearEtiqueta("Estado", Enum.TextXAlignment.Right, Vector2.new(1, 0), UDim2.fromScale(x, ySup), gui)
	etiquetas.contador = crearEtiqueta("Contador", Enum.TextXAlignment.Right, Vector2.new(1, 0),
		UDim2.fromScale(x, ySup + cfg.SeparacionLineas), gui)
	etiquetas.fecha = crearEtiqueta("Fecha", Enum.TextXAlignment.Left, Vector2.new(0, 1),
		UDim2.fromScale(cfg.MargenLateral, 1 - cfg.MargenInferior), gui)

	ajustarTamano()
	local camara = workspace.CurrentCamera
	if camara then
		camara:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarTamano)
	end

	Net.obtener("NightState").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" then
			return
		end
		OSD.setHora(datos.noche or 1, datos.minuto or 0, datos.fase)
		if datos.fase == "turno" then
			OSD.setEstado("PLAY")
		else
			OSD.setEstado("PAUSE") -- entre turnos la videocasetera queda en pausa
		end
	end)

	-- Entre dos mensajes del servidor el reloj sigue corriendo localmente con la misma escala.
	local escala = Config.Noche.DuracionMinutosJuego / Config.Noche.DuracionRealSegundos
	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		if estado.modo == "PLAY" or estado.modo == "REC" then
			estado.contadorSeg += dt
		end
		if estado.demo then
			estado.minuto = (estado.minuto + dt * escala) % Config.Noche.DuracionMinutosJuego
		elseif estado.sincro and estado.sincro.fase == "turno" then
			local transcurrido = (os.clock() - estado.sincro.t) * escala
			estado.minuto = math.min(estado.sincro.minuto + transcurrido, Config.Noche.DuracionMinutosJuego)
		end
		acumulado += dt
		if acumulado >= cfg.IntervaloActualizacion then
			acumulado = 0
			refrescar()
		end
	end)
	refrescar()
end

return OSD
