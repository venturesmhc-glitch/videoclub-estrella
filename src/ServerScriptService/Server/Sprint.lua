--!nonstrict
--[[
	Sprint (servidor): correr. El cliente pide ("Sprint" { activo }) mientras mantiene la tecla; acá se decide: la
	velocidad de carrera (Config.Jugador.Sprint.Velocidad) solo se da si el jugador se está moviendo y le queda energía.
	La energía se gasta corriendo (DuracionSeg) y se recupera sola (RecargaSeg); si se agota, hay que esperar a juntar
	UmbralRecuperar para volver a correr. El atributo "Energia" (0..1) del jugador lo muestra el cliente.

	No corren los espectadores ni quien mira la cinta (WalkSpeed 0). Esos sistemas restauran la velocidad normal por su
	cuenta: este módulo solo baja la velocidad si fue él quien la subió.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Fantasmas = require(script.Parent.Fantasmas)

local Sprint = {}

local cfg = Config.Jugador.Sprint
local estados = {} -- Player -> { pide, energia, cansado, elevado }

local function estadoDe(jugador: Player)
	local e = estados[jugador]
	if not e then
		e = { pide = false, energia = 1, cansado = false, elevado = false, publicada = 1 }
		estados[jugador] = e
	end
	return e
end

local function humanoideDe(jugador: Player): Humanoid?
	return jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
end

local function bajar(jugador: Player, e)
	if not e.elevado then
		return
	end
	e.elevado = false
	local h = humanoideDe(jugador)
	if h and h.WalkSpeed > 0 then
		h.WalkSpeed = Config.Jugador.VelocidadCaminar
	end
end

function Sprint.init()
	Net.obtener("Sprint").OnServerEvent:Connect(function(jugador, datos)
		if typeof(datos) ~= "table" or typeof(datos.activo) ~= "boolean" then
			return
		end
		if not Net.limitar(jugador, "sprint", 0.05) then
			return
		end
		estadoDe(jugador).pide = datos.activo
	end)

	Players.PlayerRemoving:Connect(function(jugador)
		estados[jugador] = nil
	end)

	local ultimo = os.clock()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ahora = os.clock()
			local dt = ahora - ultimo
			ultimo = ahora
			for _, jugador in Players:GetPlayers() do
				local e = estadoDe(jugador)
				local h = humanoideDe(jugador)
				-- (la dirección de movimiento la maneja el cliente y no siempre llega: se mira también la velocidad real)
				local raiz = h and h.RootPart
				local rapido = raiz ~= nil and Vector3.new(raiz.AssemblyLinearVelocity.X, 0, raiz.AssemblyLinearVelocity.Z).Magnitude > 1.5
				local mueve = h ~= nil and (h.MoveDirection.Magnitude > 0.1 or rapido)
				local puede = h ~= nil and h.Health > 0 and h.WalkSpeed > 0 and not Fantasmas.esFantasma(jugador)
				local corre = e.pide and mueve and puede and not e.cansado and e.energia > 0
				if corre then
					e.energia = math.max(0, e.energia - dt / cfg.DuracionSeg)
					if not e.elevado or h.WalkSpeed ~= cfg.Velocidad then
						e.elevado = true
						h.WalkSpeed = cfg.Velocidad
					end
					if e.energia <= 0 then
						e.cansado = true
						bajar(jugador, e)
					end
				else
					bajar(jugador, e)
					-- Se recupera más lento si sigue apretando la tecla, y no del todo hasta soltar.
					e.energia = math.min(1, e.energia + dt / cfg.RecargaSeg)
					if e.cansado and e.energia >= cfg.UmbralRecuperar then
						e.cansado = false
					end
				end
				if math.abs(e.energia - e.publicada) >= 0.02 or (e.energia >= 1 and e.publicada < 1) then
					e.publicada = e.energia
					jugador:SetAttribute("Energia", e.energia)
				end
				jugador:SetAttribute("Cansado", e.cansado)
			end
		end
	end)
end

return Sprint
