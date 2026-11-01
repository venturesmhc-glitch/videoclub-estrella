--!nonstrict
--[[
	CursedTapeSystem (cliente) — Fase 4.
	Lo que se ve al reproducir la cinta: el local desde un ángulo fijo y alto sobre las estanterías,
	con el filtro VHS intensificado y una fecha del futuro. Solo en esta vista existen:
	  - la silueta del Socio, que se va acercando mientras dura la cinta, en el punto que predijo el servidor;
	  - jugadores "fantasma": copias semitransparentes de los jugadores. Noche 2: repiten lo que hicieron hace
	    unos segundos (se ven trabajando esa misma noche); noche 5: van unos segundos adelantados.
	    El resto de las noches hay un solo fantasma, parado donde se va a cumplir la predicción.
	E saca la cinta antes de que termine. Los demás jugadores ven estática en la tele del mostrador.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local OSD = require(script.Parent.OSD)
local Silueta = require(script.Parent.Silueta)
local VHSEffects = require(script.Parent.VHSEffects)

local CursedTapeSystem = {}

local cfg = Config.Cinta
local sesion -- datos de la reproducción en curso (nil si no hay)
local historial = {} -- Player -> { {t, CFrame}, ... } para los fantasmas de la noche 2

-- ===== Elementos que solo existen en la vista de la cinta =====

local function construirFantasma(jugador: Player): Model?
	local personaje = jugador.Character
	if not personaje then
		return nil
	end
	local ok, copia = pcall(function()
		personaje.Archivable = true
		return personaje:Clone()
	end)
	if not ok or not copia then
		return nil
	end
	for _, d in copia:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.Transparency = 0.45
			d.Material = Enum.Material.ForceField
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	copia.Name = "Fantasma_" .. jugador.Name
	return copia
end

local function posicionDe(jugador: Player): CFrame?
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	return raiz and raiz.CFrame or nil
end

-- ===== Historial (para los fantasmas de la noche 2) =====

local function registrarHistorial()
	local ahora = os.clock()
	for _, jugador in Players:GetPlayers() do
		local cf = posicionDe(jugador)
		if cf then
			local lista = historial[jugador] or {}
			historial[jugador] = lista
			table.insert(lista, { t = ahora, cf = cf })
			while #lista > 0 and ahora - lista[1].t > cfg.HistorialSeg + 2 do
				table.remove(lista, 1)
			end
		end
	end
end

local function muestraRetrasada(jugador: Player, retraso: number): CFrame?
	local lista = historial[jugador]
	if not lista or #lista == 0 then
		return nil
	end
	local objetivo = os.clock() - retraso
	local previa = lista[1]
	for _, muestra in lista do
		if muestra.t >= objetivo then
			return previa.cf:Lerp(muestra.cf, 0.5)
		end
		previa = muestra
	end
	return previa.cf
end

-- ===== Sesión =====

local function terminar()
	if not sesion then
		return
	end
	local s = sesion
	sesion = nil
	for _, conexion in s.conexiones do
		conexion:Disconnect()
	end
	for _, objeto in s.objetos do
		objeto:Destroy()
	end
	local camara = workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Custom
	camara.FieldOfView = Config.Jugador.CamaraFOV
	VHSEffects.forzar(nil)
	VHSEffects.setIntensidad(1)
	OSD.sobrescribirFecha(nil)
	OSD.setEstado("PLAY")
end

local function iniciar(datos)
	if sesion then
		terminar()
	end
	local camara = workspace.CurrentCamera
	local inicio = os.clock()
	local objetos, conexiones = {}, {}
	sesion = { objetos = objetos, conexiones = conexiones }
	local pred = datos.prediccion
	local noche = datos.noche

	camara.CameraType = Enum.CameraType.Scriptable
	camara.FieldOfView = cfg.FOV
	camara.CFrame = cfg.Camara
	VHSEffects.setIntensidad(cfg.Intensidad)
	VHSEffects.forzar(cfg.PeligroBase)
	OSD.setEstado("PLAY")
	if pred then
		OSD.sobrescribirFecha(OSD.textoFecha(noche, pred.minutoFuturo))
	end

	-- Silueta del Socio en el punto predicho; se va acercando al mostrador mientras dura la cinta.
	local silueta
	local origen, destino
	if pred then
		silueta = Silueta.crear(false)
		silueta.Parent = workspace
		table.insert(objetos, silueta)
		origen = pred.posicion
		destino = origen:Lerp(Vector3.new(-5, 0, 6), 0.4)
	end

	-- Fantasmas.
	local fantasmas = {} -- { modelo, jugador }
	if noche == 2 or noche == 5 then
		for _, jugador in Players:GetPlayers() do
			local modelo = construirFantasma(jugador)
			if modelo then
				modelo.Parent = workspace
				table.insert(objetos, modelo)
				table.insert(fantasmas, { modelo = modelo, jugador = jugador })
			end
		end
	elseif pred then
		local modelo = construirFantasma(Players.LocalPlayer)
		if modelo then
			modelo.Parent = workspace
			table.insert(objetos, modelo)
			-- Parado junto a la silueta, mirando hacia ella.
			modelo:PivotTo(CFrame.lookAt(pred.posicion + Vector3.new(2.2, 3, 2.5), pred.posicion + Vector3.new(0, 3, 0)))
			table.insert(fantasmas, { modelo = modelo, fijo = true })
		end
	end

	-- Cartel con cómo salir.
	local gui = Instance.new("ScreenGui")
	gui.Name = "CintaUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 55
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(objetos, gui)
	local ayuda = Instance.new("TextLabel")
	ayuda.AnchorPoint = Vector2.new(0.5, 1)
	ayuda.Position = UDim2.fromScale(0.5, 0.94)
	ayuda.Size = UDim2.fromScale(0.5, 0.05)
	ayuda.BackgroundTransparency = 1
	ayuda.Font = Enum.Font.Code
	ayuda.TextScaled = true
	ayuda.TextColor3 = Color3.fromRGB(236, 236, 226)
	ayuda.Text = "[E] sacar la cinta"
	ayuda.Parent = gui

	table.insert(conexiones, UserInputService.InputBegan:Connect(function(entrada, procesado)
		if entrada.KeyCode == Enum.KeyCode.E then
			Net.obtener("TapeSession"):FireServer({ accion = "detener" })
		end
	end))
	-- En móviles no hay tecla E: tocar el cartel también saca la cinta.
	ayuda.Active = true
	table.insert(conexiones, ayuda.InputBegan:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
			Net.obtener("TapeSession"):FireServer({ accion = "detener" })
		end
	end))

	table.insert(conexiones, RunService.RenderStepped:Connect(function()
		local t = os.clock() - inicio
		local mov = cfg.MovimientoAmplitud
		local v = cfg.MovimientoVelocidad
		camara.CFrame = cfg.Camara * CFrame.new(math.sin(t * v) * mov, math.sin(t * v * 1.3) * mov * 0.5, 0)

		if silueta then
			local avance = math.clamp(t / datos.duracion, 0, 1)
			local pos = origen:Lerp(destino, avance)
			-- La silueta mira hacia la cámara.
			silueta:PivotTo(CFrame.lookAt(Vector3.new(pos.X, 0, pos.Z), Vector3.new(cfg.Camara.Position.X, 0, cfg.Camara.Position.Z)))
		end

		for _, f in fantasmas do
			if not f.fijo then
				local objetivoCF
				if noche == 5 then
					local raiz = f.jugador.Character and f.jugador.Character:FindFirstChild("HumanoidRootPart")
					if raiz then
						objetivoCF = raiz.CFrame + raiz.AssemblyLinearVelocity * cfg.AdelantoSeg
					end
				else
					objetivoCF = muestraRetrasada(f.jugador, cfg.HistorialSeg)
				end
				if objetivoCF then
					f.modelo:PivotTo(objetivoCF)
				end
			end
		end
	end))
end

function CursedTapeSystem.init()
	-- Historial de posiciones de todos los jugadores (alimenta a los fantasmas de la noche 2).
	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado >= 1 / cfg.HistorialHz then
			acumulado = 0
			registrarHistorial()
		end
	end)

	Net.obtener("TapeSession").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" then
			return
		end
		if datos.accion == "inicio" then
			iniciar(datos)
		elseif datos.accion == "fin" then
			terminar()
		end
	end)

	-- La tele del mostrador (canales, estática y el modo "reproduciendo" de la cinta) la maneja Client/Tele.
end

return CursedTapeSystem
