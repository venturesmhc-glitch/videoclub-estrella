--!nonstrict
--[[
	Silueta (cliente): la figura oscura del Socio, un cuerpo humano alto y sin cara. La usan la cinta y las anomalías.
	Silueta.crear(consultable): si es true los raycasts la detectan (para poder "marcarla" con Q).
	El pivote del modelo está a la altura de los pies: PivotTo(CFrame en el piso) la apoya en el piso.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Personajes = require(ReplicatedStorage.Shared.Personajes)

local Silueta = {}

function Silueta.crear(consultable: boolean): Model
	local color = Config.Socio.Color
	local modelo = Personajes.crear({
		piel = color,
		ropa = color,
		pantalon = color,
		sinCara = true,
		escala = Config.Socio.Escala,
	})
	if not modelo then
		return Instance.new("Model") -- sin cuerpo: que el resto del sistema siga andando
	end
	modelo.Name = "Silueta"
	Personajes.convertirEnTitere(modelo, color)
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = consultable
		end
	end
	local raiz = modelo.PrimaryPart
	if raiz then
		raiz.PivotOffset = CFrame.new(0, -(modelo:GetAttribute("AlturaRaiz") or 3), 0)
	end
	Personajes.animar(modelo)
	return modelo
end

return Silueta
