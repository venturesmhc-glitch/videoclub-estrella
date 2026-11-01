--!nonstrict
--[[
	Personajes: arma los cuerpos (R15) de los clientes, el Socio y las siluetas, con pelo y animaciones.
	Lo usan el servidor (clientes y Socio) y el cliente (fantasmas de la cinta, anomalías).

	  Personajes.crear({ piel, ropa, pantalon, escala?, sinCara?, pelo?, estilo? }) -> Model (R15 con Humanoid)
	  Personajes.agregarPelo(modelo, color, estilo)       -- estilo: "corto" | "largo" | "gorra"
	  Personajes.animar(modelo) -> { caminar = function(bool), detener = function() }
	  Personajes.convertirEnTitere(modelo, color?)         -- sin Humanoid: solo la raíz anclada, para mover a mano
]]

local Players = game:GetService("Players")

local Personajes = {}

-- Animaciones R15 por defecto de Roblox.
local ANIM_CAMINAR = "rbxassetid://507777826"
local ANIM_QUIETO = "rbxassetid://507766666"
local CARA_SONRISA = 144080495

local function pintar(modelo: Model, color: Color3)
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = color
		elseif d:IsA("Decal") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
end

--- Pelo hecho con partes (sin assets): un casquete arriba y una pieza atrás.
function Personajes.agregarPelo(modelo: Model, color: Color3, estilo: string)
	local cabeza = modelo:FindFirstChild("Head")
	if not cabeza then
		return
	end
	local alto = cabeza.Size.Y
	local ancho = cabeza.Size.X
	local function pieza(nombre, tamano, desplazamiento)
		local p = Instance.new("Part")
		p.Name = nombre
		p.Size = tamano
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = cabeza.CFrame * desplazamiento
		p.Parent = modelo
		local soldadura = Instance.new("WeldConstraint")
		soldadura.Part0 = cabeza
		soldadura.Part1 = p
		soldadura.Parent = p
	end
	if estilo == "gorra" then
		pieza("GorraCopa", Vector3.new(ancho * 1.08, alto * 0.45, ancho * 1.08), CFrame.new(0, alto * 0.5, 0))
		pieza("GorraVisera", Vector3.new(ancho * 1.0, alto * 0.08, ancho * 0.55), CFrame.new(0, alto * 0.3, -ancho * 0.7))
		return
	end
	pieza("PeloArriba", Vector3.new(ancho * 1.08, alto * 0.32, ancho * 1.08), CFrame.new(0, alto * 0.52, 0))
	if estilo == "largo" then
		pieza("PeloAtras", Vector3.new(ancho * 1.08, alto * 1.35, ancho * 0.3), CFrame.new(0, -alto * 0.1, ancho * 0.5))
		pieza("PeloIzq", Vector3.new(ancho * 0.12, alto * 0.9, ancho * 0.6), CFrame.new(-ancho * 0.52, 0, ancho * 0.15))
		pieza("PeloDer", Vector3.new(ancho * 0.12, alto * 0.9, ancho * 0.6), CFrame.new(ancho * 0.52, 0, ancho * 0.15))
	else
		pieza("PeloAtras", Vector3.new(ancho * 1.08, alto * 0.7, ancho * 0.3), CFrame.new(0, alto * 0.15, ancho * 0.5))
	end
end

function Personajes.crear(opciones): Model?
	local descripcion = Instance.new("HumanoidDescription")
	descripcion.HeadColor = opciones.piel
	descripcion.TorsoColor = opciones.ropa
	descripcion.LeftArmColor = opciones.ropa
	descripcion.RightArmColor = opciones.ropa
	descripcion.LeftLegColor = opciones.pantalon
	descripcion.RightLegColor = opciones.pantalon
	descripcion.Face = opciones.sinCara and 0 or CARA_SONRISA
	local escala = opciones.escala or 1
	descripcion.HeightScale = escala
	descripcion.WidthScale = 1
	descripcion.DepthScale = 1
	descripcion.HeadScale = 1

	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modelo then
		warn("[Personajes] No se pudo crear el cuerpo: " .. tostring(modelo))
		return nil
	end
	if opciones.sinCara then
		local cabeza = modelo:FindFirstChild("Head")
		local cara = cabeza and cabeza:FindFirstChildOfClass("Decal")
		if cara then
			cara:Destroy()
		end
	end
	if opciones.pelo then
		Personajes.agregarPelo(modelo, opciones.pelo, opciones.estilo or "corto")
	end
	return modelo
end

--- Reproduce las animaciones de quieto y caminar. Funciona con Humanoid o con un AnimationController.
function Personajes.animar(modelo: Model)
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	local portador = humanoide or modelo:FindFirstChildOfClass("AnimationController")
	if not portador then
		portador = Instance.new("AnimationController")
		portador.Parent = modelo
	end
	local animador = portador:FindFirstChildOfClass("Animator")
	if not animador then
		animador = Instance.new("Animator")
		animador.Parent = portador
	end

	local function cargar(id: string, prioridad: Enum.AnimationPriority)
		local animacion = Instance.new("Animation")
		animacion.AnimationId = id
		local ok, pista = pcall(function()
			return animador:LoadAnimation(animacion)
		end)
		if not ok then
			return nil
		end
		pista.Looped = true
		pista.Priority = prioridad
		return pista
	end

	local quieto = cargar(ANIM_QUIETO, Enum.AnimationPriority.Idle)
	local caminar = cargar(ANIM_CAMINAR, Enum.AnimationPriority.Movement)
	if quieto then
		quieto:Play()
	end

	local controlador = {}
	local caminando = false
	function controlador.caminar(valor: boolean)
		if valor == caminando or not caminar then
			return
		end
		caminando = valor
		if valor then
			caminar:Play(0.15)
		else
			caminar:Stop(0.2)
		end
	end
	function controlador.detener()
		controlador.caminar(false)
		if quieto then
			quieto:Stop()
		end
	end
	function controlador.pistas()
		return quieto, caminar
	end

	if humanoide then
		humanoide.Running:Connect(function(velocidad)
			controlador.caminar(velocidad > 0.5)
		end)
	end
	return controlador
end

--- Deja el cuerpo sin Humanoid, sin colisión y con la raíz anclada (se mueve con PivotTo y las animaciones siguen andando).
function Personajes.convertirEnTitere(modelo: Model, color: Color3?)
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	if humanoide and raiz then
		-- Altura de la raíz sobre el piso: así apoyaría los pies un Humanoid.
		modelo:SetAttribute("AlturaRaiz", humanoide.HipHeight + raiz.Size.Y / 2)
	end
	if humanoide then
		humanoide:Destroy()
	end
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
		end
	end
	if raiz then
		raiz.Anchored = true
		modelo.PrimaryPart = raiz
	end
	if color then
		pintar(modelo, color)
	end
end

return Personajes
