--!nonstrict
--[[
	Pistas (cliente): muestra los consejos que manda el servidor (Server/Pistas) en un cartel chico abajo, de a uno,
	con el texto traducido. También pide los que solo el cliente puede notar:  Pistas.pedir("MARCAR").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Idioma = require(ReplicatedStorage.Shared.Idioma)
local Net = require(ReplicatedStorage.Shared.Net)

local Pistas = {}

local VISIBLE_SEG = 7.5
local cola = {}
local mostrando = false
local gui, panel, etiqueta

local function crearInterfaz()
	gui = Instance.new("ScreenGui")
	gui.Name = "Pistas"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 0.80)
	panel.Size = UDim2.fromScale(0.46, 0.085)
	panel.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(184, 148, 98)
	borde.Thickness = 1.5
	borde.Transparency = 1
	borde.Name = "Borde"
	borde.Parent = panel
	local limite = Instance.new("UISizeConstraint")
	limite.MinSize = Vector2.new(260, 54)
	limite.MaxSize = Vector2.new(640, 110)
	limite.Parent = panel

	etiqueta = Instance.new("TextLabel")
	etiqueta.BackgroundTransparency = 1
	etiqueta.Size = UDim2.new(1, -20, 1, -8)
	etiqueta.Position = UDim2.fromOffset(10, 4)
	etiqueta.Font = Enum.Font.Code
	etiqueta.TextScaled = true
	etiqueta.TextWrapped = true
	etiqueta.TextColor3 = Color3.fromRGB(236, 224, 196)
	etiqueta.TextTransparency = 1
	etiqueta.Text = ""
	etiqueta.Parent = panel
	local tope = Instance.new("UITextSizeConstraint")
	tope.MaxTextSize = 18
	tope.MinTextSize = 10
	tope.Parent = etiqueta
end

local function mostrarSiguiente()
	if mostrando or #cola == 0 then
		return
	end
	mostrando = true
	local texto = table.remove(cola, 1)
	local ok, traducido = pcall(Idioma.t, texto)
	etiqueta.Text = ok and traducido or texto
	panel.Visible = true
	local entrada = TweenInfo.new(0.35)
	TweenService:Create(panel, entrada, { BackgroundTransparency = 0.25 }):Play()
	TweenService:Create(panel.Borde, entrada, { Transparency = 0.3 }):Play()
	TweenService:Create(etiqueta, entrada, { TextTransparency = 0 }):Play()
	task.delay(VISIBLE_SEG, function()
		local salida = TweenInfo.new(0.5)
		TweenService:Create(panel, salida, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(panel.Borde, salida, { Transparency = 1 }):Play()
		TweenService:Create(etiqueta, salida, { TextTransparency = 1 }):Play()
		task.delay(0.6, function()
			panel.Visible = false
			mostrando = false
			task.delay(1.2, mostrarSiguiente)
		end)
	end)
end

--- Muestra un consejo (en la cola, de a uno).
function Pistas.mostrar(texto: string)
	table.insert(cola, texto)
	mostrarSiguiente()
end

--- Le pide al servidor la pista 'id' (solo se muestra si nunca la vio).
function Pistas.pedir(id: string)
	Net.obtener("Pista"):FireServer({ pedir = id })
end

function Pistas.init()
	crearInterfaz()
	Net.obtener("Pista").OnClientEvent:Connect(function(datos)
		if typeof(datos) == "table" and typeof(datos.texto) == "string" then
			Pistas.mostrar(datos.texto)
		end
	end)
end

return Pistas
