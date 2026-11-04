--!nonstrict
--[[
	Sustos (cliente): momentos de susto chicos y controlados que el servidor dispara por WorldEvent.
	  SUSTO_SUAVE con tres variantes (el servidor manda el tipo; ninguna hace daño, todas duran pocos segundos):
	    luces    las luces parpadean y se cortan, la tele dice MIRAME y en la oscuridad aparece la criatura al fondo
	    tele     la tele se llena de estática y dice MIRAME, el zumbido se corta y las luces tiemblan
	    ventana  las luces tiemblan y, del otro lado del vidrio, aparece la criatura mirando adentro
	El audio es analógico, como en The Mandela Catalogue: no hay grito. El ambiente se frena como una cinta y queda
	casi silencio, con un zumbido grave apagado y estática; cuando vuelve la luz, un chasquido de cinta y el ambiente
	arranca de nuevo.
	Es un gancho para que los primeros minutos no sean todos tranquilos. No hace daño ni cuenta como captura.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local LuzFluorescente = require(script.Parent.LuzFluorescente)
local Silueta = require(script.Parent.Silueta)
local AudioManager = require(script.Parent.AudioManager)
local VHSEffects = require(script.Parent.VHSEffects)

local Sustos = {}

local cfg = Config.Sustos
local ocupado = false

-- Cambia el texto de la tele del mostrador (la pantalla trae un SurfaceGui con un TextLabel).
local function textoTele(texto: string?, color: Color3?): (() -> ())?
	local etiqueta
	for _, pantalla in CollectionService:GetTagged("TV") do
		etiqueta = pantalla:FindFirstChildWhichIsA("TextLabel", true)
		if etiqueta then
			break
		end
	end
	if not etiqueta then
		return nil
	end
	local original = { Text = etiqueta.Text, TextColor3 = etiqueta.TextColor3 }
	etiqueta.Text = texto or etiqueta.Text
	etiqueta.TextColor3 = color or etiqueta.TextColor3
	return function()
		etiqueta.Text = original.Text
		etiqueta.TextColor3 = original.TextColor3
	end
end

-- Punto en el piso a unos studs delante de la cámara (si hay una pared antes, un poco antes de ella).
local function puntoAdelante(distancia: number): Vector3?
	local camara = workspace.CurrentCamera
	local personaje = Players.LocalPlayer.Character
	if not camara then
		return nil
	end
	local mirada = Vector3.new(camara.CFrame.LookVector.X, 0, camara.CFrame.LookVector.Z)
	if mirada.Magnitude < 0.1 then
		return nil
	end
	mirada = mirada.Unit
	local origen = camara.CFrame.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personaje }
	local golpe = workspace:Raycast(origen, mirada * distancia, params)
	local largo = golpe and math.max(golpe.Distance - 2, 0) or distancia
	if largo < cfg.DistanciaMinima then
		return nil -- hay una pared pegada: no aparece (no sería un susto, sería un bug)
	end
	return Vector3.new(origen.X + mirada.X * largo, 0, origen.Z + mirada.Z * largo)
end

local function log(texto: string)
	if Config.Debug.LogSistemas then
		print("[Sustos] " .. texto)
	end
end

local function sustoLuces()
	if ocupado then
		log("ya hay un susto en curso")
		return
	end
	ocupado = true
	log("empieza")
	local ok, err = pcall(function()
		-- 1) Las luces fallan: tres chasquidos de cinta bajitos, sin ninguna música.
		for i = 0, 2 do
			AudioManager.efecto(cfg.Glitch.Id, { volumen = cfg.Glitch.Volumen, retardo = i * 0.24 })
		end
		LuzFluorescente.parpadeoFuerte()
		task.wait(0.7)

		-- 2) Se corta la luz y el ambiente se va como una cinta que se frena: queda casi silencio.
		AudioManager.cintaSeDetiene(cfg.FrenadoSeg)
		LuzFluorescente.cortarTodo(true)
		VHSEffects.forzar(cfg.PeligroTracking)
		log("luz cortada")

		-- 3) En el silencio, estática de tele y un zumbido grave apagado (como sonando en otro cuarto) que crece.
		local restaurarTele = textoTele("MIRAME", Color3.fromRGB(255, 70, 60))
		AudioManager.efecto(cfg.Estatica.Id, { volumen = cfg.Estatica.Volumen, duracion = cfg.DuracionSeg, apagado = true, retardo = 0.2 })
		AudioManager.efecto(cfg.Tension.Id, {
			volumen = cfg.Tension.Volumen, velocidad = cfg.Tension.Velocidad, duracion = cfg.DuracionSeg + 0.4, apagado = true, retardo = 0.3,
		})

		-- 4) La criatura, al fondo de donde mira el jugador.
		local silueta
		local punto = puntoAdelante(cfg.DistanciaCriatura)
		if punto then
			silueta = Silueta.crear(false)
			local camara = workspace.CurrentCamera.CFrame.Position
			silueta:PivotTo(CFrame.lookAt(punto, Vector3.new(camara.X, 0, camara.Z)))
			silueta.Parent = workspace
			log("criatura en " .. tostring(punto))
		end

		task.wait(cfg.DuracionSeg)

		-- 5) Vuelve la luz: un chasquido de cinta y el ambiente arranca de nuevo, de a poco. Ya no hay nada.
		if silueta then
			silueta:Destroy()
		end
		AudioManager.efecto(cfg.Glitch.Id, { volumen = cfg.Glitch.Volumen * 1.3 })
		LuzFluorescente.cortarTodo(false)
		AudioManager.cintaArranca(cfg.ReanudarSeg)
		VHSEffects.forzar(nil)
		if restaurarTele then
			restaurarTele()
		end
		log("termina")
	end)
	if not ok then
		warn("[Sustos] " .. tostring(err))
		LuzFluorescente.cortarTodo(false)
		AudioManager.cintaArranca(0.5)
		VHSEffects.forzar(nil)
	end
	ocupado = false
end

-- Variante "tele": sin oscuridad. Estática en la tele, el zumbido se corta un rato y las luces tiemblan.
local function sustoTele()
	if ocupado then
		return
	end
	ocupado = true
	local ok, err = pcall(function()
		AudioManager.efecto(cfg.Glitch.Id, { volumen = cfg.Glitch.Volumen })
		LuzFluorescente.parpadeoFuerte()
		AudioManager.cortar("Zumbido", 2.8)
		local restaurar = textoTele("MIRAME", Color3.fromRGB(255, 70, 60))
		VHSEffects.forzar(0.5)
		AudioManager.efecto(cfg.Estatica.Id, { volumen = cfg.Estatica.Volumen * 1.2, duracion = 2.2, apagado = true, retardo = 0.15 })
		task.wait(2.4)
		AudioManager.efecto(cfg.Glitch.Id, { volumen = cfg.Glitch.Volumen })
		if restaurar then
			restaurar()
		end
		VHSEffects.forzar(nil)
	end)
	if not ok then
		warn("[Sustos] " .. tostring(err))
		VHSEffects.forzar(nil)
	end
	ocupado = false
end

-- Variante "ventana": la criatura del otro lado del vidrio, mirando hacia adentro. Si el jugador está lejos del
-- frente, se cambia por la variante de las luces (para que siempre pase algo que se pueda ver).
local VENTANA_Z = Config.Local.ZFrente + 3.5 -- un poco afuera del vidrio
local function sustoVentana()
	local camara = workspace.CurrentCamera
	if not camara or camara.CFrame.Position.Z < 8 then
		return sustoLuces()
	end
	if ocupado then
		return
	end
	ocupado = true
	local ok, err = pcall(function()
		AudioManager.efecto(cfg.Glitch.Id, { volumen = cfg.Glitch.Volumen })
		LuzFluorescente.parpadeoFuerte()
		task.wait(0.7)
		AudioManager.cintaSeDetiene(0.4)
		VHSEffects.forzar(0.6)
		local pos = camara.CFrame.Position
		local silueta = Silueta.crear(false)
		local x = math.clamp(pos.X, -20, 20)
		silueta:PivotTo(CFrame.lookAt(Vector3.new(x, 0, VENTANA_Z), Vector3.new(pos.X, 0, pos.Z)))
		silueta.Parent = workspace
		AudioManager.efecto(cfg.Tension.Id, { volumen = cfg.Tension.Volumen * 0.8, velocidad = cfg.Tension.Velocidad, duracion = 2.2, apagado = true })
		task.wait(1.8)
		silueta:Destroy()
		LuzFluorescente.parpadeoFuerte()
		AudioManager.efecto(cfg.Glitch.Id, { volumen = cfg.Glitch.Volumen * 1.3, retardo = 0.1 })
		AudioManager.cintaArranca(cfg.ReanudarSeg)
		VHSEffects.forzar(nil)
	end)
	if not ok then
		warn("[Sustos] " .. tostring(err))
		AudioManager.cintaArranca(0.5)
		VHSEffects.forzar(nil)
	end
	ocupado = false
end

local VARIANTES = { luces = sustoLuces, tele = sustoTele, ventana = sustoVentana }

--- Dispara un susto a mano (pruebas): tipo = "luces" | "tele" | "ventana".
function Sustos.disparar(tipo: string?)
	task.spawn(VARIANTES[tipo or "luces"] or sustoLuces)
end

function Sustos.init()
	Net.obtener("WorldEvent").OnClientEvent:Connect(function(datos)
		if typeof(datos) == "table" and datos.id == "SUSTO_SUAVE" and not Players.LocalPlayer:GetAttribute("Espectador") then
			Sustos.disparar(typeof(datos.valor) == "string" and datos.valor or "luces")
		end
	end)
end

return Sustos
