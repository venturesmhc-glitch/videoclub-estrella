--!nonstrict
--[[
	Cordura (cliente): el progreso del Socio se siente, no se lee.
	Los bordes de la pantalla se van oscureciendo y enrojeciendo de a poco, con una respiración lenta que se
	acelera. No hay número, barra ni aviso: solo la sensación de que algo se acerca.
	El servidor manda la presión (0..1) por el remote Presion; todos los valores están en Config.Cordura.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Cordura = {}

local cfg = Config.Cordura
local bordes = {} -- { frame = Frame, gradiente = UIGradient }
local objetivo = 0 -- presión que manda el servidor (0..1)
local actual = 0 -- presión suavizada
local ultimoAviso = 0

local function crearBorde(padre, nombre, ancla, posicion, rotacion)
	local frame = Instance.new("Frame")
	frame.Name = nombre
	frame.AnchorPoint = ancla
	frame.Position = posicion
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = cfg.ColorBase
	frame.BackgroundTransparency = 1
	frame.Parent = padre
	-- De opaco en el borde a transparente hacia adentro.
	local gradiente = Instance.new("UIGradient")
	gradiente.Rotation = rotacion
	gradiente.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.55, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradiente.Parent = frame
	table.insert(bordes, { frame = frame, nombre = nombre })
	return frame
end

function Cordura.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Cordura"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- por debajo de los diálogos, el menú y el filtro VHS
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Arriba, abajo, izquierda y derecha. Los tamaños se ajustan en cada cuadro según la presión.
	crearBorde(gui, "Arriba", Vector2.new(0, 0), UDim2.fromScale(0, 0), 90)
	crearBorde(gui, "Abajo", Vector2.new(0, 1), UDim2.fromScale(0, 1), -90)
	crearBorde(gui, "Izquierda", Vector2.new(0, 0), UDim2.fromScale(0, 0), 0)
	crearBorde(gui, "Derecha", Vector2.new(1, 0), UDim2.fromScale(1, 0), 180)

	Net.obtener("Presion").OnClientEvent:Connect(function(valor)
		if typeof(valor) == "number" then
			objetivo = math.clamp(valor, 0, 1)
			ultimoAviso = os.clock()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		-- Sin noticias del servidor (menú, fin de turno): se disipa.
		local meta = (os.clock() - ultimoAviso < 4) and objetivo or 0
		actual += (meta - actual) * math.min(1, dt * cfg.Suavizado)

		local nivel = math.clamp((actual - cfg.Desde) / (1 - cfg.Desde), 0, 1)
		local respiracion = 0
		if nivel > 0 then
			-- Respira más rápido y más hondo cuanto peor está.
			local frecuencia = cfg.RespiraMin + (cfg.RespiraMax - cfg.RespiraMin) * nivel
			respiracion = math.sin(os.clock() * frecuencia * math.pi * 2) * cfg.RespiraAmplitud * nivel
		end
		local opacidad = math.clamp(cfg.OpacidadMax * nivel * (1 + respiracion), 0, 1)
		local ancho = cfg.AnchoMin + (cfg.AnchoMax - cfg.AnchoMin) * nivel
		local color = cfg.ColorBase:Lerp(cfg.ColorRojo, nivel)

		for _, borde in bordes do
			local frame = borde.frame
			frame.BackgroundColor3 = color
			frame.BackgroundTransparency = 1 - opacidad
			frame.Visible = opacidad > 0.004
			if borde.nombre == "Arriba" or borde.nombre == "Abajo" then
				frame.Size = UDim2.fromScale(1, ancho * 1.15)
			else
				frame.Size = UDim2.fromScale(ancho * 0.7, 1)
			end
		end
	end)
end

return Cordura
