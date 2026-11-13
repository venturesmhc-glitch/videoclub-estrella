--!nonstrict
--[[
	SocioSentidos (cliente): lo que se oye y se siente de la IA de caza del Socio.
	  * Pasos pesados en 3D pegados al cuerpo (más seguidos cuanto más rápido camina; en la caza suenan más fuertes).
	  * El servidor avisa por SocioEvento: "rugido" (empieza la caza), "hallazgo" (te volvió a encontrar), "aviso" (se detiene
	    un instante antes de lanzarse) y "embiste" (la embestida). Cada uno suena distinto, sacude la cámara y deja un
	    destello rojo en la pantalla.
	Valores en Config.Socio.Sentidos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local SocioSentidos = {}

local cfg = Config.Socio.Sentidos

local pantalla: ScreenGui? = nil
local destello: Frame? = nil

local function asegurarPantalla()
	if pantalla and pantalla.Parent then
		return
	end
	pantalla = Instance.new("ScreenGui")
	pantalla.Name = "SocioSentidos"
	pantalla.IgnoreGuiInset = true
	pantalla.ResetOnSpawn = false
	pantalla.DisplayOrder = 40
	destello = Instance.new("Frame")
	destello.Size = UDim2.fromScale(1, 1)
	destello.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	destello.BackgroundTransparency = 1
	destello.BorderSizePixel = 0
	destello.Parent = pantalla
	pantalla.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function destellar(fuerza: number)
	asegurarPantalla()
	if not destello then
		return
	end
	destello.BackgroundTransparency = 1 - math.clamp(fuerza, 0, 1) * 0.55
	TweenService:Create(destello, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local function sonido(id: string, volumen: number, velocidad: number, distorsion: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volumen
	s.PlaybackSpeed = velocidad
	if distorsion then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = distorsion
		d.Parent = s
	end
	local r = Instance.new("ReverbSoundEffect")
	r.DecayTime = 2.2
	r.WetLevel = -8
	r.Parent = s
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(8, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function sacudir(fuerza: number)
	local ok, Temblor = pcall(function()
		return require(script.Parent.Temblor)
	end)
	if ok and Temblor.sobresaltar then
		Temblor.sobresaltar(fuerza)
	end
end

local function evento(nombre)
	local e = cfg.Eventos[nombre]
	if not e then
		return
	end
	sonido(e.Id or Config.Screamer.Sonidos[1].Id, e.Volumen, e.Velocidad, e.Distorsion)
	sacudir(e.Sacudida)
	destellar(e.Destello)
end

-- ===== Pasos =====

local function enlazarPasos(modelo: Model)
	local pieza = modelo.PrimaryPart or modelo:FindFirstChildWhichIsA("BasePart", true)
	if not pieza then
		return
	end
	local paso = Instance.new("Sound")
	paso.Name = "PasosSocio"
	paso.SoundId = cfg.Pasos.Id
	paso.RollOffMode = Enum.RollOffMode.InverseTapered
	paso.RollOffMinDistance = 8
	paso.RollOffMaxDistance = cfg.Pasos.Alcance
	paso.Parent = pieza
	local ultimo = modelo:GetPivot().Position
	local proximo = 0
	local velocidad = 0
	local conexion
	conexion = RunService.Heartbeat:Connect(function(dt)
		if not modelo.Parent or not paso.Parent then
			conexion:Disconnect()
			return
		end
		local pos = modelo:GetPivot().Position
		local plano = Vector3.new(pos.X - ultimo.X, 0, pos.Z - ultimo.Z).Magnitude
		ultimo = pos
		velocidad += (plano / math.max(dt, 1e-3) - velocidad) * math.min(1, dt * 6)
		if velocidad < 1.5 then
			proximo = 0
			return
		end
		proximo -= dt
		if proximo <= 0 then
			local rapido = math.clamp(velocidad / 14, 0.3, 1.4)
			proximo = math.clamp(cfg.Pasos.Zancada / velocidad, 0.22, 1.1)
			local caza = modelo:GetAttribute("SocioFase") == "caza"
			paso.Volume = cfg.Pasos.Volumen * (caza and 1.35 or 0.8) * math.clamp(rapido, 0.6, 1.2)
			paso.PlaybackSpeed = cfg.Pasos.Velocidad * (0.9 + math.random() * 0.2) * (0.85 + rapido * 0.3)
			paso:Play()
		end
	end)
end

function SocioSentidos.init()
	Net.obtener("SocioEvento").OnClientEvent:Connect(evento)
	workspace.ChildAdded:Connect(function(hijo)
		if hijo.Name == "Socio0000" and hijo:IsA("Model") then
			task.defer(enlazarPasos, hijo)
		end
	end)
	local ya = workspace:FindFirstChild("Socio0000")
	if ya and ya:IsA("Model") then
		enlazarPasos(ya)
	end
end

return SocioSentidos
