--!nonstrict
--[[
	LuzFluorescente (cliente): parpadeo de los tubos del local (partes con el tag "Tubo").
	Los que además tienen el tag "TuboDefectuoso" parpadean mucho más seguido.
	Es local a cada jugador, así que cada uno ve un parpadeo distinto.

	El servidor manda cambios del mundo por el remote WorldEvent:
	  CORTE_LUZ  se corta (o vuelve) la luz: se apagan los tubos, el ambiente queda casi negro y se habilita la linterna
	  FLICKER    parpadeo fuerte (consecuencia de romper una regla de Darío)

	API:
	  LuzFluorescente.cortarTodo(bool)
	  LuzFluorescente.parpadeoFuerte()
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Linterna = require(script.Parent.Linterna)

local LuzFluorescente = {}

local cfg = Config.Luces
local rng = Random.new()
local tubos = {} -- tubo -> { perfil, encendido, siguiente, pendientes, colorEncendido, materialEncendido }
local cortadoBase = false -- el corte de luz "de verdad"
local cortado = false -- lo que se está mostrando ahora (el parpadeo fuerte lo altera un instante)
local ambienteNormal

local function aplicar(tubo, datos, encendido)
	datos.encendido = encendido
	local visible = encendido and not cortado
	tubo.Material = visible and datos.materialEncendido or Enum.Material.SmoothPlastic
	tubo.Color = visible and datos.colorEncendido or cfg.ColorApagado
	for _, hijo in tubo:GetChildren() do
		if hijo:IsA("Light") then
			hijo.Enabled = visible
		end
	end
end

local function proximoEvento(perfil)
	return os.clock() + rng:NextNumber(perfil.IntervaloMin, perfil.IntervaloMax)
end

local function registrar(tubo)
	if not tubo:IsA("BasePart") or tubos[tubo] then
		return
	end
	local perfil = CollectionService:HasTag(tubo, "TuboDefectuoso") and cfg.Defectuoso or cfg.Normal
	tubos[tubo] = {
		perfil = perfil,
		encendido = true,
		siguiente = proximoEvento(perfil),
		pendientes = 0,
		colorEncendido = tubo.Color,
		materialEncendido = tubo.Material,
	}
	aplicar(tubo, tubos[tubo], true) -- si ya está cortada la luz, el tubo nuevo nace apagado
end

local function mostrarCorte(valor: boolean)
	cortado = valor
	for tubo, datos in tubos do
		aplicar(tubo, datos, datos.encendido)
	end
end

function LuzFluorescente.cortarTodo(valor: boolean)
	cortadoBase = valor
	mostrarCorte(valor)
	Lighting.Ambient = valor and Color3.fromRGB(7, 8, 8) or ambienteNormal.Ambient
	Lighting.OutdoorAmbient = valor and Color3.fromRGB(5, 6, 6) or ambienteNormal.OutdoorAmbient
	Linterna.habilitar(valor)
end

function LuzFluorescente.parpadeoFuerte()
	task.spawn(function()
		for i = 1, 6 do
			mostrarCorte(i % 2 == 1 or cortadoBase)
			task.wait(0.09)
		end
		mostrarCorte(cortadoBase)
	end)
end

function LuzFluorescente.init()
	ambienteNormal = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }

	for _, tubo in CollectionService:GetTagged("Tubo") do
		registrar(tubo)
	end
	CollectionService:GetInstanceAddedSignal("Tubo"):Connect(registrar)
	CollectionService:GetInstanceRemovedSignal("Tubo"):Connect(function(tubo)
		tubos[tubo] = nil
	end)

	Net.obtener("WorldEvent").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" then
			return
		end
		if datos.id == "CORTE_LUZ" then
			LuzFluorescente.cortarTodo(datos.valor == true)
		elseif datos.id == "FLICKER" then
			LuzFluorescente.parpadeoFuerte()
		end
	end)

	RunService.Heartbeat:Connect(function()
		local ahora = os.clock()
		for tubo, datos in tubos do
			if ahora < datos.siguiente then
				continue
			end
			if datos.pendientes == 0 then
				-- Una ráfaga son varios apagado/encendido seguidos (2 cambios por parpadeo).
				datos.pendientes = rng:NextInteger(datos.perfil.RafagaMin, datos.perfil.RafagaMax) * 2
			end
			aplicar(tubo, datos, not datos.encendido)
			datos.pendientes -= 1
			if datos.pendientes <= 0 then
				aplicar(tubo, datos, true)
				datos.siguiente = proximoEvento(datos.perfil)
			else
				datos.siguiente = ahora + rng:NextNumber(cfg.ParpadeoMin, cfg.ParpadeoMax)
			end
		end
	end)
end

return LuzFluorescente
