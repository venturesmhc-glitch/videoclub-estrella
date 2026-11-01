--!nonstrict
--[[
	ChoreSystem (servidor): tareas extra del turno, pensadas para repartirse entre varios jugadores.
	  - BASURA: aparece una bolsa en una zona del local; hay que llevarla al contenedor del patio.
	    Se lleva en las manos: mientras tanto no se puede tomar un casete.
	  - DERRAME: aparece una mancha en el piso; se limpia manteniendo E.
	Los eventos de NightData (BASURA / DERRAME, con una lista de zonas) crean las tareas;
	las zonas son los atributos "Zona" de los puntos con tag "BasuraSpot" y "DerrameSpot".
	Cada tarea resuelta suma al objetivo "basura" o "limpiar" de la ficha (TaskSystem).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local Prompts = require(script.Parent.Prompts)
local TapeItem = require(script.Parent.TapeItem)
local TaskSystem = require(script.Parent.TaskSystem)

local ChoreSystem = {}

local cfg = Config.Tareas
local rng = Random.new()
local NOMBRES_ZONA = {
	LOCAL = "el local",
	MOSTRADOR = "detrás del mostrador",
	BANO = "el baño",
	COCINA = "la cocina",
	DEPOSITO = "el depósito",
	PATIO = "el patio",
}

local bolsas = {} -- lista de { parte, zona, base = CFrame, dueno = Player? }
local manchas = {} -- lista de { parte, zona }
local cargando = {} -- Player -> bolsa
local carpeta

local function carpetaMundo()
	if not carpeta or not carpeta.Parent then
		carpeta = workspace:FindFirstChild("TareasExtra")
		if not carpeta then
			carpeta = Instance.new("Folder")
			carpeta.Name = "TareasExtra"
			carpeta.Parent = workspace
		end
	end
	return carpeta
end

local function puntoDeZona(etiqueta: string, zona: string): BasePart?
	for _, p in CollectionService:GetTagged(etiqueta) do
		if p:IsA("BasePart") and p:GetAttribute("Zona") == zona then
			return p
		end
	end
	return nil
end

local function nombreZona(zona: string): string
	return NOMBRES_ZONA[zona] or zona
end

-- ===== Basura =====

local function soltarBolsa(bolsa)
	local jugador = bolsa.dueno
	if jugador then
		cargando[jugador] = nil
	end
	bolsa.dueno = nil
	local parte = bolsa.parte
	if not parte or not parte.Parent then
		return
	end
	local agarre = parte:FindFirstChild("AgarreMano")
	if agarre then
		agarre:Destroy()
	end
	parte.Anchored = true
	parte.Massless = false
	parte.CFrame = bolsa.base
	parte.Parent = carpetaMundo()
	bolsa.prompt.Enabled = true
end

local function levantar(jugador: Player, bolsa)
	if bolsa.dueno or not bolsa.parte.Parent then
		return
	end
	if cargando[jugador] then
		Net.aviso(jugador, "Ya llevás una bolsa.")
		return
	end
	if TapeItem.enMano(jugador) then
		Net.aviso(jugador, "Tenés un casete en la mano. Dejalo primero.")
		return
	end
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	bolsa.dueno = jugador
	cargando[jugador] = bolsa
	bolsa.prompt.Enabled = false
	local parte = bolsa.parte
	parte.Anchored = false
	parte.Massless = true
	local weld = Instance.new("Weld")
	weld.Name = "AgarreMano"
	weld.Part0 = raiz
	weld.Part1 = parte
	weld.C0 = cfg.BolsaEnMano
	weld.Parent = parte
	-- La bolsa se queda donde estaba (no dentro del personaje): en primera persona la cámara
	-- oculta todo lo que cuelga de él y no se vería en las manos.
	Net.aviso(jugador, "Llevá la bolsa al contenedor del patio.")
	TaskSystem.sincronizar()
end

local function crearBolsa(zona: string)
	local punto = puntoDeZona("BasuraSpot", zona)
	if not punto then
		warn("[ChoreSystem] No hay punto de basura en la zona " .. zona)
		return
	end
	local parte = Instance.new("Part")
	parte.Name = "BolsaBasura"
	parte.Shape = Enum.PartType.Ball
	parte.Size = Vector3.new(1.8, 1.6, 1.8)
	parte.Color = Color3.fromRGB(16, 16, 18)
	parte.Material = Enum.Material.Plastic
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = true
	local base = CFrame.new(punto.Position.X, 0.8, punto.Position.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	parte.CFrame = base
	-- Nudo de la bolsa.
	local nudo = Instance.new("Part")
	nudo.Name = "Nudo"
	nudo.Size = Vector3.new(0.5, 0.5, 0.5)
	nudo.Color = parte.Color
	nudo.Material = Enum.Material.Plastic
	nudo.CanCollide = false
	nudo.CanQuery = false
	nudo.Massless = true
	nudo.CFrame = base * CFrame.new(0, 0.95, 0)
	nudo.Parent = parte
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0, soldadura.Part1 = parte, nudo
	soldadura.Parent = nudo
	-- Un contorno suave para encontrarla en la oscuridad.
	local contorno = Instance.new("Highlight")
	contorno.FillTransparency = 1
	contorno.OutlineColor = Color3.fromRGB(235, 225, 190)
	contorno.OutlineTransparency = 0.55
	contorno.DepthMode = Enum.HighlightDepthMode.Occluded
	contorno.Parent = parte

	local bolsa = { parte = parte, zona = zona, base = base }
	bolsa.activar = function(jugador)
		levantar(jugador, bolsa)
	end
	bolsa.prompt = Prompts.crear(parte, {
		clave = "bolsa",
		accion = "Levantar bolsa",
		objeto = "Bolsa de basura",
		distancia = 6,
		alActivar = bolsa.activar,
	})
	parte.Parent = carpetaMundo()
	table.insert(bolsas, bolsa)
	Net.avisoATodos("Hay una bolsa de basura en " .. nombreZona(zona) .. ".")
end

local function tirarEnContenedor(jugador: Player)
	local bolsa = cargando[jugador]
	if not bolsa then
		Net.aviso(jugador, "No llevás ninguna bolsa.")
		return
	end
	cargando[jugador] = nil
	bolsa.dueno = nil
	local lugar = table.find(bolsas, bolsa)
	if lugar then
		table.remove(bolsas, lugar)
	end
	bolsa.parte:Destroy()
	TaskSystem.registrar("basura")
	TaskSystem.sincronizar()
	Net.aviso(jugador, "Bolsa tirada.")
end

-- ===== Manchas =====

local function crearMancha(zona: string)
	local punto = puntoDeZona("DerrameSpot", zona)
	if not punto then
		warn("[ChoreSystem] No hay punto de mancha en la zona " .. zona)
		return
	end
	local diametro = rng:NextNumber(2.4, 3.4)
	local parte = Instance.new("Part")
	parte.Name = "Mancha"
	parte.Shape = Enum.PartType.Cylinder
	parte.Size = Vector3.new(0.08, diametro, diametro)
	parte.CFrame = CFrame.new(punto.Position.X, 0.06, punto.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	parte.Color = Color3.fromRGB(26, 20, 18)
	parte.Material = Enum.Material.SmoothPlastic
	parte.Reflectance = 0.12
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	local contorno = Instance.new("Highlight")
	contorno.FillTransparency = 1
	contorno.OutlineColor = Color3.fromRGB(235, 225, 190)
	contorno.OutlineTransparency = 0.6
	contorno.DepthMode = Enum.HighlightDepthMode.Occluded
	contorno.Parent = parte

	local mancha = { parte = parte, zona = zona }
	mancha.activar = function(jugador)
		local lugar = table.find(manchas, mancha)
		if not lugar then
			return
		end
		table.remove(manchas, lugar)
		parte:Destroy()
		TaskSystem.registrar("limpiar")
		Net.aviso(jugador, "Limpiado.")
	end
	Prompts.crear(parte, {
		clave = "mancha",
		accion = "Limpiar",
		objeto = "Mancha",
		hold = cfg.LimpiezaSeg,
		distancia = 6,
		alActivar = mancha.activar,
	})
	parte.Parent = carpetaMundo()
	table.insert(manchas, mancha)
	Net.avisoATodos("Hay una mancha para limpiar en " .. nombreZona(zona) .. ".")
end

-- ===== API =====

function ChoreSystem.crearBolsa(zona: string)
	crearBolsa(zona)
end

function ChoreSystem.crearMancha(zona: string)
	crearMancha(zona)
end

--- Para pruebas: hace lo mismo que el prompt ("levantar" | "tirar" | "limpiar") sobre la primera tarea pendiente.
function ChoreSystem.probar(accion: string, jugador: Player)
	if accion == "levantar" then
		for _, b in bolsas do
			if not b.dueno then
				b.activar(jugador)
				return
			end
		end
	elseif accion == "tirar" then
		tirarEnContenedor(jugador)
	elseif accion == "limpiar" and manchas[1] then
		manchas[1].activar(jugador)
	end
end

function ChoreSystem.llevaBolsa(jugador: Player): boolean
	return cargando[jugador] ~= nil
end

function ChoreSystem.limpiarTodo()
	for _, bolsa in bolsas do
		if bolsa.parte then
			bolsa.parte:Destroy()
		end
	end
	for _, mancha in manchas do
		if mancha.parte then
			mancha.parte:Destroy()
		end
	end
	table.clear(bolsas)
	table.clear(manchas)
	table.clear(cargando)
end

function ChoreSystem.estadoTexto(): string
	local zonas = {}
	for _, b in bolsas do
		table.insert(zonas, "bolsa:" .. b.zona .. (b.dueno and "(llevada)" or ""))
	end
	for _, m in manchas do
		table.insert(zonas, "mancha:" .. m.zona)
	end
	return #zonas > 0 and table.concat(zonas, ", ") or "nada pendiente"
end

local function alSalirElPersonaje(jugador: Player)
	local bolsa = cargando[jugador]
	if bolsa then
		soltarBolsa(bolsa) -- la bolsa vuelve a su lugar
	end
end

function ChoreSystem.init()
	NightManager.suscribir("NOCHE_INICIA", ChoreSystem.limpiarTodo)
	NightManager.suscribir("BASURA", function(datos)
		for _, zona in datos.zonas or {} do
			crearBolsa(zona)
		end
	end)
	NightManager.suscribir("DERRAME", function(datos)
		for _, zona in datos.zonas or {} do
			crearMancha(zona)
		end
	end)

	-- Con una bolsa en las manos no se pueden tomar casetes.
	TapeItem.restringir(function(jugador)
		if cargando[jugador] then
			return "Tenés las manos ocupadas con la bolsa."
		end
		return nil
	end)

	for _, contenedor in CollectionService:GetTagged("Contenedor") do
		if contenedor:IsA("BasePart") then
			Prompts.crear(contenedor, {
				clave = "contenedor",
				accion = "Tirar bolsa",
				objeto = "Contenedor",
				distancia = 9,
				alActivar = tirarEnContenedor,
			})
		end
	end

	local function vigilar(jugador: Player)
		jugador.CharacterRemoving:Connect(function()
			alSalirElPersonaje(jugador)
		end)
	end
	Players.PlayerAdded:Connect(vigilar)
	for _, jugador in Players:GetPlayers() do
		vigilar(jugador)
	end
	Players.PlayerRemoving:Connect(alSalirElPersonaje)
end

return ChoreSystem
