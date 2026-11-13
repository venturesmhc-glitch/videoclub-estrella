--[[
	Agrupa la decoración del salón en objetos editables. Se corre DESPUÉS de build/videoclub.lua y build/decoracion.lua:
	  node mcp-call.js execute_luau @build/agrupar.lua

	La decoración se arma con muchísimas partes sueltas (la máquina de pochoclos son 79, un ficus son 9...): en Studio no se podía
	seleccionar, mover ni borrar un objeto entero. Esto mete las partes de cada objeto en un Model con nombre (clic = el objeto
	entero; Delete lo borra; las flechas o el gizmo de Mover lo cambian de lugar) y se asegura de que nada esté bloqueado.

	Es idempotente: solo agrupa lo que sigue suelto. OJO: build/decoracion.lua borra y rehace Workspace.Videoclub.Decoracion, así que
	correrlo de nuevo pierde lo que hayas movido o borrado a mano (y obliga a volver a correr este script).
]]

local raiz = workspace:FindFirstChild("Videoclub")
assert(raiz, "Primero hay que correr build/videoclub.lua")
local deco = raiz:FindFirstChild("Decoracion")
assert(deco, "Primero hay que correr build/decoracion.lua")

local creados = {}

-- Mete las partes en un Model con ese nombre (el pivote lo da la parte más grande).
local function modelo(nombre: string, partes: { BasePart }, padre: Instance)
	if #partes == 0 then
		return nil
	end
	local mayor, volumen = partes[1], -1
	for _, p in partes do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > volumen then
			mayor, volumen = p, v
		end
	end
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = padre
	for _, p in partes do
		p.Parent = m
	end
	m.PrimaryPart = mayor
	table.insert(creados, string.format("%s (%d partes)", nombre, #partes))
	return m
end

-- Partes que siguen sueltas dentro de la carpeta (no dentro de otro Model).
local function sueltas(carpeta: Instance, filtro: ((BasePart) -> boolean)?): { BasePart }
	local r = {}
	for _, p in carpeta:GetChildren() do
		if p:IsA("BasePart") and (not filtro or filtro(p)) then
			table.insert(r, p)
		end
	end
	return r
end

-- Agrupa por cercanía: dos partes a menos de `radio` studs son del mismo objeto (se unen las cadenas).
local function grupos(partes: { BasePart }, radio: number): { { BasePart } }
	local g = {}
	for _, p in partes do
		local unidos = {}
		for i, grupo in g do
			for _, q in grupo do
				if (p.Position - q.Position).Magnitude < radio then
					table.insert(unidos, i)
					break
				end
			end
		end
		local nuevo = { p }
		for k = #unidos, 1, -1 do
			for _, q in g[unidos[k]] do
				table.insert(nuevo, q)
			end
			table.remove(g, unidos[k])
		end
		table.insert(g, nuevo)
	end
	table.sort(g, function(a, b)
		return a[1].Position.X < b[1].Position.X
	end)
	return g
end

local function porCercania(carpeta: Instance, filtro: (BasePart) -> boolean, radio: number, nombre: string)
	for i, g in grupos(sueltas(carpeta, filtro), radio) do
		modelo(nombre .. " " .. i, g, carpeta)
	end
end

local function empieza(prefijo: string)
	return function(p: BasePart)
		return string.sub(p.Name, 1, #prefijo) == prefijo
	end
end

-- ===== Pochoclos: la máquina entera, y el cartel aparte (para poder moverlo solo) =====
local pochoclos = deco:FindFirstChild("Pochoclos")
if pochoclos then
	for _, p in sueltas(pochoclos, function(p)
		return p.Name == "Cartel"
	end) do
		p.Name = "CartelPochoclos"
	end
	modelo("MaquinaDePochoclos", sueltas(pochoclos, function(p)
		return p.Name ~= "CartelPochoclos"
	end), pochoclos)
end

-- ===== Torre de televisores =====
local torre = deco:FindFirstChild("TorreTV")
if torre then
	modelo("TorreDeTelevisores", sueltas(torre), torre)
end

-- ===== Sala de espera: sofá, banco, mesa baja y lámpara. Revistas y almohadones van con lo que tengan más cerca. =====
local espera = deco:FindFirstChild("SalaDeEspera")
if espera then
	local familias = {
		{ "Sofa", function(p) return empieza("Sofa")(p) end },
		{ "Banco", function(p) return empieza("Banco")(p) end },
		{ "MesaBaja", function(p) return empieza("Mesa")(p) end },
		{ "Lampara", function(p) return empieza("Lampara")(p) end },
	}
	local por = {}
	for _, f in familias do
		por[f[1]] = sueltas(espera, f[2])
	end
	for _, suelta in sueltas(espera, function(p) return p.Name == "Revista" or p.Name == "Almohadon" end) do
		local mejor, distancia = nil, math.huge
		for nombre, lista in por do
			for _, q in lista do
				local d = (q.Position - suelta.Position).Magnitude
				if d < distancia then
					mejor, distancia = nombre, d
				end
			end
		end
		if mejor then
			table.insert(por[mejor], suelta)
		end
	end
	for _, f in familias do
		modelo(f[1], por[f[1]], espera)
	end
end

-- ===== Varios: bebedero, reloj y matafuegos =====
local varios = deco:FindFirstChild("Varios")
if varios then
	modelo("Bebedero", sueltas(varios, empieza("Bebedero")), varios)
	modelo("Reloj", sueltas(varios, empieza("Reloj")), varios)
	porCercania(varios, empieza("Matafuego"), 3, "Matafuego")
end

-- ===== Figuras: ficus, exhibidores giratorios y figuras de cartón =====
local figuras = deco:FindFirstChild("Figuras")
if figuras then
	porCercania(figuras, empieza("Ficus"), 4, "Ficus")
	porCercania(figuras, empieza("Exhibidor"), 6, "ExhibidorGiratorio")
	porCercania(figuras, empieza("Figura"), 4, "FiguraDeCarton")
end

-- ===== Props de ofertas: planta y cartel =====
local props = raiz:FindFirstChild("Props")
if props then
	modelo("PlantaDeOfertas", sueltas(props, function(p) return p.Name:find("Planta") ~= nil end), props)
	modelo("CartelDeOferta", sueltas(props, function(p) return p.Name:find("CartelOferta") ~= nil end), props)
end

-- ===== Arcades: ya son Models, solo falta el pivote =====
local arcades = deco:FindFirstChild("Arcades")
if arcades then
	for _, m in arcades:GetChildren() do
		if m:IsA("Model") and not m.PrimaryPart then
			local mayor, volumen = nil, -1
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and p.Size.X * p.Size.Y * p.Size.Z > volumen then
					mayor, volumen = p, p.Size.X * p.Size.Y * p.Size.Z
				end
			end
			m.PrimaryPart = mayor
		end
	end
end

-- ===== Que nada esté bloqueado =====
local desbloqueadas = 0
for _, p in raiz:GetDescendants() do
	if p:IsA("BasePart") and p.Locked then
		p.Locked = false
		desbloqueadas += 1
	end
end

print(string.format("[agrupar] %d objetos agrupados, %d partes desbloqueadas", #creados, desbloqueadas))
return table.concat(creados, "\n") .. "\ndesbloqueadas: " .. desbloqueadas
