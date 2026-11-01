--!nonstrict
--[[
	Autos: arma un auto simple hecho con partes (carrocería, cabina, ruedas, faros y luces traseras).
	Lo usan el builder del mapa (el auto estacionado frente al motel) y Calle (los autos que pasan por la ruta).
	El auto mira hacia +X: para que vaya hacia -X se lo gira 180° sobre Y. El pivote del modelo está a la altura de las ruedas.

	  Autos.crear(color, opciones?) -> Model   opciones: { largo?, conFaros? }
]]

local Autos = {}

local function parte(modelo, nombre, tamano, cframe, color, material, extra)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tamano
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in extra or {} do
		p[k] = v
	end
	p.Parent = modelo
	return p
end

function Autos.crear(color: Color3, opciones)
	opciones = opciones or {}
	local largo = opciones.largo or 9
	local mitad = largo / 2
	local modelo = Instance.new("Model")
	modelo.Name = "Auto"

	local origen = CFrame.new(0, 0, 0)
	local carroceria = parte(modelo, "Carroceria", Vector3.new(largo, 1.5, 4.4), origen * CFrame.new(0, 1.85, 0), color, Enum.Material.Metal, { Reflectance = 0.15 })
	modelo.PrimaryPart = carroceria
	-- El punto de pivote queda en el piso (debajo de las ruedas), no en el centro de la carrocería: así PivotTo(y = altura del
	-- asfalto) apoya el auto sobre el camino en vez de hundirlo.
	carroceria.PivotOffset = CFrame.new(0, -1.85, 0)
	-- Cabina con vidrios oscuros.
	parte(modelo, "Cabina", Vector3.new(largo * 0.5, 1.3, 3.9), origen * CFrame.new(-largo * 0.07, 3.2, 0), Color3.fromRGB(30, 36, 42), Enum.Material.Glass, { Transparency = 0.15 })
	parte(modelo, "Techo", Vector3.new(largo * 0.46, 0.15, 3.8), origen * CFrame.new(-largo * 0.07, 3.9, 0), color, Enum.Material.Metal)
	-- Parachoques.
	parte(modelo, "ParachoquesDelantero", Vector3.new(0.4, 0.5, 4.6), origen * CFrame.new(mitad + 0.1, 1.3, 0), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	parte(modelo, "ParachoquesTrasero", Vector3.new(0.4, 0.5, 4.6), origen * CFrame.new(-mitad - 0.1, 1.3, 0), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	-- Ruedas (cilindros con el eje a lo ancho del auto).
	for _, dx in { -mitad * 0.62, mitad * 0.62 } do
		for _, dz in { -2.25, 2.25 } do
			local rueda = parte(modelo, "Rueda", Vector3.new(0.8, 2, 2), origen * CFrame.new(dx, 1, dz) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(18, 18, 20), Enum.Material.Rubber)
			rueda.Shape = Enum.PartType.Cylinder
			parte(modelo, "Llanta", Vector3.new(0.85, 1.1, 1.1), origen * CFrame.new(dx, 1, dz) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(170, 170, 170), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
		end
	end
	-- Faros y luces traseras.
	for _, dz in { -1.5, 1.5 } do
		local faro = parte(modelo, "Faro", Vector3.new(0.2, 0.55, 0.9), origen * CFrame.new(mitad + 0.02, 1.95, dz), Color3.fromRGB(255, 244, 205), Enum.Material.Neon)
		parte(modelo, "LuzTrasera", Vector3.new(0.2, 0.5, 0.9), origen * CFrame.new(-mitad - 0.02, 1.95, dz), Color3.fromRGB(230, 30, 30), Enum.Material.Neon)
		if opciones.conFaros ~= false and dz == 1.5 then
			local haz = Instance.new("SpotLight")
			haz.Face = Enum.NormalId.Right
			haz.Range = 38
			haz.Angle = 75
			haz.Brightness = 1.3
			haz.Color = Color3.fromRGB(255, 240, 205)
			haz.Shadows = false
			haz.Parent = faro
		end
	end
	return modelo
end

return Autos
