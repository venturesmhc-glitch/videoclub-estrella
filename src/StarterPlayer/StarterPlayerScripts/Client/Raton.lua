--!nonstrict
--[[
	Raton (cliente): Shift suelta y vuelve a atrapar el mouse.
	El juego es en primera persona y el mouse queda bloqueado en el centro, así que no se pueden tocar botones como
	"Asustar a todos" o "Revivir". Con Shift (izquierdo o derecho) se libera el mouse para hacer clic; otro Shift lo
	vuelve a atrapar. Mientras está libre la cámara no gira y se muestra un aviso abajo.

	Para liberarlo se usa un botón "Modal" de 1 píxel (igual que el menú): mientras está visible, Roblox suelta el mouse.
	  Raton.alternar()
	  Raton.estaLibre() -> boolean
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Raton = {}

local gui, aviso
local libre = false

local function aplicar()
	gui.Enabled = libre
	aviso.Visible = libre
end

function Raton.estaLibre(): boolean
	return libre
end

function Raton.alternar()
	libre = not libre
	aplicar()
end

function Raton.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Raton"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- debajo de todo: no tapa ningún botón del juego
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local modal = Instance.new("TextButton")
	modal.Name = "Modal"
	modal.Size = UDim2.fromOffset(1, 1)
	modal.Position = UDim2.fromOffset(0, 0)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Modal = true
	modal.Parent = gui

	aviso = Instance.new("TextLabel")
	aviso.Name = "Aviso"
	aviso.AnchorPoint = Vector2.new(0.5, 1)
	aviso.Position = UDim2.fromScale(0.5, 0.985)
	aviso.Size = UDim2.fromScale(0.32, 0.035)
	aviso.BackgroundColor3 = Color3.new(0, 0, 0)
	aviso.BackgroundTransparency = 0.45
	aviso.Font = Enum.Font.Code
	aviso.TextScaled = true
	aviso.TextColor3 = Color3.fromRGB(236, 236, 226)
	aviso.Text = "MOUSE LIBRE · Shift para volver a jugar"
	aviso.Visible = false
	aviso.Parent = gui

	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.LeftShift or entrada.KeyCode == Enum.KeyCode.RightShift then
			Raton.alternar()
		end
	end)
end

return Raton
