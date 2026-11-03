--!nonstrict
--[[
	Escoba: construye la escoba del local (tamaño normal: unos 5,5 studs de largo entre el palo y las cerdas).
	ChoreSystem la deja apoyada contra la pared del baño y la clona a la mano de quien la toma.
	El modelo queda con el palo (Mango) como PrimaryPart, el eje largo en Y y las cerdas hacia abajo (-Y).
]]

local Config = require(script.Parent.Config)

local Escoba = {}

local function parte(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

--- Arma una escoba centrada en el origen (el centro del palo). Las cerdas llegan hasta Config.Cepillo.AlturaBajo bajo el centro.
function Escoba.construir(): Model
	local cfg = Config.Cepillo
	local largo = cfg.LargoPalo
	local modelo = Instance.new("Model")
	modelo.Name = "Escoba"

	local mango = parte("Mango", Vector3.new(0.2, largo, 0.2), CFrame.new(), Color3.fromRGB(150, 108, 62), Enum.Material.Wood, modelo)
	local piezas = { mango }

	-- Cabezal de madera, banda de alambre y las cerdas (más anchas abajo, como una escoba de verdad).
	local base = CFrame.new(0, -largo / 2 + 0.25, 0)
	table.insert(piezas, parte("Cabezal", Vector3.new(1.35, 0.3, 0.4), base, Color3.fromRGB(118, 82, 48), Enum.Material.Wood, modelo))
	table.insert(piezas, parte("Alambre", Vector3.new(0.34, 0.14, 0.34), CFrame.new(0, -largo / 2 + 0.55, 0), Color3.fromRGB(150, 154, 158), Enum.Material.Metal, modelo))
	table.insert(piezas, parte("CerdasAltas", Vector3.new(1.25, 0.55, 0.38), base * CFrame.new(0, -0.43, 0), Color3.fromRGB(205, 182, 112), Enum.Material.Fabric, modelo))
	table.insert(piezas, parte("CerdasBajas", Vector3.new(1.45, 0.6, 0.44), base * CFrame.new(0, -0.98, 0), Color3.fromRGB(186, 160, 92), Enum.Material.Fabric, modelo))
	-- Un nudo en la punta del palo para colgarla.
	table.insert(piezas, parte("Punta", Vector3.new(0.3, 0.18, 0.3), CFrame.new(0, largo / 2 + 0.05, 0), Color3.fromRGB(110, 76, 44), Enum.Material.Wood, modelo))

	for i = 2, #piezas do
		local soldadura = Instance.new("WeldConstraint")
		soldadura.Part0, soldadura.Part1 = mango, piezas[i]
		soldadura.Parent = piezas[i]
	end
	modelo.PrimaryPart = mango
	return modelo
end

--- Distancia del centro del palo al fondo de las cerdas (para apoyarla en el piso).
function Escoba.alturaCentro(): number
	local cfg = Config.Cepillo
	return cfg.LargoPalo / 2 - 0.25 + 0.98 + 0.3
end

return Escoba
