--!nonstrict
--[[
	PhoneUI (cliente) — Fase 6.
	  - Mientras suena un teléfono, su carcasa parpadea (no hay audio todavía).
	  - Al atender, el mensaje (contestador de Don Ernesto, la cinta o una voz) sale como subtítulos.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local DialogUI = require(script.Parent.DialogUI)

local PhoneUI = {}

local ETIQUETAS = { mostrador = "Telefono", interno = "TelefonoInterno" }
local sonando = {} -- linea -> token

-- Cartel flotante visible a través de las paredes mientras suena, para que se sepa dónde atender.
local function crearCartel(parte: BasePart): BillboardGui
	local cartel = Instance.new("BillboardGui")
	cartel.Name = "CartelTelefono"
	cartel.Size = UDim2.fromOffset(190, 46)
	cartel.StudsOffset = Vector3.new(0, 2.2, 0)
	cartel.AlwaysOnTop = true
	cartel.MaxDistance = 120
	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.fromScale(1, 1)
	texto.BackgroundColor3 = Color3.new(0, 0, 0)
	texto.BackgroundTransparency = 0.35
	texto.BorderSizePixel = 0
	texto.Font = Enum.Font.Code
	texto.TextSize = 20
	texto.TextColor3 = Color3.fromRGB(255, 220, 120)
	texto.Text = "TELÉFONO SONANDO\n[E] atender"
	texto.Parent = cartel
	cartel.Parent = parte
	return cartel
end

local function parpadear(linea: string)
	local token = {}
	sonando[linea] = token
	task.spawn(function()
		local parte = CollectionService:GetTagged(ETIQUETAS[linea])[1]
		if not parte then
			return
		end
		local original = parte.Color
		local cartel = crearCartel(parte)
		local alterna = false
		while sonando[linea] == token do
			alterna = not alterna
			parte.Color = alterna and Color3.fromRGB(255, 80, 70) or original
			task.wait(0.35)
		end
		parte.Color = original
		cartel:Destroy()
	end)
end

function PhoneUI.init()
	Net.obtener("WorldEvent").OnClientEvent:Connect(function(datos)
		if typeof(datos) == "table" and datos.id == "TELEFONO" and typeof(datos.valor) == "table" then
			local linea = datos.valor.linea
			if datos.valor.suena then
				parpadear(linea)
			else
				sonando[linea] = nil
			end
		end
	end)

	Net.obtener("PhoneMessage").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" or typeof(datos.lineas) ~= "table" then
			return
		end
		task.spawn(function()
			for _, linea in datos.lineas do
				DialogUI.mostrar({ speaker = datos.speaker, texto = linea, extraSeg = Config.Telefono.LecturaExtraSeg })
			end
		end)
	end)
end

return PhoneUI
