--!nonstrict
--[[
	MenuUI (cliente): menú de inicio, sala de espera y ajustes.
	  - Al entrar se ve el menú: UN JUGADOR (arranca el turno), MULTIJUGADOR (sala de espera donde el anfitrión
	    elige cuándo empezar), AJUSTES y CÓMO JUGAR.
	  - Durante el turno, la tecla M abre los ajustes (el juego no se pausa: es cooperativo en vivo).
	El servidor (Partida) decide la fase; este módulo solo la muestra y manda las elecciones (remote MenuAction).
	Todos los textos están en TEXTOS para poder traducirlos más adelante.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AudioManager = require(script.Parent.AudioManager)
local VHSEffects = require(script.Parent.VHSEffects)

local MenuUI = {}

local TEXTOS = {
	titulo = "VIDEOCLUB ESTRELLA",
	subtitulo = "TURNO NOCHE · NOVIEMBRE DE 1997",
	solo = "UN JUGADOR",
	multi = "MULTIJUGADOR",
	ajustes = "AJUSTES",
	ayuda = "CÓMO JUGAR",
	volver = "VOLVER",
	cargando = "CARGANDO...",
	salaTitulo = "SALA DE ESPERA",
	salaEspera = "Esperando que %s empiece el turno...",
	salaAnfitrion = "Sos el anfitrión. Cuando estén todos, empezá el turno.",
	salaCupo = "%d / %d jugadores",
	empezar = "EMPEZAR TURNO",
	ajustesTitulo = "AJUSTES",
	volMusica = "Música",
	volAmbiente = "Sonido ambiente",
	estatica = "Estática del filtro VHS",
	idioma = "Idioma: Español (más idiomas pronto)",
	ayudaTitulo = "CÓMO JUGAR",
	ayudaTexto = table.concat({
		"WASD  moverte",
		"E  interactuar  (mantené E donde lo pida)",
		"R (mantener)  segunda acción: rechazar, grabar encima",
		"Tab  mostrar u ocultar tu ficha de socio",
		"Q  marcar algo fuera de lugar (apuntale)",
		"F  linterna      M  ajustes",
		"",
		"Aguantá el turno noche hasta las 04:00.",
		"Atendé clientes, rebobiná y reponé casetes, tirá la basura en el patio y limpiá las manchas.",
		"El Socio N° 0000 solo se mueve cuando nadie lo mira.",
	}, "\n"),
}

local COLOR_TEXTO = Color3.fromRGB(236, 236, 226)
local COLOR_ACENTO = Color3.fromRGB(255, 220, 120)
local COLOR_APAGADO = Color3.fromRGB(150, 150, 142)
local FUENTE = Enum.Font.Code
local FUENTE_TITULO = Enum.Font.Arcade

local gui, fondo, pantallas
local estadoPartida = { fase = "cargando" }
local enJuego = false -- el turno ya empezó
local ajustesAbiertos = false
local pantallaActual = "cargando"
local ajustes = { Musica = 1, Ambiente = 1, Estatica = 1 } -- guardados solo en esta sesión

-- ===== Utilidades de interfaz =====

local function texto(padre, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.fuente or FUENTE
	t.TextColor3 = props.color or COLOR_TEXTO
	t.TextScaled = props.escalado ~= false
	t.TextWrapped = true
	t.TextXAlignment = props.alineacion or Enum.TextXAlignment.Center
	t.TextYAlignment = props.alineacionY or Enum.TextYAlignment.Center
	t.Text = props.texto or ""
	t.Size = props.tamano or UDim2.fromScale(1, 0.1)
	t.Position = props.posicion or UDim2.fromScale(0, 0)
	t.AnchorPoint = props.ancla or Vector2.new(0, 0)
	t.Parent = padre
	return t
end

local function boton(padre, etiqueta, posicion, alActivar, tamano)
	local b = Instance.new("TextButton")
	b.Size = tamano or UDim2.fromScale(0.34, 0.085)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = posicion
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Font = FUENTE
	b.TextScaled = true
	b.TextColor3 = COLOR_TEXTO
	b.Text = etiqueta
	b.Parent = padre
	local borde = Instance.new("UIStroke")
	borde.Color = COLOR_TEXTO
	borde.Thickness = 2
	borde.Transparency = 0.5
	borde.Parent = b
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	relleno.Parent = b
	b.MouseEnter:Connect(function()
		b.BackgroundTransparency = 0.88
		b.TextColor3 = COLOR_ACENTO
		borde.Color = COLOR_ACENTO
		borde.Transparency = 0
		b.Text = "▶ " .. etiqueta
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundTransparency = 1
		b.TextColor3 = COLOR_TEXTO
		borde.Color = COLOR_TEXTO
		borde.Transparency = 0.5
		b.Text = etiqueta
	end)
	b.Activated:Connect(alActivar)
	return b
end

-- Deslizador 0..1 con el valor visible. alCambiar(valor) se llama mientras se arrastra.
local function deslizador(padre, etiqueta, posicionY, inicial, alCambiar)
	local fila = Instance.new("Frame")
	fila.BackgroundTransparency = 1
	fila.Size = UDim2.fromScale(0.7, 0.09)
	fila.AnchorPoint = Vector2.new(0.5, 0.5)
	fila.Position = UDim2.fromScale(0.5, posicionY)
	fila.Parent = padre
	texto(fila, { texto = etiqueta, tamano = UDim2.fromScale(0.4, 1), alineacion = Enum.TextXAlignment.Left })
	local pista = Instance.new("TextButton")
	pista.Text = ""
	pista.AutoButtonColor = false
	pista.AnchorPoint = Vector2.new(0, 0.5)
	pista.Position = UDim2.fromScale(0.45, 0.5)
	pista.Size = UDim2.fromScale(0.42, 0.22)
	pista.BackgroundColor3 = Color3.fromRGB(70, 70, 66)
	pista.BorderSizePixel = 0
	pista.Parent = fila
	local lleno = Instance.new("Frame")
	lleno.BackgroundColor3 = COLOR_ACENTO
	lleno.BorderSizePixel = 0
	lleno.Size = UDim2.fromScale(inicial, 1)
	lleno.Parent = pista
	local perilla = Instance.new("Frame")
	perilla.AnchorPoint = Vector2.new(0.5, 0.5)
	perilla.Size = UDim2.new(0, 10, 1.9, 0)
	perilla.Position = UDim2.fromScale(inicial, 0.5)
	perilla.BackgroundColor3 = COLOR_TEXTO
	perilla.BorderSizePixel = 0
	perilla.Parent = pista
	local valorTexto = texto(fila, { texto = "", tamano = UDim2.fromScale(0.12, 1), posicion = UDim2.fromScale(0.88, 0), alineacion = Enum.TextXAlignment.Right })

	local function fijar(valor)
		valor = math.clamp(valor, 0, 1)
		lleno.Size = UDim2.fromScale(valor, 1)
		perilla.Position = UDim2.fromScale(valor, 0.5)
		valorTexto.Text = string.format("%d%%", math.floor(valor * 100 + 0.5))
		alCambiar(valor)
	end
	fijar(inicial)

	local arrastrando = false
	local function desdeEntrada(entrada)
		local ancho = pista.AbsoluteSize.X
		if ancho > 0 then
			fijar((entrada.Position.X - pista.AbsolutePosition.X) / ancho)
		end
	end
	pista.InputBegan:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.UserInputType == Enum.UserInputType.Touch then
			arrastrando = true
			desdeEntrada(entrada)
		end
	end)
	UserInputService.InputChanged:Connect(function(entrada)
		if arrastrando and (entrada.UserInputType == Enum.UserInputType.MouseMovement or entrada.UserInputType == Enum.UserInputType.Touch) then
			desdeEntrada(entrada)
		end
	end)
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.UserInputType == Enum.UserInputType.Touch then
			arrastrando = false
		end
	end)
	return fijar
end

-- ===== Pantallas =====

local function nuevaPantalla(nombre)
	local p = Instance.new("Frame")
	p.Name = nombre
	p.Size = UDim2.fromScale(1, 1)
	p.BackgroundTransparency = 1
	p.Visible = false
	p.Parent = fondo
	pantallas[nombre] = p
	return p
end

local mostrarPantalla

-- A dónde vuelve "VOLVER": al turno si ya empezó, a la sala si se eligió multijugador, o al menú.
local function destinoVolver()
	if enJuego then
		return "juego"
	elseif estadoPartida.fase == "lobby" then
		return "lobby"
	end
	return "principal"
end

local function enviar(accion)
	Net.obtener("MenuAction"):FireServer({ accion = accion })
end

local function construirPrincipal()
	local p = nuevaPantalla("principal")
	texto(p, { texto = TEXTOS.titulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.8, 0.14), posicion = UDim2.fromScale(0.5, 0.2), ancla = Vector2.new(0.5, 0.5) })
	texto(p, { texto = TEXTOS.subtitulo, tamano = UDim2.fromScale(0.5, 0.04), posicion = UDim2.fromScale(0.5, 0.31), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	-- Botones separados 0.13 de alto y de 0.075: queda aire entre uno y otro para no confundirlos.
	local TAM_BOTON = UDim2.fromScale(0.34, 0.075)
	boton(p, TEXTOS.solo, UDim2.fromScale(0.5, 0.45), function()
		enviar("solo")
	end, TAM_BOTON)
	boton(p, TEXTOS.multi, UDim2.fromScale(0.5, 0.58), function()
		enviar("multi")
	end, TAM_BOTON)
	boton(p, TEXTOS.ajustes, UDim2.fromScale(0.5, 0.71), function()
		mostrarPantalla("ajustes")
	end, TAM_BOTON)
	boton(p, TEXTOS.ayuda, UDim2.fromScale(0.5, 0.84), function()
		mostrarPantalla("ayuda")
	end, TAM_BOTON)
end

local lobbyLista, lobbyEstado, lobbyBotonEmpezar, lobbyBotonVolver

local function construirLobby()
	local p = nuevaPantalla("lobby")
	texto(p, { texto = TEXTOS.salaTitulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.11), posicion = UDim2.fromScale(0.5, 0.16), ancla = Vector2.new(0.5, 0.5) })
	lobbyEstado = texto(p, { texto = "", tamano = UDim2.fromScale(0.7, 0.05), posicion = UDim2.fromScale(0.5, 0.26), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	lobbyLista = texto(p, { texto = "", tamano = UDim2.fromScale(0.4, 0.3), posicion = UDim2.fromScale(0.5, 0.45), ancla = Vector2.new(0.5, 0.5), escalado = false })
	lobbyLista.TextSize = 24
	lobbyBotonEmpezar = boton(p, TEXTOS.empezar, UDim2.fromScale(0.5, 0.7), function()
		enviar("empezar")
	end, UDim2.fromScale(0.34, 0.075))
	lobbyBotonVolver = boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.85), function()
		enviar("cancelar")
	end, UDim2.fromScale(0.25, 0.07))
end

local function construirAyuda()
	local p = nuevaPantalla("ayuda")
	texto(p, { texto = TEXTOS.ayudaTitulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.1), posicion = UDim2.fromScale(0.5, 0.14), ancla = Vector2.new(0.5, 0.5) })
	local cuerpo = texto(p, {
		texto = TEXTOS.ayudaTexto, escalado = false, tamano = UDim2.fromScale(0.72, 0.5), posicion = UDim2.fromScale(0.5, 0.48),
		ancla = Vector2.new(0.5, 0.5), alineacion = Enum.TextXAlignment.Left, alineacionY = Enum.TextYAlignment.Top,
	})
	cuerpo.TextSize = 24
	boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.82), function()
		mostrarPantalla(destinoVolver())
	end, UDim2.fromScale(0.25, 0.07))
end

local function construirAjustes()
	local p = nuevaPantalla("ajustes")
	texto(p, { texto = TEXTOS.ajustesTitulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.1), posicion = UDim2.fromScale(0.5, 0.14), ancla = Vector2.new(0.5, 0.5) })
	deslizador(p, TEXTOS.volMusica, 0.32, ajustes.Musica, function(v)
		ajustes.Musica = v
		AudioManager.setGrupo("Musica", v)
	end)
	deslizador(p, TEXTOS.volAmbiente, 0.44, ajustes.Ambiente, function(v)
		ajustes.Ambiente = v
		AudioManager.setGrupo("Ambiente", v)
	end)
	deslizador(p, TEXTOS.estatica, 0.56, ajustes.Estatica, function(v)
		ajustes.Estatica = v
		VHSEffects.setAjusteEstatica(v)
	end)
	texto(p, { texto = TEXTOS.idioma, tamano = UDim2.fromScale(0.7, 0.045), posicion = UDim2.fromScale(0.5, 0.67), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.8), function()
		mostrarPantalla(destinoVolver())
	end, UDim2.fromScale(0.25, 0.07))
end

local function actualizarLobby()
	if not lobbyLista then
		return
	end
	local lineas = {}
	for _, nombre in estadoPartida.jugadores or {} do
		table.insert(lineas, "• " .. nombre)
	end
	table.insert(lineas, "")
	table.insert(lineas, string.format(TEXTOS.salaCupo, #(estadoPartida.jugadores or {}), estadoPartida.maximo or Config.Partida.MaxJugadores))
	lobbyLista.Text = table.concat(lineas, "\n")
	local soyAnfitrion = estadoPartida.anfitrionId == Players.LocalPlayer.UserId
	lobbyEstado.Text = soyAnfitrion and TEXTOS.salaAnfitrion or string.format(TEXTOS.salaEspera, estadoPartida.anfitrion or "el anfitrión")
	lobbyBotonEmpezar.Visible = soyAnfitrion
	lobbyBotonVolver.Visible = soyAnfitrion
end

-- ===== Visibilidad y bloqueo del movimiento =====

local function bloquearMovimiento(bloquear: boolean)
	if bloquear then
		ContextActionService:BindActionAtPriority("MenuBloqueo", function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Thumbstick1)
	else
		ContextActionService:UnbindAction("MenuBloqueo")
	end
end

function mostrarPantalla(nombre)
	pantallaActual = nombre
	ajustesAbiertos = nombre == "ajustes" and enJuego
	if nombre == "juego" then
		fondo.Visible = false
		bloquearMovimiento(false)
		return
	end
	fondo.Visible = true
	-- En pleno turno el fondo es translúcido (se sigue viendo el local); en el menú, negro.
	fondo.BackgroundTransparency = enJuego and 0.35 or 0
	bloquearMovimiento(not enJuego)
	for clave, pantalla in pantallas do
		pantalla.Visible = clave == nombre
	end
	if nombre == "lobby" then
		actualizarLobby()
	end
end

local function alCambiarPartida(datos)
	if typeof(datos) ~= "table" then
		return
	end
	estadoPartida = datos
	if datos.fase == "jugando" then
		if not enJuego then
			enJuego = true
			if pantallaActual ~= "ajustes" and pantallaActual ~= "ayuda" then
				mostrarPantalla("juego")
			end
		end
	elseif datos.fase == "lobby" then
		enJuego = false
		if pantallaActual ~= "ajustes" and pantallaActual ~= "ayuda" then
			mostrarPantalla("lobby")
		else
			actualizarLobby()
		end
	elseif datos.fase == "menu" then
		enJuego = false
		if pantallaActual == "lobby" or pantallaActual == "cargando" then
			mostrarPantalla("principal")
		end
	end
	actualizarLobby()
end

function MenuUI.init()
	local jugador = Players.LocalPlayer
	gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90 -- por debajo del filtro VHS (100): el menú también sale con scanlines
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = jugador:WaitForChild("PlayerGui")

	-- El fondo es un botón "Modal": libera el mouse (la cámara en primera persona lo tiene bloqueado) y bloquea los clics hacia atrás.
	fondo = Instance.new("TextButton")
	fondo.Name = "Fondo"
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Color3.new(0, 0, 0)
	fondo.BorderSizePixel = 0
	fondo.AutoButtonColor = false
	fondo.Text = ""
	fondo.Modal = true
	fondo.Parent = gui

	pantallas = {}
	local carga = nuevaPantalla("cargando")
	texto(carga, { texto = TEXTOS.cargando, tamano = UDim2.fromScale(0.4, 0.06), posicion = UDim2.fromScale(0.5, 0.5), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	construirPrincipal()
	construirLobby()
	construirAyuda()
	construirAjustes()
	mostrarPantalla("cargando")

	Net.obtener("PartidaState").OnClientEvent:Connect(alCambiarPartida)
	Net.obtener("MenuAction"):FireServer({ accion = "estado" })
	-- Si el primer pedido llegó antes de que el servidor estuviera listo, se repite.
	task.delay(2, function()
		if pantallaActual == "cargando" then
			Net.obtener("MenuAction"):FireServer({ accion = "estado" })
		end
	end)

	-- M abre y cierra los ajustes durante el turno.
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado or entrada.KeyCode ~= Enum.KeyCode.M or not enJuego then
			return
		end
		if ajustesAbiertos then
			mostrarPantalla("juego")
		elseif pantallaActual == "juego" then
			mostrarPantalla("ajustes")
		end
	end)
end

return MenuUI
