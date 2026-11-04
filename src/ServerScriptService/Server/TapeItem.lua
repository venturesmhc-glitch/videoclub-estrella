--!nonstrict
--[[
	TapeItem (servidor) — Fase 2.
	Cada casete tiene título, género, estado ("normal" | "danado" | "anomalo") y si está rebobinado.
	Este módulo crea la parte física (con su carátula y su prompt "Tomar"), la lleva en la mano
	del jugador (uno por jugador) y la hace entrar por la ranura de devoluciones.

	El servidor es la autoridad: el cliente solo recibe, vía TaskUpdate, qué tiene en la mano.

	API (el estado vive en el registro "casete", una tabla):
	  TapeItem.crear({ titulo, genero, estado?, rebobinado?, sinEtiqueta? }) -> casete (todavía sin colocar)
	  TapeItem.colocar(casete, cframe)       -- lo deja en el mundo, listo para que lo tomen
	  TapeItem.dejarEnMostrador(casete, cframe) -- igual, pero retira las cintas viejas que nadie levantó
	  TapeItem.entregarPorBuzon(casete)      -- entra por la ranura y cae sobre la caja de devoluciones
	  TapeItem.tomar(jugador, casete) / TapeItem.enMano(jugador) / TapeItem.consumir(casete)
	  TapeItem.actualizarEtiqueta(casete)    -- redibuja la carátula (p. ej. después de rebobinar)
	  TapeItem.alCambiar(fn)                 -- fn() cada vez que cambia algo que ven las fichas
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)

local TapeItem = {}

local cfg = Config.Casetes
local rng = Random.new()
local registros = {} -- id -> casete
local enMano = {} -- Player -> casete
local enMostrador = {} -- casete -> true: cintas que dejó un cliente y nadie levantó todavía
local contador = 0
local oyentesCambio = {}
local restricciones = {}
local llegoCintaSinEtiqueta = false
local carpetaMundo

local function notificarCambio()
	for _, fn in oyentesCambio do
		task.spawn(fn)
	end
end

local function mundo()
	if not carpetaMundo or not carpetaMundo.Parent then
		carpetaMundo = workspace:FindFirstChild("Casetes")
		if not carpetaMundo then
			carpetaMundo = Instance.new("Folder")
			carpetaMundo.Name = "Casetes"
			carpetaMundo.Parent = workspace
		end
	end
	return carpetaMundo
end

local function textoEstado(casete)
	if casete.estado == "danado" and cfg.MostrarDanoEnEtiqueta then
		return "ARRUGADA"
	end
	return casete.rebobinado and "REBOBINADA" or "REBOBINAR"
end

-- Carátula en las dos caras (frente y dorso). Una cinta sin etiqueta no lleva nada.
local function dibujarEtiqueta(casete)
	local parte = casete.parte
	if not parte then
		return
	end
	for _, hijo in parte:GetChildren() do
		if hijo.Name == "Etiqueta" then
			hijo:Destroy()
		end
	end
	if casete.sinEtiqueta then
		return
	end
	local colorGenero = Catalogo.Colores[casete.genero] or Color3.fromRGB(60, 60, 64)
	local nombreGenero = Catalogo.Nombres[casete.genero] or casete.genero
	-- Texto claro u oscuro según qué tan claro es el color del género.
	local claro = colorGenero.R * 0.3 + colorGenero.G * 0.59 + colorGenero.B * 0.11 > 0.55
	local colorFranja = claro and Color3.fromRGB(24, 22, 20) or Color3.fromRGB(244, 238, 222)
	for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Etiqueta"
		gui.Face = cara
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 160

		-- La caja del casete lleva el color del género; arriba, una franja con el nombre del género.
		local franjaGenero = Instance.new("TextLabel")
		franjaGenero.Size = UDim2.fromScale(1, 0.2)
		franjaGenero.BackgroundColor3 = colorGenero
		franjaGenero.BackgroundTransparency = 0
		franjaGenero.BorderSizePixel = 0
		franjaGenero.TextScaled = true
		franjaGenero.Font = Enum.Font.Arcade
		franjaGenero.TextColor3 = colorFranja
		franjaGenero.Text = nombreGenero
		franjaGenero.Parent = gui
		local borde = Instance.new("UIStroke")
		borde.Color = Color3.fromRGB(14, 14, 14)
		borde.Thickness = 2
		borde.Parent = franjaGenero

		local papel = Instance.new("Frame")
		papel.Size = UDim2.fromScale(0.84, 0.42)
		papel.Position = UDim2.fromScale(0.08, 0.27)
		papel.BackgroundColor3 = Color3.fromRGB(232, 226, 205)
		papel.BorderSizePixel = 0
		papel.Parent = gui

		local titulo = Instance.new("TextLabel")
		titulo.Size = UDim2.fromScale(0.92, 0.88)
		titulo.Position = UDim2.fromScale(0.04, 0.06)
		titulo.BackgroundTransparency = 1
		titulo.TextScaled = true
		titulo.Font = Enum.Font.SourceSansBold
		titulo.TextColor3 = Color3.fromRGB(30, 28, 26)
		titulo.Text = casete.titulo
		titulo.Parent = papel

		local franja = Instance.new("TextLabel")
		franja.Size = UDim2.fromScale(0.86, 0.14)
		franja.Position = UDim2.fromScale(0.07, 0.74)
		franja.BackgroundTransparency = 1
		franja.TextScaled = true
		franja.Font = Enum.Font.Code
		franja.TextColor3 = if casete.estado == "danado" and cfg.MostrarDanoEnEtiqueta
			then Color3.fromRGB(255, 120, 100)
			else Color3.fromRGB(240, 236, 224)
		franja.Text = textoEstado(casete)
		franja.Parent = gui

		gui.Parent = parte
	end
end

local function soltarDeMano(casete)
	if casete.dueno then
		enMano[casete.dueno] = nil
		casete.dueno = nil
	end
	local parte = casete.parte
	if parte then
		local weld = parte:FindFirstChild("AgarreMano")
		if weld then
			weld:Destroy()
		end
	end
end

--- Otro sistema puede impedir que un jugador tome casetes: fn(jugador) devuelve el motivo (texto) o nil.
function TapeItem.restringir(fn)
	table.insert(restricciones, fn)
end

--- Otro sistema (la escoba, la bolsa) atiende la tecla G antes que el casete: fn(jugador) devuelve true si soltó algo.
local sustitutosSoltar = {}
function TapeItem.alSoltar(fn)
	table.insert(sustitutosSoltar, fn)
end

function TapeItem.alCambiar(fn)
	table.insert(oyentesCambio, fn)
end

function TapeItem.crear(datos)
	contador += 1
	local casete = {
		id = "C" .. contador,
		titulo = datos.titulo or "Sin título",
		genero = datos.genero or "ACCION",
		estado = datos.estado or "normal",
		rebobinado = datos.rebobinado == true,
		sinEtiqueta = datos.sinEtiqueta == true,
		vivo = true,
		alquiler = false, -- true si es el casete que se le saca a un cliente (no cuenta como "reponer")
	}

	local parte = Instance.new("Part")
	parte.Name = "Casete"
	parte.Size = cfg.Tamano
	-- Carcasa oscura como los VHS de las góndolas y del depósito; el género se ve en la franja de la carátula.
	parte.Color = casete.sinEtiqueta and cfg.ColorSinEtiqueta or cfg.ColorCarcasa
	parte.Material = Enum.Material.SmoothPlastic
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte:SetAttribute("CasetId", casete.id)
	CollectionService:AddTag(parte, "Casete")
	casete.parte = parte

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Tomar"
	prompt.ObjectText = casete.sinEtiqueta and "Casete sin etiqueta" or casete.titulo
	prompt.MaxActivationDistance = cfg.DistanciaPrompt
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Triggered:Connect(function(jugador)
		if Net.limitar(jugador, "tomar", 0.3) then
			TapeItem.tomar(jugador, casete)
		end
	end)
	prompt.Parent = parte
	casete.prompt = prompt

	dibujarEtiqueta(casete)
	registros[casete.id] = casete
	return casete
end

function TapeItem.actualizarEtiqueta(casete)
	dibujarEtiqueta(casete)
	notificarCambio()
end

function TapeItem.colocar(casete, cframe: CFrame)
	if not casete.vivo then
		return
	end
	soltarDeMano(casete)
	local parte = casete.parte
	parte.Anchored = true
	parte.Massless = false
	parte.CFrame = cframe
	parte.Parent = mundo()
	casete.prompt.Enabled = true
	notificarCambio()
end

--- Deja sobre el mostrador la cinta que devolvió un cliente. Si alguna anterior quedó sin levantar se
--- retira (así no se amontonan una encima de otra) y la nueva también se retira sola pasado
--- Config.Casetes.VidaMostradorSeg si nadie la toma.
function TapeItem.dejarEnMostrador(casete, cframe: CFrame)
	local abandonadas = {}
	for otro in enMostrador do
		table.insert(abandonadas, otro)
	end
	for _, otro in abandonadas do
		TapeItem.consumir(otro)
	end
	if #abandonadas > 0 then
		Net.avisoATodos("Una cinta quedó sin recoger en el mostrador y se retiró.")
	end

	TapeItem.colocar(casete, cframe)
	enMostrador[casete] = true
	task.delay(cfg.VidaMostradorSeg, function()
		if enMostrador[casete] and casete.vivo and not casete.dueno then
			TapeItem.consumir(casete)
			Net.avisoATodos("Una cinta quedó sin recoger en el mostrador y se retiró.")
		end
	end)
end

function TapeItem.entregarPorBuzon(casete)
	local parte = casete.parte
	soltarDeMano(casete)
	parte.Anchored = true
	local plano = CFrame.Angles(math.rad(90), 0, 0) -- acostado, carátula hacia arriba
	parte.CFrame = CFrame.new(cfg.BuzonEntrada) * plano
	parte.Parent = mundo()

	local tiempo = TweenInfo.new(cfg.BuzonAnimSeg, Enum.EasingStyle.Quad)
	local entrada = TweenService:Create(parte, tiempo, { CFrame = CFrame.new(cfg.BuzonRanura) * plano })
	entrada.Completed:Connect(function()
		if not casete.vivo then
			return
		end
		local variacion = CFrame.Angles(0, math.rad(rng:NextInteger(-25, 25)), 0)
		local caida = TweenService:Create(
			parte,
			TweenInfo.new(cfg.BuzonAnimSeg, Enum.EasingStyle.Bounce),
			{ CFrame = CFrame.new(cfg.BuzonCaida) * plano * variacion }
		)
		caida.Completed:Connect(function()
			if casete.vivo then
				casete.prompt.Enabled = true
				notificarCambio()
			end
		end)
		caida:Play()
	end)
	entrada:Play()
end

function TapeItem.tomar(jugador: Player, casete): boolean
	if not casete.vivo or casete.dueno then
		return false
	end
	if enMano[jugador] then
		Net.aviso(jugador, "Ya tenés un casete en la mano.")
		return false
	end
	for _, restriccion in restricciones do
		local motivo = restriccion(jugador)
		if motivo then
			Net.aviso(jugador, motivo)
			return false
		end
	end
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return false
	end

	enMano[jugador] = casete
	enMostrador[casete] = nil
	if casete.sinEtiqueta then
		Net.aviso(jugador, "Casete sin etiqueta: en la videocasetera se reproduce (mantené E) o se le graba encima (mantené R). Con G lo soltás.")
	end
	casete.dueno = jugador
	casete.prompt.Enabled = false

	local parte = casete.parte
	parte.Anchored = false
	parte.Massless = true
	parte.CanCollide = false
	local weld = Instance.new("Weld")
	weld.Name = "AgarreMano"
	weld.Part0 = raiz
	weld.Part1 = parte
	weld.C0 = cfg.OffsetEnMano
	weld.Parent = parte
	-- No va dentro del personaje: en primera persona la cámara oculta todo lo que cuelga de él
	-- (LocalTransparencyModifier = 1) y el jugador no vería la cinta que lleva en la mano.
	parte.Parent = mundo()

	notificarCambio()
	return true
end

--- Suelta en el piso, delante del jugador, el casete que lleva en la mano (queda listo para volver a tomarse).
function TapeItem.soltar(jugador: Player): boolean
	local casete = enMano[jugador]
	if not casete or not casete.vivo then
		Net.aviso(jugador, "No tenés ningún casete en la mano.")
		return false
	end
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return false
	end
	-- Un poco hacia adelante y apoyado en el piso (raycast hacia abajo).
	local adelante = raiz.Position + raiz.CFrame.LookVector * 3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personaje, mundo() }
	local suelo = workspace:Raycast(adelante + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), params)
	local y = (suelo and suelo.Position.Y or 0) + cfg.Tamano.Z / 2 + 0.02
	local giro = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	TapeItem.colocar(casete, CFrame.new(adelante.X, y, adelante.Z) * giro * CFrame.Angles(math.rad(90), 0, 0))
	Net.aviso(jugador, "Soltaste el casete.")
	return true
end

function TapeItem.enMano(jugador: Player)
	local casete = enMano[jugador]
	if casete and casete.vivo then
		return casete
	end
	return nil
end

--- Destruye el casete (se lo llevó un cliente, se repuso en la góndola, etc.).
function TapeItem.consumir(casete)
	if not casete.vivo then
		return
	end
	casete.vivo = false
	soltarDeMano(casete)
	enMostrador[casete] = nil
	registros[casete.id] = nil
	if casete.parte then
		casete.parte:Destroy()
	end
	notificarCambio()
end

function TapeItem.limpiarTodo()
	for _, casete in registros do
		casete.vivo = false
		if casete.parte then
			casete.parte:Destroy()
		end
	end
	table.clear(registros)
	table.clear(enMano)
	table.clear(enMostrador)
	notificarCambio()
end

--- Casetes que están en el mundo y se pueden tomar (para pruebas y depuración).
function TapeItem.enElMundo()
	local lista = {}
	for _, casete in registros do
		if casete.vivo and not casete.dueno and casete.prompt.Enabled then
			table.insert(lista, casete)
		end
	end
	return lista
end

function TapeItem.llegoCintaSinEtiqueta(): boolean
	return llegoCintaSinEtiqueta
end

local function alSalirElPersonaje(jugador: Player)
	local casete = enMano[jugador]
	if casete then
		TapeItem.consumir(casete)
	end
end

function TapeItem.init()
	Net.obtener("DropTape").OnServerEvent:Connect(function(jugador)
		if Net.limitar(jugador, "soltar", 0.4) then
			if not enMano[jugador] then
				for _, fn in sustitutosSoltar do
					if fn(jugador) then
						return
					end
				end
			end
			TapeItem.soltar(jugador)
		end
	end)

	NightManager.suscribir("NOCHE_INICIA", function()
		TapeItem.limpiarTodo()
		llegoCintaSinEtiqueta = false
	end)

	NightManager.suscribir("BUZON", function(datos)
		local estado = if datos.anomalo then "anomalo" elseif datos.danado then "danado" else "normal"
		local casete = TapeItem.crear({
			titulo = Catalogo.tituloPara(datos.genero, estado, rng),
			genero = datos.genero,
			estado = estado,
			rebobinado = false,
		})
		TapeItem.entregarPorBuzon(casete)
		Net.avisoATodos("Cayó un casete en el buzón de devoluciones.")
	end)

	NightManager.suscribir("CINTA_LLEGA", function()
		llegoCintaSinEtiqueta = true
		local casete = TapeItem.crear({ titulo = "", genero = "TERROR", sinEtiqueta = true })
		TapeItem.entregarPorBuzon(casete)
		Net.avisoATodos("Algo cayó en el buzón. Es un casete sin caja ni etiqueta.")
	end)

	local function vigilar(jugador: Player)
		jugador.CharacterRemoving:Connect(function()
			alSalirElPersonaje(jugador)
		end)
	end
	Players.PlayerAdded:Connect(vigilar)
	for _, jugador in Players:GetPlayers() do
		vigilar(jugador)
	end
	Players.PlayerRemoving:Connect(alSalirElPersonaje)
end

return TapeItem
