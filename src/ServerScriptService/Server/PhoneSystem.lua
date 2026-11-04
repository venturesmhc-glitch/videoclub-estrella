--!nonstrict
--[[
	PhoneSystem (servidor) — Fase 6.
	Teléfono del mostrador (con el contestador de Don Ernesto) y teléfono interno del depósito.
	Un evento TELEFONO de NightData hace sonar una línea; el prompt "Atender teléfono" solo existe mientras suena.
	  mensaje = n  -> contestador de Don Ernesto (Catalogo.Telefono.Mensajes)
	  voz = "cinta"     -> audio de la cinta (estática)
	  voz = "companero" -> la voz de un compañero diciendo algo que no dijo (con un solo jugador, la de Darío)
	El texto se muestra como subtítulos (remote PhoneMessage).
	Atender el interno pasadas las 2:00 rompe la regla de Darío R_INTERNO (evento INTERNO_ATENDIDO).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local Prompts = require(script.Parent.Prompts)

local PhoneSystem = {}

local lineas = {
	mostrador = { etiqueta = "Telefono", nombre = "teléfono del mostrador" },
	interno = { etiqueta = "TelefonoInterno", nombre = "teléfono del depósito" },
}
local sonando = {} -- linea -> { datos, token }
local prompts = {} -- linea -> ProximityPrompt

local function mensajePara(datos, jugador: Player)
	if datos.voz == "cinta" then
		return Catalogo.Telefono.VozCinta
	elseif datos.voz == "companero" then
		local otro = "Darío"
		for _, j in Players:GetPlayers() do
			if j ~= jugador then
				otro = j.DisplayName
				break
			end
		end
		return { speaker = otro, lineas = Catalogo.Telefono.VozCompanero.lineas }
	end
	return Catalogo.Telefono.Mensajes[datos.mensaje or 1] or Catalogo.Telefono.Mensajes[1]
end

local function dejarDeSonar(linea: string)
	sonando[linea] = nil
	if prompts[linea] then
		prompts[linea].Enabled = false
	end
	Net.obtener("WorldEvent"):FireAllClients({ id = "TELEFONO", valor = { linea = linea, suena = false } })
end

local function atender(linea: string, jugador: Player)
	local llamada = sonando[linea]
	if not llamada then
		Net.aviso(jugador, "No está sonando.")
		return
	end
	local mensaje = mensajePara(llamada.datos, jugador)
	dejarDeSonar(linea)
	-- Lo que explica el contestador de Don Ernesto (cómo se trabaja, las anomalías...) lo leen todos los del equipo: si lo
	-- viera solo quien atendió, los demás no sabrían qué hacer. Las voces raras (la cinta, el "compañero") son solo de
	-- quien atendió.
	local paquete = { speaker = mensaje.speaker, lineas = mensaje.lineas }
	if llamada.datos.voz then
		Net.obtener("PhoneMessage"):FireClient(jugador, paquete)
	else
		Net.obtener("PhoneMessage"):FireAllClients(paquete)
	end
	if linea == "interno" then
		NightManager.emitir("INTERNO_ATENDIDO", { jugador = jugador })
	end
end

function PhoneSystem.sonar(datos)
	local linea = datos.linea or "mostrador"
	if not lineas[linea] or sonando[linea] then
		return
	end
	local token = {}
	sonando[linea] = { datos = datos, token = token }
	if prompts[linea] then
		prompts[linea].Enabled = true
	end
	Net.obtener("WorldEvent"):FireAllClients({ id = "TELEFONO", valor = { linea = linea, suena = true } })
	Net.avisoATodos("Suena el " .. lineas[linea].nombre .. ". Acercate y apretá E para atender.")
	-- La llamada de bienvenida (espera) suena hasta que alguien la atiende.
	if not datos.espera then
		task.delay(Config.Telefono.SonarSeg, function()
			if sonando[linea] and sonando[linea].token == token then
				dejarDeSonar(linea)
			end
		end)
	end
end

function PhoneSystem.atender(linea: string, jugador: Player)
	atender(linea, jugador)
end

function PhoneSystem.estadoTexto(): string
	local activos = {}
	for linea in sonando do
		table.insert(activos, linea)
	end
	return "sonando: " .. (#activos > 0 and table.concat(activos, ",") or "ninguno")
end

function PhoneSystem.init()
	NightManager.suscribir("TELEFONO", PhoneSystem.sonar)
	NightManager.suscribir("NOCHE_INICIA", function()
		for linea in table.clone(sonando) do
			dejarDeSonar(linea)
		end
	end)

	for linea, def in lineas do
		for _, parte in CollectionService:GetTagged(def.etiqueta) do
			if parte:IsA("BasePart") then
				local prompt = Prompts.crear(parte, {
					clave = "telefono" .. linea,
					accion = "Atender teléfono",
					objeto = def.nombre,
					alActivar = function(jugador)
						atender(linea, jugador)
					end,
				})
				prompt.Enabled = false
				prompts[linea] = prompt
			end
		end
	end
end

return PhoneSystem
