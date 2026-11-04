--!nonstrict
--[[
	Filtro (cliente): el filtro de cinta que el jugador compró y tiene puesto en la tienda (blanco y negro, 8 mm, sepia).
	Es una corrección de color sobre toda la imagen (Config.Filtros). El perfil llega por ProfileLoaded
	(equipado.filtro); sin filtro no queda ningún efecto puesto.

	  Filtro.poner(nombre?)   -- "bn" | "8mm" | "sepia" | nil
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Filtro = {}

local efecto
local actual

function Filtro.poner(nombre: string?)
	if nombre == actual then
		return
	end
	actual = nombre
	local ajustes = nombre and Config.Filtros[nombre]
	if not ajustes then
		if efecto then
			efecto:Destroy()
			efecto = nil
		end
		return
	end
	if not efecto then
		efecto = Instance.new("ColorCorrectionEffect")
		efecto.Name = "FiltroTienda"
		efecto.Parent = Lighting
	end
	efecto.Saturation = ajustes.Saturation
	efecto.Contrast = ajustes.Contrast
	efecto.Brightness = ajustes.Brightness
	efecto.TintColor = ajustes.TintColor
end

function Filtro.init()
	Net.obtener("ProfileLoaded").OnClientEvent:Connect(function(perfil)
		if typeof(perfil) == "table" then
			local equipado = typeof(perfil.equipado) == "table" and perfil.equipado or {}
			Filtro.poner(equipado.filtro)
		end
	end)
end

return Filtro
