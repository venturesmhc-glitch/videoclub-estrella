--!nonstrict
--[[
	Calle (cliente): la vida de afuera, visible por las ventanas y la puerta.
	  - Pasan autos por la ruta (dos carriles, uno en cada sentido), con faros y luces traseras.
	  - Los carteles de neón del motel de enfrente parpadean (partes con el tag "NeonParpadeo").
	  - De vez en cuando, en la zona sin luz al costado del motel, hay una entidad quieta. Solo se le ven los ojos
	    brillantes, y únicamente cuando el jugador se acerca a la ventana (Config.EntidadLejana).
	Es solo decorado: no interactúa con nada. Cada jugador ve sus propios autos.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Autos = require(ReplicatedStorage.Shared.Autos)
local Personajes = require(ReplicatedStorage.Shared.Personajes)
local Config = require(ReplicatedStorage.Shared.Config)

local Calle = {}

local cfg = Config.Calle
local rng = Random.new()
local autos = {} -- { modelo, direccion, velocidad, z }
local carpeta

local ASFALTO_Y = -0.44 -- cara de arriba de la calzada (ver CalleDeAfuera en el builder)

local function crearAuto()
	local sentido = rng:NextInteger(0, 1) == 0 and 1 or -1 -- 1: hacia +X, -1: hacia -X
	local z = sentido == 1 and cfg.CarrilZ[1] or cfg.CarrilZ[2]
	local color = cfg.Colores[rng:NextInteger(1, #cfg.Colores)]
	local modelo = Autos.crear(color, { largo = rng:NextNumber(8, 10.5) })
	local xInicio = -sentido * cfg.LargoRuta / 2
	modelo:PivotTo(CFrame.new(xInicio, ASFALTO_Y, z) * CFrame.Angles(0, sentido == 1 and 0 or math.pi, 0))
	modelo.Parent = carpeta

	-- Sonido 3D del auto que pasa.
	if #cfg.Sonidos > 0 then
		local sonido = Instance.new("Sound")
		sonido.SoundId = cfg.Sonidos[rng:NextInteger(1, #cfg.Sonidos)]
		sonido.Volume = cfg.Volumen
		sonido.RollOffMode = Enum.RollOffMode.InverseTapered
		sonido.RollOffMinDistance = 10
		sonido.RollOffMaxDistance = 90
		sonido.Parent = modelo.PrimaryPart
		sonido:Play()
	end

	table.insert(autos, {
		modelo = modelo,
		sentido = sentido,
		velocidad = rng:NextNumber(cfg.VelocidadMin, cfg.VelocidadMax),
		z = z,
		x = xInicio,
	})
end

-- ===== Entidad lejana =====

local ZFRENTE = Config.Local.ZFrente -- plano del vidrio del local
local entidad = nil -- { modelo, ojos = { Part }, hasta, deriva }

local function crearEntidad(posicion: Vector3)
	local ecfg = Config.EntidadLejana
	local modelo = Personajes.crearSocioMalla(Config.Socio)
	local cuerpo = modelo and modelo.PrimaryPart
	if not modelo or not cuerpo then
		return nil
	end
	-- Casi negra, sin textura ni resplandor: en la oscuridad no se ve nada más que los ojos.
	cuerpo.TextureID = ""
	cuerpo.Color = Color3.fromRGB(6, 6, 8)
	for _, d in modelo:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SurfaceAppearance") or (d:IsA("Part") and d.Name == "Ojo") then
			d:Destroy()
		end
	end
	local ojos = {}
	for _, lado in { -1, 1 } do
		local ojo = Instance.new("Part")
		ojo.Name = "OjoLejano"
		ojo.Size = ecfg.TamanoOjo
		ojo.Color = Color3.fromRGB(240, 244, 232)
		ojo.Material = Enum.Material.Neon
		ojo.Anchored = true
		ojo.CanCollide = false
		ojo.CanTouch = false
		ojo.CanQuery = false
		ojo.CastShadow = false
		ojo.Transparency = 1
		if modelo:GetAttribute("ConHuesos") then
			local s = Config.Socio.AlturaMalla / Personajes.ALTURA_ESQUELETO
			ojo.CFrame = modelo:GetPivot() * CFrame.new(lado * 0.077 * s, 2.88 * s, -0.13 * s)
		else
			ojo.CFrame = cuerpo.CFrame * CFrame.new(lado * 0.85, cuerpo.Size.Y * 0.378, -cuerpo.Size.Z * 0.49)
		end
		ojo.Parent = modelo
		table.insert(ojos, ojo)
	end
	modelo:PivotTo(CFrame.lookAt(posicion, Vector3.new(posicion.X * 0.3, 0, ZFRENTE)))
	modelo.Parent = workspace
	return modelo, ojos
end

local function actualizarEntidad(dt: number)
	if not entidad then
		return
	end
	local ecfg = Config.EntidadLejana
	if os.clock() >= entidad.hasta then
		entidad.modelo:Destroy()
		entidad = nil
		return
	end
	-- Se corre despacito de lado a lado, como si esperara.
	entidad.modelo:PivotTo(entidad.modelo:GetPivot() + Vector3.new(entidad.deriva * dt, 0, 0))
	-- Los ojos solo se ven si el jugador está cerca de la ventana (y no mientras parpadea).
	local camara = workspace.CurrentCamera
	local visible = 0
	if camara then
		local z = camara.CFrame.Position.Z
		if z <= ZFRENTE and z >= ZFRENTE - ecfg.DistanciaVentana then
			visible = math.clamp((1 - (ZFRENTE - z) / ecfg.DistanciaVentana) * 1.5, 0, 1)
		end
	end
	if os.clock() < entidad.parpadeoHasta then
		visible = 0
	elseif os.clock() >= entidad.proximoParpadeo then
		entidad.parpadeoHasta = os.clock() + 0.18
		entidad.proximoParpadeo = os.clock() + rng:NextNumber(2.5, 6)
	end
	for _, ojo in entidad.ojos do
		ojo.Transparency = 1 - visible
	end
end

local function bucleEntidad()
	local ecfg = Config.EntidadLejana
	while true do
		task.wait(rng:NextNumber(ecfg.IntervaloMin, ecfg.IntervaloMax))
		if not entidad then
			local posicion = ecfg.Posiciones[rng:NextInteger(1, #ecfg.Posiciones)]
			local modelo, ojos = crearEntidad(posicion)
			if modelo then
				entidad = {
					modelo = modelo,
					ojos = ojos,
					hasta = os.clock() + rng:NextNumber(ecfg.VisibleSegMin, ecfg.VisibleSegMax),
					deriva = rng:NextNumber(-0.7, 0.7),
					parpadeoHasta = 0,
					proximoParpadeo = os.clock() + rng:NextNumber(2, 5),
				}
			end
		end
	end
end

function Calle.init()
	task.spawn(bucleEntidad)
	RunService.Heartbeat:Connect(actualizarEntidad)

	carpeta = Instance.new("Folder")
	carpeta.Name = "AutosDeLaCalle"
	carpeta.Parent = workspace

	-- Autos: uno cada tanto, más seguido al principio para que la calle no esté vacía.
	local proximo = os.clock() + 8
	RunService.Heartbeat:Connect(function(dt)
		if os.clock() >= proximo then
			proximo = os.clock() + rng:NextNumber(cfg.IntervaloMin, cfg.IntervaloMax)
			if #autos < cfg.MaxAutos then
				crearAuto()
			end
		end
		for i = #autos, 1, -1 do
			local a = autos[i]
			a.x += a.sentido * a.velocidad * dt
			if math.abs(a.x) > cfg.LargoRuta / 2 + 10 then
				a.modelo:Destroy()
				table.remove(autos, i)
			else
				a.modelo:PivotTo(CFrame.new(a.x, ASFALTO_Y, a.z) * CFrame.Angles(0, a.sentido == 1 and 0 or math.pi, 0))
			end
		end
	end)

	-- Neones del motel: cada uno parpadea a su ritmo (atributo "Periodo" en segundos; sin atributo queda fijo).
	local neones = {} -- parte -> { color, material, siguiente, encendido }
	local function registrar(parte)
		if not parte:IsA("BasePart") or neones[parte] then
			return
		end
		neones[parte] = {
			color = parte.Color,
			material = parte.Material,
			siguiente = os.clock() + rng:NextNumber(1, 6),
			encendido = true,
		}
	end
	for _, p in CollectionService:GetTagged("NeonParpadeo") do
		registrar(p)
	end
	CollectionService:GetInstanceAddedSignal("NeonParpadeo"):Connect(registrar)

	RunService.Heartbeat:Connect(function()
		local ahora = os.clock()
		for parte, datos in neones do
			local periodo = parte:GetAttribute("Periodo")
			if periodo and ahora >= datos.siguiente then
				datos.encendido = not datos.encendido
				-- Encendido dura un buen rato; apagado, un destello corto (como un tubo de neón con fallas).
				datos.siguiente = ahora + (datos.encendido and rng:NextNumber(periodo * 0.6, periodo * 1.4) or rng:NextNumber(0.05, 0.25))
				parte.Material = datos.encendido and datos.material or Enum.Material.SmoothPlastic
				parte.Color = datos.encendido and datos.color or datos.color:Lerp(Color3.new(0, 0, 0), 0.8)
				for _, hijo in parte:GetChildren() do
					if hijo:IsA("Light") or hijo:IsA("SurfaceGui") then
						hijo.Enabled = datos.encendido -- los letreros (SurfaceGui) también se apagan
					end
				end
			end
		end
	end)
end

return Calle
