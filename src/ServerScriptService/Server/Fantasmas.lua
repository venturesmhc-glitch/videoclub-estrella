--!nonstrict
--[[
	Fantasmas (servidor): jugadores que quedaron fuera de la noche (SocioEntity los graba por segunda vez).

	  - El jugador pasa a ser ESPECTADOR: su cuerpo real queda invisible y guardado lejos del mapa, y el cliente
	    (Client/Espectador) le muestra el local desde la cámara de sus compañeros, con el mundo distorsionado y sin el
	    monstruo. Lo marca el atributo "Espectador" del Player.
	  - Una ESTATUA de su personaje (copia traslúcida de su skin, con resplandor pálido) queda quieta en el
	    estacionamiento del motel de enfrente, mirando al local: es lo que ven sus compañeros por las ventanas.
	  - Vuelve a jugar solo si compra el revivir con Robux (Tienda) o si todo el equipo cayó y la noche se repite.

	  Fantasmas.init()
	  Fantasmas.convertir(jugador)
	  Fantasmas.revivir(jugador)
	  Fantasmas.reviverTodos()
	  Fantasmas.esFantasma(jugador) -> boolean
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Fantasmas = {}

local cfg = Config.Fantasma
local estado = {} -- Player -> { plaza, estatua = Model?, guardado = { [pieza] = transparencia }, colisiones = { [pieza] = bool } }
local carpeta

local function carpetaEstatuas()
	if not carpeta or not carpeta.Parent then
		carpeta = workspace:FindFirstChild("Fantasmas") or Instance.new("Folder")
		carpeta.Name = "Fantasmas"
		carpeta.Parent = workspace
	end
	return carpeta
end

local function plazaLibre(): number
	local usadas = {}
	for _, e in estado do
		usadas[e.plaza] = true
	end
	for i = 1, #cfg.Plazas do
		if not usadas[i] then
			return i
		end
	end
	return 1
end

-- Copia traslúcida del personaje, quieta en el motel.
local function crearEstatua(jugador: Player, plaza: number): Model?
	local personaje = jugador.Character
	if not personaje then
		return nil
	end
	local viejoArchivable = personaje.Archivable
	personaje.Archivable = true
	local ok, copia = pcall(function()
		return personaje:Clone()
	end)
	personaje.Archivable = viejoArchivable
	if not ok or not copia then
		return nil
	end
	copia.Name = "Estatua_" .. jugador.Name
	local raiz = copia:FindFirstChild("HumanoidRootPart")
	local humanoide = copia:FindFirstChildOfClass("Humanoid")
	local alto = humanoide and (humanoide.HipHeight + (raiz and raiz.Size.Y / 2 or 1)) or 3
	for _, d in copia:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if d.Transparency < 1 then
				d.Transparency = cfg.Translucidez
			end
		elseif d:IsA("Decal") and d.Transparency < 1 then
			d.Transparency = cfg.Translucidez
		end
	end
	if humanoide then
		humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoide.RequiresNeck = false
		humanoide:Destroy() -- sin Humanoid queda en la pose en que estaba, como una estatua
	end
	local lugar = cfg.Plazas[plaza]
	local pos = Vector3.new(lugar.X, cfg.PisoY + alto, lugar.Z)
	copia:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
	-- Resplandor pálido (se ve de lejos en la oscuridad) y contorno suave.
	local cabeza = copia:FindFirstChild("Head")
	if cabeza then
		local luz = Instance.new("PointLight")
		luz.Color = cfg.ColorLuz
		luz.Brightness = cfg.BrilloLuz
		luz.Range = cfg.AlcanceLuz
		luz.Shadows = false
		luz.Parent = cabeza
	end
	local contorno = Instance.new("Highlight")
	contorno.FillColor = cfg.ColorLuz
	contorno.FillTransparency = cfg.RellenoContorno
	contorno.OutlineColor = cfg.ColorLuz
	contorno.OutlineTransparency = cfg.BordeContorno
	contorno.DepthMode = Enum.HighlightDepthMode.Occluded
	contorno.Parent = copia
	copia.Parent = carpetaEstatuas()
	return copia
end

-- El cuerpo real del espectador: invisible, quieto y guardado lejos (no lo ve ni lo toca nadie).
local function guardarCuerpo(jugador: Player)
	local e = estado[jugador]
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not e or not personaje or not humanoide or not raiz then
		return
	end
	e.guardado, e.colisiones = {}, {}
	for _, d in personaje:GetDescendants() do
		if d:IsA("BasePart") and d ~= raiz then
			e.guardado[d] = d.Transparency
			e.colisiones[d] = d.CanCollide
			d.Transparency = 1
			d.CanCollide = false
		elseif d:IsA("Decal") then
			e.guardado[d] = d.Transparency
			d.Transparency = 1
		end
	end
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.WalkSpeed = 0
	humanoide.JumpHeight = 0
	personaje:PivotTo(CFrame.new(cfg.EstacionamientoOculto))
	raiz.Anchored = true
end

function Fantasmas.esFantasma(jugador: Player): boolean
	return estado[jugador] ~= nil
end

function Fantasmas.convertir(jugador: Player)
	if estado[jugador] then
		return
	end
	local plaza = plazaLibre()
	estado[jugador] = { plaza = plaza, guardado = {}, colisiones = {} }
	estado[jugador].estatua = crearEstatua(jugador, plaza) -- antes de ocultar el cuerpo: se copia la skin tal cual
	guardarCuerpo(jugador)
	jugador:SetAttribute("Espectador", true)
	Net.aviso(jugador, "Quedaste atrapado en la cinta. Mirá a tus compañeros desde afuera: ellos ven tu estatua en el motel.")
end

function Fantasmas.revivir(jugador: Player)
	local e = estado[jugador]
	if not e then
		return
	end
	estado[jugador] = nil
	jugador:SetAttribute("Espectador", nil)
	for pieza, transparencia in e.guardado do
		if pieza.Parent then
			pieza.Transparency = transparencia
		end
	end
	for pieza, solida in e.colisiones do
		if pieza.Parent then
			pieza.CanCollide = solida
		end
	end
	if e.estatua then
		e.estatua:Destroy()
	end
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if humanoide then
		humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoide.WalkSpeed = Config.Jugador.VelocidadCaminar
		humanoide.JumpHeight = Config.Jugador.AlturaSalto
	end
	if raiz then
		raiz.Anchored = false
		local inicio = workspace:FindFirstChild("SpawnLocation")
		if inicio then
			personaje:PivotTo(CFrame.new(inicio.Position + Vector3.new(0, 3, 0)))
		end
	end
end

function Fantasmas.reviverTodos()
	for jugador in table.clone(estado) do
		Fantasmas.revivir(jugador)
	end
end

function Fantasmas.init()
	local function vigilar(jugador: Player)
		-- Si el personaje reaparece mientras el jugador sigue fuera de la noche, el cuerpo nuevo también se guarda.
		jugador.CharacterAdded:Connect(function(personaje)
			if not estado[jugador] then
				return
			end
			personaje:WaitForChild("HumanoidRootPart", 10)
			personaje:WaitForChild("Humanoid", 10)
			task.wait(0.2) -- que Roblox termine de armar la apariencia
			if estado[jugador] and jugador.Character == personaje then
				guardarCuerpo(jugador)
			end
		end)
	end
	Players.PlayerAdded:Connect(vigilar)
	for _, jugador in Players:GetPlayers() do
		vigilar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		local e = estado[jugador]
		if e and e.estatua then
			e.estatua:Destroy()
		end
		estado[jugador] = nil
	end)
end

return Fantasmas
