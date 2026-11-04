--!nonstrict
--[[
	SocioAnimacion (cliente): anima el esqueleto del Socio N° 0000 en cada pantalla.

	Bone.Transform no se replica del servidor a los clientes: si el servidor mueve los huesos, el cliente ve la malla en
	pose de reposo deslizándose rígida (como un juguete de plástico) y los ojos, que sí se replican, flotan lejos de la cara.
	Por eso el servidor (SocioEntity) solo lleva la lógica y publica en los atributos del modelo hacia dónde está y gira
	(SocioPos, SocioRot, SocioSalto al aparecer de golpe) y si lo están alumbrando (SocioAlumbrado); acá cada cliente
	desliza el cuerpo hasta ahí, calcula quién está cerca y anima los huesos y los ojos con Shared/SocioHuesos en modo suave.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SocioHuesos = require(ReplicatedStorage.Shared.SocioHuesos)

local SocioAnimacion = {}

local cfg = Config.Socio
local actual -- { modelo, huesos, conexion, pos, rot, vel, salto, acumulado }

local function soltar()
	if actual then
		actual.conexion:Disconnect()
		actual = nil
	end
end

-- Jugador más cercano que sigue en la noche (distancia en el plano y su posición), para la boca y la cabeza.
local function cercano(desde: Vector3): (number?, Vector3?)
	local mejor, posMejor
	for _, jugador in Players:GetPlayers() do
		if jugador:GetAttribute("Espectador") ~= true then
			local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
			if raiz then
				local d = Vector3.new(raiz.Position.X - desde.X, 0, raiz.Position.Z - desde.Z).Magnitude
				if not mejor or d < mejor then
					mejor, posMejor = d, raiz.Position
				end
			end
		end
	end
	return mejor, posMejor
end

local function enlazar(modelo: Model)
	if not modelo:GetAttribute("ConHuesos") then
		return -- el cuerpo de respaldo (sin esqueleto) se mueve con lo que replica el servidor
	end
	soltar()
	local huesos = SocioHuesos.nuevo(modelo, { distanciaBoca = cfg.BocaDistancia, anguloBoca = cfg.BocaAngulo, suave = true })
	huesos.suavizar(0, 0) -- lee la pose de reposo y los ojos antes de mover nada
	local estado = { modelo = modelo, huesos = huesos, pos = nil, rot = 0, vel = 0, salto = modelo:GetAttribute("SocioSalto"), acumulado = 0 }
	estado.conexion = RunService.RenderStepped:Connect(function(dt)
		if not modelo.Parent then
			if actual == estado then
				soltar()
			else
				estado.conexion:Disconnect()
			end
			return
		end
		local meta = modelo:GetAttribute("SocioPos")
		if typeof(meta) ~= "Vector3" then
			return
		end
		local metaRot = modelo:GetAttribute("SocioRot") or 0
		local salto = modelo:GetAttribute("SocioSalto")
		if not estado.pos or salto ~= estado.salto or (meta - estado.pos).Magnitude > 25 then
			estado.pos, estado.rot, estado.vel, estado.salto = meta, metaRot, 0, salto
		else
			local antes = estado.pos
			estado.pos = antes:Lerp(meta, 1 - math.exp(-dt * cfg.SuavizadoMovimiento))
			local giro = (metaRot - estado.rot + math.pi) % (2 * math.pi) - math.pi
			estado.rot += giro * (1 - math.exp(-dt * cfg.SuavizadoGiro))
			estado.vel += ((estado.pos - antes).Magnitude / math.max(dt, 1e-3) - estado.vel) * (1 - math.exp(-dt * 8))
		end
		modelo:PivotTo(CFrame.new(estado.pos) * CFrame.Angles(0, estado.rot, 0))

		-- La lógica de gestos corre a la cadencia de siempre (cada TickSeg); los huesos se actualizan en cada cuadro.
		estado.acumulado += dt
		if estado.acumulado >= cfg.TickSeg then
			estado.acumulado = 0
			local distancia, objetivo = cercano(estado.pos)
			huesos.actualizar(cfg.TickSeg, true, modelo:GetAttribute("SocioAlumbrado") == true, false, distancia, objetivo)
		end
		huesos.suavizar(dt, estado.vel)
	end)
	actual = estado
end

function SocioAnimacion.init()
	workspace.ChildAdded:Connect(function(hijo)
		if hijo.Name == "Socio0000" and hijo:IsA("Model") then
			enlazar(hijo)
		end
	end)
	local ya = workspace:FindFirstChild("Socio0000")
	if ya and ya:IsA("Model") then
		enlazar(ya)
	end
end

return SocioAnimacion
