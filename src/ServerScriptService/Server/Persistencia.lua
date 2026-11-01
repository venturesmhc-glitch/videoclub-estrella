--!nonstrict
--[[
	Persistencia (servidor) — Fase 7.
	DataStore por jugador: noche alcanzada, finales desbloqueados y cuántos empleados "menos" hay
	(el final REBOBINAR deja un nombre menos en la ficha).

	El servidor arranca en la noche guardada del primer jugador que entra. Si el DataStore no está disponible
	(por ejemplo en Studio sin "Allow Studio Access to API Services") se avisa una vez y se sigue con datos en memoria.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)

local Persistencia = {}

local NOMBRE_ALMACEN = "VideoclubEstrella_v1"
local almacen
local perfiles = {} -- Player -> perfil
local cargados = {} -- Player -> true cuando terminó de cargar (con datos o con los de por defecto)
local avisado = false

local function perfilNuevo()
	return { nocheAlcanzada = 1, finales = {}, empleadosMenos = 0 }
end

local function avisarSinAlmacen(motivo)
	if not avisado then
		avisado = true
		warn("[Persistencia] DataStore no disponible, se usan datos en memoria: " .. tostring(motivo))
	end
end

local function clave(jugador: Player): string
	return "J_" .. jugador.UserId
end

local function cargar(jugador: Player)
	local perfil = perfilNuevo()
	if almacen then
		for intento = 1, 3 do
			local ok, datos = pcall(function()
				return almacen:GetAsync(clave(jugador))
			end)
			if ok then
				if typeof(datos) == "table" then
					perfil.nocheAlcanzada = math.clamp(tonumber(datos.nocheAlcanzada) or 1, 1, Config.Noche.NochesImplementadas)
					perfil.finales = typeof(datos.finales) == "table" and datos.finales or {}
					perfil.empleadosMenos = tonumber(datos.empleadosMenos) or 0
				end
				break
			end
			avisarSinAlmacen(datos)
			task.wait(1)
		end
	end
	perfiles[jugador] = perfil
	cargados[jugador] = true
	Net.obtener("ProfileLoaded"):FireClient(jugador, {
		nocheAlcanzada = perfil.nocheAlcanzada,
		finales = perfil.finales,
		empleadosMenos = perfil.empleadosMenos,
	})
end

local function guardar(jugador: Player)
	local perfil = perfiles[jugador]
	if not perfil or not almacen then
		return
	end
	local ok, err = pcall(function()
		almacen:SetAsync(clave(jugador), perfil)
	end)
	if not ok then
		avisarSinAlmacen(err)
	end
end

local function enviarPerfil(jugador: Player)
	local perfil = perfiles[jugador]
	if perfil then
		Net.obtener("ProfileLoaded"):FireClient(jugador, {
			nocheAlcanzada = perfil.nocheAlcanzada,
			finales = perfil.finales,
			empleadosMenos = perfil.empleadosMenos,
		})
	end
end

--- Noche guardada del primer jugador (espera un poco a que termine de cargar).
function Persistencia.nocheInicial(): number?
	local inicio = os.clock()
	while os.clock() - inicio < 6 do
		local primero = Players:GetPlayers()[1]
		if primero and cargados[primero] then
			return perfiles[primero].nocheAlcanzada
		end
		task.wait(0.2)
	end
	return nil
end

--- Un final desbloquea ese final para todos los presentes y reinicia la partida desde la noche 1.
function Persistencia.registrarFinal(id: string)
	for _, jugador in Players:GetPlayers() do
		local perfil = perfiles[jugador]
		if perfil then
			perfil.finales[id] = true
			perfil.nocheAlcanzada = 1
			if id == "REBOBINAR" then
				perfil.empleadosMenos += 1
			end
			enviarPerfil(jugador)
			task.spawn(guardar, jugador)
		end
	end
end

function Persistencia.estadoTexto(): string
	local partes = {}
	for jugador, perfil in perfiles do
		local finales = {}
		for id in perfil.finales do
			table.insert(finales, id)
		end
		table.insert(partes, string.format("%s: noche %d, empleadosMenos %d, finales [%s]",
			jugador.Name, perfil.nocheAlcanzada, perfil.empleadosMenos, table.concat(finales, ",")))
	end
	return #partes > 0 and table.concat(partes, "\n") or "sin perfiles"
end

function Persistencia.init()
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore(NOMBRE_ALMACEN)
	end)
	if ok then
		almacen = resultado
	else
		avisarSinAlmacen(resultado)
	end

	NightManager.registrarNocheInicial(Persistencia.nocheInicial)

	Players.PlayerAdded:Connect(function(jugador)
		task.spawn(cargar, jugador)
	end)
	for _, jugador in Players:GetPlayers() do
		task.spawn(cargar, jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		guardar(jugador)
		perfiles[jugador], cargados[jugador] = nil, nil
	end)

	-- Al pasar una noche (sin fracasar ni llegar a un final) se guarda la siguiente.
	NightManager.suscribir("NOCHE_TERMINA", function(datos)
		if datos.fracaso or datos.final then
			return
		end
		local siguiente = math.min(datos.noche + 1, Config.Noche.NochesImplementadas)
		for _, jugador in Players:GetPlayers() do
			local perfil = perfiles[jugador]
			if perfil and siguiente > perfil.nocheAlcanzada then
				perfil.nocheAlcanzada = siguiente
				task.spawn(guardar, jugador)
			end
		end
	end)

	game:BindToClose(function()
		for _, jugador in Players:GetPlayers() do
			guardar(jugador)
		end
	end)
end

return Persistencia
