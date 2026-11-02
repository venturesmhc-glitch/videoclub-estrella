--!nonstrict
--[[
	MenuUI (cliente): menú de inicio, salas de multijugador y ajustes.
	  - Al entrar se ve el menú: UN JUGADOR (arranca el turno), MULTIJUGADOR, LOGROS (insignias desbloqueadas y por desbloquear), AJUSTES y CÓMO JUGAR.
	  - MULTIJUGADOR lista las salas públicas y abajo ofrece CREAR (pública o privada, de 2 a 4 jugadores) y UNIRSE POR
	    CÓDIGO. Una vez dentro de una sala se ve su código, quiénes están, y el anfitrión la inicia con INICIAR.
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
local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Idioma = require(ReplicatedStorage.Shared.Idioma)
local AudioManager = require(script.Parent.AudioManager)
local Rendimiento = require(script.Parent.Rendimiento)
local VHSEffects = require(script.Parent.VHSEffects)

local MenuUI = {}

local TEXTOS = {
	titulo = "VIDEOCLUB ESTRELLA",
	subtitulo = "TURNO NOCHE · NOVIEMBRE DE 1997",
	solo = "UN JUGADOR",
	multi = "MULTIJUGADOR",
	modoHistoria = "HISTORIA",
	modoSinFin = "SIN FIN",
	modoSinFinBloqueado = "SIN FIN (BLOQUEADO)",
	sinFinAyuda = "El modo Sin fin se desbloquea al alcanzar un final de la historia.",
	modoLobbyHistoria = "MODO: HISTORIA",
	modoLobbySinFin = "MODO: SIN FIN",
	ajustes = "AJUSTES",
	logros = "LOGROS",
	logrosConteo = "%d / %d desbloqueados",
	logrosRecord = "Récord en Sin fin: %d noches",
	logroSi = "DESBLOQUEADO",
	logroNo = "BLOQUEADO",
	ayuda = "CÓMO JUGAR",
	volver = "VOLVER",
	cargando = "CARGANDO...",
	reuniendo = "REUNIENDO AL EQUIPO...",
	salaIniciando = "Iniciando la partida... entrando al servidor de juego.",
	salaTitulo = "SALA DE ESPERA",
	salaEspera = "Esperando que %s empiece el turno...",
	salaAnfitrion = "Sos el anfitrión. Cuando estén todos, empezá el turno.",
	salaCupo = "%d / %d jugadores",
	empezar = "INICIAR",
	salasTitulo = "MULTIJUGADOR",
	salasSub = "Salas públicas",
	salasVacio = "No hay salas públicas por ahora.\nCreá una o unite con un código.",
	crear = "CREAR",
	unirseCodigo = "UNIRSE POR CÓDIGO",
	crearTitulo = "CREAR SALA",
	visibilidad = "Visibilidad de la sala",
	publica = "PÚBLICA",
	privada = "PRIVADA",
	cantidadJugadores = "Cantidad de jugadores (máx. %d)",
	crearSala = "CREAR SALA",
	unirseTitulo = "UNIRSE POR CÓDIGO",
	codigoAyuda = "Escribí el código de la sala (%d caracteres)",
	codigoHint = "CÓDIGO",
	unirse = "UNIRSE",
	codigoSala = "CÓDIGO: %s",
	salaPublicaTipo = "Sala pública · %d/%d jugadores",
	salaPrivadaTipo = "Sala privada · %d/%d jugadores",
	salir = "SALIR DE LA SALA",
	salirAlMenu = "SALIR AL MENÚ PRINCIPAL",
	entrando = "Entrando a la sala...",
	ajustesTitulo = "AJUSTES",
	volMusica = "Música",
	volAmbiente = "Sonido ambiente",
	estatica = "Estática del filtro VHS",
	calidad = "Calidad gráfica: %s",
	salaConteo = "\nEl turno arranca solo en %d s.",
	ayudaTitulo = "CÓMO JUGAR",
	ayudaTexto = table.concat({
		"WASD  moverte",
		"E  interactuar  (mantené E donde lo pida)",
		"R (mantener)  segunda acción: rechazar, grabar encima",
		"Tab  mostrar u ocultar tu ficha de socio      G  soltar lo que llevás en la mano",
		"Q  marcar algo fuera de lugar (apuntale)",
		"F  linterna      M  ajustes",
		"Shift  soltar o atrapar el mouse (para tocar botones, como comprar)",
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

local gui, fondo, pantallas, cargandoTexto
local estadoPartida = { fase = "cargando" }
local enJuego = false -- el turno ya empezó
local ajustesAbiertos = false
local pantallaActual = "cargando"
local ajustes = { Musica = 1, Ambiente = 1, Estatica = 1 } -- guardados solo en esta sesión
local modoElegido = "historia" -- "historia" | "sinfin": lo que se manda al elegir UN JUGADOR o CREAR una sala
local sinFinListo = false -- el servidor avisó que ya alcanzó un final (perfil)
local actualizarModo -- (se define con la pantalla principal)
local perfilInsignias, mejorSinFin = {}, 0 -- logros desbloqueados y récord del modo Sin fin (perfil)
local actualizarLogros -- (se define con la pantalla de logros)

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

local function enviar(accion, extra)
	local datos = { accion = accion }
	for clave, valor in extra or {} do
		datos[clave] = valor
	end
	Net.obtener("MenuAction"):FireServer(datos)
end

-- Mensaje de estado de las pantallas de salas (errores del servidor, "Creando la sala...", etc.).
local mensajes = {}
local function ponerMensaje(texto, esError)
	for _, etiqueta in mensajes do
		etiqueta.Text = texto or ""
		etiqueta.TextColor3 = esError and Color3.fromRGB(235, 110, 100) or COLOR_APAGADO
	end
end

-- Botón que queda marcado (borde y texto en acento) cuando está elegido.
local function selector(padre, etiqueta, posicion, tamano, alActivar)
	local b = Instance.new("TextButton")
	b.Size = tamano
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = posicion
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Font = FUENTE
	b.TextScaled = true
	b.Text = etiqueta
	b.Parent = padre
	local borde = Instance.new("UIStroke")
	borde.Thickness = 2
	borde.Parent = b
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	relleno.Parent = b
	local function marcar(activo)
		b.TextColor3 = activo and COLOR_ACENTO or COLOR_APAGADO
		borde.Color = activo and COLOR_ACENTO or COLOR_TEXTO
		borde.Transparency = activo and 0 or 0.6
		b.BackgroundTransparency = activo and 0.88 or 1
	end
	marcar(false)
	b.Activated:Connect(alActivar)
	return b, marcar
end

local function construirPrincipal()
	local p = nuevaPantalla("principal")
	texto(p, { texto = TEXTOS.titulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.8, 0.14), posicion = UDim2.fromScale(0.5, 0.2), ancla = Vector2.new(0.5, 0.5) })
	texto(p, { texto = TEXTOS.subtitulo, tamano = UDim2.fromScale(0.5, 0.04), posicion = UDim2.fromScale(0.5, 0.31), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	-- Botones separados 0.13 de alto y de 0.075: queda aire entre uno y otro para no confundirlos.
	local TAM_BOTON = UDim2.fromScale(0.34, 0.075)
	-- Modo de juego: HISTORIA (cinco noches con final) o SIN FIN (desbloqueable). Vale para UN JUGADOR y para las salas.
	local TAM_MODO = UDim2.fromScale(0.17, 0.05)
	local botonHistoria, marcarHistoria = selector(p, TEXTOS.modoHistoria, UDim2.fromScale(0.415, 0.38), TAM_MODO, function()
		modoElegido = "historia"
		actualizarModo()
	end)
	local botonSinFin, marcarSinFin = selector(p, TEXTOS.modoSinFin, UDim2.fromScale(0.585, 0.38), TAM_MODO, function()
		if not sinFinListo then
			ponerMensaje(TEXTOS.sinFinAyuda, true)
			return
		end
		modoElegido = "sinfin"
		actualizarModo()
	end)
	function actualizarModo()
		if modoElegido == "sinfin" and not sinFinListo then
			modoElegido = "historia"
		end
		marcarHistoria(modoElegido == "historia")
		marcarSinFin(modoElegido == "sinfin")
		botonSinFin.Text = sinFinListo and TEXTOS.modoSinFin or TEXTOS.modoSinFinBloqueado
		botonSinFin.TextTransparency = sinFinListo and 0 or 0.45
		botonHistoria.TextTransparency = 0
	end
	actualizarModo()
	boton(p, TEXTOS.solo, UDim2.fromScale(0.5, 0.46), function()
		enviar("solo", { modo = modoElegido })
	end, TAM_BOTON)
	boton(p, TEXTOS.multi, UDim2.fromScale(0.5, 0.56), function()
		mostrarPantalla("salas")
		enviar("salas")
	end, TAM_BOTON)
	boton(p, TEXTOS.logros, UDim2.fromScale(0.5, 0.66), function()
		enviar("perfil") -- por si el perfil cambió desde que se abrió el menú
		actualizarLogros()
		mostrarPantalla("logros")
	end, TAM_BOTON)
	boton(p, TEXTOS.ajustes, UDim2.fromScale(0.5, 0.76), function()
		mostrarPantalla("ajustes")
	end, TAM_BOTON)
	boton(p, TEXTOS.ayuda, UDim2.fromScale(0.5, 0.86), function()
		mostrarPantalla("ayuda")
	end, TAM_BOTON)
	table.insert(mensajes, texto(p, { texto = "", tamano = UDim2.fromScale(0.5, 0.04), posicion = UDim2.fromScale(0.5, 0.93), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO }))
end

local lobbyLista, lobbyEstado, lobbyBotonEmpezar, lobbyBotonVolver, lobbyCodigo, lobbyTipo, lobbyModo
local listaSalas, listaVacia

local function construirLobby()
	local p = nuevaPantalla("lobby")
	texto(p, { texto = TEXTOS.salaTitulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.1), posicion = UDim2.fromScale(0.5, 0.13), ancla = Vector2.new(0.5, 0.5) })
	lobbyCodigo = texto(p, { texto = "", fuente = FUENTE_TITULO, color = COLOR_TEXTO, tamano = UDim2.fromScale(0.6, 0.085), posicion = UDim2.fromScale(0.5, 0.23), ancla = Vector2.new(0.5, 0.5) })
	lobbyTipo = texto(p, { texto = "", tamano = UDim2.fromScale(0.6, 0.04), posicion = UDim2.fromScale(0.5, 0.3), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	lobbyModo = texto(p, { texto = "", tamano = UDim2.fromScale(0.4, 0.035), posicion = UDim2.fromScale(0.5, 0.345), ancla = Vector2.new(0.5, 0.5), color = COLOR_ACENTO })
	lobbyLista = texto(p, { texto = "", tamano = UDim2.fromScale(0.4, 0.26), posicion = UDim2.fromScale(0.5, 0.49), ancla = Vector2.new(0.5, 0.5), escalado = false })
	lobbyLista.TextSize = 24
	lobbyEstado = texto(p, { texto = "", tamano = UDim2.fromScale(0.7, 0.05), posicion = UDim2.fromScale(0.5, 0.67), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	-- Abajo: INICIAR (solo el anfitrión) y SALIR.
	lobbyBotonEmpezar = boton(p, TEXTOS.empezar, UDim2.fromScale(0.5, 0.77), function()
		enviar("empezar")
	end, UDim2.fromScale(0.34, 0.075))
	lobbyBotonVolver = boton(p, TEXTOS.salir, UDim2.fromScale(0.5, 0.89), function()
		enviar("salir")
	end, UDim2.fromScale(0.3, 0.07))
end

-- Lista de salas públicas: una fila por sala; tocar una fila entra a esa sala.
local function actualizarListaSalas(salas)
	if not listaSalas then
		return
	end
	for _, hijo in listaSalas:GetChildren() do
		if hijo:IsA("TextButton") then
			hijo:Destroy()
		end
	end
	listaVacia.Visible = #salas == 0
	for i, sala in salas do
		local fila = Instance.new("TextButton")
		fila.LayoutOrder = i
		fila.Size = UDim2.new(1, -10, 0, 46)
		fila.BackgroundColor3 = COLOR_TEXTO
		fila.BackgroundTransparency = 0.93
		fila.AutoButtonColor = false
		fila.Font = FUENTE
		fila.TextSize = 22
		fila.TextColor3 = COLOR_TEXTO
		fila.TextXAlignment = Enum.TextXAlignment.Left
		fila.Text = string.format("%s    %s    %d/%d", sala.codigo, sala.anfitrion or "—", sala.jugadores or 1, sala.maximo or Config.Partida.MaxJugadores)
		fila.Parent = listaSalas
		local relleno = Instance.new("UIPadding")
		relleno.PaddingLeft = UDim.new(0, 12)
		relleno.Parent = fila
		fila.MouseEnter:Connect(function()
			fila.BackgroundTransparency = 0.8
			fila.TextColor3 = COLOR_ACENTO
		end)
		fila.MouseLeave:Connect(function()
			fila.BackgroundTransparency = 0.93
			fila.TextColor3 = COLOR_TEXTO
		end)
		fila.Activated:Connect(function()
			ponerMensaje(TEXTOS.entrando)
			enviar("unirse", { codigo = sala.codigo })
		end)
	end
end

local function construirSalas()
	local p = nuevaPantalla("salas")
	texto(p, { texto = TEXTOS.salasTitulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.1), posicion = UDim2.fromScale(0.5, 0.13), ancla = Vector2.new(0.5, 0.5) })
	texto(p, { texto = TEXTOS.salasSub, tamano = UDim2.fromScale(0.4, 0.04), posicion = UDim2.fromScale(0.5, 0.2), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	listaSalas = Instance.new("ScrollingFrame")
	listaSalas.Size = UDim2.fromScale(0.6, 0.38)
	listaSalas.AnchorPoint = Vector2.new(0.5, 0.5)
	listaSalas.Position = UDim2.fromScale(0.5, 0.43)
	listaSalas.BackgroundTransparency = 1
	listaSalas.BorderSizePixel = 0
	listaSalas.ScrollBarThickness = 6
	listaSalas.CanvasSize = UDim2.new(0, 0, 0, 0)
	listaSalas.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listaSalas.Parent = p
	local marco = Instance.new("UIStroke")
	marco.Color = COLOR_TEXTO
	marco.Transparency = 0.7
	marco.Parent = listaSalas
	local orden = Instance.new("UIListLayout")
	orden.Padding = UDim.new(0, 6)
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = listaSalas
	listaVacia = texto(p, { texto = TEXTOS.salasVacio, tamano = UDim2.fromScale(0.5, 0.12), posicion = UDim2.fromScale(0.5, 0.43), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	table.insert(mensajes, texto(p, { texto = "", tamano = UDim2.fromScale(0.6, 0.045), posicion = UDim2.fromScale(0.5, 0.67), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO }))
	-- Abajo: CREAR y UNIRSE POR CÓDIGO.
	boton(p, TEXTOS.crear, UDim2.fromScale(0.31, 0.78), function()
		mostrarPantalla("crear")
	end, UDim2.fromScale(0.28, 0.075))
	boton(p, TEXTOS.unirseCodigo, UDim2.fromScale(0.69, 0.78), function()
		mostrarPantalla("unirse")
	end, UDim2.fromScale(0.28, 0.075))
	boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.9), function()
		mostrarPantalla("principal")
	end, UDim2.fromScale(0.25, 0.07))
end

local function construirCrear()
	local p = nuevaPantalla("crear")
	local publica, maximo = true, Config.Partida.MaxJugadores
	texto(p, { texto = TEXTOS.crearTitulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.1), posicion = UDim2.fromScale(0.5, 0.12), ancla = Vector2.new(0.5, 0.5) })
	texto(p, { texto = TEXTOS.visibilidad, tamano = UDim2.fromScale(0.5, 0.045), posicion = UDim2.fromScale(0.5, 0.27), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	local TAM = UDim2.fromScale(0.2, 0.075)
	local marcarPublica, marcarPrivada
	local function elegir(esPublica)
		publica = esPublica
		marcarPublica(esPublica)
		marcarPrivada(not esPublica)
	end
	local _
	_, marcarPublica = selector(p, TEXTOS.publica, UDim2.fromScale(0.39, 0.36), TAM, function()
		elegir(true)
	end)
	_, marcarPrivada = selector(p, TEXTOS.privada, UDim2.fromScale(0.61, 0.36), TAM, function()
		elegir(false)
	end)
	elegir(true)

	texto(p, { texto = string.format(TEXTOS.cantidadJugadores, Config.Partida.MaxJugadores), tamano = UDim2.fromScale(0.6, 0.045), posicion = UDim2.fromScale(0.5, 0.5), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	local numero = texto(p, { texto = tostring(maximo), fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.08, 0.08), posicion = UDim2.fromScale(0.5, 0.59), ancla = Vector2.new(0.5, 0.5) })
	local function cambiar(delta)
		maximo = math.clamp(maximo + delta, 2, Config.Partida.MaxJugadores)
		numero.Text = tostring(maximo)
	end
	boton(p, "-", UDim2.fromScale(0.41, 0.59), function()
		cambiar(-1)
	end, UDim2.fromScale(0.06, 0.07))
	boton(p, "+", UDim2.fromScale(0.59, 0.59), function()
		cambiar(1)
	end, UDim2.fromScale(0.06, 0.07))

	table.insert(mensajes, texto(p, { texto = "", tamano = UDim2.fromScale(0.6, 0.045), posicion = UDim2.fromScale(0.5, 0.69), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO }))
	boton(p, TEXTOS.crearSala, UDim2.fromScale(0.5, 0.78), function()
		ponerMensaje("")
		enviar("crear", { publica = publica, maximo = maximo, modo = modoElegido })
	end, UDim2.fromScale(0.34, 0.075))
	boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.9), function()
		mostrarPantalla("salas")
		enviar("salas")
	end, UDim2.fromScale(0.25, 0.07))
end

local function construirUnirse()
	local p = nuevaPantalla("unirse")
	texto(p, { texto = TEXTOS.unirseTitulo, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.1), posicion = UDim2.fromScale(0.5, 0.12), ancla = Vector2.new(0.5, 0.5) })
	texto(p, { texto = string.format(TEXTOS.codigoAyuda, Config.Salas.LargoCodigo), tamano = UDim2.fromScale(0.6, 0.045), posicion = UDim2.fromScale(0.5, 0.3), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	local caja = Instance.new("TextBox")
	caja.Size = UDim2.fromScale(0.3, 0.11)
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	caja.Position = UDim2.fromScale(0.5, 0.45)
	caja.BackgroundColor3 = Color3.new(1, 1, 1)
	caja.BackgroundTransparency = 0.93
	caja.BorderSizePixel = 0
	caja.Font = FUENTE_TITULO
	caja.TextScaled = true
	caja.TextColor3 = COLOR_ACENTO
	caja.PlaceholderText = TEXTOS.codigoHint
	caja.PlaceholderColor3 = COLOR_APAGADO
	caja.ClearTextOnFocus = false
	caja.Text = ""
	caja.Parent = p
	local borde = Instance.new("UIStroke")
	borde.Color = COLOR_TEXTO
	borde.Transparency = 0.4
	borde.Thickness = 2
	borde.Parent = caja
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	relleno.Parent = caja
	-- Solo letras y números, en mayúsculas y del largo del código.
	caja:GetPropertyChangedSignal("Text"):Connect(function()
		local limpio = string.upper(caja.Text):gsub("[^%w]", "")
		limpio = string.sub(limpio, 1, Config.Salas.LargoCodigo)
		if limpio ~= caja.Text then
			caja.Text = limpio
		end
	end)
	local function unirse()
		ponerMensaje(TEXTOS.entrando)
		enviar("unirse", { codigo = caja.Text })
	end
	caja.FocusLost:Connect(function(apretoEnter)
		if apretoEnter then
			unirse()
		end
	end)
	table.insert(mensajes, texto(p, { texto = "", tamano = UDim2.fromScale(0.6, 0.045), posicion = UDim2.fromScale(0.5, 0.58), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO }))
	boton(p, TEXTOS.unirse, UDim2.fromScale(0.5, 0.74), unirse, UDim2.fromScale(0.34, 0.075))
	boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.88), function()
		mostrarPantalla("salas")
		enviar("salas")
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

-- Logros: una fila por insignia de Catalogo.Insignias, con su estado (desbloqueado o bloqueado).
local logrosLista, logrosConteo, logrosRecord

local COLOR_LOGRO_SI = Color3.fromRGB(150, 220, 140)

local function construirLogros()
	local p = nuevaPantalla("logros")
	texto(p, { texto = TEXTOS.logros, fuente = FUENTE_TITULO, color = COLOR_ACENTO, tamano = UDim2.fromScale(0.7, 0.1), posicion = UDim2.fromScale(0.5, 0.11), ancla = Vector2.new(0.5, 0.5) })
	logrosConteo = texto(p, { texto = "", tamano = UDim2.fromScale(0.4, 0.04), posicion = UDim2.fromScale(0.5, 0.18), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	logrosLista = Instance.new("ScrollingFrame")
	logrosLista.Size = UDim2.fromScale(0.7, 0.65)
	logrosLista.AnchorPoint = Vector2.new(0.5, 0)
	logrosLista.Position = UDim2.fromScale(0.5, 0.21)
	logrosLista.BackgroundTransparency = 1
	logrosLista.BorderSizePixel = 0
	logrosLista.ScrollBarThickness = 6
	logrosLista.CanvasSize = UDim2.new(0, 0, 0, 0)
	logrosLista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logrosLista.Parent = p
	local marco = Instance.new("UIStroke")
	marco.Color = COLOR_TEXTO
	marco.Transparency = 0.7
	marco.Parent = logrosLista
	local orden = Instance.new("UIListLayout")
	orden.Padding = UDim.new(0, 6)
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = logrosLista
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	relleno.Parent = logrosLista
	for i, logro in Catalogo.Insignias do
		local fila = Instance.new("Frame")
		fila.Name = logro.clave
		fila.LayoutOrder = i
		fila.Size = UDim2.new(1, -4, 0, 58)
		fila.BackgroundColor3 = COLOR_TEXTO
		fila.BackgroundTransparency = 0.94
		fila.BorderSizePixel = 0
		fila.Parent = logrosLista
		local nombre = Instance.new("TextLabel")
		nombre.Name = "Nombre"
		nombre.BackgroundTransparency = 1
		nombre.Font = FUENTE
		nombre.TextSize = 22
		nombre.TextXAlignment = Enum.TextXAlignment.Left
		nombre.Position = UDim2.new(0, 12, 0, 4)
		nombre.Size = UDim2.new(0.6, 0, 0, 26)
		nombre.Text = logro.nombre
		nombre.Parent = fila
		local estado = Instance.new("TextLabel")
		estado.Name = "Estado"
		estado.BackgroundTransparency = 1
		estado.Font = FUENTE
		estado.TextSize = 18
		estado.TextXAlignment = Enum.TextXAlignment.Right
		estado.AnchorPoint = Vector2.new(1, 0)
		estado.Position = UDim2.new(1, -12, 0, 6)
		estado.Size = UDim2.new(0.34, 0, 0, 22)
		estado.Parent = fila
		local descripcion = Instance.new("TextLabel")
		descripcion.Name = "Descripcion"
		descripcion.BackgroundTransparency = 1
		descripcion.Font = FUENTE
		descripcion.TextSize = 16
		descripcion.TextXAlignment = Enum.TextXAlignment.Left
		descripcion.TextWrapped = true
		descripcion.Position = UDim2.new(0, 12, 0, 32)
		descripcion.Size = UDim2.new(1, -24, 0, 22)
		descripcion.Text = logro.descripcion
		descripcion.Parent = fila
	end
	logrosRecord = texto(p, { texto = "", tamano = UDim2.fromScale(0.5, 0.04), posicion = UDim2.fromScale(0.5, 0.895), ancla = Vector2.new(0.5, 0.5), color = COLOR_ACENTO })
	boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.955), function()
		mostrarPantalla("principal")
	end, UDim2.fromScale(0.25, 0.07))
end

function actualizarLogros()
	if not logrosLista then
		return
	end
	local total, desbloqueados = 0, 0
	for _, logro in Catalogo.Insignias do
		total += 1
		local fila = logrosLista:FindFirstChild(logro.clave)
		local tiene = perfilInsignias[logro.clave] == true
		if tiene then
			desbloqueados += 1
		end
		if fila then
			fila.Nombre.TextColor3 = tiene and COLOR_ACENTO or COLOR_APAGADO
			fila.Descripcion.TextColor3 = tiene and COLOR_TEXTO or COLOR_APAGADO
			fila.Estado.Text = Idioma.t(tiene and TEXTOS.logroSi or TEXTOS.logroNo) -- (el texto base es español; Idioma lo pasa al idioma de Roblox)
			fila.Estado.TextColor3 = tiene and COLOR_LOGRO_SI or COLOR_APAGADO
			fila.BackgroundTransparency = tiene and 0.88 or 0.96
		end
	end
	logrosConteo.Text = Idioma.t(string.format(TEXTOS.logrosConteo, desbloqueados, total))
	logrosRecord.Text = mejorSinFin > 0 and Idioma.t(string.format(TEXTOS.logrosRecord, mejorSinFin)) or ""
end

local botonSalirAlMenu

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
	-- Calidad gráfica: cada toque pasa al siguiente nivel (Auto / Alta / Media / Baja). En celulares, Auto usa Media.
	local botonCalidad = boton(p, string.format(TEXTOS.calidad, Rendimiento.nivel()), UDim2.fromScale(0.5, 0.66), function() end)
	botonCalidad.Activated:Connect(function()
		local nivel = Rendimiento.siguiente()
		botonCalidad.Text = string.format(TEXTOS.calidad, nivel)
		botonCalidad.MouseLeave:Once(function() end)
	end)
	botonCalidad.MouseLeave:Connect(function()
		botonCalidad.Text = string.format(TEXTOS.calidad, Rendimiento.nivel())
	end)
	boton(p, TEXTOS.volver, UDim2.fromScale(0.5, 0.85), function()
		mostrarPantalla(destinoVolver())
	end, UDim2.fromScale(0.25, 0.07))
	-- El servidor de juego es aparte del menú: desde acá se vuelve al servidor de entrada.
	botonSalirAlMenu = boton(p, TEXTOS.salirAlMenu, UDim2.fromScale(0.5, 0.94), function()
		enviar("salir")
	end, UDim2.fromScale(0.3, 0.06))
	botonSalirAlMenu.Visible = false
end

local function actualizarLobby()
	if not lobbyLista then
		return
	end
	local jugadores = estadoPartida.jugadores or {}
	local maximo = estadoPartida.maximo or Config.Partida.MaxJugadores
	local lineas = {}
	for _, nombre in jugadores do
		table.insert(lineas, "• " .. nombre)
	end
	lobbyLista.Text = table.concat(lineas, "\n")
	lobbyCodigo.Text = estadoPartida.codigo and string.format(TEXTOS.codigoSala, estadoPartida.codigo) or ""
	lobbyTipo.Text = string.format(estadoPartida.publica == false and TEXTOS.salaPrivadaTipo or TEXTOS.salaPublicaTipo, #jugadores, maximo)
	lobbyModo.Text = estadoPartida.modoJuego == "sinfin" and TEXTOS.modoLobbySinFin or TEXTOS.modoLobbyHistoria
	local soyAnfitrion = estadoPartida.anfitrionId == Players.LocalPlayer.UserId
	lobbyEstado.Text = soyAnfitrion and TEXTOS.salaAnfitrion or string.format(TEXTOS.salaEspera, estadoPartida.anfitrion or "el anfitrión")
	local iniciando = estadoPartida.iniciando == true
	if iniciando then
		lobbyEstado.Text = TEXTOS.salaIniciando
	end
	lobbyBotonEmpezar.Visible = soyAnfitrion and not iniciando
	-- En servidores aparte cualquiera puede irse; en el modo local de Studio solo el anfitrión (cierra la sala).
	lobbyBotonVolver.Visible = (soyAnfitrion or estadoPartida.nube == true) and not iniciando
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
	if nombre == "salas" or nombre == "crear" or nombre == "unirse" or nombre == "principal" then
		ponerMensaje("")
	end
	if botonSalirAlMenu then
		botonSalirAlMenu.Visible = nombre == "ajustes" and enJuego and estadoPartida.nube == true
	end
	if nombre == "lobby" then
		actualizarLobby()
	end
end

-- Entre que arranca la partida (el menú se va) y que aparece el cartel "NOCHE n" con los controles (lo muestra
-- DialogUI cuando llega NightState "turno") hay un instante: ahí el fondo negro se queda puesto para que nunca
-- se vea el local sin el cartel.
local faseNoche = "espera"
local ESPERA_CARTEL_MAX_SEG = 8

local function esperarCartelDeNoche()
	pantallaActual = "esperando"
	fondo.Visible = true
	fondo.BackgroundTransparency = 0
	bloquearMovimiento(true)
	for _, pantalla in pantallas do
		pantalla.Visible = false
	end
	task.delay(ESPERA_CARTEL_MAX_SEG, function()
		if pantallaActual == "esperando" then
			mostrarPantalla("juego")
		end
	end)
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
				if faseNoche == "espera" then
					esperarCartelDeNoche()
				else
					mostrarPantalla("juego") -- el turno ya está en marcha (se entró tarde): no hay cartel que esperar
				end
			end
		end
	elseif datos.fase == "lobby" then
		enJuego = false
		if pantallaActual ~= "ajustes" and pantallaActual ~= "ayuda" then
			mostrarPantalla("lobby")
		else
			actualizarLobby()
		end
	elseif datos.fase == "reuniendo" then
		enJuego = false
		cargandoTexto.Text = TEXTOS.reuniendo
		if pantallaActual ~= "ajustes" and pantallaActual ~= "ayuda" then
			mostrarPantalla("cargando")
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

	-- Ya hay un fondo negro propio: se retira el que puso ReplicatedFirst/InicioNegro apenas arrancó el cliente.
	local inicio = jugador.PlayerGui:FindFirstChild("InicioNegro")
	if inicio then
		inicio:Destroy()
	end

	pantallas = {}
	local carga = nuevaPantalla("cargando")
	cargandoTexto = texto(carga, { texto = TEXTOS.cargando, tamano = UDim2.fromScale(0.4, 0.06), posicion = UDim2.fromScale(0.5, 0.5), ancla = Vector2.new(0.5, 0.5), color = COLOR_APAGADO })
	construirPrincipal()
	construirSalas()
	construirCrear()
	construirUnirse()
	construirLobby()
	construirLogros()
	actualizarLogros()
	construirAyuda()
	construirAjustes()
	mostrarPantalla("cargando")

	Net.obtener("PartidaState").OnClientEvent:Connect(alCambiarPartida)
	Net.obtener("SalasState").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" then
			return
		end
		if datos.tipo == "lista" then
			actualizarListaSalas(datos.salas or {})
			if datos.error then
				ponerMensaje(datos.error, true)
			end
		elseif datos.tipo == "mensaje" then
			ponerMensaje(tostring(datos.texto or ""), datos.error == true)
		end
	end)
	-- Mientras se ve la lista de salas se refresca sola.
	task.spawn(function()
		while true do
			task.wait(Config.Salas.RefrescoListaSeg)
			if pantallaActual == "salas" and fondo.Visible then
				enviar("salas")
			end
		end
	end)
	Net.obtener("NightState").OnClientEvent:Connect(function(estadoNoche)
		if typeof(estadoNoche) ~= "table" then
			return
		end
		faseNoche = estadoNoche.fase
		if pantallaActual == "esperando" and faseNoche ~= "espera" then
			-- task.defer: que DialogUI ponga primero su cartel negro en este mismo cuadro y recién después se suelte el fondo.
			task.defer(function()
				if pantallaActual == "esperando" then
					mostrarPantalla("juego")
				end
			end)
		end
	end)
	Net.obtener("MenuAction"):FireServer({ accion = "estado" })
	-- Si el primer pedido llegó antes de que el servidor estuviera listo, se repite.
	task.delay(2, function()
		if pantallaActual == "cargando" then
			Net.obtener("MenuAction"):FireServer({ accion = "estado" })
		end
		Net.obtener("MenuAction"):FireServer({ accion = "perfil" }) -- el perfil puede haber llegado antes de que el menú estuviera listo
	end)
	-- Perfil guardado: con cualquier final alcanzado se habilita el modo Sin fin.
	Net.obtener("ProfileLoaded").OnClientEvent:Connect(function(perfil)
		if typeof(perfil) == "table" then
			sinFinListo = perfil.sinFinDesbloqueado == true
			perfilInsignias = typeof(perfil.insignias) == "table" and perfil.insignias or {}
			mejorSinFin = tonumber(perfil.mejorSinFin) or 0
			actualizarModo()
			actualizarLogros()
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
