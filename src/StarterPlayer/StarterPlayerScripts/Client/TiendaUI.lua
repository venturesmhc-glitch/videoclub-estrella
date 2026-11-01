--!nonstrict
--[[
	TiendaUI (cliente): el botón "ASUSTAR A TODOS" (Robux), abajo a la derecha, mientras hay un turno en marcha.
	Al tocarlo se le pide al servidor abrir la compra (Tienda.lua); recién cuando Roblox confirma el pago, todos los demás
	reciben un screamer. No se muestra a los espectadores (ellos tienen "REVIVIR", ver Espectador).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local TiendaUI = {}

local jugador = Players.LocalPlayer
local boton
local enTurno = false

local function actualizar()
	if boton then
		boton.Visible = enTurno and not jugador:GetAttribute("Espectador")
	end
end

function TiendaUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TiendaUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60 -- debajo del menú y de los avisos
	gui.Parent = jugador:WaitForChild("PlayerGui")

	boton = Instance.new("TextButton")
	boton.Name = "AsustarATodos"
	boton.AnchorPoint = Vector2.new(1, 1)
	boton.Position = UDim2.new(0.985, 0, 0.97, 0)
	boton.Size = UDim2.fromScale(0.17, 0.055)
	boton.BackgroundColor3 = Color3.fromRGB(26, 10, 12)
	boton.BackgroundTransparency = 0.25
	boton.Font = Enum.Font.Code
	boton.TextScaled = true
	boton.TextColor3 = Color3.fromRGB(255, 190, 170)
	boton.Text = string.format("ASUSTAR A TODOS · R$ %d", Config.Tienda.Precios.Asustar)
	boton.Visible = false
	boton.Parent = gui
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(200, 70, 60)
	borde.Thickness = 2
	borde.Parent = boton
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0.2, 0), UDim.new(0.2, 0)
	relleno.Parent = boton
	boton.Activated:Connect(function()
		Net.obtener("Comprar"):FireServer({ producto = "asustar" })
	end)

	Net.obtener("NightState").OnClientEvent:Connect(function(datos)
		if typeof(datos) == "table" then
			enTurno = datos.fase == "turno"
			actualizar()
		end
	end)
	jugador:GetAttributeChangedSignal("Espectador"):Connect(actualizar)
end

return TiendaUI
