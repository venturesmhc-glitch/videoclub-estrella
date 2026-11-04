--!nonstrict
--[[
	AnomalySystem (cliente) — Fase 3.
	Genera, solo en la pantalla de este jugador, anomalías sutiles en el local (títulos de portadas cambiados,
	carátulas alteradas, objetos movidos, una figura al fondo de un pasillo). Cada jugador ve cosas distintas.

	La semilla la manda el servidor (remote AnomalySeed); con ella se arma la misma lista que tiene el servidor.
	Para marcar una anomalía hay que apuntarle y apretar Q (en móviles, el botón REPORTAR): el cliente solo
	avisa y el servidor valida; si la acepta, manda "resolver" y la anomalía se corrige en pantalla.
	La figura desaparece sola si se la mira fijo un rato (o pasado un tiempo), pero entonces cuenta como no detectada.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AnomalyCatalog = require(ReplicatedStorage.Shared.AnomalyCatalog)
local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Silueta = require(script.Parent.Silueta)
local Reptante = require(script.Parent.Reptante)
local AudioManager = require(script.Parent.AudioManager)
local DialogUI = require(script.Parent.DialogUI)
local TaskCard = require(script.Parent.TaskCard)
local VHSEffects = require(script.Parent.VHSEffects)

local AnomalySystem = {}

local cfg = Config.Anomalias
local escala = Config.Noche.DuracionMinutosJuego / Config.Noche.DuracionRealSegundos
local escena
local lista = {} -- anomalías de la noche
local activas = {} -- id -> { restaurar, modelo?, inicio, mirando }
local resueltas = {}
local detectadas = 0 -- anomalías que este jugador ya marcó esta noche
local sincro = { minuto = 0, t = os.clock(), fase = "espera" }

local function minutoActual(): number
	if sincro.fase ~= "turno" then
		return sincro.minuto
	end
	return sincro.minuto + (os.clock() - sincro.t) * (sincro.escala or escala)
end

-- ===== Cada tipo de anomalía: aplica el cambio y devuelve la función que lo deshace =====

local function partesDePortada(id)
	local portada = escena.instancias[id]
	local etiqueta = portada and portada:FindFirstChild("Etiqueta")
	local papel = etiqueta and etiqueta:FindFirstChild("Papel")
	local titulo = papel and papel:FindFirstChild("Titulo")
	return portada, papel, titulo
end

local function aplicarTitulo(a)
	local _, _, titulo = partesDePortada(a.objetivo)
	if not titulo then
		return nil
	end
	local original = titulo.Text
	titulo.Text = Catalogo.TitulosExtranos[a.variante]
	return function()
		titulo.Text = original
	end
end

local function aplicarCaratula(a)
	local portada, papel, titulo = partesDePortada(a.objetivo)
	if not portada or not papel or not titulo then
		return nil
	end
	local colorOriginal, papelOriginal, textoOriginal, colorTexto = portada.Color, papel.BackgroundColor3, titulo.Text, titulo.TextColor3
	portada.Color = AnomalyCatalog.ColoresExtranos[a.variante]
	papel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	titulo.TextColor3 = Color3.fromRGB(200, 200, 200)
	titulo.Text = "▒▒▒▒"
	return function()
		portada.Color, papel.BackgroundColor3, titulo.Text, titulo.TextColor3 = colorOriginal, papelOriginal, textoOriginal, colorTexto
	end
end

local function aplicarMovido(a)
	local objeto = escena.instancias[a.objetivo]
	if not objeto then
		return nil
	end
	local original = objeto.CFrame
	objeto.CFrame = original * CFrame.new(a.dx, 0, a.dz) * CFrame.Angles(0, math.rad(a.rotacion), 0)
	return function()
		objeto.CFrame = original
	end
end

local function aplicarFigura(a, registro)
	local punto = escena.instancias[a.objetivo]
	if not punto then
		return nil
	end
	local modelo = Silueta.crear(true, true) -- sombra humana quieta: NO es el Socio
	-- Aparece sin aviso: el zumbido se corta un instante y suena un chasquido bajito (sin música ni grito).
	AudioManager.cortar("Zumbido", 1.1)
	AudioManager.efecto(Config.Sustos.Glitch.Id, { volumen = Config.Sustos.Glitch.Volumen * 0.7, retardo = 0.05 })
	for _, p in modelo:GetChildren() do
		p:SetAttribute("AnomaliaRef", a.id)
	end
	-- Aparece colgada del techo, sobre su punto, y desde ahí camina por el techo y las paredes siguiéndote.
	modelo.Parent = workspace
	local animacion = Silueta.animacion(modelo)
	local detener = Reptante.iniciar(modelo, punto.Position, {
		caminar = animacion and animacion.caminar or nil,
	})
	registro.modelo = modelo
	return function()
		detener()
		modelo:Destroy()
		registro.modelo = nil
	end
end

local APLICAR = {
	TituloCambiado = aplicarTitulo,
	CaratulaAlterada = aplicarCaratula,
	ObjetoMovido = aplicarMovido,
	FiguraAlFondo = aplicarFigura,
}

local function restaurarTodo()
	for _, registro in activas do
		if registro.restaurar then
			registro.restaurar()
		end
	end
	activas, resueltas = {}, {}
	detectadas = 0
end

local function activar(a)
	local registro = { inicio = os.clock(), mirando = 0 }
	local aplicar = APLICAR[a.tipo]
	registro.restaurar = aplicar and aplicar(a, registro) or nil
	activas[a.id] = registro
end

local function resolver(id)
	resueltas[id] = true
	detectadas += 1
	TaskCard.setAnomalias(detectadas, #lista)
	local registro = activas[id]
	if registro and registro.restaurar then
		registro.restaurar()
		registro.restaurar = nil
	end
end

-- ===== Reporte =====

local function reportar()
	local camara = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character }
	local resultado = workspace:Raycast(camara.CFrame.Position, camara.CFrame.LookVector * cfg.DistanciaReporte, params)

	local id
	if resultado then
		local instancia = resultado.Instance
		-- El Socio de verdad no es una anomalía: no se lo marca, se lo mira.
		local socio = workspace:FindFirstChild("Socio0000")
		if socio and instancia:IsDescendantOf(socio) then
			DialogUI.aviso("Ese no es un recuerdo de la cinta: es el Socio. Con la Q no se lo marca: hay que mirarlo, porque cuando lo mirás se arrastra mucho más lento.")
			return
		end
		local portadaId = instancia:GetAttribute("PortadaId")
		local movibleId = instancia:GetAttribute("AnomaliaId")
		local ref = instancia:GetAttribute("AnomaliaRef")
		for _, a in lista do
			if activas[a.id] and not resueltas[a.id] and (a.objetivo == portadaId or a.objetivo == movibleId or a.id == ref) then
				id = a.id
				break
			end
		end
	end
	Net.obtener("AnomalyReport"):FireServer({ id = id })
end

local function nuevaSemilla(datos)
	restaurarTodo()
	escena = AnomalyCatalog.escena()
	lista = AnomalyCatalog.generar(datos.semilla, datos.noche, escena)
	detectadas = 0
	TaskCard.setAnomalias(0, #lista)
end

function AnomalySystem.init()
	escena = AnomalyCatalog.escena()

	Net.obtener("AnomalySeed").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" then
			return
		end
		if datos.accion == "semilla" then
			nuevaSemilla(datos)
		elseif datos.accion == "resolver" then
			resolver(datos.id)
		end
	end)

	Net.obtener("NightState").OnClientEvent:Connect(function(datos)
		if typeof(datos) == "table" then
			sincro = { minuto = datos.minuto or 0, t = os.clock(), fase = datos.fase, escala = datos.escala }
			if datos.fase ~= "turno" and next(activas) then
				restaurarTodo() -- entre turnos el local vuelve a la normalidad
			end
		end
	end)

	-- Activa las anomalías cuando les toca y vigila la figura.
	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado < 0.25 then
			return
		end
		local paso = acumulado
		acumulado = 0
		if sincro.fase ~= "turno" then
			return
		end
		local minuto = minutoActual()
		local camara = workspace.CurrentCamera
		local cercania = 0 -- qué tan cerca y de frente tiene una anomalía sin resolver (sube la estática del filtro)
		for _, a in lista do
			if not activas[a.id] and not resueltas[a.id] and minuto >= a.minuto then
				activar(a)
			end
			local registro = activas[a.id]
			if registro and not resueltas[a.id] then
				local objetivo = registro.modelo or escena.instancias[a.objetivo]
				local punto = nil
				if objetivo then
					punto = if objetivo:IsA("Model") then objetivo:GetPivot().Position else objetivo.Position
				end
				if punto then
					local hacia = punto - camara.CFrame.Position
					local distancia = hacia.Magnitude
					if distancia < cfg.EstaticaDistancia and distancia > 0.1 and camara.CFrame.LookVector:Dot(hacia.Unit) > 0.6 then
						cercania = math.max(cercania, 1 - distancia / cfg.EstaticaDistancia)
					end
				end
			end
			if registro and registro.modelo then
				-- La figura se esfuma si se la mira fijo o pasado su tiempo de vida.
				local pivote = registro.modelo:GetPivot()
				local centro = pivote.Position + pivote.UpVector * 3 -- (cuelga del techo: "arriba" del cuerpo apunta hacia abajo)
				local hacia = centro - camara.CFrame.Position
				local mirada = camara.CFrame.LookVector:Dot(hacia.Unit)
				if mirada > 0.93 and hacia.Magnitude < 60 then
					registro.mirando += paso
				else
					registro.mirando = math.max(0, registro.mirando - paso)
				end
				if registro.mirando >= cfg.MirarParaDesaparecerSeg or os.clock() - registro.inicio > cfg.VidaFiguraSeg then
					registro.restaurar()
					registro.restaurar = nil -- la figura se fue sin que nadie la marcara
				end
			end
		end
		VHSEffects.setAnomalia(cercania)
	end)

	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if not procesado and entrada.KeyCode == Enum.KeyCode.Q then
			reportar()
		end
	end)

	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "ReportarUI"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 55
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local boton = Instance.new("TextButton")
		boton.AnchorPoint = Vector2.new(1, 1)
		boton.Position = UDim2.fromScale(0.98, 0.86)
		boton.Size = UDim2.fromScale(0.14, 0.07)
		boton.BackgroundColor3 = Color3.fromRGB(184, 148, 98)
		boton.TextColor3 = Color3.fromRGB(66, 46, 28)
		boton.Font = Enum.Font.Code
		boton.TextScaled = true
		boton.Text = "REPORTAR"
		boton.Parent = gui
		boton.Activated:Connect(reportar)
	end

	-- Por si la semilla se mandó antes de que este cliente estuviera listo.
	task.delay(3, function()
		Net.obtener("AnomalyReport"):FireServer({ pedir = true })
	end)
end

return AnomalySystem
