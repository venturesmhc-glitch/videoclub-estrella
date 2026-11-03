--!nonstrict
--[[
	Parpadeo (cliente): el Socio N° 0000 parpadea. De a ratos desaparece un instante (como un cuadro que la cinta no logra
	leer) y vuelve a aparecer en el mismo lugar. Cuanto más cerca está, más seguido y más largo parpadea; a veces son dos
	parpadeos seguidos. Es solo visual y solo en esta pantalla: no cambia dónde está el Socio ni si te ve o te captura.
	El peligro (0..1) lo manda el servidor por el remote Danger. Los valores están en Config.Parpadeo.
	Al espectador no le hace nada (él ya no ve al Socio: ver Client/Espectador).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Parpadeo = {}

local cfg = Config.Parpadeo
local rng = Random.new()
local jugador = Players.LocalPlayer

local peligro = 0
local escondido = false -- ahora está invisible (parpadeo en curso)
local modelo -- el modelo que se escondió (para devolverle la vista aunque desaparezca del mundo)
local luces = {} -- luces que estaban prendidas antes de esconderlo
local cambiarEn = 0 -- os.clock() del próximo cambio
local restantes = 0 -- parpadeos que faltan de una ráfaga (para los dobles)

local function aplicar(socio: Model, oculto: boolean)
	for _, d in socio:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = oculto and 1 or 0
		elseif d:IsA("Light") then
			if oculto then
				if d.Enabled then
					luces[d] = true
					d.Enabled = false
				end
			elseif luces[d] then
				d.Enabled = true
				luces[d] = nil
			end
		end
	end
end

local function mostrar()
	if escondido and modelo then
		aplicar(modelo, false)
	end
	escondido = false
	modelo = nil
	table.clear(luces)
end

-- Tiempo hasta el próximo parpadeo: se acorta con el peligro.
local function esperaHastaParpadeo(): number
	local lejos = rng:NextNumber(cfg.IntervaloMin, cfg.IntervaloMax)
	local cerca = rng:NextNumber(cfg.IntervaloMinCerca, cfg.IntervaloMaxCerca)
	return lejos + (cerca - lejos) * math.clamp(peligro, 0, 1)
end

local function duracionDelParpadeo(): number
	local corta = rng:NextNumber(cfg.DuracionMin, cfg.DuracionMax)
	return corta * (1 + peligro * cfg.DuracionExtraCerca)
end

function Parpadeo.init()
	Net.obtener("Danger").OnClientEvent:Connect(function(valor)
		if typeof(valor) == "number" then
			peligro = math.clamp(valor, 0, 1)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local socio = workspace:FindFirstChild("Socio0000")
		if not socio or socio.Parent ~= workspace or jugador:GetAttribute("Espectador") then
			if escondido then
				mostrar() -- se fue (o te volviste espectador): que no quede invisible para la próxima aparición
			end
			cambiarEn = 0
			return
		end

		local ahora = os.clock()
		if cambiarEn == 0 then
			cambiarEn = ahora + esperaHastaParpadeo()
			return
		end
		if ahora < cambiarEn then
			return
		end

		if escondido then
			-- Termina el parpadeo; si era una ráfaga doble, el segundo viene enseguida.
			aplicar(modelo, false)
			escondido = false
			modelo = nil
			table.clear(luces)
			if restantes > 0 then
				restantes -= 1
				cambiarEn = ahora + rng:NextNumber(cfg.EntreDoblesMin, cfg.EntreDoblesMax)
			else
				cambiarEn = ahora + esperaHastaParpadeo()
			end
		else
			modelo = socio
			escondido = true
			aplicar(socio, true)
			if restantes == 0 and rng:NextNumber() < cfg.ProbDoble then
				restantes = 1
			end
			cambiarEn = ahora + duracionDelParpadeo()
		end
	end)
end

return Parpadeo
