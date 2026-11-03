--!nonstrict
--[[
	Temblor (cliente): la cámara se sacude cuando el Socio se acerca.
	El peligro (0..1, por jugador) lo manda el servidor por el remote Danger; cuanto más cerca está, más fuerte y más
	rápido tiembla la cámara, con latidos que se aceleran. Cuando el Socio aparece hay además una sacudida brusca.
	Solo toca la cámara normal (CameraType.Custom): la cinta, los screamers y el espectador usan su propia cámara.
	Todos los valores están en Config.Temblor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Temblor = {}

local cfg = Config.Temblor
local objetivo = 0 -- peligro que manda el servidor
local actual = 0 -- peligro suavizado
local ultimoAviso = 0
local sobresalto = 0 -- sacudida brusca de la aparición (decae sola)
local faseLatido = 0
local faseRuido = 0 -- avanza más rápido con el peligro (así el ruido no da saltos al cambiar la frecuencia)

-- Un latido doble: golpe fuerte y un segundo más suave justo después.
local function latido(fase: number): number
	local p = fase % 1
	local primero = math.exp(-p * 16)
	local segundo = p > 0.3 and 0.55 * math.exp(-(p - 0.3) * 18) or 0
	return primero + segundo
end

function Temblor.init()
	Net.obtener("Danger").OnClientEvent:Connect(function(valor)
		if typeof(valor) == "number" then
			objetivo = math.clamp(valor, 0, 1)
			ultimoAviso = os.clock()
		end
	end)
	Net.obtener("SocioPresencia").OnClientEvent:Connect(function(presente)
		if presente == true then
			sobresalto = 1
		end
	end)

	local semilla = math.random() * 100
	-- La cámara de Roblox saca su rotación de camera.CFrame en cada cuadro: si el desvío se queda puesto se acumula y la
	-- vista se va corriendo. Por eso antes de que ella se actualice se saca el desvío del cuadro anterior.
	local aplicado = CFrame.identity
	RunService:BindToRenderStep("TemblorQuitar", Enum.RenderPriority.First.Value, function()
		if aplicado ~= CFrame.identity then
			local camara = workspace.CurrentCamera
			if camara then
				camara.CFrame = camara.CFrame * aplicado:Inverse()
			end
			aplicado = CFrame.identity
		end
	end)
	RunService:BindToRenderStep("Temblor", Enum.RenderPriority.Camera.Value + 1, function(dt)
		-- Sin noticias del servidor (el Socio se fue, se acabó el turno): se calma.
		local meta = (os.clock() - ultimoAviso < 3) and objetivo or 0
		actual += (meta - actual) * math.min(1, dt * cfg.Suavizado)
		sobresalto = math.max(0, sobresalto - dt / cfg.SobresaltoSeg)

		local nivel = math.clamp((actual - cfg.Desde) / (1 - cfg.Desde), 0, 1)
		local fuerza = math.clamp(nivel + sobresalto * cfg.SobresaltoFuerza, 0, 1.4)
		if fuerza <= 0.002 then
			return
		end
		local camara = workspace.CurrentCamera
		if not camara or camara.CameraType ~= Enum.CameraType.Custom then
			return
		end

		-- Temblor continuo (ruido suave, no un tic): más amplio y más rápido con el peligro.
		local frecuencia = cfg.FrecuenciaMin + (cfg.FrecuenciaMax - cfg.FrecuenciaMin) * math.min(1, fuerza)
		faseRuido += dt * frecuencia
		local amplitud = math.rad(cfg.AmplitudMaxGrados) * fuerza ^ 1.3
		local rx = math.noise(faseRuido, semilla, 0) * amplitud
		local ry = math.noise(faseRuido, semilla, 10) * amplitud
		local rz = math.noise(faseRuido, semilla, 20) * amplitud * cfg.GiroRelativo

		-- Latidos que se aceleran con el peligro; cada golpe empuja la cámara hacia arriba.
		faseLatido += dt * (cfg.LatidoMin + (cfg.LatidoMax - cfg.LatidoMin) * math.min(1, nivel)) / 60
		local golpe = latido(faseLatido) * math.rad(cfg.LatidoGrados) * math.min(1, nivel * 1.5)

		aplicado = CFrame.Angles(rx + golpe, ry, rz)
		camara.CFrame = camara.CFrame * aplicado
	end)
end

return Temblor
