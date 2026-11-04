--!nonstrict
--[[
	Personajes: arma los cuerpos (R15) de los clientes, el Socio y las siluetas, con pelo y animaciones.
	Lo usan el servidor (clientes y Socio) y el cliente (fantasmas de la cinta, anomalías).

	  Personajes.crear({ piel, ropa, pantalon, escala?, sinCara?, pelo?, estilo? }) -> Model (R15 con Humanoid)
	  Personajes.agregarPelo(modelo, color, estilo)       -- estilo: "corto" | "largo" | "gorra"
	  Personajes.animar(modelo) -> { caminar = function(bool), detener = function() }
	  Personajes.convertirEnTitere(modelo, color?)         -- sin Humanoid: solo la raíz anclada, para mover a mano
]]

local InsertService = game:GetService("InsertService")
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
			if d:IsA("MeshPart") then
				d.TextureID = "" -- la cabeza trae la cara pintada en la textura: sin esto el Color no la oscurece
			end
		elseif d:IsA("Decal") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("SurfaceAppearance") or d:IsA("FaceControls") then
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

--- Dos rendijas claras y brillantes en lugar de cara: lo único que se ve del Socio en la oscuridad.
function Personajes.agregarOjos(modelo: Model, color: Color3)
	local cabeza = modelo:FindFirstChild("Head")
	if not cabeza then
		return
	end
	for _, lado in { -1, 1 } do
		local ojo = Instance.new("Part")
		ojo.Name = "Ojo"
		ojo.Size = Vector3.new(cabeza.Size.X * 0.2, cabeza.Size.Y * 0.06, 0.06)
		ojo.Color = color
		ojo.Material = Enum.Material.Neon
		ojo.CanCollide = false
		ojo.CanTouch = false
		ojo.CanQuery = false
		ojo.Massless = true
		ojo.CFrame = cabeza.CFrame * CFrame.new(lado * cabeza.Size.X * 0.2, cabeza.Size.Y * 0.08, -cabeza.Size.Z / 2 - 0.01)
		ojo.Parent = modelo
		local soldadura = Instance.new("WeldConstraint")
		soldadura.Part0 = cabeza
		soldadura.Part1 = ojo
		soldadura.Parent = ojo
	end
end

local plantillaSocio -- MeshPart ya cargado (false si falló): se clona para cada Socio

-- Alto en metros del Socio con huesos tal como sale de blender/socio.py (las posiciones de los ojos están en esas unidades).
Personajes.ALTURA_ESQUELETO = 3.245

--- Socio con esqueleto (calavera, capa y huesos para moverse a tirones): clon del molde ReplicatedStorage.SocioModelo,
--- importado de assets/socio/socio.fbx con "Import 3D". Pivote en los pies, mira hacia -Z, queda escalado a cfg.AlturaMalla.
--- nil si el molde no está (quien llama usa el cuerpo de una sola malla o el humano de respaldo).
local function crearSocioConHuesos(cfg): Model?
	local molde = game:GetService("ReplicatedStorage"):FindFirstChild("SocioModelo")
	if not molde then
		return nil
	end
	local modelo = molde:Clone()
	local parte = modelo:FindFirstChild("Socio_Malla")
	if not (parte and parte:IsA("MeshPart")) then
		modelo:Destroy()
		return nil
	end
	modelo.PrimaryPart = parte
	modelo:ScaleTo(modelo:GetScale() * cfg.AlturaMalla / parte.Size.Y)
	parte.Name = "Cuerpo"
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	parte.Massless = true
	-- El importador deja el pivote girado 90° respecto de la malla: se fija uno derecho, en el centro de la base (los pies), mirando a -Z.
	parte.PivotOffset = CFrame.new(0, -parte.Size.Y / 2, 0)
	local pivote = modelo:GetPivot()
	local s = cfg.AlturaMalla / Personajes.ALTURA_ESQUELETO
	-- Ojos blancos dentro de las órbitas (lo único que se ve en la oscuridad).
	for _, lado in { -1, 1 } do
		local ojo = Instance.new("Part")
		ojo.Name = "Ojo"
		ojo.Size = Vector3.new(0.19, 0.07, 0.04)
		ojo.Color = cfg.ColorOjos
		ojo.Material = Enum.Material.Neon
		ojo.Anchored = true
		ojo.CanCollide = false
		ojo.CanTouch = false
		ojo.CanQuery = false
		ojo.CFrame = pivote * CFrame.new(lado * 0.077 * s, 2.88 * s, -0.13 * s)
		ojo.Parent = modelo
	end
	local aura = Instance.new("PointLight")
	aura.Range = 11
	aura.Brightness = 0.5
	aura.Color = Color3.fromRGB(170, 190, 215)
	aura.Shadows = false
	aura.Parent = parte
	modelo:SetAttribute("ConHuesos", true)
	return modelo
end

--- Cuerpo del Socio: una criatura flaca y encorvada generada con IA (Config.Socio.MeshId / TextureId).
--- Devuelve un Model con una sola MeshPart anclada, con el pivote en los pies (el frente de la malla es -Z, como un personaje).
--- nil si no hay malla configurada o no se pudo cargar (quien llama usa el cuerpo humano de respaldo).
function Personajes.crearSocioMalla(cfg): Model?
	local conHuesos = crearSocioConHuesos(cfg)
	if conHuesos then
		return conHuesos
	end
	if cfg.MeshId == "" or plantillaSocio == false then
		return nil
	end
	if not plantillaSocio then
		local ok, parte = pcall(function()
			return InsertService:CreateMeshPartAsync(cfg.MeshId, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
		end)
		if not ok or not parte then
			warn("[Personajes] No se pudo cargar la malla del Socio, se usa el cuerpo humano: " .. tostring(parte))
			plantillaSocio = false
			return nil
		end
		parte.Name = "Cuerpo"
		parte.TextureID = cfg.TextureId
		parte.Color = cfg.Tinte
		local nativo = parte.Size
		parte.Size = nativo * (cfg.AlturaMalla / nativo.Y)
		parte.Anchored = true
		parte.CanCollide = false
		parte.CanTouch = false
		parte.Massless = true
		plantillaSocio = parte
	end
	if not plantillaSocio then
		return nil -- otra llamada falló mientras esperábamos
	end
	local parte = plantillaSocio:Clone()
	-- Pivote en los pies: PivotTo la apoya en el piso. La malla ya mira hacia -Z, como un personaje.
	parte.PivotOffset = CFrame.new(0, -parte.Size.Y / 2, 0)
	local modelo = Instance.new("Model")
	parte.Parent = modelo
	modelo.PrimaryPart = parte
	-- Ojos blancos en la abertura de la capucha (lo único que se ve en la oscuridad) y un resplandor frío muy tenue.
	for _, lado in { -1, 1 } do
		local ojo = Instance.new("Part")
		ojo.Name = "Ojo"
		ojo.Size = Vector3.new(0.2, 0.1, 0.1)
		ojo.Color = cfg.ColorOjos
		ojo.Material = Enum.Material.Neon
		ojo.Anchored = true
		ojo.CanCollide = false
		ojo.CanTouch = false
		ojo.CanQuery = false
		ojo.CFrame = parte.CFrame * CFrame.new(lado * 0.22, parte.Size.Y * 0.378, -parte.Size.Z * 0.49)
		ojo.Parent = modelo
	end
	local aura = Instance.new("PointLight")
	aura.Range = 11
	aura.Brightness = 0.5
	aura.Color = Color3.fromRGB(170, 190, 215)
	aura.Shadows = false
	aura.Parent = parte
	return modelo
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
	descripcion.WidthScale = opciones.ancho or 1
	descripcion.DepthScale = opciones.ancho or 1
	descripcion.HeadScale = opciones.cabeza or 1
	descripcion.ProportionScale = opciones.proporcion or 0

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
	if opciones.ojos then
		Personajes.agregarOjos(modelo, opciones.ojos)
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
	local factor = 1 -- velocidad de las animaciones (1 normal, 0 congelado)
	function controlador.caminar(valor: boolean)
		if valor == caminando or not caminar then
			return
		end
		caminando = valor
		if valor then
			caminar:Play(0.15)
			if factor ~= 1 then
				caminar:AdjustSpeed(factor)
			end
		else
			caminar:Stop(0.2)
		end
	end
	--- Cambia la velocidad de las animaciones: 1 normal, 0.2 en cámara lenta, 0 congela la pose en el cuadro actual.
	function controlador.ralentizar(valor: number)
		if valor == factor then
			return
		end
		factor = valor
		for _, pista in { quieto, caminar } do
			if pista and pista.IsPlaying then
				pista:AdjustSpeed(valor)
			end
		end
	end
	function controlador.congelar(valor: boolean)
		controlador.ralentizar(valor and 0 or 1)
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
