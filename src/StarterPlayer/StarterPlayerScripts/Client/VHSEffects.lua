--!nonstrict
--[[
	VHSEffects (cliente): filtro de imagen VHS y "tracking" que indica peligro.
	  - Efectos de Lighting locales: color lavado, bloom suave, desenfoque leve.
	  - ScreenGui con negros levantados, scanlines, ruido animado, aberración cromática
	    simulada (bordes rojo/cian), viñeta y una franja de tracking que se deforma con el peligro.
	No hay barra de vida ni de cordura: este filtro es el indicador de peligro.

	API:
	  VHSEffects.setPeligro(0..1)   -- el servidor lo envía por el remote "Danger"
	  VHSEffects.setIntensidad(x)   -- 1 = normal; >1 = cinta (más lavado y más desenfoque)
	Todos los números salen de Config.VHS.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local VHSEffects = {}

local cfg = Config.VHS
local rng = Random.new()

local estado = { peligroObjetivo = 0, peligro = 0, intensidad = 1, anomaliaObjetivo = 0, anomalia = 0, ajusteEstatica = 1 }
local efectos = {}
local ui = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function nuevo(clase, propiedades, padre)
	local obj = Instance.new(clase)
	for clave, valor in propiedades do
		obj[clave] = valor
	end
	obj.Parent = padre
	return obj
end

local function elegirPerfil()
	local nombre = cfg.Calidad
	if nombre == "Auto" then
		local esMovil = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		nombre = esMovil and "Media" or "Alta"
	end
	return cfg.Perfiles[nombre] or cfg.Perfiles.Alta
end

local function crearEfectosDeLighting()
	efectos.color = nuevo("ColorCorrectionEffect", { Name = "VHS_Color" }, Lighting)
	efectos.bloom = nuevo("BloomEffect", { Name = "VHS_Bloom" }, Lighting)
	efectos.blur = nuevo("BlurEffect", { Name = "VHS_Blur" }, Lighting)
end

local function aplicarIntensidad()
	local k = estado.intensidad
	efectos.color.Saturation = math.clamp(cfg.Color.Saturacion * k, -1, 1)
	efectos.color.Contrast = math.clamp(cfg.Color.Contraste * k, -1, 1)
	efectos.color.Brightness = cfg.Color.Brillo
	efectos.color.TintColor = cfg.Color.Tinte
	efectos.bloom.Intensity = cfg.Bloom.Intensidad * k
	efectos.bloom.Size = cfg.Bloom.Tamano
	efectos.bloom.Threshold = cfg.Bloom.Umbral
	efectos.blur.Size = cfg.Desenfoque * k
end

local function capaCompleta(nombre, padre)
	return nuevo("Frame", {
		Name = nombre,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, padre)
end

local function bordeDegradado(nombre, posicion, tamano, rotacion, color, transparencia, padre)
	local borde = nuevo("Frame", {
		Name = nombre,
		Position = posicion,
		Size = tamano,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, padre)
	nuevo("UIGradient", {
		Transparency = NumberSequence.new(transparencia, 1),
		Rotation = rotacion,
	}, borde)
	return borde
end

local function crearInterfaz(perfil)
	local gui = nuevo("ScreenGui", {
		Name = "VHS",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	ui.gui = gui

	-- Negros levantados: velo gris que sube el nivel de negro de toda la imagen.
	nuevo("Frame", {
		Name = "NegrosLevantados",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = cfg.NegrosLevantados.Color,
		BackgroundTransparency = cfg.NegrosLevantados.Transparencia,
		BorderSizePixel = 0,
	}, gui)

	-- Scanlines: franjas horizontales oscuras repartidas por toda la pantalla.
	local lineas = capaCompleta("Scanlines", gui)
	for i = 0, perfil.Lineas - 1 do
		nuevo("Frame", {
			Size = UDim2.fromScale(1, cfg.Scanlines.Grosor),
			Position = UDim2.fromScale(0, i / perfil.Lineas),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = cfg.Scanlines.Transparencia,
			BorderSizePixel = 0,
		}, lineas)
	end

	-- Ruido: marcas blancas que saltan de lugar varias veces por segundo.
	ui.ruido = {}
	local capaRuido = capaCompleta("Ruido", gui)
	for _ = 1, perfil.RuidoMarcas do
		table.insert(ui.ruido, nuevo("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, capaRuido))
	end

	-- Aberración cromática simulada: halos rojo (izquierda) y cian (derecha) en los bordes.
	local ab = cfg.Aberracion
	bordeDegradado("AberracionRoja", UDim2.fromScale(0, 0), UDim2.fromScale(ab.Ancho, 1), 0,
		Color3.fromRGB(255, 40, 40), ab.Transparencia, gui)
	bordeDegradado("AberracionCian", UDim2.fromScale(1 - ab.Ancho, 0), UDim2.fromScale(ab.Ancho, 1), 180,
		Color3.fromRGB(40, 220, 255), ab.Transparencia, gui)

	-- Viñeta: cuatro bordes oscuros.
	local v = cfg.Vineta
	local negro = Color3.new(0, 0, 0)
	bordeDegradado("VinetaArriba", UDim2.fromScale(0, 0), UDim2.fromScale(1, v.Ancho), 90, negro, v.Transparencia, gui)
	bordeDegradado("VinetaAbajo", UDim2.fromScale(0, 1 - v.Ancho), UDim2.fromScale(1, v.Ancho), 270, negro, v.Transparencia, gui)
	bordeDegradado("VinetaIzquierda", UDim2.fromScale(0, 0), UDim2.fromScale(v.Ancho, 1), 0, negro, v.Transparencia, gui)
	bordeDegradado("VinetaDerecha", UDim2.fromScale(1 - v.Ancho, 0), UDim2.fromScale(v.Ancho, 1), 180, negro, v.Transparencia, gui)

	-- Franja de tracking: sube por la pantalla; con peligro se agranda y se rompe en ráfagas.
	ui.banda = nuevo("Frame", {
		Name = "Tracking",
		Size = UDim2.fromScale(1, cfg.Tracking.AlturaMin),
		BackgroundColor3 = Color3.fromRGB(235, 240, 235),
		BackgroundTransparency = cfg.Tracking.TransparenciaMin,
		BorderSizePixel = 0,
	}, gui)
	ui.rafagas = {}
	for _ = 1, cfg.Tracking.Rafagas do
		table.insert(ui.rafagas, nuevo("Frame", {
			BackgroundColor3 = Color3.fromRGB(205, 212, 205),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, ui.banda))
	end
end

local function reubicarRuido(p)
	local r = cfg.Ruido
	for _, marca in ui.ruido do
		local ancho = rng:NextNumber(0.002, 0.04)
		marca.Size = UDim2.fromScale(ancho, rng:NextNumber(0.0015, 0.003))
		marca.Position = UDim2.fromScale(rng:NextNumber(0, 1 - ancho), rng:NextNumber(0, 1))
		local t = rng:NextNumber(r.TransparenciaMin, r.TransparenciaMax) - p * r.AumentoPorPeligro
		-- El ajuste del menú escala la opacidad de la estática (0 = apagada).
		marca.BackgroundTransparency = math.clamp(1 - (1 - t) * estado.ajusteEstatica, 0, 1)
	end
end

local function reubicarRafagas(p)
	local t = cfg.Tracking
	local activo = p >= t.UmbralRafagas
	for _, rafaga in ui.rafagas do
		if activo then
			local ancho = rng:NextNumber(0.1, 0.6)
			rafaga.Size = UDim2.fromScale(ancho, rng:NextNumber(0.2, 0.9))
			rafaga.Position = UDim2.fromScale(rng:NextNumber(0, 1 - ancho), rng:NextNumber(0, 0.8))
			rafaga.BackgroundTransparency = math.clamp(
				lerp(t.RafagaTransparenciaMin, t.RafagaTransparenciaMax, p) + rng:NextNumber(-0.08, 0.08), 0, 1)
		else
			rafaga.BackgroundTransparency = 1
		end
	end
end

local function actualizar(dt, estadoRuido)
	local objetivo = estado.forzado or estado.peligroObjetivo
	estado.peligro += (objetivo - estado.peligro) * math.clamp(dt * cfg.SuavizadoPeligro, 0, 1)
	estado.anomalia += (estado.anomaliaObjetivo - estado.anomalia) * math.clamp(dt * 2, 0, 1)
	-- Una anomalía a la vista sube la estática como si hubiera algo de peligro.
	local p = math.max(estado.peligro, estado.anomalia * cfg.AnomaliaPeso)
	local t = cfg.Tracking

	local alto = lerp(t.AlturaMin, t.AlturaMax, p)
	estadoRuido.posicionBanda = (estadoRuido.posicionBanda + lerp(t.VelocidadMin, t.VelocidadMax, p) * dt) % 1.15
	ui.banda.Size = UDim2.fromScale(1, alto)
	ui.banda.Position = UDim2.fromScale(0, 1.05 - estadoRuido.posicionBanda)
	ui.banda.BackgroundTransparency = lerp(t.TransparenciaMin, t.TransparenciaMax, p)

	estadoRuido.acumulado += dt
	if estadoRuido.acumulado >= 1 / estadoRuido.hz then
		estadoRuido.acumulado = 0
		reubicarRuido(p)
		reubicarRafagas(p)
	end
end

--- El susto fuerte de la noche: destello, silueta del Socio y tracking al máximo por un instante.
function VHSEffects.susto()
	local previo = estado.peligroObjetivo
	local capa = nuevo("Frame", {
		Name = "Susto",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(235, 240, 235),
		BorderSizePixel = 0,
		ZIndex = 50,
	}, ui.gui)
	-- Silueta: cabeza y hombros oscuros contra el destello.
	local cabeza = nuevo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.18, 0.3),
		BackgroundColor3 = Color3.fromRGB(6, 6, 8),
		BorderSizePixel = 0,
		ZIndex = 51,
	}, capa)
	nuevo("UICorner", { CornerRadius = UDim.new(0.5, 0) }, cabeza)
	local hombros = nuevo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.6, 0.5),
		BackgroundColor3 = Color3.fromRGB(6, 6, 8),
		BorderSizePixel = 0,
		ZIndex = 51,
	}, capa)
	nuevo("UICorner", { CornerRadius = UDim.new(0.4, 0) }, hombros)

	estado.peligroObjetivo = 1
	estado.peligro = 1
	task.delay(0.22, function()
		capa:Destroy()
	end)
	task.delay(1.5, function()
		estado.peligroObjetivo = previo
	end)
end

--- Peligro de 0 a 1. El filtro lo sigue con suavizado (Config.VHS.SuavizadoPeligro).
function VHSEffects.setPeligro(valor: number)
	estado.peligroObjetivo = math.clamp(valor, 0, 1)
end

--- Qué tan presente está una anomalía a la vista (0..1): sube la estática. Lo calcula AnomalySystem.
function VHSEffects.setAnomalia(valor: number)
	estado.anomaliaObjetivo = math.clamp(valor, 0, 1)
end

--- Multiplicador de la estática (ajuste del menú): 0 = sin estática, 1 = normal, hasta 2.
function VHSEffects.setAjusteEstatica(valor: number)
	estado.ajusteEstatica = math.clamp(valor, 0, 2)
end

function VHSEffects.getAjusteEstatica(): number
	return estado.ajusteEstatica
end

--- Fija el peligro (por ejemplo mientras se ve la cinta) ignorando lo que mande el servidor. nil = vuelve a seguirlo.
function VHSEffects.forzar(valor: number?)
	estado.forzado = valor
end

--- Intensidad del filtro. 1 = normal; la cinta usa valores mayores.
function VHSEffects.setIntensidad(valor: number)
	estado.intensidad = math.max(valor, 0)
	aplicarIntensidad()
end

function VHSEffects.init()
	local perfil = elegirPerfil()
	crearEfectosDeLighting()
	aplicarIntensidad()
	crearInterfaz(perfil)

	local estadoRuido = { posicionBanda = 0, acumulado = 0, hz = perfil.RuidoHz }
	RunService.RenderStepped:Connect(function(dt)
		actualizar(dt, estadoRuido)
	end)

	Net.obtener("Danger").OnClientEvent:Connect(function(valor)
		if typeof(valor) == "number" then
			VHSEffects.setPeligro(valor)
		end
	end)
	Net.obtener("Scare").OnClientEvent:Connect(VHSEffects.susto)
end

return VHSEffects
