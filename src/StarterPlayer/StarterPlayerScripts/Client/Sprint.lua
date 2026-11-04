--!nonstrict
--[[
	Sprint (cliente): mantener Ctrl izquierdo para correr. Le avisa al servidor (remote Sprint), que decide la velocidad y
	gasta la energía. Muestra una barra fina abajo al centro cuando la energía no está llena, y abre un poco el campo de
	visión mientras se corre (túnel de velocidad). En celulares no hay tecla: el botón CORRER aparece a la derecha.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Sprint = {}

local jugador = Players.LocalPlayer
local cfg = Config.Jugador.Sprint
local pide = false
local barra, relleno

local function pedir(valor: boolean)
	if pide == valor then
		return
	end
	pide = valor
	Net.obtener("Sprint"):FireServer({ activo = valor })
end

function Sprint.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SprintUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 58
	gui.Parent = jugador:WaitForChild("PlayerGui")

	barra = Instance.new("Frame")
	barra.AnchorPoint = Vector2.new(0.5, 1)
	barra.Position = UDim2.fromScale(0.5, 0.955)
	barra.Size = UDim2.fromScale(0.16, 0.008)
	barra.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	barra.BackgroundTransparency = 0.4
	barra.BorderSizePixel = 0
	barra.Visible = false
	barra.Parent = gui
	relleno = Instance.new("Frame")
	relleno.Size = UDim2.fromScale(1, 1)
	relleno.BackgroundColor3 = Color3.fromRGB(236, 232, 210)
	relleno.BorderSizePixel = 0
	relleno.Parent = barra

	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if entrada.KeyCode == Enum.KeyCode.LeftControl and not procesado then
			pedir(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.LeftControl then
			pedir(false)
		end
	end)

	if UserInputService.TouchEnabled then
		local boton = Instance.new("TextButton")
		boton.AnchorPoint = Vector2.new(1, 1)
		boton.Position = UDim2.fromScale(0.98, 0.78)
		boton.Size = UDim2.fromScale(0.12, 0.07)
		boton.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
		boton.BackgroundTransparency = 0.3
		boton.TextColor3 = Color3.fromRGB(236, 232, 210)
		boton.Font = Enum.Font.Code
		boton.TextScaled = true
		boton.Text = "CORRER"
		boton.Parent = gui
		boton.InputBegan:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
				pedir(true)
			end
		end)
		boton.InputEnded:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
				pedir(false)
			end
		end)
	end

	local fov = Config.Jugador.CamaraFOV
	RunService.RenderStepped:Connect(function(dt)
		local energia = jugador:GetAttribute("Energia")
		energia = typeof(energia) == "number" and energia or 1
		local cansado = jugador:GetAttribute("Cansado") == true
		local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
		local corriendo = humanoide ~= nil and humanoide.WalkSpeed >= cfg.Velocidad - 0.5 and humanoide.MoveDirection.Magnitude > 0.1
		barra.Visible = energia < 0.999 or corriendo
		relleno.Size = UDim2.fromScale(math.clamp(energia, 0, 1), 1)
		relleno.BackgroundColor3 = cansado and Color3.fromRGB(190, 70, 60) or Color3.fromRGB(236, 232, 210)
		-- Campo de visión: se abre al correr (no toca la cámara de la cinta ni la del espectador: solo si es la normal).
		local camara = workspace.CurrentCamera
		if camara and camara.CameraType == Enum.CameraType.Custom then
			local meta = fov + (corriendo and cfg.FovExtra or 0)
			camara.FieldOfView += (meta - camara.FieldOfView) * math.min(1, dt * 6)
		end
	end)
end

return Sprint
