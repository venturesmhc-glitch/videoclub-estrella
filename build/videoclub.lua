--[[
	Construye (o reconstruye) el greybox del Videoclub Estrella en Workspace.Videoclub.
	Es idempotente: borra solo lo que construyó antes (Workspace.Videoclub) y lo vuelve a crear.
	Ejecutar con:  node mcp-call.js execute_luau @build/videoclub.lua

	Medidas en studs. El piso interior tiene su cara superior en y = 0.
	Local de ventas: x -24..24, z -12..26 (entrada por z = +26; el frente se corrió 6 studs para dar aire al mostrador y a los props).
	Fondo: depósito (x -24..6.5) y baño (x 7.5..24), z -20..-12.
	Cocina (x -52..-25) y patio (x 25..52), z -21..-1: se entra por puertas en las paredes laterales (z -11.5..-8).
]]

local CollectionService = game:GetService("CollectionService")

local V3, C3 = Vector3.new, Color3.fromRGB
local rng = Random.new(1997)

local viejo = workspace:FindFirstChild("Videoclub")
if viejo then
	viejo:Destroy()
end

local raiz = Instance.new("Model")
raiz.Name = "Videoclub"

local ALTURA = 12
local GROSOR = 1
local Z_FRENTE = 26.5 -- eje de la pared del frente (la cara interior queda en z = 26)

-- ===== Utilidades =====

local function carpeta(nombre, padre)
	local f = Instance.new("Folder")
	f.Name = nombre
	f.Parent = padre or raiz
	return f
end

local function parte(nombre, tam, pos, color, material, padre, extra)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	-- Materiales PBR generados (MaterialService.AssistantMaterials): madera vieja en todo lo que era Wood.
	if p.Material == Enum.Material.Wood then
		p.Material = Enum.Material.WoodPlanks
		p.MaterialVariant = "MaderaVieja"
	end
	p.CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	p.Parent = padre
	return p
end

-- Decoración que no debe frenar al jugador ni a los raycasts.
local DECO = { CanCollide = false, CanTouch = false, CanQuery = false }

local function texto(parteBase, cara, contenido, fuente, colorTexto, colorFondo)
	local sg = Instance.new("SurfaceGui")
	sg.Face = cara
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.Parent = parteBase
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = colorFondo or Color3.new(0, 0, 0)
	fondo.BackgroundTransparency = colorFondo and 0 or 1
	fondo.BorderSizePixel = 0
	fondo.Parent = sg
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.92, 0.8)
	t.Position = UDim2.fromScale(0.04, 0.1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = fuente or Enum.Font.Arcade
	t.TextColor3 = colorTexto or C3(240, 240, 230)
	t.Text = contenido
	t.Parent = fondo
	return t
end

-- Juntas de azulejos: líneas finas sobre una cara, cada "paso" studs (SurfaceGui, sin partes extra).
local function grilla(p, cara, paso, color)
	local ancho, alto
	if cara == Enum.NormalId.Front or cara == Enum.NormalId.Back then
		ancho, alto = p.Size.X, p.Size.Y
	elseif cara == Enum.NormalId.Left or cara == Enum.NormalId.Right then
		ancho, alto = p.Size.Z, p.Size.Y
	else
		ancho, alto = p.Size.X, p.Size.Z
	end
	local PPS = 16
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Grilla"
	sg.Face = cara
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = PPS
	sg.Parent = p
	local function linea(x, y, w, h)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 0.25
		f.BorderSizePixel = 0
		f.Parent = sg
	end
	for i = 0, math.floor(ancho / paso) do
		linea(i * paso * PPS, 0, 2, alto * PPS)
	end
	for j = 0, math.floor(alto / paso) do
		linea(0, j * paso * PPS, ancho * PPS, 2)
	end
end

-- Muro con aberraciones. eje "X": corre a lo largo de x en z = fijo; eje "Z": a lo largo de z en x = fijo.
-- aberturas: { {a, b, y0, y1}, ... } ordenadas por a.
-- variante: material PBR de la pared (por defecto pintura prolija; el cerco del patio usa el yeso viejo).
local function muro(nombre, eje, fijo, desde, hasta, aberturas, color, padre, variante)
	local function seg(a, b, y0, y1)
		if b - a <= 0.001 or y1 - y0 <= 0.001 then
			return
		end
		local tam, pos
		if eje == "X" then
			tam = V3(b - a, y1 - y0, GROSOR)
			pos = V3((a + b) / 2, (y0 + y1) / 2, fijo)
		else
			tam = V3(GROSOR, y1 - y0, b - a)
			pos = V3(fijo, (y0 + y1) / 2, (a + b) / 2)
		end
		parte(nombre, tam, pos, color, Enum.Material.Plaster, padre, { MaterialVariant = variante or "ParedLimpia" })
	end
	local cursor = desde
	for _, o in aberturas do
		seg(cursor, o[1], 0, ALTURA)
		seg(o[1], o[2], 0, o[3])
		seg(o[1], o[2], o[4], ALTURA)
		cursor = o[2]
	end
	seg(cursor, hasta, 0, ALTURA)
end

local function vidrio(nombre, eje, fijo, a, b, y0, y1, padre, transparencia)
	local ancho, alto = b - a, y1 - y0
	local tam = eje == "X" and V3(ancho, alto, 0.2) or V3(0.2, alto, ancho)
	local pos = eje == "X" and V3((a + b) / 2, (y0 + y1) / 2, fijo) or V3(fijo, (y0 + y1) / 2, (a + b) / 2)
	return parte(nombre, tam, pos, C3(150, 190, 200), Enum.Material.Glass, padre, { Transparency = transparencia or 0.7 })
end

local function tubo(nombre, x, z, encendida, defectuoso, padre)
	local t = parte(nombre, V3(4.5, 0.25, 0.9), V3(x, ALTURA - 0.45, z), C3(235, 245, 230), Enum.Material.Neon, padre, DECO)
	CollectionService:AddTag(t, "Tubo")
	if defectuoso then
		CollectionService:AddTag(t, "TuboDefectuoso")
	end
	if encendida then
		local luz = Instance.new("SurfaceLight")
		luz.Face = Enum.NormalId.Bottom
		luz.Angle = 160
		luz.Range = 18
		luz.Brightness = 1.7
		luz.Color = C3(225, 255, 235)
		luz.Shadows = true -- las góndolas y el mostrador proyectan sombra
		luz.Parent = t
	end
	return t
end

-- ===== Paleta =====

local COL_PARED = C3(222, 212, 190)
local COL_PARED_FONDO = C3(196, 202, 196)
local COL_MADERA = C3(96, 66, 42)
local COL_MADERA_OSC = C3(64, 44, 30)

-- Colores de las cajas de casete según el género del pasillo.
local PALETAS = {
	ACCION = { C3(160, 40, 36), C3(30, 30, 34), C3(210, 130, 30), C3(60, 70, 90) },
	TERROR = { C3(20, 20, 22), C3(70, 18, 24), C3(40, 50, 42), C3(90, 88, 70) },
	COMEDIA = { C3(220, 190, 50), C3(60, 150, 200), C3(210, 100, 40), C3(230, 230, 225) },
	DRAMA = { C3(110, 70, 90), C3(60, 80, 110), C3(150, 140, 120), C3(40, 40, 46) },
	INFANTIL = { C3(230, 80, 90), C3(80, 190, 120), C3(70, 130, 220), C3(240, 200, 60) },
}

-- ===== Estructura =====

local estructura = carpeta("Estructura")
local pisos = carpeta("Piso", estructura)

-- Calle oscura que rodea el local (se ve por las ventanas).
parte("Calle", V3(400, 1, 400), V3(0, -1.05, 0), C3(24, 26, 28), Enum.Material.Asphalt, estructura)

-- Piso: baldosas de 4x4 en damero.
for ix = 0, 11 do
	for iz = 0, 10 do
		local x = -24 + ix * 4 + 2
		local z = -20 + iz * 4 + 2
		local fondo = z < -12
		local claro = (ix + iz) % 2 == 0
		local color
		if fondo then
			color = claro and C3(150, 152, 146) or C3(120, 122, 116)
		else
			color = claro and C3(160, 178, 164) or C3(116, 134, 122)
		end
		parte("Baldosa", V3(4, 1, 4), V3(x, -0.5, z), color, Enum.Material.CeramicTiles, pisos, { MaterialVariant = "SueloBaldosas" })
	end
	-- Última fila (z 24..26): baldosas de 4x2 para llegar justo a la pared del frente.
	local claro = (ix + 11) % 2 == 0
	parte("Baldosa", V3(4, 1, 2), V3(-24 + ix * 4 + 2, -0.5, 25), claro and C3(96, 108, 98) or C3(70, 82, 74), Enum.Material.SmoothPlastic, pisos)
end

parte("Techo", V3(50, 1, 48), V3(0, ALTURA + 0.5, 3), C3(196, 192, 180), Enum.Material.SmoothPlastic, estructura)

local muros = carpeta("Muros", estructura)
local VIDRIOS = carpeta("Vidrios", estructura)

-- Frente (z = Z_FRENTE): puerta central y dos ventanas.
muro("MuroFrente", "X", Z_FRENTE, -24.5, 24.5, {
	{ -22, -8, 3, 9 },
	{ -3, 3, 0, 9 },
	{ 9, 22, 3, 9 },
}, COL_PARED, muros)
vidrio("VentanaIzquierda", "X", Z_FRENTE, -22, -8, 3, 9, VIDRIOS)
vidrio("VentanaDerecha", "X", Z_FRENTE, 9, 22, 3, 9, VIDRIOS)
local puerta = vidrio("PuertaEntrada", "X", Z_FRENTE, -3, 3, 0, 9, VIDRIOS, 0.55)
puerta:SetAttribute("Cerrada", true) -- turno noche: la puerta no se abre
parte("PuertaMarcoIzq", V3(0.3, 9, 0.5), V3(-3, 4.5, Z_FRENTE), C3(30, 30, 32), Enum.Material.Metal, estructura)
parte("PuertaMarcoDer", V3(0.3, 9, 0.5), V3(3, 4.5, Z_FRENTE), C3(30, 30, 32), Enum.Material.Metal, estructura)

-- Vereda: pequeño recinto invisible afuera de la puerta, para que los clientes entren y salgan
-- sin que nadie pueda irse caminando por la calle.
local barreras = carpeta("Barreras", estructura)
local INVISIBLE = { Transparency = 1, CanQuery = false, CanTouch = false }
parte("BarreraIzquierda", V3(0.5, 10, 6), V3(-4.75, 5, Z_FRENTE + 3.25), C3(255, 255, 255), nil, barreras, INVISIBLE)
parte("BarreraDerecha", V3(0.5, 10, 6), V3(4.75, 5, Z_FRENTE + 3.25), C3(255, 255, 255), nil, barreras, INVISIBLE)
parte("BarreraFrente", V3(10, 10, 0.5), V3(0, 5, Z_FRENTE + 6.25), C3(255, 255, 255), nil, barreras, INVISIBLE)

-- Laterales.
muro("MuroIzquierdo", "Z", -24.5, -20.5, Z_FRENTE, { { -11.5, -8, 0, 8.5 } }, COL_PARED, muros) -- puerta a la cocina
muro("MuroDerecho", "Z", 24.5, -20.5, Z_FRENTE, { { -11.5, -8, 0, 8.5 } }, COL_PARED, muros) -- puerta al patio

-- Fondo (z = -20.5) y pared divisoria entre local y fondo (z = -12.5), con puertas al depósito y al baño.
-- El fondo del depósito es un tramo aparte: en la noche 4 se oculta y el depósito se alarga.
muro("MuroFondoDeposito", "X", -20.5, -24.5, 7, {}, COL_PARED_FONDO, muros)
muro("MuroFondoBano", "X", -20.5, 7, 24.5, {}, COL_PARED_FONDO, muros)
for _, p in muros:GetChildren() do
	if p.Name == "MuroFondoDeposito" then
		CollectionService:AddTag(p, "MuroFondoDeposito")
	end
end
muro("MuroDivisorio", "X", -12.5, -24.5, 24.5, {
	{ -8, -4, 0, 8.5 }, -- puerta al depósito
	{ 14, 18, 0, 8.5 }, -- puerta al baño
}, COL_PARED, muros)
-- Pared entre depósito y baño.
muro("MuroDepositoBano", "Z", 7, -20.5, -12.5, {}, COL_PARED_FONDO, muros)

-- ===== Iluminación del local =====

local luces = carpeta("Luces", estructura)
local ix = 0
local defectuosos = { ["-12,-7"] = true, ["20,7"] = true, ["-4,15"] = true }
for _, x in { -20, -12, -4, 4, 12, 20 } do
	local iz = 0
	for _, z in { -7, 0, 7, 15, 22 } do
		local encendida = (ix + iz) % 2 == 0
		tubo("Tubo", x, z, encendida, defectuosos[x .. "," .. z] == true, luces)
		iz += 1
	end
	ix += 1
end
tubo("Tubo", -14, -16, true, false, luces) -- depósito
tubo("Tubo", -2, -16, true, false, luces) -- depósito
tubo("Tubo", 15, -16, true, true, luces) -- baño

-- ===== Mostrador =====
-- Largo (x -18..7.5): a la izquierda la tele y la videocasetera (bien separadas), en el medio el lugar de
-- atención y la caja, a la derecha las fichas, el contestador y el teléfono. Así los prompts de cada
-- estación no se pisan. El mostrador está 6 studs más adelante que antes: queda lugar para circular
-- entre las góndolas y el mostrador.

local mostrador = carpeta("Mostrador")
local Z_MOSTRADOR = 16
local M_X0, M_X1 = -18, 7.5
local M_LARGO, M_CENTRO = M_X1 - M_X0, (M_X0 + M_X1) / 2
local LATERAL_X = M_X0 + 1
parte("MostradorCuerpo", V3(M_LARGO, 3.5, 2), V3(M_CENTRO, 1.75, Z_MOSTRADOR), COL_MADERA, Enum.Material.Wood, mostrador)
parte("MostradorTapa", V3(M_LARGO + 1, 0.3, 3), V3(M_CENTRO, 3.65, Z_MOSTRADOR), C3(190, 180, 160), Enum.Material.SmoothPlastic, mostrador)
-- Lateral izquierdo: cierra el lado de los empleados. Empieza en z 7, así queda un paso de 4 studs entre
-- el final de la góndola de ACCIÓN (z 3, con su punto de uso en z 3.9) y el mostrador.
local LAT_Z0, LAT_Z1 = 7, Z_MOSTRADOR - 1
parte("MostradorLateral", V3(2, 3.5, LAT_Z1 - LAT_Z0), V3(LATERAL_X, 1.75, (LAT_Z0 + LAT_Z1) / 2), COL_MADERA, Enum.Material.Wood, mostrador)
parte("MostradorLateralTapa", V3(3, 0.3, LAT_Z1 - LAT_Z0 + 1), V3(LATERAL_X, 3.65, (LAT_Z0 + LAT_Z1) / 2), C3(190, 180, 160), Enum.Material.SmoothPlastic, mostrador)
-- Tablones verticales en el frente (lado de los clientes) y zócalo oscuro.
for i = 0, 12 do
	parte("MostradorTablon", V3(0.12, 3.1, 0.1), V3(M_X0 + 1 + i * 2, 1.9, Z_MOSTRADOR + 1.05), COL_MADERA_OSC, Enum.Material.Wood, mostrador, DECO)
end
parte("MostradorZocalo", V3(M_LARGO, 0.35, 0.12), V3(M_CENTRO, 0.2, Z_MOSTRADOR + 1.05), C3(30, 24, 20), Enum.Material.Wood, mostrador, DECO)

-- Tele CRT: pantalla hacia el lado del empleado (hacia -Z).
local TV_X = -15.8
local tv = Instance.new("Model")
tv.Name = "TV_Mostrador"
tv.Parent = mostrador
parte("CuerpoTV", V3(2.8, 2.4, 2), V3(TV_X, 4.95, Z_MOSTRADOR), C3(60, 58, 54), Enum.Material.Plastic, tv)
parte("BaseTV", V3(2.2, 0.2, 1.6), V3(TV_X, 3.9, Z_MOSTRADOR), C3(40, 40, 38), Enum.Material.Plastic, tv)
local pantalla = parte("Pantalla", V3(2.1, 1.7, 0.1), V3(TV_X, 5.1, Z_MOSTRADOR - 1.0), C3(18, 24, 22), Enum.Material.SmoothPlastic, tv)
CollectionService:AddTag(pantalla, "TV")
texto(pantalla, Enum.NormalId.Front, "SIN SEÑAL", Enum.Font.Code, C3(150, 190, 170), C3(16, 22, 20))
local luzTV = Instance.new("SurfaceLight")
luzTV.Face = Enum.NormalId.Front
luzTV.Range = 14
luzTV.Brightness = 0.9
luzTV.Angle = 120
luzTV.Color = C3(150, 190, 220)
luzTV.Shadows = true
luzTV.Parent = pantalla

-- Videocasetera al lado de la tele (estación de rebobinado).
local VCR_X = -11
local vcr = parte("Videocasetera", V3(2.8, 0.5, 1.8), V3(VCR_X, 3.95, Z_MOSTRADOR), C3(22, 22, 24), Enum.Material.Plastic, mostrador)
parte("VCR_Ranura", V3(1.8, 0.12, 0.05), V3(VCR_X, 3.98, Z_MOSTRADOR - 0.92), C3(8, 8, 8), Enum.Material.SmoothPlastic, mostrador)
parte("VCR_Display", V3(0.5, 0.12, 0.05), V3(VCR_X + 0.9, 4.1, Z_MOSTRADOR - 0.92), C3(60, 255, 120), Enum.Material.Neon, mostrador)
CollectionService:AddTag(vcr, "Videocasetera")

-- Zona de atención: x ~ -4.2, libre a los dos lados. Los clientes dejan acá los casetes.
local caja = parte("CajaRegistradora", V3(1.8, 1, 1.5), V3(-1, 4.3, Z_MOSTRADOR + 0.3), C3(200, 190, 160), Enum.Material.Metal, mostrador)
parte("CajaDisplay", V3(1.1, 0.4, 0.1), V3(-1, 5, Z_MOSTRADOR - 0.2), C3(40, 255, 140), Enum.Material.Neon, mostrador)
CollectionService:AddTag(caja, "CajaRegistradora")
local fichas = parte("FichasSocios", V3(1, 0.7, 1.4), V3(1.6, 4.1, Z_MOSTRADOR + 0.4), C3(180, 150, 90), Enum.Material.Cardboard, mostrador)
local contestador = parte("Contestador", V3(1.2, 0.4, 1), V3(3.6, 3.95, Z_MOSTRADOR + 0.6), C3(30, 30, 32), Enum.Material.Plastic, mostrador)
local telefono = parte("Telefono", V3(1, 0.5, 1.2), V3(5.8, 4.05, Z_MOSTRADOR + 0.4), C3(110, 24, 30), Enum.Material.Plastic, mostrador)
parte("TelefonoAuricular", V3(1.3, 0.25, 0.35), V3(5.8, 4.4, Z_MOSTRADOR + 0.4), C3(90, 18, 24), Enum.Material.Plastic, mostrador)
CollectionService:AddTag(telefono, "Telefono")

-- Punto invisible donde se atiende (el prompt "Atender" lo crea CustomerSystem).
local puntoMostrador = parte("PuntoMostrador", V3(1, 1, 1), V3(-4.2, 4.6, Z_MOSTRADOR - 0.6), C3(255, 255, 255), nil, mostrador, {
	Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false,
})
CollectionService:AddTag(puntoMostrador, "PuntoMostrador")

-- Caja donde se separan las cintas dañadas: contra el lateral del mostrador, al lado de la videocasetera
-- (el recorrido de rebobinar -> separar queda corto) y fuera del camino entre las góndolas y el mostrador.
local CD_X, CD_Z = LATERAL_X + 1.9, Z_MOSTRADOR - 4
local cajaDanadas = parte("CajaDanadas", V3(1.3, 1.5, 1.3), V3(CD_X, 0.75, CD_Z), C3(150, 40, 36), Enum.Material.Plastic, mostrador)
CollectionService:AddTag(cajaDanadas, "CajaDanadas")
parte("CajaDanadasTapa", V3(1.5, 0.15, 1.5), V3(CD_X, 1.58, CD_Z), C3(110, 28, 26), Enum.Material.Plastic, mostrador, DECO)
parte("CajaDanadasRanura", V3(0.9, 0.05, 0.12), V3(CD_X, 1.67, CD_Z), C3(10, 10, 10), Enum.Material.SmoothPlastic, mostrador, DECO)
for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
	texto(cajaDanadas, cara, "DAÑADAS", Enum.Font.Arcade, C3(245, 240, 220))
end

-- ===== Ranura de devoluciones (al lado de la puerta, sobre el frente) =====

local devol = carpeta("Devoluciones")
local bin = parte("CajaDevoluciones", V3(3, 2.6, 1.8), V3(6, 1.3, Z_FRENTE - 1.4), C3(70, 84, 98), Enum.Material.Metal, devol)
CollectionService:AddTag(bin, "RanuraDevoluciones")
parte("RanuraInterior", V3(2, 0.25, 0.15), V3(6, 3.5, Z_FRENTE - 0.45), C3(10, 10, 10), Enum.Material.SmoothPlastic, devol, DECO)
parte("RanuraExterior", V3(2, 0.25, 0.15), V3(6, 3.5, Z_FRENTE + 0.55), C3(10, 10, 10), Enum.Material.SmoothPlastic, devol, DECO)
local cartel = parte("CartelDevoluciones", V3(2.6, 0.7, 0.1), V3(6, 4.3, Z_FRENTE - 0.55), C3(230, 220, 190), Enum.Material.SmoothPlastic, devol, DECO)
texto(cartel, Enum.NormalId.Back, "DEVOLUCIONES", Enum.Font.Arcade, C3(30, 30, 30))

-- ===== Góndolas (pasillos por género) =====

local GENEROS = {
	{ x = -16, nombre = "ACCIÓN", clave = "ACCION" },
	{ x = -8, nombre = "TERROR", clave = "TERROR" },
	{ x = 0, nombre = "COMEDIA", clave = "COMEDIA" },
	{ x = 8, nombre = "DRAMA", clave = "DRAMA" },
	{ x = 16, nombre = "INFANTIL", clave = "INFANTIL" },
}
local Z_DESDE, Z_HASTA = -9, 3
local LARGO = Z_HASTA - Z_DESDE
local FILAS = 4
local PASO_FILA = 1.35

local gondolas = carpeta("Gondolas")

-- Formato de todos los VHS del local (góndolas, estantes de pared, depósito y las cintas que se llevan en la
-- mano): carcasa oscura con una etiqueta de color. Acá los de las góndolas, de frente (carátula hacia el pasillo).
local COL_VHS = { C3(22, 22, 24), C3(34, 30, 30), C3(28, 34, 44), C3(50, 28, 28), C3(40, 40, 44), C3(18, 26, 22) }

local function aleatorio(lista)
	return lista[rng:NextInteger(1, #lista)]
end

-- `hacia`: -1 o 1, el lado (en x) hacia el que mira la carátula.
local function cajaCasete(padre, x, y, z, paleta, genero, hacia)
	local c = paleta[rng:NextInteger(1, #paleta)]
	local k = rng:NextNumber(0.85, 1.1)
	parte("Casete", V3(0.3, 1.1, 0.8), V3(x, y, z), aleatorio(COL_VHS), Enum.Material.SmoothPlastic, padre, DECO)
	parte("CasetEtiqueta", V3(0.02, 0.82, 0.6), V3(x + hacia * 0.16, y + 0.05, z), C3(c.R * 255 * k, c.G * 255 * k, c.B * 255 * k), Enum.Material.SmoothPlastic, padre, DECO)
end

-- Portada: casete con título legible y que se puede apuntar (CanQuery). AnomalySystem la altera
-- del lado del cliente (título cambiado, carátula alterada). El id es estable para que cliente y
-- servidor generen las mismas anomalías a partir de la misma semilla.
local Catalogo = require(game.ReplicatedStorage.Shared.Catalogo)
local function portada(padre, g, lado, y, z, fila, col)
	local p = parte("Portada", V3(0.3, 1.1, 0.8), V3(g.x + lado * 0.85, y, z), aleatorio(COL_VHS), Enum.Material.SmoothPlastic, padre, {
		CanCollide = false, CanTouch = false,
	})
	local titulo = Catalogo.tituloAleatorio(g.clave, rng)
	p:SetAttribute("PortadaId", string.format("P_%s_%d_%d_%d", g.clave, lado, fila, col))
	p:SetAttribute("Genero", g.clave)
	p:SetAttribute("TituloOriginal", titulo)
	CollectionService:AddTag(p, "Portada")
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Etiqueta"
	gui.Face = lado < 0 and Enum.NormalId.Left or Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.Parent = p
	local papel = Instance.new("Frame")
	papel.Name = "Papel"
	papel.Size = UDim2.fromScale(0.86, 0.5)
	papel.Position = UDim2.fromScale(0.07, 0.1)
	papel.BackgroundColor3 = C3(232, 226, 205)
	papel.BorderSizePixel = 0
	papel.Parent = gui
	local t = Instance.new("TextLabel")
	t.Name = "Titulo"
	t.Size = UDim2.fromScale(0.92, 0.88)
	t.Position = UDim2.fromScale(0.04, 0.06)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.SourceSansBold
	t.TextColor3 = C3(30, 28, 26)
	t.Text = titulo
	t.Parent = papel
end

for _, g in GENEROS do
	local pasillo = carpeta("Pasillo_" .. g.clave, gondolas)
	pasillo:SetAttribute("Genero", g.clave)
	local zc = (Z_DESDE + Z_HASTA) / 2
	parte("Cuerpo", V3(1.4, 6.3, LARGO), V3(g.x, 3.15, zc), COL_MADERA, Enum.Material.Wood, pasillo)
	parte("Tope", V3(2.2, 0.2, LARGO + 0.2), V3(g.x, 6.4, zc), COL_MADERA_OSC, Enum.Material.Wood, pasillo, DECO)
	for fila = 1, FILAS do
		local y = 1.35 + (fila - 1) * PASO_FILA
		parte("Repisa", V3(2.2, 0.12, LARGO), V3(g.x, y - 0.6, zc), COL_MADERA_OSC, Enum.Material.Wood, pasillo, DECO)
		for col = 0, LARGO - 1 do
			local z = Z_DESDE + col + 0.5
			local esPortada = (fila == 2 or fila == 3) and (col == 1 or col == 4 or col == 7 or col == 10)
			if esPortada then
				portada(pasillo, g, -1, y, z, fila, col)
				portada(pasillo, g, 1, y, z, fila, col)
			else
				cajaCasete(pasillo, g.x - 0.85, y, z, PALETAS[g.clave], g.clave, -1)
				cajaCasete(pasillo, g.x + 0.85, y, z, PALETAS[g.clave], g.clave, 1)
			end
		end
	end

	-- Cartel colgante con el género (se lee desde el mostrador y desde el fondo).
	local cartelG = parte("Cartel_" .. g.clave, V3(6, 1.4, 0.2), V3(g.x, 9.6, Z_HASTA + 0.6), C3(30, 28, 26), Enum.Material.SmoothPlastic, pasillo)
	texto(cartelG, Enum.NormalId.Back, g.nombre, Enum.Font.Arcade, C3(240, 220, 120))
	texto(cartelG, Enum.NormalId.Front, g.nombre, Enum.Font.Arcade, C3(240, 220, 120))
	-- Punto invisible de la góndola: el prompt "Usar góndola" lo crea TaskSystem.
	local puntoGondola = parte("PuntoGondola", V3(1.2, 1.2, 1.2), V3(g.x, 3.4, Z_HASTA + 0.9), C3(255, 255, 255), nil, pasillo, {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false,
	})
	puntoGondola:SetAttribute("Genero", g.clave)
	CollectionService:AddTag(puntoGondola, "PuntoGondola")

	for _, dx in { -2.5, 2.5 } do
		parte("Varilla", V3(0.1, ALTURA - 10.3, 0.1), V3(g.x + dx, (ALTURA + 10.3) / 2, Z_HASTA + 0.6), C3(40, 40, 40), Enum.Material.Metal, pasillo, DECO)
	end
end

-- Estantes de pared (cajas de estrenos en los laterales).
local paredes = carpeta("EstantesPared", gondolas)
local PALETA_PARED = { C3(160, 40, 36), C3(30, 30, 34), C3(220, 190, 50), C3(60, 150, 200), C3(110, 70, 90), C3(70, 130, 220) }
for _, lado in { -1, 1 } do
	local xCuerpo = lado * 23.4
	parte("EstantePared", V3(1.2, 6.3, 23), V3(xCuerpo, 3.15, 5.5), COL_MADERA, Enum.Material.Wood, paredes)
	for fila = 1, FILAS do
		local y = 1.35 + (fila - 1) * PASO_FILA
		parte("RepisaPared", V3(0.5, 0.12, 23), V3(lado * 22.95, y - 0.6, 5.5), COL_MADERA_OSC, Enum.Material.Wood, paredes, DECO)
		for col = 0, 22 do
			cajaCasete(paredes, lado * 22.65, y, -6 + col + 0.5, PALETA_PARED, "PARED", -lado)
		end
	end
end

-- ===== Carteles y afiches =====

local afiches = carpeta("Afiches")
-- ancho: largo del afiche sobre la pared (2.5 por defecto). unaLinea: el texto no se parte en dos renglones.
local function afiche(nombre, pos, cara, contenido, color, orientacion, ancho, unaLinea)
	ancho = ancho or 2.5
	local tam = orientacion == "X" and V3(0.1, 3.4, ancho) or V3(ancho, 3.4, 0.1)
	local p = parte(nombre, tam, pos, color, Enum.Material.SmoothPlastic, afiches, DECO)
	local t = texto(p, cara, contenido, Enum.Font.Arcade, C3(245, 240, 220))
	if unaLinea then
		t.TextScaled = false
		t.TextWrapped = false
		t.TextSize = 32
	end
end
-- "ESTRENOS" en 2.5 studs de ancho se cortaba como "ES / TRENOS": más ancho y en un solo renglón.
afiche("AficheIzq1", V3(-23.9, 9, -2), Enum.NormalId.Right, "ESTRENOS", C3(120, 30, 40), "X", 4.6, true)
afiche("AficheIzq2", V3(-23.9, 9, 8), Enum.NormalId.Right, "HAGASE SOCIO", C3(40, 70, 120), "X")
afiche("AficheDer1", V3(23.9, 9, -2), Enum.NormalId.Left, "2x1 LOS MARTES", C3(30, 100, 70), "X")
afiche("AficheDer2", V3(23.9, 9, 8), Enum.NormalId.Left, "REBOBINE ANTES DE DEVOLVER", C3(110, 80, 30), "X")

local letrero = parte("LetreroVideoclub", V3(14, 2.4, 0.2), V3(0, 10, -11.9), C3(30, 28, 26), Enum.Material.SmoothPlastic, afiches, DECO)
texto(letrero, Enum.NormalId.Back, "VIDEOCLUB ESTRELLA", Enum.Font.Arcade, C3(255, 220, 90))

-- Cartel de instrucciones: en la pared del frente, a la izquierda de la puerta (se ve desde el mostrador y al
-- entrar o salir). Repite lo que explica la llamada inicial para quien no se acuerde.
do
	local CREMA, AMARILLO = C3(240, 232, 205), C3(255, 220, 90)
	local panel = parte("CartelInstrucciones", V3(4.4, 7, 0.15), V3(-5.5, 4.6, Z_FRENTE - 0.575), C3(30, 28, 26), Enum.Material.SmoothPlastic, afiches)
	parte("CartelInstruccionesMarco", V3(4.6, 7.2, 0.1), V3(-5.5, 4.6, Z_FRENTE - 0.52), C3(92, 70, 44), Enum.Material.Wood, afiches, DECO)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Instrucciones"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.Parent = panel
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = C3(30, 28, 26)
	fondo.BorderSizePixel = 0
	fondo.Parent = gui
	local marco = Instance.new("UIStroke")
	marco.Color = AMARILLO
	marco.Thickness = 3
	marco.Parent = fondo
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 6)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = fondo
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 14), UDim.new(0, 10)
	relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 18), UDim.new(0, 14)
	relleno.Parent = fondo
	local orden = 0
	local function linea(txt, alto, fuente, color, tam, centrado)
		orden += 1
		local t = Instance.new("TextLabel")
		t.LayoutOrder = orden
		t.Size = UDim2.new(1, 0, 0, alto)
		t.BackgroundTransparency = 1
		t.RichText = true
		t.TextWrapped = true
		t.Font = fuente
		t.TextSize = tam
		t.TextColor3 = color
		t.TextXAlignment = centrado and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.Text = txt
		t.Parent = fondo
	end
	local function tecla(k, que)
		linea('<font color="#FFDC5A"><b>[' .. k .. ']</b></font>  ' .. que, 30, Enum.Font.SourceSansBold, CREMA, 25)
	end
	linea("CÓMO SE TRABAJA", 44, Enum.Font.Arcade, AMARILLO, 40, true)
	linea("Turno noche · Videoclub Estrella", 24, Enum.Font.Code, C3(190, 184, 160), 19, true)
	linea("CONTROLES", 28, Enum.Font.Arcade, AMARILLO, 24)
	tecla("E", "Interactuar (atender, tomar, usar)")
	tecla("R", "Mantener: rechazar o grabar")
	tecla("G", "Soltar el casete")
	tecla("Q", "Marcar una anomalía")
	tecla("F", "Linterna (si se corta la luz)")
	tecla("TAB", "Ocultar la ficha")
	linea("EL TURNO", 28, Enum.Font.Arcade, AMARILLO, 24)
	linea("1. Atendé al cliente en el mostrador", 32, Enum.Font.SourceSansBold, CREMA, 25)
	linea("2. Rebobiná las cintas devueltas", 32, Enum.Font.SourceSansBold, CREMA, 25)
	linea("3. Las dañadas, a la caja roja", 32, Enum.Font.SourceSansBold, CREMA, 25)
	linea("4. Cada cinta a la góndola de su género", 32, Enum.Font.SourceSansBold, CREMA, 25)
	linea("5. Basura al patio, manchas a limpiar", 32, Enum.Font.SourceSansBold, CREMA, 25)
	linea('<font color="#E0584A"><b>El Socio N° 0000 solo se mueve cuando nadie lo mira.</b></font>', 60, Enum.Font.SourceSansBold, CREMA, 25, true)
end

-- ===== Depósito =====

local deposito = carpeta("Deposito")

-- Piezas del depósito (y de su ampliación de la noche 4): estanterías metálicas con VHS sueltos y cajas de cartón
-- tiradas. Todo apoyado en el piso o en una repisa; nada flota. Van en una tabla para no gastar locales.
local Deposito = {}
local CARTON = { C3(168, 130, 84), C3(152, 118, 76), C3(180, 142, 92), C3(140, 108, 70) }
local COL_ETIQUETA = { C3(236, 230, 210), C3(210, 70, 56), C3(230, 200, 80), C3(90, 140, 190) }

-- Un VHS parado (lomo hacia el frente +Z del marco `cf`) o acostado. `cf` es el centro de la base.
function Deposito.vhs(padre, cf, modo, inclinacion)
	local color = aleatorio(COL_VHS)
	if modo == "acostado" then
		parte("VHS", V3(1.1, 0.3, 0.8), cf * CFrame.new(0, 0.15, 0), color, Enum.Material.SmoothPlastic, padre, DECO)
		parte("VHSEtiqueta", V3(0.7, 0.02, 0.5), cf * CFrame.new(0, 0.31, 0), aleatorio(COL_ETIQUETA), Enum.Material.SmoothPlastic, padre, DECO)
		return
	end
	local ang = inclinacion or 0
	-- Al inclinarlo, el centro sube para que la esquina inferior siga tocando la repisa.
	local alto = 0.55 * math.cos(ang) + 0.15 * math.abs(math.sin(ang))
	local c = cf * CFrame.new(0, alto, 0) * CFrame.Angles(0, 0, ang)
	parte("VHS", V3(0.3, 1.1, 0.8), c, color, Enum.Material.SmoothPlastic, padre, DECO)
	parte("VHSEtiqueta", V3(0.22, 0.7, 0.02), c * CFrame.new(0, 0.05, 0.41), aleatorio(COL_ETIQUETA), Enum.Material.SmoothPlastic, padre, DECO)
end

-- Caja cerrada de cartón con cinta de embalar. `cf` es el centro de la base.
function Deposito.caja(padre, cf, ancho, alto, prof, conTexto)
	local p = parte("CajaCarton", V3(ancho, alto, prof), cf * CFrame.new(0, alto / 2, 0), aleatorio(CARTON), Enum.Material.Cardboard, padre)
	parte("CajaCinta", V3(0.35, 0.03, prof + 0.02), cf * CFrame.new(0, alto + 0.01, 0), C3(196, 170, 120), Enum.Material.SmoothPlastic, padre, DECO)
	if conTexto then
		texto(p, Enum.NormalId.Front, "FRÁGIL", Enum.Font.Arcade, C3(110, 40, 34))
	end
	return p
end

-- Caja volcada con la boca hacia el frente (+Z del marco `cf`): paredes finas, solapas abiertas y VHS desparramados.
function Deposito.cajaAbierta(padre, cf, ancho, alto, prof)
	local E = 0.08
	local color = aleatorio(CARTON)
	local c = cf * CFrame.new(0, alto / 2, 0)
	parte("CajaFondo", V3(ancho, alto, E), c * CFrame.new(0, 0, -prof / 2 + E / 2), color, Enum.Material.Cardboard, padre)
	parte("CajaPared", V3(E, alto, prof), c * CFrame.new(-ancho / 2 + E / 2, 0, 0), color, Enum.Material.Cardboard, padre)
	parte("CajaPared", V3(E, alto, prof), c * CFrame.new(ancho / 2 - E / 2, 0, 0), color, Enum.Material.Cardboard, padre)
	parte("CajaPared", V3(ancho, E, prof), c * CFrame.new(0, alto / 2 - E / 2, 0), color, Enum.Material.Cardboard, padre)
	parte("CajaPiso", V3(ancho, E, prof), c * CFrame.new(0, -alto / 2 + E / 2, 0), C3(130, 100, 64), Enum.Material.Cardboard, padre)
	-- Solapa de arriba levantada y solapa de abajo caída sobre el piso.
	local arriba = c * CFrame.new(0, alto / 2, prof / 2) * CFrame.Angles(-math.rad(50), 0, 0) * CFrame.new(0, 0, 0.45)
	parte("CajaSolapa", V3(ancho, E, 0.9), arriba, color, Enum.Material.Cardboard, padre, DECO)
	parte("CajaSolapa", V3(ancho, E, 0.9), cf * CFrame.new(0, E / 2, prof / 2 + 0.45), color, Enum.Material.Cardboard, padre, DECO)
	for _ = 1, rng:NextInteger(3, 5) do
		local d = prof / 2 + 0.9 + rng:NextNumber(0, 1.6)
		Deposito.vhs(padre, cf * CFrame.new(rng:NextNumber(-ancho * 0.7, ancho * 0.7), 0, d) * CFrame.Angles(0, rng:NextNumber(-1.2, 1.2), 0), "acostado")
	end
end

-- Estantería metálica de 4 niveles. `cf` es el centro de la base en el piso y el frente mira a +Z de `cf`.
function Deposito.estante(padre, cf, ancho)
	local PROF, ALTO = 1.6, 6.2
	local NIVELES = { 0.35, 1.9, 3.45, 5.0 }
	local AZUL, GRIS = C3(58, 84, 122), C3(150, 154, 156)
	local m = carpeta("EstanteriaMetalica", padre)
	for _, dx in { -ancho / 2 + 0.08, ancho / 2 - 0.08 } do
		for _, dz in { -PROF / 2 + 0.08, PROF / 2 - 0.08 } do
			parte("Montante", V3(0.16, ALTO, 0.16), cf * CFrame.new(dx, ALTO / 2, dz), AZUL, Enum.Material.Metal, m)
		end
	end
	for _, y in NIVELES do
		parte("Tabla", V3(ancho, 0.12, PROF), cf * CFrame.new(0, y, 0), GRIS, Enum.Material.Metal, m)
		parte("Larguero", V3(ancho, 0.2, 0.1), cf * CFrame.new(0, y - 0.1, PROF / 2 - 0.05), C3(214, 128, 40), Enum.Material.Metal, m, DECO)
	end
	-- Riostra en diagonal en el costado derecho.
	local diag = math.sqrt(ALTO ^ 2 + PROF ^ 2)
	parte("Arriostre", V3(0.06, 0.06, diag), cf * CFrame.new(ancho / 2 - 0.08, ALTO / 2, 0) * CFrame.Angles(math.atan2(ALTO, PROF), 0, 0), AZUL, Enum.Material.Metal, m, DECO)
	-- Cada nivel lleva tandas de VHS parados (alguno inclinado), pilas de VHS acostados y alguna caja chica.
	for _, y in NIVELES do
		local base = y + 0.06
		local x = -ancho / 2 + 0.3
		local limite = ancho / 2 - 0.3
		while x < limite - 0.4 do
			local tipo = rng:NextNumber()
			local necesita = tipo < 0.55 and 0.35 or tipo < 0.78 and 1.2 or tipo < 0.92 and 1.65 or 0.5
			if x + necesita > limite then
				break
			end
			if tipo < 0.55 then
				local n = rng:NextInteger(3, 9)
				for i = 1, n do
					if x + 0.35 > limite then
						break
					end
					local ultimo = i == n and rng:NextNumber() < 0.5
					local ang = ultimo and rng:NextNumber(0.18, 0.3) * (rng:NextNumber() < 0.5 and -1 or 1) or 0
					Deposito.vhs(m, cf * CFrame.new(x + 0.17, base, rng:NextNumber(-0.25, 0.1)), "parado", ang)
					x += ultimo and 0.55 or 0.34
				end
			elseif tipo < 0.78 then
				for k = 1, rng:NextInteger(2, 4) do
					Deposito.vhs(m, cf * CFrame.new(x + 0.6, base + (k - 1) * 0.3, rng:NextNumber(-0.15, 0.15)) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0), "acostado")
				end
				x += 1.35
			elseif tipo < 0.92 then
				local w, h, d = rng:NextNumber(0.9, 1.5), rng:NextNumber(0.8, 1.3), rng:NextNumber(0.9, 1.2)
				Deposito.caja(m, cf * CFrame.new(x + w / 2, base, 0) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), w, h, d, false)
				x += w + 0.15
			else
				x += rng:NextNumber(0.5, 1.1) -- hueco
			end
		end
	end
	return m
end

-- Cajas tiradas (cerradas, apiladas torcidas y abiertas con VHS desparramados) en las posiciones `lugares`.
function Deposito.cajasTiradas(padre, lugares)
	for _, l in lugares do
		local cf = CFrame.new(l.x, 0, l.z) * CFrame.Angles(0, math.rad(l.giro or 0), 0)
		if l.tipo == "abierta" then
			Deposito.cajaAbierta(padre, cf, l.w or 1.9, l.h or 1.4, l.d or 1.6)
		elseif l.tipo == "pila" then
			Deposito.caja(padre, cf, 1.8, 1.3, 1.5, true)
			Deposito.caja(padre, cf * CFrame.new(0.25, 1.3, 0.1) * CFrame.Angles(0, math.rad(-22), 0), 1.4, 1.0, 1.2, false)
		else
			Deposito.caja(padre, cf, l.w or 1.6, l.h or 1.2, l.d or 1.4, l.texto)
		end
	end
end

-- Pared del fondo: tres estanterías (frente a +Z); pared derecha: una más (frente a -X).
for i = 0, 2 do
	Deposito.estante(deposito, CFrame.new(-21 + i * 7, 0, -19.1), 6)
end
Deposito.estante(deposito, CFrame.new(5.65, 0, -17.2) * CFrame.Angles(0, -math.rad(90), 0), 5)
Deposito.cajasTiradas(deposito, {
	{ tipo = "abierta", x = -22.2, z = -15.6, giro = 70 },
	{ tipo = "pila", x = -22.8, z = -14.4, giro = 12 },
	{ tipo = "caja", x = -17.2, z = -14.3, giro = -18, texto = true },
	{ tipo = "caja", x = -17.6, z = -16.3, giro = 35, w = 1.2, h = 0.9, d = 1.2 },
	{ tipo = "abierta", x = 1.6, z = -15.3, giro = -70 },
	{ tipo = "pila", x = 3.3, z = -14.5, giro = -25 },
	{ tipo = "caja", x = -6.6, z = -17.2, giro = 8, w = 1.4, h = 1.0, d = 1.3 },
})
local pila1 = parte("PilaCajas1", V3(2.4, 2.2, 2.4), V3(-3, 1.1, -17.5), C3(160, 124, 80), Enum.Material.Cardboard, deposito)
local pila2 = parte("PilaCajas2", V3(2, 1.4, 2), V3(-3.2, 2.9, -17.5), C3(150, 116, 76), Enum.Material.Cardboard, deposito)
parte("Mesa", V3(5, 0.3, 2.4), V3(-13, 3.2, -15), COL_MADERA, Enum.Material.Wood, deposito)
for _, dx in { -2.2, 2.2 } do
	for _, dz in { -0.9, 0.9 } do
		parte("PataMesa", V3(0.3, 3.2, 0.3), V3(-13 + dx, 1.6, -15 + dz), COL_MADERA_OSC, Enum.Material.Wood, deposito)
	end
end
local telInterno = parte("TelefonoInterno", V3(0.5, 1.2, 0.9), V3(-1.5, 4.2, -13.3), C3(90, 90, 96), Enum.Material.Plastic, deposito)
CollectionService:AddTag(telInterno, "TelefonoInterno")

-- ===== Baño =====
-- x 7.5..24, z -20..-12.5. Azulejos hasta media pared, cubículo con puerta, inodoro, lavatorio, espejo, dispensador.

local bano = carpeta("Bano")
local AZULEJO = C3(176, 190, 184)
local AZULEJO_OSC = C3(120, 134, 130)
-- Piso de baldositas chicas (damero de 2x2).
for ix = 0, 7 do
	for iz = 0, 3 do
		local claro = (ix + iz) % 2 == 0
		parte("BaldosaBano", V3(2, 0.1, 2), V3(8.5 + ix * 2, 0.05, -19.5 + iz * 2), claro and C3(150, 164, 160) or C3(96, 110, 108), Enum.Material.SmoothPlastic, bano, DECO)
	end
end
-- Azulejos en las paredes (lado interior) hasta 5 de alto, con guarda oscura arriba.
grilla(parte("AzulejoFondo", V3(16.4, 5, 0.1), V3(15.8, 2.5, -19.95), AZULEJO, Enum.Material.SmoothPlastic, bano, DECO), Enum.NormalId.Back, 1, C3(96, 110, 106))
parte("GuardaFondo", V3(16.4, 0.35, 0.12), V3(15.8, 5.1, -19.94), AZULEJO_OSC, Enum.Material.SmoothPlastic, bano, DECO)
grilla(parte("AzulejoDerecha", V3(0.1, 5, 7.4), V3(23.95, 2.5, -16.2), AZULEJO, Enum.Material.SmoothPlastic, bano, DECO), Enum.NormalId.Left, 1, C3(96, 110, 106))
parte("GuardaDerecha", V3(0.12, 0.35, 7.4), V3(23.94, 5.1, -16.2), AZULEJO_OSC, Enum.Material.SmoothPlastic, bano, DECO)
grilla(parte("AzulejoIzquierda", V3(0.1, 5, 7.4), V3(7.55, 2.5, -16.2), AZULEJO, Enum.Material.SmoothPlastic, bano, DECO), Enum.NormalId.Right, 1, C3(96, 110, 106))

-- Cubículo del inodoro (esquina derecha): tabiques y puerta entornada.
local CUB_X0, CUB_X1 = 19, 24
-- El frente del cubículo quedó 1.1 studs más atrás que antes: queda
-- un pasillo de 2.5 studs entre el frente y la pared divisoria, y una entrada de 2.6 studs (x 19..21.6).
-- La puerta (más corta) está abierta hacia adentro, así que no tapa la entrada.
do
	local FZ = -15.6 -- z del frente del cubículo
	local entrada = 2.6
	parte("CubiculoTabique", V3(0.2, 7, FZ + 19.95 + 0.1), V3(CUB_X0, 3.5, (-19.95 + FZ + 0.1) / 2), C3(96, 110, 120), Enum.Material.Metal, bano)
	parte("CubiculoFrente", V3(CUB_X1 - CUB_X0 - entrada, 7, 0.2), V3((CUB_X0 + entrada + CUB_X1) / 2, 3.5, FZ), C3(96, 110, 120), Enum.Material.Metal, bano)
	local largo, ang = 2.4, math.rad(60)
	local bisagra = V3(CUB_X0 + 0.15, 0, FZ)
	local dir = V3(math.cos(ang), 0, -math.sin(ang))
	local centro = bisagra + dir * (largo / 2)
	parte("CubiculoPuerta", V3(largo, 6.6, 0.15), CFrame.new(centro.X, 3.5, centro.Z) * CFrame.Angles(0, ang, 0), C3(110, 126, 136), Enum.Material.Metal, bano, { CanCollide = false })
	local pomo = bisagra + dir * (largo - 0.3) + V3(math.sin(ang), 0, math.cos(ang)) * 0.12
	parte("CubiculoPomo", V3(0.15, 0.4, 0.15), V3(pomo.X, 3.4, pomo.Z), C3(200, 60, 50), Enum.Material.Metal, bano, DECO)
end

-- Inodoro: taza, base, tanque, tapa y botón.
parte("InodoroBase", V3(1.2, 0.9, 1.2), V3(21.5, 0.45, -19.1), C3(235, 235, 232), Enum.Material.SmoothPlastic, bano)
parte("InodoroTaza", V3(1.7, 0.5, 2.1), V3(21.5, 1.15, -18.8), C3(238, 238, 235), Enum.Material.SmoothPlastic, bano)
parte("InodoroTanque", V3(1.9, 1.7, 0.7), V3(21.5, 2.2, -19.85), C3(228, 228, 225), Enum.Material.SmoothPlastic, bano)
parte("InodoroTapa", V3(1.5, 0.12, 1.7), V3(21.5, 1.45, -18.7), C3(214, 214, 210), Enum.Material.SmoothPlastic, bano, DECO)
parte("InodoroBoton", V3(0.4, 0.1, 0.25), V3(21.5, 3.1, -19.85), C3(180, 180, 176), Enum.Material.Metal, bano, DECO)
parte("PortaRollo", V3(0.2, 0.2, 0.9), V3(23.7, 3.4, -18.4), C3(180, 180, 176), Enum.Material.Metal, bano, DECO)
parte("RolloPapel", V3(0.6, 0.6, 0.6), V3(23.6, 3.4, -18.4), C3(240, 240, 235), Enum.Material.SmoothPlastic, bano, DECO)

-- Lavatorio con pie, canilla, espejo con marco y dispensador de jabón.
parte("Lavatorio", V3(2.4, 0.4, 1.6), V3(12, 3.4, -19.1), C3(235, 235, 232), Enum.Material.SmoothPlastic, bano)
parte("LavatorioBorde", V3(2.4, 0.3, 0.3), V3(12, 3.75, -19.75), C3(238, 238, 235), Enum.Material.SmoothPlastic, bano, DECO)
parte("LavatorioPie", V3(0.7, 3.2, 0.7), V3(12, 1.6, -19.5), C3(225, 225, 222), Enum.Material.SmoothPlastic, bano)
parte("CanillaBase", V3(0.35, 0.5, 0.35), V3(12, 3.85, -19.5), C3(190, 194, 196), Enum.Material.Metal, bano, DECO)
parte("CanillaPico", V3(0.2, 0.2, 0.7), V3(12, 4.2, -19.2), C3(190, 194, 196), Enum.Material.Metal, bano, DECO)
parte("MarcoEspejo", V3(2.9, 3.5, 0.12), V3(12, 6.6, -19.93), C3(60, 52, 44), Enum.Material.Wood, bano, DECO)
parte("Espejo", V3(2.5, 3.1, 0.1), V3(12, 6.6, -19.88), C3(160, 190, 200), Enum.Material.Glass, bano, { Transparency = 0.35, CanCollide = false, CanQuery = false })
parte("Jabonera", V3(0.5, 0.8, 0.4), V3(14.2, 4.6, -19.75), C3(210, 214, 210), Enum.Material.Plastic, bano, DECO)

-- Secador de manos, tacho y lavatorio de repuesto con cartel de "No funciona".
parte("SecadorManos", V3(1.1, 1.4, 0.7), V3(16.5, 4.4, -19.7), C3(220, 220, 214), Enum.Material.Plastic, bano, DECO)
parte("TachoBano", V3(1.1, 1.6, 1.1), V3(17.5, 0.8, -19.2), C3(80, 90, 94), Enum.Material.Metal, bano)
local cartelBano = parte("CartelBano", V3(1.4, 0.8, 0.08), V3(16.5, 5.6, -19.9), C3(236, 226, 190), Enum.Material.SmoothPlastic, bano, DECO)
texto(cartelBano, Enum.NormalId.Front, "NO TIRAR PAPEL AL INODORO", Enum.Font.Arcade, C3(120, 30, 30))
-- Papeles tirados en el piso (detalle).
for i = 1, 4 do
	parte("PapelPiso", V3(0.5, 0.04, 0.4), CFrame.new(13 + i * 1.3, 0.08, -17 + (i % 2) * 1.4) * CFrame.Angles(0, i * 1.1, 0), C3(236, 232, 218), Enum.Material.SmoothPlastic, bano, DECO)
end

-- ===== Objetos movibles (AnomalySystem los desplaza del lado del cliente) =====
-- Cada movible es UNA parte (el cliente le cambia el CFrame); los detalles que lo acompañan son decoración fija.

local props = carpeta("Props")
local function movible(p)
	p:SetAttribute("AnomaliaId", "M_" .. p.Name)
	CollectionService:AddTag(p, "Movible")
	return p
end
-- Cilindro vertical: en Roblox el eje del cilindro es X, así que se lo acuesta 90° sobre Z.
local function cilindro(nombre, diametro, altura, pos, color, material, padre, extra)
	local p = parte(nombre, V3(altura, diametro, diametro), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, padre, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

movible(contestador)
movible(fichas)
movible(pila1)
movible(pila2)
-- (La banqueta cilíndrica que hacía de silla se eliminó.)
movible(parte("Planta", V3(2.3, 2.6, 2.3), V3(21.5, 1.5, 23.5), C3(52, 96, 56), Enum.Material.Grass, props, { Shape = Enum.PartType.Ball }))
parte("MacetaPlanta", V3(1.3, 0.9, 1.3), V3(21.5, 0.45, 23.5), C3(140, 74, 52), Enum.Material.Concrete, props, DECO)

-- Cartel de oferta: de cartón, finito, contra la pared (no estorba el paso) y con diseño propio.
-- Girado 90°: su cara principal mira hacia -X (el mostrador y la puerta), así al entrar y mirar a la derecha se lee.
local GIRO_CARTEL = CFrame.Angles(0, math.rad(90), 0)
local standee = movible(parte("CartelOferta", V3(2, 3.6, 0.12), CFrame.new(20.2, 1.9, 19.5) * GIRO_CARTEL, C3(210, 60, 50), Enum.Material.SmoothPlastic, props))
parte("CartelOfertaBase", V3(1.7, 0.1, 1.1), CFrame.new(20.2, 0.07, 19.5) * GIRO_CARTEL, C3(60, 52, 46), Enum.Material.Plastic, props, DECO)
for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
	local sg = Instance.new("SurfaceGui")
	sg.Face = cara
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.Parent = standee
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = C3(200, 48, 44)
	fondo.BorderSizePixel = 0
	fondo.Parent = sg
	local marco = Instance.new("UIStroke")
	marco.Color = C3(250, 236, 190)
	marco.Thickness = 4
	marco.Parent = fondo
	local function linea(txt, y, alto, color, fuente)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.9, alto)
		t.Position = UDim2.fromScale(0.05, y)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = fuente or Enum.Font.Arcade
		t.TextColor3 = color
		t.Text = txt
		t.Parent = fondo
	end
	linea("¡OFERTA!", 0.06, 0.16, C3(255, 226, 120))
	linea("2x1", 0.24, 0.42, C3(255, 248, 230))
	linea("LOS MARTES", 0.7, 0.1, C3(255, 226, 120))
	linea("en alquileres", 0.82, 0.07, C3(250, 236, 200), Enum.Font.Code)
end


-- ===== Anexos: cocina (a la izquierda) y patio (a la derecha) =====
-- Se entra por una puerta en cada pared lateral (z -11.5..-8), al fondo del local de ventas.

local PUERTA_Z0, PUERTA_Z1 = -11.5, -8
local PUERTA_ALTO = 8.5

local function marcoPuerta(x, padre)
	parte("MarcoPuertaA", V3(0.5, PUERTA_ALTO, 0.4), V3(x, PUERTA_ALTO / 2, PUERTA_Z0), C3(56, 40, 30), Enum.Material.Wood, padre)
	parte("MarcoPuertaB", V3(0.5, PUERTA_ALTO, 0.4), V3(x, PUERTA_ALTO / 2, PUERTA_Z1), C3(56, 40, 30), Enum.Material.Wood, padre)
	parte("MarcoPuertaDintel", V3(0.5, 0.4, PUERTA_Z1 - PUERTA_Z0 + 0.4), V3(x, PUERTA_ALTO, (PUERTA_Z0 + PUERTA_Z1) / 2), C3(56, 40, 30), Enum.Material.Wood, padre)
end

-- ----- Cocina / sala de empleados -----

local cocina = carpeta("Cocina")
local CX0, CX1, CZ0, CZ1 = -52, -25, -21, -1
local cocCentroX, cocCentroZ = (CX0 + CX1) / 2, (CZ0 + CZ1) / 2
grilla(parte("PisoCocina", V3(CX1 - CX0, 1, CZ1 - CZ0), V3(cocCentroX, -0.5, cocCentroZ), C3(132, 142, 130), Enum.Material.SmoothPlastic, cocina), Enum.NormalId.Top, 3, C3(70, 78, 72))
-- Guarda de baldosas oscuras: damero a lo largo del pasillo central.
for ix = 0, 6 do
	for iz = 0, 4 do
		if (ix + iz) % 2 == 0 then
			parte("BaldosaCocina", V3(3.8, 0.05, 3.8), V3(CX0 + 2 + ix * 3.9, 0.03, CZ0 + 2 + iz * 3.9), C3(100, 112, 104), Enum.Material.SmoothPlastic, cocina, DECO)
		end
	end
end
parte("TechoCocina", V3(CX1 - CX0 + 1, 1, CZ1 - CZ0 + 1), V3(cocCentroX, ALTURA + 0.5, cocCentroZ), C3(196, 192, 180), Enum.Material.SmoothPlastic, cocina)
muro("MuroCocinaOeste", "Z", CX0 - 0.5, CZ0 - 0.5, CZ1 + 0.5, {}, COL_PARED_FONDO, cocina)
muro("MuroCocinaNorte", "X", CZ0 - 0.5, CX0 - 1, CX1, {}, COL_PARED_FONDO, cocina)
muro("MuroCocinaSur", "X", CZ1 + 0.5, CX0 - 1, CX1, {}, COL_PARED_FONDO, cocina)
marcoPuerta(-24.5, cocina)
-- Zócalo de azulejos en las paredes.
grilla(parte("AzulejoCocinaNorte", V3(CX1 - CX0, 5, 0.1), V3(cocCentroX, 2.5, CZ0 + 0.05), C3(186, 194, 186), Enum.Material.SmoothPlastic, cocina, DECO), Enum.NormalId.Back, 1, C3(110, 120, 112))
grilla(parte("AzulejoCocinaOeste", V3(0.1, 5, CZ1 - CZ0), V3(CX0 + 0.05, 2.5, cocCentroZ), C3(186, 194, 186), Enum.Material.SmoothPlastic, cocina, DECO), Enum.NormalId.Right, 1, C3(110, 120, 112))

-- Mesada con pileta, alacenas y microondas (pared norte).
parte("MesadaCuerpo", V3(18, 3.4, 2.2), V3(-37, 1.7, CZ0 + 1.2), COL_MADERA_OSC, Enum.Material.Wood, cocina)
parte("MesadaTapa", V3(18.4, 0.25, 2.5), V3(-37, 3.5, CZ0 + 1.3), C3(190, 190, 184), Enum.Material.SmoothPlastic, cocina)
parte("Pileta", V3(3.2, 0.12, 1.6), V3(-40, 3.64, CZ0 + 1.3), C3(110, 116, 120), Enum.Material.Metal, cocina, DECO)
parte("CanillaCocinaPie", V3(0.3, 0.9, 0.3), V3(-40, 4.1, CZ0 + 0.55), C3(190, 194, 196), Enum.Material.Metal, cocina, DECO)
parte("CanillaCocinaPico", V3(0.2, 0.2, 0.9), V3(-40, 4.5, CZ0 + 0.95), C3(190, 194, 196), Enum.Material.Metal, cocina, DECO)
parte("Microondas", V3(2.4, 1.4, 1.7), V3(-34, 4.4, CZ0 + 1.3), C3(210, 210, 204), Enum.Material.Plastic, cocina)
parte("MicroondasPuerta", V3(1.5, 1, 0.06), V3(-34.3, 4.4, CZ0 + 2.2), C3(30, 34, 34), Enum.Material.Glass, cocina, DECO)
parte("Cafetera", V3(0.9, 1.3, 0.9), V3(-30, 4.3, CZ0 + 1.2), C3(40, 40, 42), Enum.Material.Plastic, cocina)
for i = 0, 3 do
	parte("Alacena", V3(4.2, 3, 1.4), V3(-44 + i * 4.4, 9, CZ0 + 0.9), COL_MADERA, Enum.Material.Wood, cocina)
	parte("AlacenaManija", V3(0.12, 0.8, 0.12), V3(-44 + i * 4.4 + 1.7, 8.4, CZ0 + 1.65), C3(190, 190, 186), Enum.Material.Metal, cocina, DECO)
end
-- Cocina a gas (pared norte, a la derecha de la mesada).
parte("Cocina", V3(3, 3.4, 2.6), V3(-27.5, 1.7, CZ0 + 1.4), C3(190, 192, 190), Enum.Material.Metal, cocina)
for _, dx in { -0.7, 0.7 } do
	for _, dz in { -0.5, 0.5 } do
		local hornalla = parte("Hornalla", V3(0.1, 0.9, 0.9), CFrame.new(-27.5 + dx, 3.45, CZ0 + 1.4 + dz) * CFrame.Angles(0, 0, math.rad(90)), C3(20, 20, 22), Enum.Material.Metal, cocina, DECO)
		hornalla.Shape = Enum.PartType.Cylinder
	end
end
parte("Olla", V3(1.1, 0.9, 1.1), V3(-26.8, 4, CZ0 + 1.9), C3(150, 154, 158), Enum.Material.Metal, cocina, DECO)

-- Heladera (esquina noroeste) con imanes y un papel pegado.
parte("Heladera", V3(3.2, 7.4, 3), V3(-49.5, 3.7, CZ0 + 2), C3(226, 228, 224), Enum.Material.Metal, cocina)
parte("HeladeraManija", V3(0.15, 2.2, 0.15), V3(-47.8, 4.4, CZ0 + 3.6), C3(150, 154, 158), Enum.Material.Metal, cocina, DECO)
parte("HeladeraManijaB", V3(0.15, 1.6, 0.15), V3(-47.8, 6.4, CZ0 + 3.6), C3(150, 154, 158), Enum.Material.Metal, cocina, DECO)
local papelHeladera = parte("HeladeraPapel", V3(0.9, 1.2, 0.05), V3(-49.5, 5.4, CZ0 + 3.53), C3(244, 238, 210), Enum.Material.SmoothPlastic, cocina, DECO)
texto(papelHeladera, Enum.NormalId.Front, "NO COMER LO DE OTROS", Enum.Font.Code, C3(120, 30, 30))

-- Mesa central con sillas.
parte("MesaCocina", V3(7, 0.3, 3.6), V3(-38, 3.1, -9), C3(222, 214, 190), Enum.Material.Wood, cocina)
for _, dx in { -3.2, 3.2 } do
	for _, dz in { -1.5, 1.5 } do
		parte("PataMesaCocina", V3(0.3, 3, 0.3), V3(-38 + dx, 1.5, -9 + dz), C3(150, 150, 146), Enum.Material.Metal, cocina)
	end
end
for _, pos in { V3(-40, 0, -11.4), V3(-36, 0, -11.4), V3(-40, 0, -6.6), V3(-36, 0, -6.6) } do
	parte("SillaAsiento", V3(1.6, 0.2, 1.6), V3(pos.X, 1.8, pos.Z), C3(70, 60, 50), Enum.Material.Wood, cocina)
	parte("SillaRespaldo", V3(1.6, 1.7, 0.15), V3(pos.X, 2.8, pos.Z + (pos.Z < -9 and -0.75 or 0.75)), C3(70, 60, 50), Enum.Material.Wood, cocina)
	for _, dx in { -0.65, 0.65 } do
		for _, dz in { -0.65, 0.65 } do
			parte("SillaPata", V3(0.15, 1.7, 0.15), V3(pos.X + dx, 0.85, pos.Z + dz), C3(50, 44, 38), Enum.Material.Wood, cocina)
		end
	end
end
parte("TazaMesa", V3(0.5, 0.5, 0.5), V3(-38.6, 3.5, -9.2), C3(236, 236, 230), Enum.Material.SmoothPlastic, cocina, DECO)
parte("Termo", V3(0.5, 1.1, 0.5), V3(-37.2, 3.9, -8.8), C3(60, 80, 70), Enum.Material.Metal, cocina, DECO)

-- Casilleros de los empleados (pared oeste): uno entreabierto.
for i = 0, 2 do
	local z = CZ0 + 8 + i * 2.4
	parte("Casillero", V3(2, 7, 2.3), V3(CX0 + 1.2, 3.5, z), C3(86, 104, 112), Enum.Material.Metal, cocina)
	parte("CasilleroRendija", V3(0.05, 0.6, 1.2), V3(CX0 + 2.22, 5.6, z), C3(20, 22, 24), Enum.Material.Metal, cocina, DECO)
	parte("CasilleroPomo", V3(0.18, 0.4, 0.18), V3(CX0 + 2.3, 3.5, z + 0.7), C3(190, 190, 186), Enum.Material.Metal, cocina, DECO)
end
local etiquetaCasillero = parte("CasilleroNombre", V3(0.05, 0.5, 1.4), V3(CX0 + 2.24, 6.4, CZ0 + 8 + 1 * 2.4), C3(244, 238, 210), Enum.Material.SmoothPlastic, cocina, DECO)
texto(etiquetaCasillero, Enum.NormalId.Right, "DARÍO", Enum.Font.Code, C3(40, 40, 40))

-- Reloj de pared (clavado en 3:33) y pizarra de turnos.
local reloj = parte("RelojPared", V3(0.15, 2.2, 2.2), V3(CX0 + 0.1, 8.8, CZ0 + 9), C3(236, 232, 220), Enum.Material.SmoothPlastic, cocina, DECO)
reloj.Shape = Enum.PartType.Cylinder
parte("RelojAgujaH", V3(0.05, 0.9, 0.08), CFrame.new(CX0 + 0.22, 9.15, CZ0 + 9.15) * CFrame.Angles(math.rad(35), 0, 0), C3(20, 20, 20), Enum.Material.SmoothPlastic, cocina, DECO)
parte("RelojAgujaM", V3(0.05, 0.1, 0.8), CFrame.new(CX0 + 0.22, 8.6, CZ0 + 9.45) * CFrame.Angles(math.rad(-20), 0, 0), C3(20, 20, 20), Enum.Material.SmoothPlastic, cocina, DECO)
local pizarra = parte("PizarraTurnos", V3(0.1, 3.2, 5), V3(CX0 + 0.1, 6.2, CZ0 + 17), C3(226, 226, 220), Enum.Material.SmoothPlastic, cocina, DECO)
texto(pizarra, Enum.NormalId.Right, "TURNOS\nLUN  DARÍO\nMAR  DARÍO\nMIE  DARÍO\nJUE  ---", Enum.Font.Code, C3(40, 60, 120))

tubo("Tubo", -44, -16, true, false, cocina)
tubo("Tubo", -34, -16, true, true, cocina)
tubo("Tubo", -44, -6, true, false, cocina)
tubo("Tubo", -34, -6, true, false, cocina)

-- ----- Patio -----

local patio = carpeta("Patio")
local PX0, PX1, PZ0, PZ1 = 25, 52, -21, -1
local patCentroX, patCentroZ = (PX0 + PX1) / 2, (PZ0 + PZ1) / 2
parte("PisoPatio", V3(PX1 - PX0, 1, PZ1 - PZ0), V3(patCentroX, -0.5, patCentroZ), C3(102, 104, 100), Enum.Material.Concrete, patio)
for i = 0, 5 do
	parte("JuntaPatio", V3(0.1, 0.04, PZ1 - PZ0), V3(PX0 + 4.5 * (i + 1), 0.02, patCentroZ), C3(60, 62, 60), Enum.Material.Concrete, patio, DECO)
end
for i = 0, 3 do
	parte("JuntaPatioZ", V3(PX1 - PX0, 0.04, 0.1), V3(patCentroX, 0.02, PZ0 + 4 * (i + 1)), C3(60, 62, 60), Enum.Material.Concrete, patio, DECO)
end
-- Yuyos entre las baldosas y en las esquinas.
for i = 1, 14 do
	local yx, yz = rng:NextNumber(PX0 + 1, PX1 - 1), rng:NextNumber(PZ0 + 1, PZ1 - 1)
	parte("Yuyo", V3(rng:NextNumber(0.3, 0.7), rng:NextNumber(0.4, 1.0), rng:NextNumber(0.3, 0.7)), V3(yx, 0.3, yz), C3(56, 88, 52), Enum.Material.Grass, patio, DECO)
end
-- Cerco de ladrillo alrededor (alto: nadie sale a la calle).
local LADRILLO = C3(112, 70, 60)
muro("CercoNorte", "X", PZ0 - 0.5, PX0 - 0.5, PX1 + 1, {}, LADRILLO, patio, "ParedYeso")
muro("CercoSur", "X", PZ1 + 0.5, PX0 - 0.5, PX1 + 1, {}, LADRILLO, patio, "ParedYeso")
muro("CercoEste", "Z", PX1 + 0.5, PZ0 - 0.5, PZ1 + 0.5, {}, LADRILLO, patio, "ParedYeso")
marcoPuerta(24.5, patio)
-- Tapa de ladrillos arriba del cerco.
parte("CercoRemateN", V3(PX1 - PX0 + 2, 0.4, 1.5), V3(patCentroX, ALTURA + 0.2, PZ0 - 0.5), C3(80, 52, 44), Enum.Material.Brick, patio, DECO)
parte("CercoRemateS", V3(PX1 - PX0 + 2, 0.4, 1.5), V3(patCentroX, ALTURA + 0.2, PZ1 + 0.5), C3(80, 52, 44), Enum.Material.Brick, patio, DECO)
parte("CercoRemateE", V3(1.5, 0.4, PZ1 - PZ0 + 2), V3(PX1 + 0.5, ALTURA + 0.2, patCentroZ), C3(80, 52, 44), Enum.Material.Brick, patio, DECO)
-- Cielo cerrado con un techo negro (la noche sin estrellas) para que no se vea el vacío.
parte("CieloPatio", V3(PX1 - PX0 + 3, 1, PZ1 - PZ0 + 3), V3(patCentroX, ALTURA + 20, patCentroZ), C3(6, 6, 8), Enum.Material.SmoothPlastic, patio, DECO)
-- Techo invisible (y 10 a 11): subiéndose a la parrilla y la chimenea se llegaba al borde del cerco (y 12) y se podía
-- salir. A esta altura nadie alcanza el borde, y a pie (cabeza a y 5) o parado sobre el contenedor no molesta.
parte("TechoInvisiblePatio", V3(PX1 - PX0 + 2, 1, PZ1 - PZ0 + 2), V3(patCentroX, 10.5, patCentroZ), C3(255, 255, 255), nil, patio, {
	Transparency = 1, CanCollide = true, CanTouch = false, CanQuery = false,
})

-- Contenedor de basura (donde se tiran las bolsas).
local contenedor = parte("Contenedor", V3(5.4, 3.6, 2.8), V3(44, 1.8, PZ0 + 2.2), C3(34, 78, 52), Enum.Material.Metal, patio)
CollectionService:AddTag(contenedor, "Contenedor")
parte("ContenedorTapaA", V3(2.8, 0.2, 2.9), CFrame.new(42.7, 4.2, PZ0 + 1.2) * CFrame.Angles(0, 0, math.rad(25)), C3(26, 62, 42), Enum.Material.Metal, patio, DECO)
parte("ContenedorTapaB", V3(2.6, 0.2, 2.9), V3(45.5, 3.7, PZ0 + 2.2), C3(26, 62, 42), Enum.Material.Metal, patio, DECO)
parte("ContenedorRueda", V3(0.5, 0.5, 0.5), V3(41.6, 0.25, PZ0 + 3.4), C3(20, 20, 20), Enum.Material.Plastic, patio, DECO)
parte("ContenedorRuedaB", V3(0.5, 0.5, 0.5), V3(46.4, 0.25, PZ0 + 3.4), C3(20, 20, 20), Enum.Material.Plastic, patio, DECO)
local carteContenedor = parte("ContenedorCartel", V3(2.4, 0.8, 0.06), V3(44, 2.6, PZ0 + 3.62), C3(236, 232, 214), Enum.Material.SmoothPlastic, patio, DECO)
texto(carteContenedor, Enum.NormalId.Front, "SOLO BOLSAS CERRADAS", Enum.Font.Arcade, C3(30, 70, 40))
-- Bolsas decorativas sueltas y cajones.
-- (usan la malla "trash bag" de ServerStorage.Plantillas, la misma que las bolsas de la tarea de basura)
local moldeBolsa = game.ServerStorage:FindFirstChild("Plantillas") and game.ServerStorage.Plantillas:FindFirstChild("trash bag")
moldeBolsa = moldeBolsa and moldeBolsa:FindFirstChildWhichIsA("MeshPart", true)
for i = 1, 5 do
	local bx, bz = 37 + rng:NextNumber(0, 5), PZ0 + 1.6 + rng:NextNumber(0, 2.5)
	if moldeBolsa then
		local alto = rng:NextNumber(1.4, 1.9)
		local bolsa = moldeBolsa:Clone()
		bolsa.Name = "BolsaSuelta"
		bolsa.Size = bolsa.Size * (alto / bolsa.Size.Y)
		bolsa.CFrame = CFrame.new(bx, alto / 2, bz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		bolsa.Anchored, bolsa.CanCollide, bolsa.CanTouch, bolsa.CanQuery = true, false, false, false
		bolsa.Parent = patio
	else
		local bolsa = parte("BolsaSuelta", V3(1.3, 1.2, 1.3), V3(bx, 0.6, bz), C3(14, 14, 16), Enum.Material.Plastic, patio, DECO)
		bolsa.Shape = Enum.PartType.Ball
	end
end
for i = 0, 2 do
	parte("Tarima", V3(3.4, 0.45, 3.4), V3(29.5, 0.25 + i * 0.5, PZ0 + 2.4), C3(150, 112, 70), Enum.Material.Wood, patio, DECO)
end
parte("CajonVerduras", V3(1.6, 1.2, 1.1), V3(33, 0.6, PZ0 + 1.5), C3(120, 90, 60), Enum.Material.Wood, patio)

-- Tendedero con ropa colgada.
for _, z in { -17, -5 } do
	parte("PostePatio", V3(0.3, 8, 0.3), V3(48, 4, z), C3(76, 70, 62), Enum.Material.Metal, patio)
end
parte("CuerdaRopa", V3(0.06, 0.06, 12), V3(48, 7.6, -11), C3(210, 206, 196), Enum.Material.Fabric, patio, DECO)
local ROPA = { C3(140, 40, 40), C3(210, 210, 200), C3(50, 70, 110), C3(200, 170, 70) }
for i = 0, 3 do
	parte("Ropa", V3(0.1, 2.6, 1.8), V3(48, 6.2, -16 + i * 3.2), ROPA[i + 1], Enum.Material.Fabric, patio, DECO)
end

-- Mesa de plástico con sillas rotas y una parrilla.
parte("MesaPatio", V3(4, 0.25, 4), V3(36, 3, -6), C3(214, 214, 208), Enum.Material.Plastic, patio)
for _, dx in { -1.7, 1.7 } do
	for _, dz in { -1.7, 1.7 } do
		parte("PataMesaPatio", V3(0.25, 3, 0.25), V3(36 + dx, 1.5, -6 + dz), C3(190, 190, 184), Enum.Material.Plastic, patio, DECO)
	end
end
for _, pos in { V3(33.2, 1.5, -6), V3(38.8, 1.5, -6.5) } do
	parte("SillaPatio", V3(1.5, 0.2, 1.5), V3(pos.X, 1.6, pos.Z), C3(190, 70, 50), Enum.Material.Plastic, patio, DECO)
	parte("SillaPatioPatas", V3(1.2, 1.5, 1.2), V3(pos.X, 0.8, pos.Z), C3(70, 70, 70), Enum.Material.Metal, patio, DECO)
end
-- Parrilla de ladrillo apoyada contra el cerco sur (cara interior en z = -1): el cuerpo y la chimenea tocan la pared.
local PARRILLA_Z = PZ1 - 0.8 -- el cuerpo mide 1.6 de fondo
local parrilla = parte("Parrilla", V3(4, 0.3, 1.6), V3(30, 2.9, PARRILLA_Z), C3(30, 30, 32), Enum.Material.Metal, patio)
parte("ParrillaCuerpo", V3(4, 2.6, 1.6), V3(30, 1.3, PARRILLA_Z), C3(96, 52, 40), Enum.Material.Brick, patio)
parte("ParrillaChimenea", V3(1.2, 5, 1.2), V3(30, 5.1, PZ1 - 0.6), C3(90, 50, 38), Enum.Material.Brick, patio)

-- Faroles del patio (única luz de afuera): uno de pared sobre la puerta, con soporte y brazo atornillados al
-- muro, y otro en un poste en el fondo. Los dos son una lámpara con jaula metálica, tapa y base.
do
	local METAL = C3(36, 36, 38)
	local function lampara(x, y, z)
		local foco = parte("Farol", V3(0.8, 0.8, 0.8), V3(x, y, z), C3(255, 230, 160), Enum.Material.Neon, patio, DECO)
		foco.Shape = Enum.PartType.Ball
		local luz = Instance.new("PointLight")
		luz.Range = 22
		luz.Brightness = 0.9
		luz.Color = C3(255, 214, 140)
		luz.Shadows = false
		luz.Parent = foco
		parte("FarolBase", V3(1, 0.14, 1), V3(x, y - 0.55, z), METAL, Enum.Material.Metal, patio, DECO)
		parte("FarolTapa", V3(1.2, 0.14, 1.2), V3(x, y + 0.55, z), METAL, Enum.Material.Metal, patio, DECO)
		parte("FarolRemate", V3(0.5, 0.14, 0.5), V3(x, y + 0.68, z), METAL, Enum.Material.Metal, patio, DECO)
		for _, dx in { -0.45, 0.45 } do
			for _, dz in { -0.45, 0.45 } do
				parte("FarolJaula", V3(0.06, 1.0, 0.06), V3(x + dx, y, z + dz), METAL, Enum.Material.Metal, patio, DECO)
			end
		end
	end
	-- De pared: placa y brazo contra la cara del muro del patio (x = 25), sobre la puerta (que termina en y 8.5).
	local YP, ZP = 9.9, -9.75
	parte("FarolPlaca", V3(0.15, 1.4, 1), V3(25.075, YP - 0.2, ZP), METAL, Enum.Material.Metal, patio, DECO)
	parte("FarolBrazo", V3(1.1, 0.18, 0.18), V3(25.6, YP - 0.55, ZP), METAL, Enum.Material.Metal, patio, DECO)
	lampara(26.15, YP, ZP)
	-- De poste: apoyada arriba del poste (que llega a y 8.6).
	parte("FarolPoste", V3(0.3, 8.6, 0.3), V3(46, 4.3, -10), METAL, Enum.Material.Metal, patio)
	lampara(46, 9.15, -10)
end

-- ===== Lugares de las tareas extra: basura, manchas y el contenedor (ChoreSystem los usa) =====

local tareasExtra = carpeta("TareasExtra")
local function spot(nombre, etiqueta, zona, x, z)
	local p = parte(nombre, V3(1, 1, 1), V3(x, 0.5, z), C3(255, 255, 255), nil, tareasExtra, {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false,
	})
	p:SetAttribute("Zona", zona)
	CollectionService:AddTag(p, etiqueta)
end
-- Dónde aparece una bolsa de basura.
spot("BasuraLocal", "BasuraSpot", "LOCAL", -20, 21)
spot("BasuraMostrador", "BasuraSpot", "MOSTRADOR", -8, 5.2)
spot("BasuraBano", "BasuraSpot", "BANO", 23.1, -16.9)
spot("BasuraCocina", "BasuraSpot", "COCINA", -44.5, -5.5)
spot("BasuraDeposito", "BasuraSpot", "DEPOSITO", -19, -17)
-- Dónde aparece una mancha para limpiar.
spot("DerrameLocal", "DerrameSpot", "LOCAL", 11, 21.5)
spot("DerrameMostrador", "DerrameSpot", "MOSTRADOR", -8.5, 7.8)
spot("DerrameBano", "DerrameSpot", "BANO", 15.8, -16.2)
spot("DerrameCocina", "DerrameSpot", "COCINA", -33, -12.5)
spot("DerramePatio", "DerrameSpot", "PATIO", 38, -12)
spot("DerrameDeposito", "DerrameSpot", "DEPOSITO", -9.5, -16.6)

-- ===== Puntos donde puede aparecer una figura (anomalía y predicción de la cinta) =====

local puntosFigura = carpeta("PuntosFigura")
local ZONAS = {
	[-20] = "junto a la pared izquierda",
	[-12] = "entre ACCIÓN y TERROR",
	[-4] = "entre TERROR y COMEDIA",
	[4] = "entre COMEDIA y DRAMA",
	[12] = "entre DRAMA e INFANTIL",
	[20] = "junto a la pared derecha",
}
local idFigura = 0
local function puntoFigura(x, z, zona)
	idFigura += 1
	local p = parte("PuntoFigura", V3(1, 1, 1), V3(x, 0.5, z), C3(255, 255, 255), nil, puntosFigura, {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false,
	})
	p:SetAttribute("FiguraId", "F" .. idFigura)
	p:SetAttribute("Zona", zona)
	CollectionService:AddTag(p, "PuntoFigura")
end
for _, x in { -20, -12, -4, 4, 12, 20 } do
	puntoFigura(x, -10.7, ZONAS[x])
end
puntoFigura(-6, -15, "en la puerta del depósito")
puntoFigura(16, -15, "en la puerta del baño")
puntoFigura(-18, 21.5, "cerca de la entrada")

-- ===== Lugares para las notas de Darío (RulesUI las dibuja del lado del cliente) =====

local notas = carpeta("NotaSlots")
local function notaSlot(i, pos, cara)
	local tam = (cara == "Left" or cara == "Right") and V3(0.05, 2.1, 1.6) or V3(1.6, 2.1, 0.05)
	local p = parte("NotaSlot", tam, pos, C3(255, 255, 255), nil, notas, {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false,
	})
	p:SetAttribute("SlotId", "N" .. i)
	p:SetAttribute("Cara", cara)
	CollectionService:AddTag(p, "NotaSlot")
end
notaSlot(1, V3(-5.5, 6, Z_FRENTE - 0.53), "Front") -- pared del frente, entre la ventana y la puerta
notaSlot(2, V3(-23.95, 8.8, 14.5), "Right") -- pared izquierda, sobre el estante
notaSlot(3, V3(23.95, 8.8, 14.5), "Left") -- pared derecha, sobre el estante
notaSlot(4, V3(1, 5, -11.95), "Back") -- pared del fondo, hacia el local
notaSlot(5, V3(-20, 5, -12.97), "Front") -- adentro del depósito
notaSlot(6, V3(LATERAL_X + 1.03, 2.6, 10), "Right") -- lateral del mostrador, del lado del empleado

-- ===== Waypoints (el Socio se mueve entre ellos; el servidor los conecta con raycasts) =====

local waypoints = carpeta("Waypoints")
local function waypoint(x, z)
	local p = parte("Waypoint", V3(0.6, 0.6, 0.6), V3(x, 3, z), C3(255, 255, 255), nil, waypoints, {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false,
	})
	CollectionService:AddTag(p, "Waypoint")
end
for _, x in { -20, -12, -4, 4, 12, 20 } do
	-- 6 y 11: lado de los empleados; 20: lado de los clientes (el mostrador está en z 16).
	for _, z in { -10.5, -3, 6, 11, 20 } do
		waypoint(x, z)
	end
end
for _, w in { { -44, -16 }, { -34, -16 }, { -44, -6 }, { -34, -6 }, { -28, -9.75 }, { -22, -9.75 }, { 22, -9.75 }, { 28, -9.75 }, { 34, -16 }, { 44, -12 }, { 34, -5 }, { 44, -5 }, { 40, -9 } } do
	waypoint(w[1], w[2])
end
for _, w in { { -6, -10.5 }, { 16, -10.5 }, { -6, -13 }, { 16, -13 }, { -6, -16 }, { -14, -16 }, { 0, -16 }, { 16, -16 } } do
	waypoint(w[1], w[2])
end

-- ===== Depósito largo (noche 4): se guarda en ServerStorage y el servidor lo activa =====

local viejoLargo = game.ServerStorage:FindFirstChild("DepositoLargo")
if viejoLargo then
	viejoLargo:Destroy()
end
local largo = Instance.new("Model")
largo.Name = "DepositoLargo"
parte("Piso", V3(31.5, 1, 27), V3(-8.75, -0.5, -34), C3(88, 90, 86), Enum.Material.Concrete, largo)
parte("Techo", V3(31.5, 1, 27), V3(-8.75, ALTURA + 0.5, -34), C3(196, 192, 180), Enum.Material.SmoothPlastic, largo)
parte("MuroIzquierdo", V3(1, ALTURA, 27), V3(-24.5, ALTURA / 2, -34), COL_PARED_FONDO, Enum.Material.Concrete, largo)
parte("MuroDerecho", V3(1, ALTURA, 27), V3(7, ALTURA / 2, -34), COL_PARED_FONDO, Enum.Material.Concrete, largo)
parte("MuroFin", V3(32.5, ALTURA, 1), V3(-8.75, ALTURA / 2, -47.5), COL_PARED_FONDO, Enum.Material.Concrete, largo)
for i = 0, 2 do
	Deposito.estante(largo, CFrame.new(-21 + i * 7, 0, -46.15), 6)
	Deposito.estante(largo, CFrame.new(5.65, 0, -26 - i * 8) * CFrame.Angles(0, -math.rad(90), 0), 6)
end
Deposito.cajasTiradas(largo, {
	{ tipo = "abierta", x = -18, z = -28, giro = 30 },
	{ tipo = "pila", x = -6, z = -31, giro = 15 },
	{ tipo = "caja", x = -12, z = -38, giro = -20, texto = true },
	{ tipo = "abierta", x = -20, z = -41.5, giro = 100 },
	{ tipo = "pila", x = 1, z = -42, giro = -30 },
	{ tipo = "caja", x = -3, z = -24.5, giro = 40, w = 1.4, h = 1.0, d = 1.3 },
})
for _, zz in { -27, -34, -41 } do
	tubo("Tubo", -14, zz, true, zz == -34, largo)
	tubo("Tubo", -2, zz, zz ~= -41, false, largo)
end
largo.Parent = game.ServerStorage

-- ===== La calle y el motel de enfrente (decorado: se ve por las ventanas y la puerta) =====
-- Vereda (z 27..35), ruta de dos carriles (z 35..53, con autos que pasan: ver Client/Calle), banquina de tierra,
-- guardarraíl, campo con alambrado y, bien al fondo, el motel con sus neones de los 90.
-- Entre la ruta y los edificios queda una franja de campo: la sensación es de ruta argentina, no de calle de ciudad.

local calle = carpeta("CalleDeAfuera")
local ASFALTO = C3(34, 36, 38)

parte("Vereda", V3(220, 1, 8), V3(0, -0.5, 31), C3(118, 116, 110), Enum.Material.Concrete, calle)
parte("Cordon", V3(220, 0.5, 0.5), V3(0, -0.25, 35.25), C3(150, 148, 140), Enum.Material.Concrete, calle)
parte("Calzada", V3(260, 0.2, 18), V3(0, -0.55, 44), ASFALTO, Enum.Material.Asphalt, calle)
-- Banquina de tierra y campo de pasto entre la ruta y el motel.
parte("Banquina", V3(260, 0.3, 8), V3(0, -0.6, 57), C3(96, 82, 62), Enum.Material.Ground, calle)
parte("Pasto", V3(260, 0.3, 36), V3(0, -0.6, 79), C3(40, 54, 34), Enum.Material.Grass, calle)
parte("Estacionamiento", V3(100, 0.2, 16), V3(0, -0.45, 97), ASFALTO, Enum.Material.Asphalt, calle)
-- Camino de entrada al motel: ripio que sale de la ruta.
parte("CaminoMotel", V3(12, 0.25, 42), V3(0, -0.55, 74), C3(120, 108, 90), Enum.Material.Pebble, calle)
-- Pintura de la ruta: doble línea amarilla al medio y líneas blancas en los bordes.
for _, dz in { -0.25, 0.25 } do
	parte("LineaAmarilla", V3(220, 0.03, 0.15), V3(0, -0.43, 44 + dz), C3(224, 180, 40), Enum.Material.SmoothPlastic, calle, DECO)
end
for _, z in { 36, 52.2 } do
	parte("LineaBorde", V3(220, 0.03, 0.2), V3(0, -0.43, z), C3(220, 220, 214), Enum.Material.SmoothPlastic, calle, DECO)
end
-- Rayas del estacionamiento.
for i = -5, 5 do
	parte("RayaEstacionamiento", V3(0.2, 0.03, 8), V3(i * 8, -0.33, 97.5), C3(220, 220, 214), Enum.Material.SmoothPlastic, calle, DECO)
end

-- Luminarias de ruta: poste alto con brazo y un tubo amarillo (como las de sodio de las rutas nacionales).
local AMARILLO_RUTA = C3(255, 206, 84)
local function luminaria(x, zPoste, sentido)
	parte("FarolPoste", V3(0.5, 16, 0.5), V3(x, 8, zPoste), C3(70, 72, 74), Enum.Material.Metal, calle, DECO)
	parte("FarolBrazo", V3(0.35, 0.35, 5), V3(x, 16, zPoste + sentido * 2.5), C3(70, 72, 74), Enum.Material.Metal, calle, DECO)
	local tubo = parte("FarolTubo", V3(5, 0.35, 1.1), V3(x, 15.6, zPoste + sentido * 4.6), AMARILLO_RUTA, Enum.Material.Neon, calle, DECO)
	local foco = Instance.new("SpotLight")
	foco.Face = Enum.NormalId.Bottom
	foco.Angle = 130
	foco.Range = 42
	foco.Brightness = 1.2
	foco.Color = AMARILLO_RUTA
	foco.Shadows = false
	foco.Parent = tubo
end
for _, x in { -90, -60, -30, 0, 30, 60, 90 } do
	luminaria(x, 34, 1) -- lado del local
	luminaria(x + 15, 54.5, -1) -- lado de enfrente (entre la ruta y el campo)
end

-- Guardarraíl a lo largo de la banquina (con un hueco donde sale el camino al motel).
for _, x in { -100, -80, -60, -40, -22, 22, 40, 60, 80, 100 } do
	parte("Guardarrail", V3(14, 0.9, 0.25), V3(x, 1.7, 54), C3(168, 172, 170), Enum.Material.CorrodedMetal, calle, DECO)
	for dx = -6, 6, 6 do
		parte("GuardarrailPoste", V3(0.25, 1.9, 0.25), V3(x + dx, 0.95, 54), C3(120, 124, 124), Enum.Material.Metal, calle, DECO)
	end
end

-- Mojón de kilometraje (blanco con tope rojo) y cartel de ruta (chapa verde con letras blancas).
local mojon = parte("Mojon", V3(0.9, 2.6, 0.9), V3(-48, 1.3, 55.5), C3(236, 232, 220), Enum.Material.Concrete, calle, DECO)
parte("MojonTope", V3(0.95, 0.7, 0.95), V3(-48, 2.55, 55.5), C3(190, 40, 36), Enum.Material.Concrete, calle, DECO)
local sgMojon = Instance.new("SurfaceGui")
sgMojon.Face = Enum.NormalId.Front
sgMojon.MaxDistance = 400
sgMojon.Parent = mojon
local tMojon = Instance.new("TextLabel")
tMojon.Size = UDim2.fromScale(1, 0.5)
tMojon.Position = UDim2.fromScale(0, 0.25)
tMojon.BackgroundTransparency = 1
tMojon.TextScaled = true
tMojon.Font = Enum.Font.Arcade
tMojon.TextColor3 = C3(20, 20, 20)
tMojon.Text = "143"
tMojon.Parent = sgMojon
parte("CartelRutaPata", V3(0.3, 7, 0.3), V3(40, 3.5, 55.5), C3(80, 82, 84), Enum.Material.Metal, calle, DECO)
local cartelRuta = parte("CartelRuta", V3(8, 3, 0.2), V3(40, 7.5, 55.5), C3(18, 90, 56), Enum.Material.SmoothPlastic, calle, DECO)
local sgRuta = Instance.new("SurfaceGui")
sgRuta.Face = Enum.NormalId.Front
sgRuta.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sgRuta.PixelsPerStud = 40
sgRuta.MaxDistance = 400
sgRuta.Parent = cartelRuta
local tRuta = Instance.new("TextLabel")
tRuta.Size = UDim2.fromScale(0.94, 0.8)
tRuta.Position = UDim2.fromScale(0.03, 0.1)
tRuta.BackgroundTransparency = 1
tRuta.TextScaled = true
tRuta.Font = Enum.Font.SourceSansBold
tRuta.TextColor3 = C3(240, 240, 235)
tRuta.Text = "RUTA 8\nSALDÁS 12 KM"
tRuta.Parent = sgRuta

-- Alambrado que separa el campo de la banquina (con el hueco del camino al motel).
for x = -110, 110, 4 do
	if math.abs(x) > 8 then
		parte("AlambradoPoste", V3(0.2, 3.4, 0.2), V3(x, 1.7, 61), C3(110, 96, 78), Enum.Material.Wood, calle, DECO)
	end
end
for _, y in { 0.9, 1.8, 2.7 } do
	parte("AlambradoHilo", V3(100, 0.05, 0.05), V3(-58, y, 61), C3(180, 180, 176), Enum.Material.Metal, calle, DECO)
	parte("AlambradoHilo", V3(100, 0.05, 0.05), V3(58, y, 61), C3(180, 180, 176), Enum.Material.Metal, calle, DECO)
end
-- Álamos oscuros en el campo (de lejos son una silueta): tronco que se afina, unas ramas peladas abajo y una copa
-- alargada hecha de muchas matas de hojas superpuestas (no una bola). Apoyados sobre el pasto (cara de arriba en y -0.45).
do
	local HOJAS = { C3(26, 48, 30), C3(34, 62, 36), C3(22, 40, 26), C3(42, 72, 40), C3(30, 54, 28) }
	local CORTEZA = { C3(74, 58, 46), C3(64, 50, 40) }
	local function alamo(x, z, k)
		local base = -0.45
		local alto = 24 * k
		-- Tronco en tres tramos cada vez más finos.
		local tramo = alto * 0.36
		for i, diametro in { 1.7, 1.25, 0.85 } do
			local t = parte("AlamoTronco", V3(tramo, diametro * k, diametro * k), CFrame.new(x, base + tramo * (i - 0.5), z) * CFrame.Angles(0, 0, math.rad(90)), aleatorio(CORTEZA), Enum.Material.Wood, calle, DECO)
			t.Shape = Enum.PartType.Cylinder
			t.Material = Enum.Material.Wood
			t.MaterialVariant = ""
		end
		-- Raíces que se abren en la base.
		for i = 0, 3 do
			local ang = i * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
			local r = parte("AlamoRaiz", V3(0.7 * k, 0.6 * k, 2.2 * k), CFrame.new(x + math.cos(ang) * 0.9 * k, base + 0.2, z + math.sin(ang) * 0.9 * k) * CFrame.Angles(0, -ang + math.pi / 2, 0) * CFrame.Angles(math.rad(-18), 0, 0), CORTEZA[1], Enum.Material.Wood, calle, DECO)
			r.MaterialVariant = ""
		end
		-- Ramas que salen del tronco hacia la copa.
		for i = 0, 5 do
			local ang = i * 1.05 + rng:NextNumber(-0.3, 0.3)
			local y = base + alto * (0.3 + 0.07 * i)
			local largo = 4.2 * k
			local rama = parte("AlamoRama", V3(0.3 * k, 0.3 * k, largo), CFrame.new(x, y, z) * CFrame.Angles(0, ang, 0) * CFrame.Angles(math.rad(38), 0, 0) * CFrame.new(0, 0, -largo / 2), CORTEZA[2], Enum.Material.Wood, calle, DECO)
			rama.MaterialVariant = ""
		end
		-- Copa: matas de hojas de distinto tamaño y verde, más anchas al medio y en punta arriba.
		local n = 26
		for j = 0, n - 1 do
			local t = j / (n - 1)
			local radio = 3.6 * k * math.sin(math.pi * (0.12 + 0.82 * t)) ^ 0.7
			local y = base + alto * (0.26 + 0.74 * t)
			for _ = 1, 3 do
				local dx, dz = rng:NextNumber(-1, 1) * radio * 0.75, rng:NextNumber(-1, 1) * radio * 0.75
				local d = math.max(1.3 * k, radio * rng:NextNumber(0.6, 1.0))
				local m = parte("AlamoHojas", V3(d, d * rng:NextNumber(1.0, 1.35), d), V3(x + dx, y + rng:NextNumber(-0.8, 0.8), z + dz), aleatorio(HOJAS), Enum.Material.LeafyGrass, calle, DECO)
				m.Shape = Enum.PartType.Ball
			end
		end
	end
	for _, pos in { V3(-62, 0, 70), V3(-50, 0, 82), V3(50, 0, 72), V3(66, 0, 84), V3(-78, 0, 88), V3(80, 0, 92) } do
		alamo(pos.X, pos.Z, rng:NextNumber(0.85, 1.15))
	end
end

-- Matorrales secos en el campo y la banquina, y una serranía lejana (silueta azul oscura contra el cielo estrellado).
for i = 1, 34 do
	local x = rng:NextNumber(-120, 120)
	local z = rng:NextNumber(56, 94)
	if math.abs(x) > 9 then
		local d = rng:NextNumber(1.6, 3.4)
		local m = parte("Matorral", V3(d * 1.7, d * 0.55, d * 1.7), V3(x, d * 0.2, z), C3(rng:NextInteger(70, 92), rng:NextInteger(64, 76), rng:NextInteger(44, 54)), Enum.Material.Grass, calle, DECO)
		m.Shape = Enum.PartType.Ball
	end
end
for i, x in { -520, -330, -150, 40, 210, 380, 560 } do
	local alto = 120 + (i % 3) * 40
	local sierra = parte("Sierra", V3(300 + (i % 2) * 80, alto, 220), V3(x, alto / 2 - 40, 560), C3(14, 20, 34), Enum.Material.Rock, calle, DECO)
	sierra.Shape = Enum.PartType.Ball
end

-- Cielo estrellado: una cúpula de puntos de luz lejanos y una luna (el Sky sin texturas no dibuja estrellas).
local cielo = carpeta("Estrellas", calle)
local estrellas = Random.new(1997)
for i = 1, 900 do
	local elevacion = math.rad(estrellas:NextNumber(6, 88))
	local azimut = math.rad(estrellas:NextNumber(0, 360))
	local radio = 640
	local pos = V3(math.cos(elevacion) * math.cos(azimut) * radio, math.sin(elevacion) * radio - 20, math.cos(elevacion) * math.sin(azimut) * radio)
	local grande = estrellas:NextNumber() < 0.07
	local tam = grande and estrellas:NextNumber(3, 4.6) or estrellas:NextNumber(1.2, 2.6)
	local tono = estrellas:NextNumber()
	local color = tono < 0.6 and C3(240, 244, 255) or (tono < 0.85 and C3(255, 236, 200) or C3(190, 210, 255))
	local e = parte("Estrella", V3(tam, tam, tam), pos, color, Enum.Material.Neon, cielo, { CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
	e.Shape = Enum.PartType.Ball
end
local luna = parte("Luna", V3(46, 46, 46), V3(-260, 300, 520), C3(214, 226, 245), Enum.Material.Neon, cielo, { CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
luna.Shape = Enum.PartType.Ball

-- ----- Motel -----

local motel = carpeta("Motel", calle)
local Z_MOTEL = 105 -- cara del frente del edificio (lejos de la ruta: se ve chico y brillante)
local COL_MOTEL = C3(172, 128, 132)
-- Paleta de ruta nostálgica: neón rojo anaranjado, verde de la estrella y amarillo (ROSA y CELESTE son los nombres viejos)
local ROSA, CELESTE, ROJO, AMARILLO = C3(255, 74, 38), C3(70, 255, 160), C3(255, 40, 50), C3(255, 200, 70)

-- Neón: parte brillante que parpadea (tag NeonParpadeo, atributo Periodo) y tiñe de color lo que tiene cerca.
local function neon(nombre, tam, pos, color, periodo, rango)
	local p = parte(nombre, tam, pos, color, Enum.Material.Neon, motel, DECO)
	if periodo then
		p:SetAttribute("Periodo", periodo)
		CollectionService:AddTag(p, "NeonParpadeo")
	end
	if rango then
		local luz = Instance.new("PointLight")
		luz.Range = rango
		luz.Brightness = 1.1
		luz.Color = color
		luz.Shadows = false
		luz.Parent = p
	end
	return p
end

-- Letrero luminoso: panel oscuro con texto que brilla (SurfaceGui sin influencia de la luz).
local function letrero(nombre, tam, pos, lineas, cara)
	local panel = parte(nombre, tam, pos, C3(14, 12, 18), Enum.Material.SmoothPlastic, motel, DECO)
	local sg = Instance.new("SurfaceGui")
	sg.Face = cara or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 4
	sg.Parent = panel
	local total = 0
	for _, l in lineas do
		total += l.alto
	end
	local y = 0
	for _, l in lineas do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.94, l.alto / total)
		t.Position = UDim2.fromScale(0.03, y / total)
		t.TextScaled = true
		t.Font = l.fuente or Enum.Font.Arcade
		t.TextColor3 = l.color
		t.Text = l.texto
		t.Parent = sg
		local borde = Instance.new("UIStroke")
		borde.Color = l.borde or l.color
		borde.Thickness = 2
		borde.Transparency = 0.35
		borde.Parent = t
		y += l.alto
	end
	return panel
end

-- Edificio: cuerpo, techo y cornisa.
parte("MotelCuerpo", V3(76, 9, 14), V3(0, 4.5, Z_MOTEL + 7), COL_MOTEL, Enum.Material.Concrete, motel)
parte("MotelTecho", V3(78, 0.6, 16), V3(0, 9.3, Z_MOTEL + 7), C3(60, 44, 50), Enum.Material.Concrete, motel)
parte("MotelAlero", V3(76, 0.4, 3.2), V3(0, 7.4, Z_MOTEL - 1.6), C3(70, 50, 58), Enum.Material.Concrete, motel)
-- Ocho habitaciones con puerta numerada, ventana con cortina y lámpara sobre la puerta.
local COL_PUERTA = { C3(40, 96, 128), C3(120, 40, 76) }
for i = 0, 7 do
	local x = -31.5 + i * 9
	local puerta = parte("MotelPuerta", V3(2.4, 6, 0.2), V3(x, 3, Z_MOTEL - 0.1), COL_PUERTA[i % 2 + 1], Enum.Material.Wood, motel, DECO)
	local num = parte("MotelNumero", V3(1.1, 0.7, 0.05), V3(x, 5.4, Z_MOTEL - 0.24), C3(236, 232, 216), Enum.Material.SmoothPlastic, motel, DECO)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = num
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.Arcade
	t.TextColor3 = C3(40, 30, 30)
	t.Text = tostring(101 + i)
	t.Parent = sg
	-- Ventana: unas con luz cálida de adentro, otras apagadas.
	local encendida = (i % 3 ~= 1)
	parte("MotelVentana", V3(2.6, 2.6, 0.15), V3(x + 4, 4, Z_MOTEL - 0.08), encendida and C3(255, 190, 110) or C3(20, 24, 30), encendida and Enum.Material.Neon or Enum.Material.Glass, motel, DECO)
	parte("MotelCortina", V3(0.9, 2.6, 0.12), V3(x + 3.2, 4, Z_MOTEL - 0.2), C3(120, 40, 60), Enum.Material.Fabric, motel, DECO)
	local lampara = parte("MotelLampara", V3(0.7, 0.5, 0.5), V3(x, 6.6, Z_MOTEL - 0.5), C3(255, 214, 150), Enum.Material.Neon, motel, DECO)
	local luz = Instance.new("PointLight")
	luz.Range = 14
	luz.Brightness = 1
	luz.Color = C3(255, 200, 140)
	luz.Shadows = false
	luz.Parent = lampara
end

-- Franja de neón en el alero (rosa y celeste, parpadean distinto) y cartel grande en el techo.
neon("NeonAleroRosa", V3(72, 0.25, 0.25), V3(0, 7.7, Z_MOTEL - 3.1), ROSA, 9, 40)
neon("NeonAleroCeleste", V3(72, 0.25, 0.25), V3(0, 7.2, Z_MOTEL - 3.1), CELESTE, 14, 40)
for _, x in { -12, 12 } do
	parte("CartelTechoPata", V3(0.5, 3, 0.5), V3(x, 10.8, Z_MOTEL + 1), C3(40, 40, 44), Enum.Material.Metal, motel, DECO)
end
letrero("CartelTecho", V3(30, 6.2, 0.5), V3(0, 14.5, Z_MOTEL + 1), {
	{ texto = "MOTEL LUNA", alto = 3, color = ROSA, borde = CELESTE },
	{ texto = "HABITACIONES · TV COLOR", alto = 1.4, color = AMARILLO, fuente = Enum.Font.Code },
})
neon("CartelTechoMarcoA", V3(31, 0.3, 0.3), V3(0, 17.75, Z_MOTEL + 0.7), CELESTE, 7, 45)
neon("CartelTechoMarcoB", V3(31, 0.3, 0.3), V3(0, 11.25, Z_MOTEL + 0.7), CELESTE, 7)

-- Poste con letrero vertical frente a la ruta ("VACANTE" parpadea).
parte("PosteLetrero", V3(1, 26, 1), V3(-12, 13, 66), C3(40, 40, 44), Enum.Material.Metal, motel, DECO)
letrero("LetreroPoste", V3(10, 14, 0.7), V3(-12, 24, 66), {
	{ texto = "MOTEL", alto = 2.6, color = ROSA, borde = CELESTE },
	{ texto = "LUNA", alto = 2.2, color = CELESTE, borde = ROSA },
	{ texto = "24 HS", alto = 1.6, color = AMARILLO },
	{ texto = "TV COLOR", alto = 1.2, color = C3(240, 240, 235), fuente = Enum.Font.Code },
})
neon("LetreroPosteMarco", V3(10.4, 0.35, 0.35), V3(-12, 31.15, 65.6), ROSA, 6, 55)
neon("LetreroPosteBase", V3(10.4, 0.35, 0.35), V3(-12, 16.85, 65.6), CELESTE, 11, 35)
local vacante = letrero("LetreroVacante", V3(8, 2, 0.5), V3(-12, 14.6, 66), {
	{ texto = "VACANTE", alto = 1, color = ROJO },
})
vacante:SetAttribute("Periodo", 4)
CollectionService:AddTag(vacante, "NeonParpadeo")
-- Estrella de neón arriba del letrero (un pentagrama de barras verdes, como los carteles de ruta de las fotos de referencia).
do
	local cx, cy, zEstrella, radio = -12, 35, 65.5, 3.4
	local puntos = {}
	for k = 0, 4 do
		local ang = math.rad(90 + 72 * k)
		puntos[k] = V3(cx + math.cos(ang) * radio, cy + math.sin(ang) * radio, zEstrella)
	end
	for k = 0, 4 do
		local a, b = puntos[k], puntos[(k + 2) % 5]
		local largo = (b - a).Magnitude
		local medio = (a + b) / 2
		local giro = math.atan2(b.Y - a.Y, b.X - a.X)
		local barra = parte("NeonEstrella", V3(largo, 0.3, 0.3), CFrame.new(medio) * CFrame.Angles(0, 0, giro), CELESTE, Enum.Material.Neon, motel, DECO)
		barra:SetAttribute("Periodo", 12)
		CollectionService:AddTag(barra, "NeonParpadeo")
	end
	-- Un resplandor rojizo que tiñe la ruta, como en las fotos.
	local brillo = parte("BrilloRuta", V3(1, 1, 1), V3(cx, 24, 62), ROSA, Enum.Material.SmoothPlastic, motel, { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false })
	local luzRoja = Instance.new("PointLight")
	luzRoja.Range = 80
	luzRoja.Brightness = 0.9
	luzRoja.Color = C3(255, 70, 40)
	luzRoja.Shadows = false
	luzRoja.Parent = brillo
end

-- Auto estacionado frente a una habitación.
-- (se clona el módulo: así el builder no usa una copia vieja guardada en caché si Autos cambió)
local Autos = require(game.ReplicatedStorage.Shared.Autos:Clone())
local estacionado = Autos.crear(C3(120, 30, 40), { conFaros = false })
estacionado:PivotTo(CFrame.new(-22, -0.34, 98.5) * CFrame.Angles(0, math.rad(90), 0))
estacionado.Parent = motel

-- ===== Spawn (detrás del mostrador) =====

local spawn = workspace:FindFirstChild("SpawnLocation")
if spawn then
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CFrame = CFrame.new(-6, 0.5, 6.5)
	for _, d in spawn:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 1
			d.Texture = "" -- el asset de la plantilla no carga y ensucia la consola
		end
	end
end

raiz.Parent = workspace

-- ===== Lo que venía en la plantilla se guarda en ServerStorage/Plantilla (no se borra) =====

local plantilla = game.ServerStorage:FindFirstChild("Plantilla")
if not plantilla then
	plantilla = Instance.new("Folder")
	plantilla.Name = "Plantilla"
	plantilla.Parent = game.ServerStorage
end
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate.Parent = plantilla
end
for _, nombre in { "Sky", "SunRays", "Atmosphere", "Bloom", "DepthOfField" } do
	local obj = game.Lighting:FindFirstChild(nombre)
	if obj then
		obj.Parent = plantilla
	end
end

-- ===== Lighting de noche =====

local L = game.Lighting
local function fijar(prop, valor)
	local ok, err = pcall(function()
		L[prop] = valor
	end)
	if not ok then
		warn("No se pudo fijar Lighting." .. prop .. ": " .. tostring(err))
	end
end
fijar("ClockTime", 0)
fijar("Brightness", 0)
fijar("Ambient", C3(40, 46, 44))
fijar("OutdoorAmbient", C3(12, 14, 14))
fijar("ExposureCompensation", 0)
fijar("EnvironmentDiffuseScale", 0.2)
fijar("EnvironmentSpecularScale", 0)
fijar("FogColor", C3(14, 22, 40))
fijar("FogStart", 120)
fijar("FogEnd", 800)
fijar("GlobalShadows", true)
fijar("LightingStyle", Enum.LightingStyle.Realistic) -- reflejos y brillos más reales
fijar("PrioritizeLightingQuality", true)

-- Sin Atmosphere: con el motel y la ruta lejos, cualquier bruma lavaba la imagen y apagaba las estrellas.
local atm = L:FindFirstChildOfClass("Atmosphere")
if atm then
	atm:Destroy()
end

if not L:FindFirstChild("CieloNegro") then
	local cielo = Instance.new("Sky")
	cielo.Name = "CieloNegro"
	for _, cara in { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" } do
		cielo[cara] = ""
	end
	cielo.Parent = L
end
local cieloNoche = L:FindFirstChild("CieloNegro")
cieloNoche.StarCount = 4000 -- cielo estrellado de ruta
cieloNoche.CelestialBodiesShown = true

local partes = 0
for _, d in raiz:GetDescendants() do
	if d:IsA("BasePart") then
		partes += 1
	end
end
return "Videoclub construido: " .. partes .. " partes"
