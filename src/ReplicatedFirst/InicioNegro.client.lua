--!nonstrict
--[[
	InicioNegro (cliente, ReplicatedFirst): tapa la pantalla con negro apenas el cliente arranca, antes de que el
	local se vea y antes de que cargue el menú (MenuUI). Corre antes que cualquier otro script del juego.
	MenuUI saca este cartel (Destroy) apenas arma su propio fondo negro, así no hay ningún cuadro con el mundo a la vista.
	Si por algún motivo el menú nunca aparece, se retira solo pasado un rato para no dejar la pantalla negra para siempre.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local NOMBRE = "InicioNegro"
local TIEMPO_MAXIMO_SEG = 30

local jugador = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = NOMBRE
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local fondo = Instance.new("Frame")
fondo.Size = UDim2.fromScale(1, 1)
fondo.BackgroundColor3 = Color3.new(0, 0, 0)
fondo.BorderSizePixel = 0
fondo.Active = true
fondo.Parent = gui

gui.Parent = jugador:WaitForChild("PlayerGui")

-- Recién con el negro puesto se saca la pantalla de carga de Roblox (sin hueco entre una y otra).
ReplicatedFirst:RemoveDefaultLoadingScreen()

task.delay(TIEMPO_MAXIMO_SEG, function()
	if gui.Parent then
		gui:Destroy()
	end
end)
