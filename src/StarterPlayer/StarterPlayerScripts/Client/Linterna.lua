--!nonstrict
--[[
	Linterna (cliente) — Fase 6.
	Con el corte de luz (noches 4 y 5) se habilita la linterna: F la prende y la apaga (en móviles, el botón LINTERNA).
	La luz sale de la cámara y la ve solo quien la lleva.

	API: Linterna.habilitar(bool)   -- lo llama LuzFluorescente al cortarse o volver la luz
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Linterna = {}

local habilitada = false
local encendida = false
local parteLuz, luz, boton

local function establecer(valor: boolean)
	encendida = valor and habilitada
	if luz then
		luz.Enabled = encendida
	end
end

function Linterna.habilitar(valor: boolean)
	habilitada = valor
	if boton then
		boton.Visible = valor
	end
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

	RunService.RenderStepped:Connect(function()
		local camara = workspace.CurrentCamera
		if camara and encendida then
			parteLuz.CFrame = camara.CFrame * CFrame.new(0.4, -0.3, -0.5)
		end
	end)

	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if not procesado and entrada.KeyCode == Enum.KeyCode.F and habilitada then
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
			if habilitada then
				establecer(not encendida)
			end
		end)
	end
end

return Linterna
