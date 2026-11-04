--!nonstrict
--[[
	Cosmeticos (servidor): la ropa que se compra en la tienda (gorra, chaleco, camiseta). Lo que cada jugador tiene puesto
	está en su perfil (Persistencia.equipado: ranuras "cabeza" y "torso"); acá se arma con piezas sueltas pegadas al
	personaje, así no hace falta ningún asset de Roblox. Se vuelve a poner en cada personaje nuevo y cuando cambia el perfil.

	  Cosmeticos.aplicar(jugador)   -- deja puesto exactamente lo que tiene equipado (y saca el resto)
]]

local Players = game:GetService("Players")

local Persistencia = require(script.Parent.Persistencia)

local Cosmeticos = {}

local NOMBRE = "CosmeticosTienda"

local function pieza(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = padre
	return p
end

local function pegar(base: BasePart, p: BasePart)
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0, soldadura.Part1 = base, p
	soldadura.Parent = p
end

local function rotulo(p: BasePart, cara: Enum.NormalId, texto: string, color: Color3, fuente: Enum.Font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = cara
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.4
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = fuente
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = texto
	t.Parent = gui
end

-- ===== Cada artículo =====

local ARMADORES = {}

-- Gorra roja de Don Ernesto: copa, visera y una estrella al frente.
function ARMADORES.gorra(personaje: Model, carpeta: Folder)
	local cabeza = personaje:FindFirstChild("Head")
	if not cabeza then
		return
	end
	local base = cabeza.CFrame
	local rojo, oscuro = Color3.fromRGB(168, 32, 38), Color3.fromRGB(60, 14, 16)
	local copa = pieza("Copa", Vector3.new(0.4, 1.35, 1.35), base * CFrame.new(0, 0.56, 0) * CFrame.Angles(0, 0, math.rad(90)), rojo, Enum.Material.Fabric, carpeta)
	copa.Shape = Enum.PartType.Cylinder
	local visera = pieza("Visera", Vector3.new(1.3, 0.1, 0.8), base * CFrame.new(0, 0.42, -0.95) * CFrame.Angles(math.rad(-8), 0, 0), oscuro, Enum.Material.Fabric, carpeta)
	local estrella = pieza("Estrella", Vector3.new(0.5, 0.4, 0.06), base * CFrame.new(0, 0.62, -0.78), rojo, Enum.Material.Fabric, carpeta)
	estrella.Transparency = 1
	rotulo(estrella, Enum.NormalId.Front, "★", Color3.fromRGB(255, 214, 90), Enum.Font.GothamBold)
	for _, p in { copa, visera, estrella } do
		pegar(cabeza, p)
	end
end

local function torsoDe(personaje: Model): BasePart?
	return personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso")
end

-- Chaleco azul del Videoclub con la estrella dorada en el pecho.
function ARMADORES.chaleco(personaje: Model, carpeta: Folder)
	local torso = torsoDe(personaje)
	if not torso then
		return
	end
	local chaleco = pieza("Chaleco", torso.Size + Vector3.new(0.12, -0.15, 0.12), torso.CFrame, Color3.fromRGB(22, 40, 78), Enum.Material.Fabric, carpeta)
	rotulo(chaleco, Enum.NormalId.Front, "★", Color3.fromRGB(255, 214, 90), Enum.Font.GothamBold)
	rotulo(chaleco, Enum.NormalId.Back, "VIDEOCLUB\nESTRELLA", Color3.fromRGB(255, 214, 90), Enum.Font.Arcade)
	pegar(torso, chaleco)
end

-- Camiseta negra del Socio: 0000 al frente.
function ARMADORES.camiseta(personaje: Model, carpeta: Folder)
	local torso = torsoDe(personaje)
	if not torso then
		return
	end
	local camiseta = pieza("Camiseta", torso.Size + Vector3.new(0.1, 0, 0.1), torso.CFrame, Color3.fromRGB(10, 10, 12), Enum.Material.Fabric, carpeta)
	rotulo(camiseta, Enum.NormalId.Front, "0000", Color3.fromRGB(230, 230, 220), Enum.Font.Arcade)
	rotulo(camiseta, Enum.NormalId.Back, "SOCIO", Color3.fromRGB(230, 230, 220), Enum.Font.Arcade)
	pegar(torso, camiseta)
end

--- Deja puesto exactamente lo que el jugador tiene equipado en "cabeza" y "torso".
function Cosmeticos.aplicar(jugador: Player)
	local personaje = jugador.Character
	if not personaje or not personaje:FindFirstChild("HumanoidRootPart") then
		return
	end
	local equipado = Persistencia.equipado(jugador)
	local firma = tostring(equipado.cabeza) .. "|" .. tostring(equipado.torso)
	if personaje:GetAttribute("CosmeticosFirma") == firma and personaje:FindFirstChild(NOMBRE) then
		return
	end
	local viejo = personaje:FindFirstChild(NOMBRE)
	if viejo then
		viejo:Destroy()
	end
	personaje:SetAttribute("CosmeticosFirma", firma)
	if not equipado.cabeza and not equipado.torso then
		return
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = NOMBRE
	for _, ranura in { "cabeza", "torso" } do
		local armador = equipado[ranura] and ARMADORES[equipado[ranura]]
		if armador then
			armador(personaje, carpeta)
		end
	end
	carpeta.Parent = personaje
end

function Cosmeticos.init()
	Persistencia.suscribirPerfil(Cosmeticos.aplicar)
	local function alAparecer(jugador: Player)
		jugador.CharacterAdded:Connect(function(personaje)
			personaje:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.3) -- que termine de armarse el avatar (las partes del torso y la cabeza)
			Cosmeticos.aplicar(jugador)
		end)
		if jugador.Character then
			task.spawn(Cosmeticos.aplicar, jugador)
		end
	end
	Players.PlayerAdded:Connect(alAparecer)
	for _, jugador in Players:GetPlayers() do
		alAparecer(jugador)
	end
end

return Cosmeticos
