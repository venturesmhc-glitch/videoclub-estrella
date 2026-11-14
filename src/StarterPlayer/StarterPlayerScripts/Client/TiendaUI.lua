--!nonstrict
--[[
	TiendaUI (cliente): la tienda del Videoclub. B la abre y la cierra (también el botón TIENDA del menú inicial).
	Pestañas: AYUDA (amuleto, baterías, pausa, revivir), ASPECTO (filtros de cinta), RADIO
	(Pase de Radio y estaciones) y PROPINA. Lo que se vende está en Config.Tienda.Catalogo.
	  - Lo que se paga cada vez ("consumible") manda Comprar { producto, objetivo? } al servidor, que valida y abre la compra.
	  - Lo permanente ("permanente") se compra una vez; después el botón pasa a EQUIPAR / QUITAR (Equipar { ranura, clave }).
	  - El perfil (compras y lo que lleva puesto) llega por ProfileLoaded.
	Mientras está abierta el mouse queda libre (botón Modal) y el personaje no se mueve.

	  TiendaUI.abrir() / TiendaUI.cerrar() / TiendaUI.alternar()
	  TiendaUI.estaAbierta() -> boolean
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local TiendaUI = {}

local cfg = Config.Tienda
local jugador = Players.LocalPlayer

local COLOR_TEXTO = Color3.fromRGB(236, 236, 226)
local COLOR_ACENTO = Color3.fromRGB(255, 220, 120)
local COLOR_APAGADO = Color3.fromRGB(150, 150, 142)
local COLOR_PANEL = Color3.fromRGB(18, 16, 14)
local FUENTE = Enum.Font.Code
local FUENTE_TITULO = Enum.Font.Arcade

local PESTANAS = {
	{ clave = "ayuda", texto = "AYUDA" },
	{ clave = "aspecto", texto = "ASPECTO" },
	{ clave = "radio", texto = "RADIO" },
	{ clave = "propina", texto = "PROPINA" },
}

local gui, fondo, lista, botonesPestana, hud, etiquetaAmuleto
local abierta = false
local pestana = "ayuda"
local compras, equipado = {}, {}

local function esEspectador(otro: Player): boolean
	return otro:GetAttribute("Espectador") == true
end

local function valorDe(articulo): string
	return articulo.valor or articulo.clave
end

local function precioDe(articulo): number
	return cfg.Precios[articulo.producto] or 0
end

-- ===== Construcción de la lista =====

local function etiqueta(padre, texto: string, posicion: UDim2, tamano: UDim2, color: Color3, alineacion)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FUENTE
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.TextXAlignment = alineacion or Enum.TextXAlignment.Left
	t.Text = texto
	t.Position = posicion
	t.Size = tamano
	t.Parent = padre
	return t
end

-- Una fila: nombre, descripción y un botón a la derecha. 'accion' puede ser nil (botón apagado).
local function fila(nombre: string, descripcion: string, textoBoton: string, accion, destacada: boolean?)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -14, 0, 66)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.93
	f.BorderSizePixel = 0
	f.Parent = lista
	local borde = Instance.new("UIStroke")
	borde.Color = destacada and COLOR_ACENTO or COLOR_TEXTO
	borde.Transparency = destacada and 0.3 or 0.7
	borde.Thickness = 1
	borde.Parent = f
	etiqueta(f, nombre, UDim2.new(0, 12, 0, 6), UDim2.new(1, -190, 0, 26), destacada and COLOR_ACENTO or COLOR_TEXTO)
	etiqueta(f, descripcion, UDim2.new(0, 12, 0, 34), UDim2.new(1, -190, 0, 24), COLOR_APAGADO)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -10, 0.5, 0)
	b.Size = UDim2.fromOffset(150, 42)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = accion and 0.85 or 1
	b.AutoButtonColor = false
	b.Font = FUENTE
	b.TextScaled = true
	b.TextColor3 = accion and COLOR_ACENTO or COLOR_APAGADO
	b.Text = textoBoton
	b.Parent = f
	local contorno = Instance.new("UIStroke")
	contorno.Color = accion and COLOR_ACENTO or COLOR_APAGADO
	contorno.Transparency = accion and 0.2 or 0.7
	contorno.Thickness = 2
	contorno.Parent = b
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	relleno.Parent = b
	if accion then
		b.MouseEnter:Connect(function()
			b.BackgroundTransparency = 0.7
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundTransparency = 0.85
		end)
		b.Activated:Connect(accion)
	end
	return f
end

local function encabezado(texto: string)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -14, 0, 30)
	t.BackgroundTransparency = 1
	t.Font = FUENTE_TITULO
	t.TextScaled = true
	t.TextColor3 = COLOR_ACENTO
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = texto
	t.Parent = lista
	return t
end

local function comprar(articulo, objetivo: number?)
	Net.obtener("Comprar"):FireServer({ producto = articulo.clave, objetivo = objetivo })
end

local function filaDeArticulo(articulo)
	local precio = string.format("R$ %d", precioDe(articulo))
	if articulo.tipo ~= "permanente" then
		fila(articulo.nombre, articulo.descripcion, precio, function()
			comprar(articulo)
		end)
		return
	end
	if not compras[articulo.clave] then
		fila(articulo.nombre, articulo.descripcion, precio, function()
			comprar(articulo)
		end)
		return
	end
	if not articulo.ranura then
		fila(articulo.nombre, articulo.descripcion, "COMPRADO", nil, true)
		return
	end
	local puesto = equipado[articulo.ranura] == valorDe(articulo)
	if puesto then
		fila(articulo.nombre, articulo.descripcion, "QUITAR", function()
			Net.obtener("Equipar"):FireServer({ ranura = articulo.ranura, clave = nil })
		end, true)
	else
		fila(articulo.nombre, articulo.descripcion, "EQUIPAR", function()
			Net.obtener("Equipar"):FireServer({ ranura = articulo.ranura, clave = articulo.clave })
		end)
	end
end

local function reconstruir()
	if not lista then
		return
	end
	local posicion = lista.CanvasPosition
	for _, hijo in lista:GetChildren() do
		if hijo:IsA("GuiObject") then
			hijo:Destroy()
		end
	end
	for clave, boton in botonesPestana do
		boton.TextColor3 = clave == pestana and COLOR_ACENTO or COLOR_APAGADO
		boton.BackgroundTransparency = clave == pestana and 0.85 or 1
	end

	if pestana == "ayuda" then
		for _, articulo in cfg.Catalogo do
			if articulo.categoria == "ayuda" then
				if articulo.clave == "companero" then
					-- Un renglón por cada compañero que quedó fuera de la noche.
					local fuera = {}
					for _, otro in Players:GetPlayers() do
						if otro ~= jugador and esEspectador(otro) then
							table.insert(fuera, otro)
						end
					end
					if #fuera == 0 then
						fila(articulo.nombre, "Ningún compañero está fuera de la noche.", string.format("R$ %d", precioDe(articulo)), nil)
					end
					for _, otro in fuera do
						fila(articulo.nombre .. ": " .. otro.DisplayName, articulo.descripcion, string.format("R$ %d", precioDe(articulo)), function()
							comprar(articulo, otro.UserId)
						end)
					end
				elseif articulo.clave == "revivir" and not esEspectador(jugador) then
					fila(articulo.nombre, "Solo si quedaste fuera de la noche.", string.format("R$ %d", precioDe(articulo)), nil)
				else
					filaDeArticulo(articulo)
				end
			end
		end
	elseif pestana == "aspecto" then
		encabezado("FILTROS DE CINTA")
		for _, articulo in cfg.Catalogo do
			if articulo.categoria == "filtro" then
				filaDeArticulo(articulo)
			end
		end
	elseif pestana == "radio" then
		for _, articulo in cfg.Catalogo do
			if articulo.categoria == "radio" then
				filaDeArticulo(articulo)
			end
		end
		encabezado("ESTACIONES")
		for _, estacion in Config.Radio.Estaciones do
			local libre = not estacion.Premium
			fila(estacion.Nombre, libre and "Incluida." or "Con el Pase de Radio.", libre and "LIBRE" or (compras.paseradio and "INCLUIDA" or "PREMIUM"), nil, libre or compras.paseradio == true)
		end
		fila("Cómo cambiar de estación", "Mirá la radio del mostrador y apretá R.", "", nil)
	elseif pestana == "propina" then
		for _, articulo in cfg.Catalogo do
			if articulo.categoria == "propina" then
				filaDeArticulo(articulo)
			end
		end
	end
	lista.CanvasPosition = posicion
end

local function elegirPestana(clave: string)
	pestana = clave
	if lista then
		lista.CanvasPosition = Vector2.zero
	end
	reconstruir()
end

-- ===== Abrir y cerrar =====

local function bloquear(valor: boolean)
	if valor then
		ContextActionService:BindActionAtPriority("TiendaBloqueo", function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Thumbstick1)
	else
		ContextActionService:UnbindAction("TiendaBloqueo")
	end
end

function TiendaUI.estaAbierta(): boolean
	return abierta
end

function TiendaUI.abrir()
	if abierta then
		return
	end
	abierta = true
	gui.Enabled = true
	bloquear(true)
	Net.obtener("MenuAction"):FireServer({ accion = "perfil" }) -- por si el perfil cambió desde que llegó el último
	reconstruir()
end

function TiendaUI.cerrar()
	if not abierta then
		return
	end
	abierta = false
	gui.Enabled = false
	bloquear(false)
end

function TiendaUI.alternar()
	if abierta then
		TiendaUI.cerrar()
	else
		TiendaUI.abrir()
	end
end

function TiendaUI.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Tienda"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 95 -- encima del menú (90), por debajo del filtro VHS (100)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = jugador:WaitForChild("PlayerGui")

	-- El fondo es un botón Modal: libera el mouse y no deja pasar clics al juego.
	fondo = Instance.new("TextButton")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Color3.new(0, 0, 0)
	fondo.BackgroundTransparency = 0.35
	fondo.BorderSizePixel = 0
	fondo.AutoButtonColor = false
	fondo.Text = ""
	fondo.Modal = true
	fondo.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.62, 0.84)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = fondo
	local bordePanel = Instance.new("UIStroke")
	bordePanel.Color = COLOR_ACENTO
	bordePanel.Transparency = 0.5
	bordePanel.Thickness = 2
	bordePanel.Parent = panel

	local titulo = Instance.new("TextLabel")
	titulo.Position = UDim2.fromScale(0.03, 0.02)
	titulo.Size = UDim2.fromScale(0.5, 0.07)
	titulo.BackgroundTransparency = 1
	titulo.Font = FUENTE_TITULO
	titulo.TextScaled = true
	titulo.TextColor3 = COLOR_ACENTO
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.Text = "TIENDA"
	titulo.Parent = panel

	local cerrar = Instance.new("TextButton")
	cerrar.AnchorPoint = Vector2.new(1, 0)
	cerrar.Position = UDim2.fromScale(0.97, 0.025)
	cerrar.Size = UDim2.fromScale(0.2, 0.06)
	cerrar.BackgroundTransparency = 1
	cerrar.Font = FUENTE
	cerrar.TextScaled = true
	cerrar.TextColor3 = COLOR_TEXTO
	cerrar.Text = "CERRAR (B)"
	cerrar.Parent = panel
	local bordeCerrar = Instance.new("UIStroke")
	bordeCerrar.Color = COLOR_TEXTO
	bordeCerrar.Transparency = 0.5
	bordeCerrar.Thickness = 2
	bordeCerrar.Parent = cerrar
	cerrar.Activated:Connect(TiendaUI.cerrar)

	botonesPestana = {}
	for i, p in PESTANAS do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromScale(0.03 + (i - 1) * 0.235, 0.105)
		b.Size = UDim2.fromScale(0.22, 0.06)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 1
		b.AutoButtonColor = false
		b.Font = FUENTE
		b.TextScaled = true
		b.TextColor3 = COLOR_APAGADO
		b.Text = p.texto
		b.Parent = panel
		local contorno = Instance.new("UIStroke")
		contorno.Color = COLOR_APAGADO
		contorno.Transparency = 0.6
		contorno.Thickness = 1
		contorno.Parent = b
		b.Activated:Connect(function()
			elegirPestana(p.clave)
		end)
		botonesPestana[p.clave] = b
	end

	lista = Instance.new("ScrollingFrame")
	lista.Position = UDim2.fromScale(0.03, 0.19)
	lista.Size = UDim2.fromScale(0.94, 0.7)
	lista.BackgroundTransparency = 1
	lista.BorderSizePixel = 0
	lista.ScrollBarThickness = 6
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.CanvasSize = UDim2.new()
	lista.Parent = panel
	local orden = Instance.new("UIListLayout")
	orden.Padding = UDim.new(0, 8)
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = lista

	local pie = Instance.new("TextLabel")
	pie.AnchorPoint = Vector2.new(0.5, 1)
	pie.Position = UDim2.fromScale(0.5, 0.985)
	pie.Size = UDim2.fromScale(0.94, 0.045)
	pie.BackgroundTransparency = 1
	pie.Font = FUENTE
	pie.TextScaled = true
	pie.TextColor3 = COLOR_APAGADO
	pie.Text = "Las compras se pagan con Robux y las ayudas valen solo durante el turno."
	pie.Parent = panel

	-- HUD chico, siempre visible: el amuleto activo y la pista de la tecla.
	hud = Instance.new("ScreenGui")
	hud.Name = "TiendaHUD"
	hud.ResetOnSpawn = false
	hud.DisplayOrder = 56
	hud.Parent = jugador:WaitForChild("PlayerGui")
	etiquetaAmuleto = etiqueta(hud, "AMULETO ✦", UDim2.fromScale(0.015, 0.8), UDim2.fromScale(0.15, 0.03), COLOR_ACENTO)
	etiquetaAmuleto.Font = FUENTE
	etiquetaAmuleto.TextStrokeTransparency = 0.6
	etiquetaAmuleto.Visible = false
	jugador:GetAttributeChangedSignal("Amuleto"):Connect(function()
		etiquetaAmuleto.Visible = jugador:GetAttribute("Amuleto") == true
	end)
	local pista = etiqueta(hud, "B · TIENDA", UDim2.fromScale(0.85, 0.955), UDim2.fromScale(0.14, 0.025), COLOR_TEXTO, Enum.TextXAlignment.Right)
	pista.TextTransparency = 0.55

	Net.obtener("ProfileLoaded").OnClientEvent:Connect(function(perfil)
		if typeof(perfil) ~= "table" then
			return
		end
		compras = typeof(perfil.compras) == "table" and perfil.compras or {}
		equipado = typeof(perfil.equipado) == "table" and perfil.equipado or {}
		if abierta then
			reconstruir()
		end
	end)

	-- Cuando alguien queda fuera de la noche (o vuelve) la pestaña de ayuda cambia.
	local function vigilar(otro: Player)
		otro:GetAttributeChangedSignal("Espectador"):Connect(function()
			if abierta then
				reconstruir()
			end
		end)
	end
	for _, otro in Players:GetPlayers() do
		vigilar(otro)
	end
	Players.PlayerAdded:Connect(vigilar)
	Players.PlayerRemoving:Connect(function()
		if abierta then
			task.defer(reconstruir)
		end
	end)

	-- Para pruebas: el atributo AbrirTienda del jugador la abre (true, o el nombre de una pestaña) o la cierra (false).
	jugador:GetAttributeChangedSignal("AbrirTienda"):Connect(function()
		local valor = jugador:GetAttribute("AbrirTienda")
		if valor then
			if typeof(valor) == "string" and botonesPestana[valor] then
				elegirPestana(valor)
			end
			TiendaUI.abrir()
		else
			TiendaUI.cerrar()
		end
	end)

	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.B then
			TiendaUI.alternar()
		end
	end)
end

return TiendaUI
