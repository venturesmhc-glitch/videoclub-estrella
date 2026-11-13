--!nonstrict
--[[
	CriaturaVista (cliente): dibuja la criatura de las anomalías, que es una sola para todo el equipo (la mueve Server/Criatura).
	El servidor manda cuándo aparece, su posición (20 veces por segundo, remote CriaturaPos) y cuándo desaparece o ataca;
	acá se suaviza el movimiento, se animan las patas (Client/Aracnido) y se aplican los efectos de cercanía (temblor de cámara,
	estática del filtro). Para marcarla (Q) ver Client/AnomalySystem: sus partes llevan el atributo AnomaliaRef = "CRIATURA".

	  CriaturaVista.cercania() -> 0..1   qué tan cerca y de frente la tenés (sube la estática del filtro)
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Aracnido = require(script.Parent.Aracnido)
local AudioManager = require(script.Parent.AudioManager)
local Temblor = require(script.Parent.Temblor)
local VHSEffects = require(script.Parent.VHSEffects)

local CriaturaVista = {}

local cfg = Config.Anomalias
local objeto = nil -- { modelo, actualizar, destruir } de Client/Aracnido
local cfObjetivo: CFrame? = nil -- la última posición que mandó el servidor
local cfActual: CFrame? = nil -- la que se dibuja (suavizada)
local cercaniaActual = 0

function CriaturaVista.cercania(): number
	return cercaniaActual
end

local function limpiar()
	if objeto then
		objeto.destruir()
		objeto = nil
	end
	cfObjetivo, cfActual = nil, nil
	cercaniaActual = 0
	Temblor.fijarLocal(0)
end

local function aparecer(cf: CFrame)
	limpiar()
	if Players.LocalPlayer:GetAttribute("Espectador") then
		return -- los espectadores ven el local sin monstruos
	end
	local criatura = Aracnido.crear() -- la criatura de patas largas que anda por el techo y las paredes: NO es el Socio
	local modelo = criatura.modelo
	-- Aparece sin aviso: el zumbido se corta un instante y suena un chasquido bajito (sin música ni grito).
	AudioManager.cortar("Zumbido", 1.1)
	AudioManager.efecto(Config.Sustos.Glitch.Id, { volumen = Config.Sustos.Glitch.Volumen * 0.7, retardo = 0.05 })
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("AnomaliaRef", "CRIATURA") -- así sabe Q a qué le estás apuntando
		end
	end
	CollectionService:AddTag(modelo, "ApagaLuces") -- las luces del local se van donde está (Client/LuzFluorescente)
	criatura.actualizar(cf, 1 / 60, nil) -- que las partes arranquen en su lugar, no en el origen
	modelo.Parent = workspace
	objeto = criatura
	cfObjetivo, cfActual = cf, cf
	task.defer(function()
		local ok, Pistas = pcall(require, script.Parent.Pistas)
		if ok then
			Pistas.pedir("MARCAR")
		end
	end)
end

local function actualizar(dt: number)
	if not objeto or not cfObjetivo or not cfActual then
		return
	end
	local camara = workspace.CurrentCamera
	if (cfActual.Position - cfObjetivo.Position).Magnitude > 25 then
		cfActual = cfObjetivo -- un salto grande (por ejemplo el ataque): no se arrastra
	else
		cfActual = cfActual:Lerp(cfObjetivo, 1 - math.exp(-20 * dt))
	end
	objeto.actualizar(cfActual, dt, camara.CFrame.Position)

	-- Efectos de cercanía: la cámara tiembla cada vez más y sube la estática si está cerca y de frente.
	local torso = objeto.modelo:FindFirstChild("Torso")
	local centro = if torso then torso.Position else cfActual.Position -- (el pivote del modelo no sigue al cuerpo: se mide al torso)
	local hacia = centro - camara.CFrame.Position
	local d = hacia.Magnitude
	local ef = cfg.Efecto
	Temblor.fijarLocal(math.clamp(1 - d / ef.DistanciaTemblor, 0, 1) ^ 1.2 * ef.TemblorMax)
	if d < cfg.EstaticaDistancia and d > 0.1 and camara.CFrame.LookVector:Dot(hacia.Unit) > 0.6 then
		cercaniaActual = 1 - d / cfg.EstaticaDistancia
	else
		cercaniaActual = 0
	end
end

function CriaturaVista.init()
	Net.obtener("Criatura").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" then
			return
		end
		if datos.accion == "aparece" and typeof(datos.cf) == "CFrame" then
			aparecer(datos.cf)
		elseif datos.accion == "ataca" then
			-- Salta sobre alguien: el sobresalto (sonido y estática) es para quien va a recibir el golpe.
			if datos.objetivo == Players.LocalPlayer.UserId and objeto then
				VHSEffects.susto()
				AudioManager.efecto(Config.Sustos.Glitch.Id, { volumen = Config.Sustos.Glitch.Volumen * 4 })
			end
		elseif datos.accion == "fin" then
			limpiar()
		end
	end)
	Net.obtener("CriaturaPos").OnClientEvent:Connect(function(cf)
		if objeto and typeof(cf) == "CFrame" then
			cfObjetivo = cf
		end
	end)
	RunService.RenderStepped:Connect(actualizar)
end

return CriaturaVista
