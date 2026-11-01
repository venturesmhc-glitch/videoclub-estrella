--!nonstrict
--[[
	Fantasmas (servidor): cuando un jugador queda fuera de la noche (SocioEntity lo graba por segunda vez), su personaje
	pasa a ser un fantasma: queda quieto en el estacionamiento del motel de enfrente, mirando al videoclub, con su misma
	skin pero traslúcida y con un resplandor pálido para que se lo distinga desde las ventanas del local.
	Al empezar la siguiente noche todos vuelven al mostrador.

	  Fantasmas.init()
	  Fantasmas.convertir(jugador)      -- lo manda al motel como fantasma
	  Fantasmas.revivir(jugador)        -- lo trae de vuelta al mostrador
	  Fantasmas.reviverTodos()
	  Fantasmas.esFantasma(jugador) -> boolean
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Fantasmas = {}

local cfg = Config.Fantasma
local estado = {} -- Player -> { plaza, guardado = { [pieza] = transparencia }, colisiones = { [pieza] = bool }, extras = { Instance } }

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

local function partesDe(personaje: Model)
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	local lista = {}
	for _, d in personaje:GetDescendants() do
		if d ~= raiz and (d:IsA("BasePart") or d:IsA("Decal")) then
			table.insert(lista, d)
		end
	end
	return lista
end

local function aplicar(jugador: Player)
	local e = estado[jugador]
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not e or not personaje or not humanoide or not raiz then
		return
	end

	-- Piel traslúcida (se guarda la transparencia original de cada pieza para devolverla al revivir).
	e.guardado, e.colisiones = {}, {}
	for _, d in partesDe(personaje) do
		if d.Transparency < 1 then
			e.guardado[d] = d.Transparency
			d.Transparency = cfg.Translucidez
		end
		if d:IsA("BasePart") then
			e.colisiones[d] = d.CanCollide
			d.CanCollide = false
		end
	end
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	-- Resplandor pálido (se ve de lejos en la oscuridad) y contorno suave.
	for _, extra in e.extras or {} do
		extra:Destroy()
	end
	e.extras = {}
	local cabeza = personaje:FindFirstChild("Head")
	if cabeza then
		local luz = Instance.new("PointLight")
		luz.Name = "LuzFantasma"
		luz.Color = cfg.ColorLuz
		luz.Brightness = cfg.BrilloLuz
		luz.Range = cfg.AlcanceLuz
		luz.Shadows = false
		luz.Parent = cabeza
		table.insert(e.extras, luz)
	end
	local contorno = Instance.new("Highlight")
	contorno.Name = "ContornoFantasma"
	contorno.FillColor = cfg.ColorLuz
	contorno.FillTransparency = cfg.RellenoContorno
	contorno.OutlineColor = cfg.ColorLuz
	contorno.OutlineTransparency = cfg.BordeContorno
	contorno.DepthMode = Enum.HighlightDepthMode.Occluded
	contorno.Parent = personaje
	table.insert(e.extras, contorno)

	-- Quieto en el motel, mirando al videoclub.
	humanoide.WalkSpeed = 0
	humanoide.JumpHeight = 0
	local plaza = cfg.Plazas[e.plaza]
	local alto = humanoide.HipHeight + raiz.Size.Y / 2
	local pos = Vector3.new(plaza.X, cfg.PisoY + alto, plaza.Z)
	personaje:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
	raiz.Anchored = true
end

function Fantasmas.esFantasma(jugador: Player): boolean
	return estado[jugador] ~= nil
end

function Fantasmas.convertir(jugador: Player)
	if estado[jugador] then
		return
	end
	estado[jugador] = { plaza = plazaLibre(), guardado = {}, extras = {} }
	aplicar(jugador)
	Net.aviso(jugador, "Quedaste atrapado en la cinta. Mirá el videoclub desde el motel hasta que termine la noche.")
end

function Fantasmas.revivir(jugador: Player)
	local e = estado[jugador]
	if not e then
		return
	end
	estado[jugador] = nil
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
	for _, extra in e.extras do
		extra:Destroy()
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
		-- Si el jugador reaparece (resetea el personaje) sigue siendo fantasma hasta que termine la noche.
		jugador.CharacterAdded:Connect(function(personaje)
			if not estado[jugador] then
				return
			end
			personaje:WaitForChild("HumanoidRootPart", 10)
			personaje:WaitForChild("Humanoid", 10)
			task.wait(0.2) -- que Roblox termine de armar la apariencia
			if estado[jugador] and jugador.Character == personaje then
				aplicar(jugador)
			end
		end)
	end
	Players.PlayerAdded:Connect(vigilar)
	for _, jugador in Players:GetPlayers() do
		vigilar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		estado[jugador] = nil
	end)
end

return Fantasmas
