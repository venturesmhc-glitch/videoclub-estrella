--!nonstrict
--[[
	Screamers (cliente): el susto fuerte a pantalla completa. Cuando el servidor manda el remote Screamer (automático de la
	noche o el "Asustar a todos" que compró otro jugador), la pantalla se va a negro, la cara de la criatura se abalanza
	sobre la cámara entre destellos y estática, y suena un grito fuerte. Dura Config.Screamer.DuracionSeg.

	Usa la misma malla del Socio (Personajes.crearSocioMalla) en un ViewportFrame; si no carga, queda un rostro hecho con
	la interfaz (ojos y boca) para que el susto igual funcione.
	No se muestra a los espectadores (el servidor tampoco se lo manda).

	  Screamers.reproducir(variante?)
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Personajes = require(ReplicatedStorage.Shared.Personajes)
local VHSEffects = require(script.Parent.VHSEffects)

local Screamers = {}

local cfg = Config.Screamer
local rng = Random.new()
local gui
local ocupado = false
local cuerpo: Model? = nil -- la criatura, armada una sola vez

local function armarCuerpo()
	if cuerpo then
		return
	end
	local ok, modelo = pcall(function()
		return Personajes.crearSocioMalla(Config.Socio)
	end)
	if ok and modelo then
		cuerpo = modelo
	end
end

local function crearInterfaz()
	gui = Instance.new("ScreenGui")
	gui.Name = "Screamer"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 150 -- por encima de todo, también del filtro VHS
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Rostro de respaldo con la interfaz (ojos y boca) si la malla no cargó.
local function rostroDeRespaldo(padre: GuiObject)
	local function parte(tam, pos, color)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = tam
		f.Position = pos
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = padre
		return f
	end
	parte(UDim2.fromScale(0.22, 0.12), UDim2.fromScale(0.34, 0.4), Color3.fromRGB(240, 245, 230))
	parte(UDim2.fromScale(0.22, 0.12), UDim2.fromScale(0.66, 0.4), Color3.fromRGB(240, 245, 230))
	parte(UDim2.fromScale(0.5, 0.28), UDim2.fromScale(0.5, 0.72), Color3.fromRGB(0, 0, 0))
end

function Screamers.reproducir(variante: number?)
	if ocupado or Players.LocalPlayer:GetAttribute("Espectador") then
		return
	end
	ocupado = true
	armarCuerpo()
	gui.Enabled = true

	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Color3.new(0, 0, 0)
	fondo.BorderSizePixel = 0
	fondo.Parent = gui

	local camaraVista: Camera? = nil
	local largo = cfg.DuracionSeg
	if cuerpo then
		local vista = Instance.new("ViewportFrame")
		vista.Size = UDim2.fromScale(1, 1)
		vista.BackgroundTransparency = 1
		vista.Ambient = Color3.fromRGB(120, 120, 130)
		vista.LightColor = Color3.fromRGB(255, 255, 255)
		vista.Parent = fondo
		local copia = cuerpo:Clone()
		copia:PivotTo(CFrame.new(0, 0, 0))
		copia.Parent = vista
		camaraVista = Instance.new("Camera")
		camaraVista.FieldOfView = 60
		vista.CurrentCamera = camaraVista
		camaraVista.Parent = vista
	else
		rostroDeRespaldo(fondo)
	end

	-- Estática encima.
	local estatica = Instance.new("Frame")
	estatica.Size = UDim2.fromScale(1, 1)
	estatica.BackgroundColor3 = Color3.new(1, 1, 1)
	estatica.BackgroundTransparency = 1
	estatica.BorderSizePixel = 0
	estatica.ZIndex = 5
	estatica.Parent = fondo

	-- Grito.
	local id = cfg.Sonidos[variante or rng:NextInteger(1, #cfg.Sonidos)] or cfg.Sonidos[1]
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = cfg.Volumen
	sonido.Parent = SoundService
	sonido:Play()
	Debris:AddItem(sonido, largo + 3)
	VHSEffects.susto()

	local alto = Config.Socio.AlturaMalla
	local inicio = os.clock()
	local conexion
	conexion = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - inicio) / largo
		if t >= 1 then
			conexion:Disconnect()
			return
		end
		-- Se abalanza: la cámara pasa de lejos a pegada a la cara en el primer cuarto, con temblor.
		if camaraVista then
			local acercamiento = math.clamp(t / 0.25, 0, 1)
			local distancia = 9 - 6.6 * acercamiento ^ 2
			local temblor = Vector3.new(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.25, 0.25), 0) * (0.4 + acercamiento)
			local altura = alto * 0.78
			camaraVista.CFrame = CFrame.lookAt(Vector3.new(0, altura, -distancia) + temblor, Vector3.new(0, altura - 0.2, 0))
		end
		-- Destellos y estática que parpadean.
		fondo.BackgroundColor3 = (rng:NextNumber() < 0.12) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		estatica.BackgroundTransparency = rng:NextNumber(0.55, 0.9)
	end)

	task.delay(largo, function()
		local salida = TweenService:Create(fondo, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		salida:Play()
		task.delay(0.3, function()
			fondo:Destroy()
			gui.Enabled = false
			ocupado = false
		end)
	end)
end

function Screamers.init()
	crearInterfaz()
	task.spawn(armarCuerpo) -- la malla tarda un poco en cargar: se prepara antes del primer screamer
	Net.obtener("Screamer").OnClientEvent:Connect(function(datos)
		Screamers.reproducir(typeof(datos) == "table" and datos.variante or nil)
	end)
end

return Screamers
