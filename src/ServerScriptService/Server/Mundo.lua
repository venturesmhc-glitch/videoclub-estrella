--!nonstrict
--[[
	Mundo (servidor) — Fase 6.
	Cambios del local durante las noches avanzadas:
	  CORTE_LUZ        se corta la luz (lo aplica cada cliente con el remote WorldEvent; además habilita la linterna)
	  DEPOSITO_LARGO   el depósito se alarga: se oculta su pared del fondo y aparece un tramo nuevo (noche 4)
	  FLICKER          parpadeo fuerte de las luces (consecuencia de romper una regla)
	También maneja la tele del mostrador (prompt "Apagar tele"): apagarla es la trampa de la nota falsa F_TV.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local NightManager = require(script.Parent.NightManager)
local Prompts = require(script.Parent.Prompts)

local Mundo = {}

local luzCortada = false
local depositoLargo = false

local function enviar(id: string, valor: any, jugador: Player?)
	local remoto = Net.obtener("WorldEvent")
	if jugador then
		remoto:FireClient(jugador, { id = id, valor = valor })
	else
		remoto:FireAllClients({ id = id, valor = valor })
	end
end

local function ocultarParedFondo(oculta: boolean)
	for _, pared in CollectionService:GetTagged("MuroFondoDeposito") do
		pared.Transparency = oculta and 1 or 0
		pared.CanCollide = not oculta
	end
end

local function ponerDepositoLargo(valor: boolean)
	depositoLargo = valor
	local largo = ServerStorage:FindFirstChild("DepositoLargo") or workspace:FindFirstChild("DepositoLargo")
	if largo then
		largo.Parent = valor and workspace or ServerStorage
	end
	ocultarParedFondo(valor)
end

function Mundo.cortarLuz(valor: boolean)
	luzCortada = valor
	enviar("CORTE_LUZ", valor)
end

function Mundo.parpadeo()
	enviar("FLICKER", true)
end

--- Cambia de canal la tele del mostrador (E). Pasados todos los canales se apaga, y de apagada vuelve al canal 1.
--- Es una distracción para los ratos tranquilos: los canales traen pistas y algún mensaje raro (Client/Tele).
--- Apagarla es la trampa de la nota falsa F_TV (evento TV_APAGADA).
function Mundo.cambiarCanal(jugador: Player)
	local total = NightManager.obtenerEstado().noche >= 3 and 6 or 5
	for _, pantalla in CollectionService:GetTagged("TV") do
		local encendida = pantalla:GetAttribute("Encendida") ~= false
		local canal = pantalla:GetAttribute("Canal") or 1
		if not encendida then
			canal, encendida = 1, true
		else
			canal += 1
			if canal > total then
				canal, encendida = 0, false
			end
		end
		pantalla:SetAttribute("Canal", canal)
		pantalla:SetAttribute("Encendida", encendida)
		local luz = pantalla:FindFirstChildWhichIsA("SurfaceLight")
		if luz then
			luz.Enabled = encendida
		end
		if encendida then
			Net.aviso(jugador, "Canal " .. canal)
		else
			Net.aviso(jugador, "Apagaste la tele.")
			NightManager.emitir("TV_APAGADA", { jugador = jugador })
		end
	end
end

function Mundo.alternarTV(jugador: Player)
	for _, pantalla in CollectionService:GetTagged("TV") do
		local encendida = pantalla:GetAttribute("Encendida") ~= false
		pantalla:SetAttribute("Encendida", not encendida)
		local luz = pantalla:FindFirstChildWhichIsA("SurfaceLight")
		if luz then
			luz.Enabled = not encendida
		end
		if encendida then
			Net.aviso(jugador, "Apagaste la tele.")
			NightManager.emitir("TV_APAGADA", { jugador = jugador })
		else
			Net.aviso(jugador, "Prendiste la tele.")
		end
	end
end

local function restablecer()
	Mundo.cortarLuz(false)
	ponerDepositoLargo(false)
	for _, pantalla in CollectionService:GetTagged("TV") do
		pantalla:SetAttribute("Encendida", true)
		pantalla:SetAttribute("Canal", 1)
		local luz = pantalla:FindFirstChildWhichIsA("SurfaceLight")
		if luz then
			luz.Enabled = true
		end
	end
end

function Mundo.estadoTexto(): string
	return string.format("luzCortada=%s depositoLargo=%s", tostring(luzCortada), tostring(depositoLargo))
end

function Mundo.init()
	NightManager.suscribir("NOCHE_INICIA", restablecer)
	NightManager.suscribir("NOCHE_TERMINA", restablecer)
	NightManager.suscribir("CORTE_LUZ", function(datos)
		Mundo.cortarLuz(datos == nil or datos.valor ~= false)
	end)
	NightManager.suscribir("DEPOSITO_LARGO", function()
		ponerDepositoLargo(true)
	end)
	NightManager.suscribir("SUSTO_SUAVE", function(datos)
		-- datos.tipo: "luces" (corte de luz con la criatura), "tele" (la tele dice MIRAME) o "ventana" (ojos en el vidrio)
		enviar("SUSTO_SUAVE", datos and datos.tipo or "luces")
	end)

	-- Quien entra con el turno en marcha recibe el estado actual de la luz.
	Players.PlayerAdded:Connect(function(jugador)
		task.delay(2, function()
			enviar("CORTE_LUZ", luzCortada, jugador)
		end)
	end)

	for _, pantalla in CollectionService:GetTagged("TV") do
		Prompts.crear(pantalla, {
			clave = "tv",
			accion = "Cambiar canal",
			objeto = "Tele del mostrador",
			distancia = 4.5, -- corta, para que su botón no se mezcle con los de la videocasetera y el mostrador
			alActivar = Mundo.cambiarCanal,
		})
	end
end

return Mundo
