--!nonstrict
--[[
	Tele (cliente): los canales de la tele del mostrador (pantalla con el tag "TV").
	Es una distracción para los ratos tranquilos: con E se cambia de canal (lo decide el servidor, atributo "Canal"
	de la pantalla) y cada canal muestra algo. Algunos traen pistas o mensajes raros; el último solo existe de la noche 3.
	  Canal 0 / Encendida = false   apagada
	La estática de la tele y el modo "reproduciendo" de la cinta los maneja CursedTapeSystem, que llama a Tele.pintar.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioManager = require(script.Parent.AudioManager)
local Config = require(ReplicatedStorage.Shared.Config)

local Tele = {}

local COLOR_TEXTO = Color3.fromRGB(150, 190, 170)
local COLOR_FONDO = Color3.fromRGB(16, 22, 20)
local BARRAS = {
	Color3.fromRGB(235, 235, 225), Color3.fromRGB(230, 220, 50), Color3.fromRGB(50, 220, 220), Color3.fromRGB(60, 210, 70),
	Color3.fromRGB(220, 60, 220), Color3.fromRGB(220, 50, 50), Color3.fromRGB(50, 60, 220),
}

-- Cada canal: texto, color del texto, color del fondo y, opcional, barras de color (carta de ajuste).
local CANALES = {
	[1] = { texto = "SIN SEÑAL", color = COLOR_TEXTO, fondo = COLOR_FONDO },
	[2] = { texto = "CARTA DE AJUSTE", color = Color3.fromRGB(20, 20, 20), fondo = Color3.fromRGB(235, 235, 225), barras = true },
	[3] = { texto = "STAR VIDEOCLUB\n2x1 LOS MARTES\nREBOBINE ANTES DE DEVOLVER", color = Color3.fromRGB(255, 226, 120), fondo = Color3.fromRGB(20, 40, 110) },
	[4] = { texto = "NOTICIERO 23 HS\nSIGUE SIN APARECER DARÍO F.,\nEMPLEADO DE UN VIDEOCLUB", color = Color3.fromRGB(236, 236, 226), fondo = Color3.fromRGB(70, 24, 30) },
	[5] = { texto = "CANAL 9\n- - - - - - - -\nTRANSMISIÓN SUSPENDIDA", color = Color3.fromRGB(170, 170, 160), fondo = Color3.fromRGB(34, 34, 36) },
	[6] = { texto = "SOCIO N° 0000\nESPERA SU CINTA", color = Color3.fromRGB(255, 70, 60), fondo = Color3.fromRGB(8, 6, 6) },
}

local function etiquetaDe(pantalla: Instance): TextLabel?
	for _, d in pantalla:GetDescendants() do
		if d:IsA("TextLabel") then
			return d
		end
	end
	return nil
end

--- Dibuja el canal actual de la pantalla (si está encendida y no está mostrando la cinta).
function Tele.pintar(pantalla: Instance)
	local etiqueta = etiquetaDe(pantalla)
	if not etiqueta then
		return
	end
	local marco = etiqueta.Parent
	-- Las barras de color de la carta de ajuste se arman y se borran cada vez.
	local viejas = marco:FindFirstChild("Barras")
	if viejas then
		viejas:Destroy()
	end

	if pantalla:GetAttribute("Encendida") == false then
		etiqueta.Text = ""
		marco.BackgroundColor3 = Color3.fromRGB(6, 8, 8)
		return
	end
	if pantalla:GetAttribute("Modo") == "CINTA" then
		etiqueta.Text = "▶ REPRODUCIENDO"
		etiqueta.TextColor3 = COLOR_TEXTO
		marco.BackgroundColor3 = COLOR_FONDO
		return
	end
	local canal = CANALES[pantalla:GetAttribute("Canal") or 1] or CANALES[1]
	etiqueta.Text = canal.texto
	etiqueta.TextColor3 = canal.color
	marco.BackgroundColor3 = canal.fondo
	if canal.barras then
		local barras = Instance.new("Frame")
		barras.Name = "Barras"
		barras.BackgroundTransparency = 1
		barras.Size = UDim2.fromScale(1, 0.7)
		barras.Position = UDim2.fromScale(0, 0.3)
		barras.BorderSizePixel = 0
		barras.Parent = marco
		for i, color in BARRAS do
			local b = Instance.new("Frame")
			b.BackgroundColor3 = color
			b.BorderSizePixel = 0
			b.Size = UDim2.fromScale(1 / #BARRAS, 1)
			b.Position = UDim2.fromScale((i - 1) / #BARRAS, 0)
			b.Parent = barras
		end
		etiqueta.ZIndex = 2
	end
end

local function vigilar(pantalla: Instance)
	Tele.pintar(pantalla)
	pantalla:GetAttributeChangedSignal("Canal"):Connect(function()
		-- Al cambiar de canal suena un chasquido de estática (como zapear una tele vieja).
		AudioManager.efecto(Config.Sustos.Glitch.Id, { volumen = Config.Sustos.Glitch.Volumen * 0.8 })
		Tele.pintar(pantalla)
	end)
	pantalla:GetAttributeChangedSignal("Encendida"):Connect(function()
		Tele.pintar(pantalla)
	end)
	pantalla:GetAttributeChangedSignal("Modo"):Connect(function()
		Tele.pintar(pantalla)
	end)
end

function Tele.init()
	for _, pantalla in CollectionService:GetTagged("TV") do
		vigilar(pantalla)
	end
	CollectionService:GetInstanceAddedSignal("TV"):Connect(vigilar)
end

return Tele
