--!nonstrict
--[[
	TaskCard (cliente) — Fase 2.
	Ficha de socio de cartón: es la lista de tareas del turno, lo que llevás en la mano y lo que pide
	el cliente del mostrador. Es la interfaz diegética: no hay inventario ni barra de vida.
	Tab muestra u oculta la ficha (en móviles, el botón FICHA).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local TaskCard = {}

local cfg = Config.Ficha
local marco
local lineas = {} -- TextLabels de la ficha, de arriba hacia abajo

local function crearLinea(nombre, color)
	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = nombre
	etiqueta.BackgroundTransparency = 1
	etiqueta.Size = UDim2.new(1, 0, 0, 0)
	etiqueta.AutomaticSize = Enum.AutomaticSize.Y
	etiqueta.TextXAlignment = Enum.TextXAlignment.Left
	etiqueta.TextWrapped = true
	etiqueta.Font = Enum.Font.Code
	etiqueta.TextColor3 = color
	etiqueta.Text = ""
	etiqueta.Parent = marco
	table.insert(lineas, etiqueta)
	return etiqueta
end

local function ajustarTamano()
	local camara = workspace.CurrentCamera
	local alto = camara and camara.ViewportSize.Y or 720
	local tamano = math.clamp(math.floor(alto * cfg.TamanoRelativo), 12, 30)
	for _, etiqueta in lineas do
		etiqueta.TextSize = tamano
	end
end

local function nombre(genero)
	return Catalogo.Nombres[genero] or genero
end

local function actualizar(datos)
	if typeof(datos) ~= "table" then
		return
	end
	-- Tareas (las etiquetas 3 a 3+MaxTareas-1).
	for i = 1, cfg.MaxTareas do
		local etiqueta = lineas[2 + i]
		local tarea = datos.tareas and datos.tareas[i]
		if tarea then
			local hecha = tarea.actual >= tarea.meta
			etiqueta.Text = string.format("[%s] %s %d/%d", hecha and "x" or " ", tarea.texto, math.min(tarea.actual, tarea.meta), tarea.meta)
			etiqueta.Visible = true
		else
			etiqueta.Text = ""
			etiqueta.Visible = false
		end
	end

	local mano = datos.enMano
	local textoMano = "EN MANO: nada"
	if mano then
		if mano.sinEtiqueta then
			textoMano = "EN MANO: casete sin etiqueta"
		else
			local estado = mano.estado == "danado" and "arrugada" or (mano.rebobinado and "rebobinada" or "sin rebobinar")
			textoMano = string.format("EN MANO: %s (%s, %s)", mano.titulo, nombre(mano.genero), estado)
		end
	end
	lineas[3 + cfg.MaxTareas].Text = textoMano

	local pedido = datos.pedido
	local textoPedido = ""
	if pedido then
		if pedido.tipo == "alquiler" then
			textoPedido = "CLIENTE PIDE: " .. nombre(pedido.genero)
		elseif pedido.tipo == "final" then
			textoPedido = "EL SOCIO ESPERA SU CINTA"
		else
			textoPedido = "CLIENTE DEVUELVE UN CASETE (atendelo en el mostrador)"
		end
	end
	lineas[4 + cfg.MaxTareas].Text = textoPedido
	lineas[4 + cfg.MaxTareas].Visible = pedido ~= false and pedido ~= nil
end

function TaskCard.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Ficha"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50 -- por debajo del filtro VHS (100): la ficha también sale con scanlines
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	marco = Instance.new("Frame")
	marco.Name = "Marco"
	marco.AnchorPoint = Vector2.new(0, 0.5)
	marco.Position = UDim2.fromScale(0.015, 0.5)
	marco.Size = UDim2.fromScale(cfg.Ancho, 0)
	marco.AutomaticSize = Enum.AutomaticSize.Y
	marco.BackgroundColor3 = cfg.ColorFondo
	marco.BorderSizePixel = 0
	marco.Rotation = cfg.Inclinacion
	marco.Parent = gui

	local trazo = Instance.new("UIStroke")
	trazo.Thickness = 3
	trazo.Color = cfg.ColorBorde
	trazo.Parent = marco
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0, 4)
	esquinas.Parent = marco
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	relleno.Parent = marco
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 4)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = marco

	crearLinea("Titulo", cfg.ColorTitulo).Text = "SOCIO N° 0042"
	crearLinea("Subtitulo", cfg.ColorTexto).Text = "TURNO NOCHE - Tab: ocultar"
	for i = 1, cfg.MaxTareas do
		crearLinea("Tarea" .. i, cfg.ColorTexto)
	end
	crearLinea("EnMano", cfg.ColorTexto)
	crearLinea("Pedido", cfg.ColorTitulo)
	for orden, etiqueta in lineas do
		etiqueta.LayoutOrder = orden
	end

	ajustarTamano()
	local camara = workspace.CurrentCamera
	if camara then
		camara:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarTamano)
	end
	actualizar({ tareas = {}, enMano = false, pedido = false })

	Net.obtener("TaskUpdate").OnClientEvent:Connect(actualizar)

	-- El final REBOBINAR deja un empleado menos: el número de socio de la ficha baja.
	Net.obtener("ProfileLoaded").OnClientEvent:Connect(function(perfil)
		if typeof(perfil) == "table" then
			local numero = math.max(1, 42 - (perfil.empleadosMenos or 0))
			lineas[1].Text = string.format("SOCIO N° %04d", numero)
		end
	end)

	UserInputService.InputBegan:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.Tab then
			marco.Visible = not marco.Visible
		end
	end)

	if UserInputService.TouchEnabled then
		local boton = Instance.new("TextButton")
		boton.Name = "BotonFicha"
		boton.AnchorPoint = Vector2.new(1, 1)
		boton.Position = UDim2.fromScale(0.98, 0.96)
		boton.Size = UDim2.fromScale(0.12, 0.07)
		boton.BackgroundColor3 = cfg.ColorFondo
		boton.TextColor3 = cfg.ColorTexto
		boton.Font = Enum.Font.Code
		boton.TextScaled = true
		boton.Text = "FICHA"
		boton.Parent = gui
		boton.Activated:Connect(function()
			marco.Visible = not marco.Visible
		end)
	end
end

return TaskCard
