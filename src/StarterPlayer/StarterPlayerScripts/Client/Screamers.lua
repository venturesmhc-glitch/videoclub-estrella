--!nonstrict
--[[
	Screamers (cliente): el susto fuerte a pantalla completa. Cuando el servidor manda el remote Screamer (automático de la
	noche, el "Asustar a todos" que compró otro jugador, o cuando el Socio te agarra), la pantalla se va a negro y el Socio
	se acerca a tirones con la cara casi cerrada; de golpe la cara se parte en dos y se abre de par en par hacia los lados
	(como en IT) con un grito, entre destellos y estática, mientras la cámara se mete en la boca. Dura Config.Screamer.DuracionSeg.

	Usa el Socio con esqueleto (Personajes.crearSocioMalla + SocioHuesos.gritar) en un ViewportFrame; si el modelo no trae
	huesos queda quieto y se abalanza, y si no carga, un rostro hecho con la interfaz (ojos y boca).
	La anomalía de la araña (FiguraAlFondo) tiene su propio screamer: reproducir(nil, "aracnido") muestra el modelo de
	Client/Aracnido (no el del Socio) con su propio grito (Config.Screamer.SonidoAracnido).
	No se muestra a los espectadores (el servidor tampoco se lo manda), salvo la captura.

	  Screamers.reproducir(variante?, criatura?, captura?)
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Personajes = require(ReplicatedStorage.Shared.Personajes)
local SocioHuesos = require(ReplicatedStorage.Shared.SocioHuesos)
local VHSEffects = require(script.Parent.VHSEffects)
local Aracnido = require(script.Parent.Aracnido)

local Screamers = {}

local cfg = Config.Screamer
local rng = Random.new()
local gui
local ocupado = false
local cuerpo: Model? = nil -- la criatura, armada una sola vez

local function armarCuerpo()
	if cuerpo then
		return
	end
	local ok, modelo = pcall(function()
		return Personajes.crearSocioMalla(Config.Socio)
	end)
	if ok and modelo then
		cuerpo = modelo
	end
end

local function crearInterfaz()
	gui = Instance.new("ScreenGui")
	gui.Name = "Screamer"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 150 -- por encima de todo, también del filtro VHS
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Rostro de respaldo con la interfaz (ojos y boca) si la malla no cargó.
local function rostroDeRespaldo(padre: GuiObject)
	local function parte(tam, pos, color)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = tam
		f.Position = pos
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = padre
		return f
	end
	parte(UDim2.fromScale(0.22, 0.12), UDim2.fromScale(0.34, 0.4), Color3.fromRGB(240, 245, 230))
	parte(UDim2.fromScale(0.22, 0.12), UDim2.fromScale(0.66, 0.4), Color3.fromRGB(240, 245, 230))
	parte(UDim2.fromScale(0.5, 0.28), UDim2.fromScale(0.5, 0.72), Color3.fromRGB(0, 0, 0))
end

function Screamers.reproducir(variante: number?, criatura: string?, captura: boolean?)
	-- Si te agarró el Socio se ve siempre, aunque esa captura te deje fuera de la noche y ya figures como espectador.
	if ocupado or (not captura and Players.LocalPlayer:GetAttribute("Espectador")) then
		return
	end
	ocupado = true
	local esAracnido = criatura == "aracnido"
	if not esAracnido then
		armarCuerpo()
	end
	gui.Enabled = true

	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Color3.new(0, 0, 0)
	fondo.BorderSizePixel = 0
	fondo.Parent = gui

	local camaraVista: Camera? = nil
	local vistaGui: ViewportFrame? = nil
	local huesos = nil -- animación del Socio (SocioHuesos), si el modelo trae esqueleto
	local largo = cfg.DuracionSeg
	local aracnido = nil -- la araña de la anomalía (su propio screamer, no el del Socio)
	if esAracnido then
		local vista = Instance.new("ViewportFrame")
		vista.Size = UDim2.fromScale(1, 1)
		vista.BackgroundTransparency = 1
		vista.Ambient = Color3.fromRGB(170, 170, 178)
		vista.LightColor = Color3.fromRGB(255, 255, 255)
		vista.Parent = fondo
		aracnido = Aracnido.crear()
		if aracnido.esTrepador then
			vista.Ambient = Color3.fromRGB(70, 72, 82) -- piel negra: casi todo el volumen lo da la luz de frente
			vista.LightColor = Color3.fromRGB(215, 225, 245)
			vista.LightDirection = Vector3.new(0, -0.2, 1)
			largo = cfg.DuracionTrepadorSeg
		end
		aracnido.actualizar(CFrame.new(0, 0, 0), 1 / 60, Vector3.new(0, 3.6, -14))
		aracnido.modelo.Parent = vista
		camaraVista = Instance.new("Camera")
		camaraVista.FieldOfView = 60
		vista.CurrentCamera = camaraVista
		camaraVista.Parent = vista
	elseif cuerpo then
		local vista = Instance.new("ViewportFrame")
		vista.Size = UDim2.fromScale(1, 1)
		vista.BackgroundTransparency = 1
		vista.Ambient = Color3.fromRGB(60, 60, 70)
		vista.LightColor = Color3.fromRGB(150, 150, 170)
		vista.LightDirection = Vector3.new(0, -0.15, 1) -- la luz viaja de la cámara hacia la cara (la cara mira a -Z)
		vista.Parent = fondo
		vistaGui = vista
		local copia = cuerpo:Clone()
		copia:PivotTo(CFrame.new(0, 0, 0))
		copia.Parent = vista
		if copia:GetAttribute("ConHuesos") then
			huesos = SocioHuesos.nuevo(copia, { anguloBoca = Config.Socio.BocaAngulo })
		end
		camaraVista = Instance.new("Camera")
		camaraVista.FieldOfView = 60
		vista.CurrentCamera = camaraVista
		camaraVista.Parent = vista
	else
		rostroDeRespaldo(fondo)
	end
	if huesos then
		largo = cfg.DuracionSocioSeg -- el Socio con esqueleto necesita más tiempo: se acerca y después abre la cara
	end

	-- Estática encima.
	local estatica = Instance.new("Frame")
	estatica.Size = UDim2.fromScale(1, 1)
	estatica.BackgroundColor3 = Color3.new(1, 1, 1)
	estatica.BackgroundTransparency = 1
	estatica.BorderSizePixel = 0
	estatica.ZIndex = 5
	estatica.Parent = fondo

	-- Grito.
	local grito = if esAracnido
		then cfg.SonidoAracnido
		else (cfg.Sonidos[variante or rng:NextInteger(1, #cfg.Sonidos)] or cfg.Sonidos[1])
	local sonido = Instance.new("Sound")
	sonido.SoundId = grito.Id
	sonido.Volume = grito.Volumen
	sonido.PlaybackSpeed = grito.Velocidad or 1
	sonido.Parent = SoundService
	Debris:AddItem(sonido, largo + 3)
	if huesos then
		-- Primero el silencio y la cara que se acerca; el grito estalla con la cara abriéndose.
		task.delay(math.max(0, cfg.AbreEn * largo - 0.08), function()
			sonido:Play()
			VHSEffects.susto()
		end)
	else
		sonido:Play()
		VHSEffects.susto()
	end

	local alto = Config.Socio.AlturaMalla
	local escala = alto / Personajes.ALTURA_ESQUELETO
	local altoCara = 2.9 * escala -- altura de los ojos sobre los pies
	local inicio = os.clock()
	local conexion
	local pasoCamara, temblorSocio = -1, Vector3.zero
	local flashHasta = 0
	local yaAbrio = false
	conexion = RunService.RenderStepped:Connect(function(dt)
		local ahora = os.clock()
		local t = (ahora - inicio) / largo
		if t >= 1 then
			conexion:Disconnect()
			return
		end
		local abierta = huesos ~= nil and t >= cfg.AbreEn
		if huesos then
			-- El Socio se acerca a tirones con la cara casi cerrada y, de golpe, la parte en dos de par en par.
			huesos.gritar(t, cfg.AbreEn)
		end
		if abierta and not yaAbrio then
			yaAbrio = true
			flashHasta = ahora + 0.09 -- destello blanco justo cuando se abre
		end
		if aracnido and aracnido.esTrepador and camaraVista then
			-- El Trepador (con esqueleto) viene a saltos con la cabeza torcida y, de golpe, abre la boca con los brazos en alto.
			local abreT = cfg.TrepadorAbreEn
			local abiertaT = t >= abreT
			if abiertaT and not yaAbrio then
				yaAbrio = true
				flashHasta = ahora + 0.09 -- destello blanco justo cuando abre la boca
			end
			local avance
			if not abiertaT then
				avance = 11 * (math.floor(math.clamp(t / abreT, 0, 1) * 6) / 6) ^ 1.4 -- a saltos, cada vez más cerca
			else
				avance = 11 + 3.6 * math.clamp((t - abreT) / (1 - abreT), 0, 1)
			end
			local paso = math.floor(ahora * 24)
			if paso ~= pasoCamara then
				pasoCamara = paso
				temblorSocio = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5)) * (if abiertaT then 0.2 else 0.06)
			end
			local posCamara = Vector3.new(0, 4.2, -20.5) + temblorSocio
			aracnido.gritar(t, abreT)
			aracnido.actualizar(CFrame.new(0, 0, -avance), dt, posCamara)
			camaraVista.CFrame = CFrame.lookAt(posCamara, Vector3.new(0, 3.5, -3.64 - avance))
			camaraVista.FieldOfView = if abiertaT then 66 else 58
		elseif aracnido and camaraVista then
			-- La araña se abalanza de frente: la cámara pasa de ver todo el cuerpo a quedar pegada a la cara, y las patas se agitan.
			local acercamiento = math.clamp(t / 0.25, 0, 1)
			local distancia = 13 - 10.6 * acercamiento ^ 2
			local temblor = Vector3.new(rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.2, 0.2), 0) * (0.4 + acercamiento)
			local posCamara = Vector3.new(0, 3.9, -2.05 - distancia) + temblor
			aracnido.actualizar(CFrame.new(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12)), dt, posCamara)
			camaraVista.CFrame = CFrame.lookAt(posCamara, Vector3.new(0, 3.2, -2.05))
		elseif camaraVista then
			local distancia
			if not huesos then
				-- Sin esqueleto: se abalanza como siempre, de lejos a pegado a la cara.
				local acercamiento = math.clamp(t / 0.25, 0, 1)
				distancia = 9 - 6.6 * acercamiento ^ 2
			elseif not abierta then
				-- Se acerca a saltos (cada paso es un tirón de cámara), cada vez más cerca.
				local previo = math.clamp(t / cfg.AbreEn, 0, 1)
				distancia = 8 - 4.6 * (math.floor(previo * 5) / 5) ^ 1.5
			else
				-- Abierta: la cámara se mete de a poco en la boca.
				local dentro = math.clamp((t - cfg.AbreEn) / (1 - cfg.AbreEn), 0, 1)
				distancia = 2.5 - 1.1 * dentro
			end
			-- El temblor de cámara se renueva a unos 24 cuadros por segundo: se siente cinta, no suavidad.
			local paso = math.floor(ahora * 24)
			if paso ~= pasoCamara then
				pasoCamara = paso
				local fuerza = abierta and 0.16 or (0.04 + 0.12 * math.clamp(t / cfg.AbreEn, 0, 1))
				temblorSocio = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5)) * fuerza
			end
			local objetivo = Vector3.new(0, altoCara - (abierta and 0.15 or 0.25), -0.25 * escala * 0.4)
			camaraVista.CFrame = CFrame.lookAt(Vector3.new(0, altoCara + (abierta and 0 or 0.2), -distancia) + temblorSocio, objetivo)
			camaraVista.FieldOfView = abierta and 68 or 58
		end
		if vistaGui then
			-- Al abrirse, la luz se vuelve de golpe cálida y fuerte sobre la boca.
			vistaGui.Ambient = abierta and Color3.fromRGB(140, 105, 105) or Color3.fromRGB(60, 60, 70)
			vistaGui.LightColor = abierta and Color3.fromRGB(255, 205, 185) or Color3.fromRGB(150, 150, 170)
		end
		-- Destellos y estática que parpadean.
		local blanco = ahora < flashHasta or rng:NextNumber() < (abierta and 0.05 or 0.1)
		fondo.BackgroundColor3 = blanco and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		estatica.BackgroundTransparency = rng:NextNumber(0.55, 0.9)
		-- Todo se corta en seco al final.
		if vistaGui then
			vistaGui.Visible = t < 0.94
		end
	end)

	task.delay(largo, function()
		local salida = TweenService:Create(fondo, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		salida:Play()
		task.delay(0.3, function()
			if aracnido then
				aracnido.destruir()
			end
			fondo:Destroy()
			gui.Enabled = false
			ocupado = false
		end)
	end)
end

function Screamers.init()
	crearInterfaz()
	task.spawn(armarCuerpo) -- la malla tarda un poco en cargar: se prepara antes del primer screamer
	Net.obtener("Screamer").OnClientEvent:Connect(function(datos)
		local tabla = typeof(datos) == "table"
		Screamers.reproducir(tabla and datos.variante or nil, tabla and datos.criatura or nil, tabla and datos.captura == true)
	end)
end

return Screamers
