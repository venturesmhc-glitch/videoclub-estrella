--!nonstrict
--[[
	Linterna (cliente) — Fase 6.
	La linterna se puede usar con el corte de luz (noches 4 y 5) y mientras el Socio anda suelto: F la prende y la apaga (en móviles,
	el botón LINTERNA). La luz sale de la cámara y la ve solo quien la lleva.
	Tiene batería (Config.Linterna): se gasta prendida, se recarga sola apagada y, casi vacía, titila. Alumbrar al Socio mirándolo es
	lo único que lo frena: el servidor lo sabe porque cada reporte de cámara (JugadorLocal) dice si la linterna está prendida.

	API: Linterna.habilitar(bool)   -- lo llama LuzFluorescente al cortarse o volver la luz
	     Linterna.estaEncendida()   -- prendida y con batería (lo que ve el servidor)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Linterna = {}

local cfg = Config.Linterna
local rng = Random.new()
local habilitada = false -- por el corte de luz
local socioSuelto = false -- el Socio está en el local
local encendida = false
local bateria = 1 -- 0 a 1
local agotada = false -- se quedó sin batería: no prende hasta recuperar un poco
local parteLuz, luz, boton, barra, relleno

local function permitida(): boolean
	return habilitada or socioSuelto
end

local function establecer(valor: boolean)
	encendida = valor and permitida() and not agotada and bateria > 0
	if luz then
		luz.Enabled = encendida
	end
end

function Linterna.estaEncendida(): boolean
	return encendida
end

local function mostrarInterfaz()
	local visible = permitida()
	if boton then
		boton.Visible = visible
	end
	if barra then
		barra.Visible = visible
	end
end

function Linterna.habilitar(valor: boolean)
	habilitada = valor
	mostrarInterfaz()
	establecer(valor) -- al cortarse la luz arranca prendida
end

function Linterna.init()
	parteLuz = Instance.new("Part")
	parteLuz.Name = "LinternaLuz"
	parteLuz.Size = Vector3.new(0.2, 0.2, 0.2)
	parteLuz.Transparency = 1
	parteLuz.Anchored = true
	parteLuz.CanCollide = false
	parteLuz.CanQuery = false
	parteLuz.CanTouch = false
	luz = Instance.new("SpotLight")
	luz.Angle = 58
	luz.Range = 55
	luz.Brightness = 5
	luz.Color = Color3.fromRGB(255, 244, 214)
	luz.Shadows = true
	luz.Enabled = false
	luz.Parent = parteLuz
	parteLuz.Parent = workspace

	-- Batería: indicador finito sobre la barra de energía de correr.
	local guiBateria = Instance.new("ScreenGui")
	guiBateria.Name = "LinternaBateria"
	guiBateria.ResetOnSpawn = false
	guiBateria.DisplayOrder = 58
	guiBateria.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	barra = Instance.new("Frame")
	barra.AnchorPoint = Vector2.new(0.5, 1)
	barra.Position = UDim2.fromScale(0.5, 0.935)
	barra.Size = UDim2.fromScale(0.16, 0.008)
	barra.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	barra.BackgroundTransparency = 0.35
	barra.BorderSizePixel = 0
	barra.Visible = false
	barra.Parent = guiBateria
	relleno = Instance.new("Frame")
	relleno.Size = UDim2.fromScale(1, 1)
	relleno.BackgroundColor3 = Color3.fromRGB(255, 230, 150)
	relleno.BorderSizePixel = 0
	relleno.Parent = barra

	RunService.RenderStepped:Connect(function(dt)
		local camara = workspace.CurrentCamera
		if camara and encendida then
			parteLuz.CFrame = camara.CFrame * CFrame.new(0.4, -0.3, -0.5)
		end

		-- ¿El Socio anda suelto? (el espectador ya no lo ve ni usa la linterna por él).
		local socio = workspace:FindFirstChild("Socio0000")
		local hay = socio ~= nil and socio.Parent == workspace and not Players.LocalPlayer:GetAttribute("Espectador")
		if hay ~= socioSuelto then
			socioSuelto = hay
			mostrarInterfaz()
			if not permitida() then
				establecer(false) -- se fue y no hay corte de luz: se apaga sola
			end
		end

		if encendida then
			bateria = math.max(0, bateria - dt / cfg.BateriaSeg)
			if bateria <= 0 then
				agotada = true
				establecer(false)
			end
		else
			bateria = math.min(1, bateria + dt / cfg.RecargaSeg)
			if agotada and bateria >= cfg.MinimaParaPrender then
				agotada = false
			end
		end
		-- Con poca batería la luz titila (cada vez más).
		if encendida and luz then
			luz.Enabled = bateria > cfg.ParpadeoBajo or rng:NextNumber() > (1 - bateria / cfg.ParpadeoBajo) * 0.6
		end
		if relleno then
			relleno.Size = UDim2.fromScale(bateria, 1)
			relleno.BackgroundColor3 = bateria > cfg.ParpadeoBajo and Color3.fromRGB(255, 230, 150) or Color3.fromRGB(220, 70, 50)
		end
	end)

	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if not procesado and entrada.KeyCode == Enum.KeyCode.F and permitida() then
			establecer(not encendida)
		end
	end)

	if UserInputService.TouchEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "LinternaUI"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 55
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		boton = Instance.new("TextButton")
		boton.AnchorPoint = Vector2.new(1, 1)
		boton.Position = UDim2.fromScale(0.98, 0.77)
		boton.Size = UDim2.fromScale(0.14, 0.07)
		boton.BackgroundColor3 = Color3.fromRGB(184, 148, 98)
		boton.TextColor3 = Color3.fromRGB(66, 46, 28)
		boton.Font = Enum.Font.Code
		boton.TextScaled = true
		boton.Text = "LINTERNA"
		boton.Visible = false
		boton.Parent = gui
		boton.Activated:Connect(function()
			if permitida() then
				establecer(not encendida)
			end
		end)
	end
end

return Linterna
