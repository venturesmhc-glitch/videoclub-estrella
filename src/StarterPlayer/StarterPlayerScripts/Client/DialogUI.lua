--!nonstrict
--[[
	DialogUI (cliente) — Fase 2.
	Texto en pantalla, todo con tipografía monoespaciada:
	  - Avisos cortos (remote Notice): "Rebobinado: ...", "Ese no va acá", etc.
	  - Diálogo de clientes (remote CustomerDialog), con efecto de máquina de escribir.
	  - Cartel "NOCHE n" al empezar el turno y pantalla de resumen al terminar (remote NightState).
	Va por debajo del filtro VHS (DisplayOrder < 100): el texto también sale con scanlines.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Idioma = require(ReplicatedStorage.Shared.Idioma)
local NightData = require(ReplicatedStorage.Shared.NightData)

local DialogUI = {}

local cfg = Config.Dialogos
local FUENTE = Enum.Font.Code
local COLOR_TEXTO = Color3.fromRGB(236, 236, 226)
local COLOR_NOMBRE = Color3.fromRGB(255, 220, 120)

local gui, contenedorAvisos, cajaDialogo, textoNombre, textoDialogo, pantalla, textoPantalla
local tokenDialogo = 0
local ultimo = { noche = nil, fase = nil }

local function tamanoTexto(relativo)
	local camara = workspace.CurrentCamera
	local alto = camara and camara.ViewportSize.Y or 720
	return math.clamp(math.floor(alto * relativo), 12, 40)
end

local function fondoOscuro(objeto, transparencia)
	objeto.BackgroundColor3 = Color3.new(0, 0, 0)
	objeto.BackgroundTransparency = transparencia
	objeto.BorderSizePixel = 0
end

local function mostrarAviso(texto)
	if typeof(texto) ~= "string" then
		return
	end
	local avisos = {}
	for _, hijo in contenedorAvisos:GetChildren() do
		if hijo:IsA("TextLabel") then
			table.insert(avisos, hijo)
		end
	end
	while #avisos >= cfg.MaxAvisos do
		table.remove(avisos, 1):Destroy()
	end

	local aviso = Instance.new("TextLabel")
	aviso.AutomaticSize = Enum.AutomaticSize.XY
	aviso.Size = UDim2.fromOffset(0, 0)
	aviso.Font = FUENTE
	aviso.TextSize = tamanoTexto(0.026)
	aviso.TextColor3 = COLOR_TEXTO
	aviso.Text = texto
	aviso.LayoutOrder = os.clock() * 1000
	fondoOscuro(aviso, 0.45)
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	relleno.Parent = aviso
	aviso.Parent = contenedorAvisos

	task.delay(cfg.AvisoSeg, function()
		if aviso.Parent then
			local salida = TweenService:Create(aviso, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
			salida:Play()
			salida.Completed:Wait()
			aviso:Destroy()
		end
	end)
end

local function mostrarDialogo(datos)
	if typeof(datos) ~= "table" or typeof(datos.texto) ~= "string" then
		return
	end
	tokenDialogo += 1
	local miToken = tokenDialogo
	local texto = Idioma.t(datos.texto) -- ya traducido: así la máquina de escribir cuenta las letras del idioma que se ve
	textoNombre.Text = Idioma.t(datos.speaker or "")
	textoDialogo.Text = texto
	textoDialogo.MaxVisibleGraphemes = 0
	cajaDialogo.Visible = true

	local total = utf8.len(texto) or #texto
	local inicio = os.clock()
	while tokenDialogo == miToken and textoDialogo.MaxVisibleGraphemes < total do
		task.wait(0.03)
		textoDialogo.MaxVisibleGraphemes = math.min(total, math.floor((os.clock() - inicio) * cfg.CaracteresPorSeg))
	end
	if tokenDialogo ~= miToken then
		return
	end
	textoDialogo.MaxVisibleGraphemes = -1
	task.wait(cfg.DuracionExtraSeg + (datos.extraSeg or 0))
	if tokenDialogo == miToken then
		cajaDialogo.Visible = false
	end
end

local function fundirPantalla(transparenciaFondo, textoTransparencia)
	local info = TweenInfo.new(cfg.FundidoSeg)
	TweenService:Create(pantalla, info, { BackgroundTransparency = transparenciaFondo }):Play()
	TweenService:Create(textoPantalla, info, { TextTransparency = textoTransparencia }):Play()
end

local function alCambiarNoche(datos)
	if typeof(datos) ~= "table" then
		return
	end
	-- Durante la pantalla de un final (fase "final") no se pisa el texto con los avisos del turno.
	if ultimo.fase == "final" and datos.fase == "final" then
		return
	end
	local cambio = datos.noche ~= ultimo.noche or datos.fase ~= ultimo.fase
	if not cambio then
		return
	end
	ultimo.noche, ultimo.fase = datos.noche, datos.fase

	if datos.fase == "turno" then
		-- Cartel de inicio solo si el turno recién empieza (no a quien entra a mitad de la noche).
		if (datos.minuto or 0) < 5 then
			local info = NightData[datos.noche]
			local titulo = datos.titulo or (info and info.titulo) or "" -- el servidor lo manda (el modo Sin fin pasa de la noche 5)
			textoPantalla.Text = string.format("NOCHE %d\n%s", datos.noche, titulo)
			if datos.noche == 1 and datos.modo ~= "sinfin" then
				textoPantalla.Text ..= "\n\nWASD moverte · E interactuar · Tab ficha\nAtendé el teléfono del mostrador."
			end
			pantalla.BackgroundTransparency = 0
			textoPantalla.TextTransparency = 0
			task.delay(cfg.IntroSeg, function()
				if ultimo.fase == "turno" then
					fundirPantalla(1, 1)
				end
			end)
		else
			fundirPantalla(1, 1)
		end
	elseif datos.fase == "fin" then
		local lineas = { "04:00 - FIN DEL TURNO", "" }
		for _, linea in datos.resumen or {} do
			table.insert(lineas, linea)
		end
		textoPantalla.Text = table.concat(lineas, "\n")
		fundirPantalla(0, 0)
	end
end

--- Muestra un aviso corto en pantalla (igual que los que manda el servidor), generado en el cliente.
function DialogUI.aviso(texto: string)
	mostrarAviso(texto)
end

--- Muestra un diálogo { speaker, texto } con efecto de máquina de escribir (espera a que termine).
function DialogUI.mostrar(datos)
	mostrarDialogo(datos)
end

-- Pantalla de final: fondo negro y el texto que se escribe solo.
local function mostrarFinal(datos)
	if typeof(datos) ~= "table" then
		return
	end
	tokenDialogo += 1
	cajaDialogo.Visible = false
	local texto = (datos.titulo or "") .. "\n\n" .. table.concat(datos.lineas or {}, "\n\n")
	textoPantalla.TextSize = tamanoTexto(0.032)
	textoPantalla.Text = texto
	textoPantalla.MaxVisibleGraphemes = 0
	pantalla.BackgroundTransparency = 0
	textoPantalla.TextTransparency = 0
	ultimo.fase = "final"

	local total = utf8.len(texto) or #texto
	local inicio = os.clock()
	while textoPantalla.MaxVisibleGraphemes < total and ultimo.fase == "final" do
		task.wait(0.05)
		textoPantalla.MaxVisibleGraphemes = math.min(total, math.floor((os.clock() - inicio) * cfg.CaracteresPorSeg * 0.6))
	end
	textoPantalla.MaxVisibleGraphemes = -1
end

function DialogUI.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Dialogos"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	contenedorAvisos = Instance.new("Frame")
	contenedorAvisos.Name = "Avisos"
	contenedorAvisos.AnchorPoint = Vector2.new(0.5, 1)
	contenedorAvisos.Position = UDim2.fromScale(0.5, 0.84)
	contenedorAvisos.Size = UDim2.fromScale(0.6, 0.18)
	contenedorAvisos.BackgroundTransparency = 1
	contenedorAvisos.Parent = gui
	local lista = Instance.new("UIListLayout")
	lista.VerticalAlignment = Enum.VerticalAlignment.Bottom
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Padding = UDim.new(0, 4)
	lista.Parent = contenedorAvisos

	cajaDialogo = Instance.new("Frame")
	cajaDialogo.Name = "Dialogo"
	cajaDialogo.AnchorPoint = Vector2.new(0.5, 1)
	cajaDialogo.Position = UDim2.fromScale(0.5, 0.965)
	cajaDialogo.Size = UDim2.fromScale(0.6, 0)
	cajaDialogo.AutomaticSize = Enum.AutomaticSize.Y
	cajaDialogo.Visible = false
	fondoOscuro(cajaDialogo, 0.35)
	cajaDialogo.Parent = gui
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	relleno.Parent = cajaDialogo
	local interior = Instance.new("UIListLayout")
	interior.SortOrder = Enum.SortOrder.LayoutOrder
	interior.Padding = UDim.new(0, 2)
	interior.Parent = cajaDialogo

	local function etiqueta(color, orden)
		local e = Instance.new("TextLabel")
		e.Size = UDim2.new(1, 0, 0, 0)
		e.AutomaticSize = Enum.AutomaticSize.Y
		e.BackgroundTransparency = 1
		e.TextXAlignment = Enum.TextXAlignment.Left
		e.TextWrapped = true
		e.Font = FUENTE
		e.TextSize = tamanoTexto(0.03)
		e.TextColor3 = color
		e.LayoutOrder = orden
		e.Parent = cajaDialogo
		return e
	end
	textoNombre = etiqueta(COLOR_NOMBRE, 1)
	textoDialogo = etiqueta(COLOR_TEXTO, 2)

	-- Pantalla negra para el cartel de la noche y el resumen del turno.
	pantalla = Instance.new("Frame")
	pantalla.Name = "Pantalla"
	pantalla.Size = UDim2.fromScale(1, 1)
	pantalla.ZIndex = 10
	fondoOscuro(pantalla, 1)
	pantalla.Parent = gui
	textoPantalla = Instance.new("TextLabel")
	textoPantalla.AnchorPoint = Vector2.new(0.5, 0.5)
	textoPantalla.Position = UDim2.fromScale(0.5, 0.5)
	textoPantalla.Size = UDim2.fromScale(0.7, 0.6)
	textoPantalla.BackgroundTransparency = 1
	textoPantalla.TextWrapped = true
	textoPantalla.Font = FUENTE
	textoPantalla.TextSize = tamanoTexto(0.045)
	textoPantalla.TextColor3 = COLOR_TEXTO
	textoPantalla.TextTransparency = 1
	textoPantalla.ZIndex = 11
	textoPantalla.Text = ""
	textoPantalla.Parent = pantalla

	Net.obtener("Notice").OnClientEvent:Connect(mostrarAviso)
	Net.obtener("CustomerDialog").OnClientEvent:Connect(function(datos)
		task.spawn(mostrarDialogo, datos)
	end)
	Net.obtener("NightState").OnClientEvent:Connect(alCambiarNoche)
	Net.obtener("EndingTrigger").OnClientEvent:Connect(function(datos)
		task.spawn(mostrarFinal, datos)
	end)
end

return DialogUI
