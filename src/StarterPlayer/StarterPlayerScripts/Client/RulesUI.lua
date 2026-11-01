--!nonstrict
--[[
	RulesUI (cliente) — Fase 6.
	Dibuja las notas de Darío pegadas en las paredes del local. El servidor decide qué notas hay
	(remote RuleNotes) y en qué lugar (atributo SlotId de las partes con el tag "NotaSlot");
	acá solo se ven. Están escritas a mano y levemente torcidas.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local RulesUI = {}

local rng = Random.new()
local notas = {} -- SlotId -> SurfaceGui

local function parteDeSlot(slotId)
	for _, parte in CollectionService:GetTagged("NotaSlot") do
		if parte:GetAttribute("SlotId") == slotId then
			return parte
		end
	end
	return nil
end

local function limpiar()
	for _, gui in notas do
		gui:Destroy()
	end
	table.clear(notas)
end

local function dibujar(nota)
	local parte = parteDeSlot(nota.slot)
	if not parte then
		return
	end
	if notas[nota.slot] then
		notas[nota.slot]:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "NotaDario"
	gui.Face = Enum.NormalId[parte:GetAttribute("Cara") or "Front"]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 110
	gui.LightInfluence = 0.6
	gui.Parent = parte

	local papel = Instance.new("Frame")
	papel.Size = UDim2.fromScale(0.96, 0.96)
	papel.Position = UDim2.fromScale(0.02, 0.02)
	papel.BackgroundColor3 = Color3.fromRGB(240, 232, 190)
	papel.BorderSizePixel = 0
	papel.Rotation = rng:NextNumber(-3, 3)
	papel.Parent = gui

	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.fromScale(0.9, 0.84)
	texto.Position = UDim2.fromScale(0.05, 0.1)
	texto.BackgroundTransparency = 1
	texto.TextWrapped = true
	texto.TextScaled = true
	texto.Font = Enum.Font.IndieFlower
	texto.TextColor3 = Color3.fromRGB(28, 40, 96)
	texto.Text = nota.texto
	texto.Parent = papel

	-- La cinta adhesiva de arriba.
	local cinta = Instance.new("Frame")
	cinta.Size = UDim2.fromScale(0.3, 0.06)
	cinta.Position = UDim2.fromScale(0.35, 0)
	cinta.BackgroundColor3 = Color3.fromRGB(214, 204, 160)
	cinta.BackgroundTransparency = 0.25
	cinta.BorderSizePixel = 0
	cinta.Parent = papel

	notas[nota.slot] = gui
end

function RulesUI.init()
	Net.obtener("RuleNotes").OnClientEvent:Connect(function(datos)
		if typeof(datos) ~= "table" then
			return
		end
		if datos.accion == "limpiar" then
			limpiar()
		elseif datos.accion == "agregar" then
			for _, nota in datos.notas or {} do
				dibujar(nota)
			end
		end
	end)
end

return RulesUI
