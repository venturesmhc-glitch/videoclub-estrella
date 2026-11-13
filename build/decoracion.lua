--[[
	Decoración del salón de Star Videoclub: la "vida" del local. Se corre DESPUÉS de build/videoclub.lua:
	  node mcp-call.js execute_luau @build/videoclub.lua
	  node mcp-call.js execute_luau @build/decoracion.lua
	Es idempotente (borra Workspace.Videoclub.Decoracion y la vuelve a crear) y al final regenera los Waypoints del Socio
	(los muebles sólidos nuevos cambian por dónde puede pasar).

	Lo que agrega: zócalo de paneles con guarda rosa en todas las paredes, cielorraso con tablero, caños y rejillas, afiches de películas
	(atlas hecho en Blender, blender/afiches.py) en las paredes y las puntas de las góndolas, neones y luces de color, tres arcades,
	máquina de pochoclos, sala de espera con sofá y lámpara, torre de televisores, exhibidores giratorios, figuras de cartón, plantas,
	bebedero, matafuegos, reloj, y el desorden de un local abierto de noche (cintas tiradas, cinta magnética desenrollada, piso mojado).
]]

local CollectionService = game:GetService("CollectionService")
local Config = require(game.ReplicatedStorage.Shared.Config:Clone())

local V3, C3, CF = Vector3.new, Color3.fromRGB, CFrame.new
local rng = Random.new(2026)

local PROF = Config.Local.ExtensionFondo
local TEX = Config.Local.Texturas
local EXT = Config.Local.ExtensionFrente
local AV = Config.Local.MostradorAvance
local Z_FRENTE = Config.Local.ZFrente
local Z_ATRAS = -12 - PROF -- cara interior de la pared divisoria
local ZI = Z_FRENTE - 0.5 -- cara interior de la pared del frente

local raiz = workspace:FindFirstChild("Videoclub")
assert(raiz, "Primero hay que correr build/videoclub.lua")
local viejo = raiz:FindFirstChild("Decoracion")
if viejo then
	viejo:Destroy()
end
local deco = Instance.new("Folder")
deco.Name = "Decoracion"

local DECO = { CanCollide = false, CanTouch = false, CanQuery = false }
local SOLIDO = { CanTouch = false }

local function carpeta(nombre)
	local f = Instance.new("Folder")
	f.Name = nombre
	f.Parent = deco
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
	p.CFrame = typeof(pos) == "CFrame" and pos or CF(pos)
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	p.Parent = padre
	return p
end

local function cilindro(nombre, diametro, altura, cf, color, material, padre, extra)
	-- eje del cilindro de Roblox = X: se lo acuesta 90° sobre Z para que quede vertical
	local p = parte(nombre, V3(altura, diametro, diametro), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, padre, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function bola(nombre, d, pos, color, material, padre, extra)
	local p = parte(nombre, V3(d, d, d), pos, color, material, padre, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

local function texto(p, cara, contenido, fuente, colorTexto, colorFondo, brillo)
	local sg = Instance.new("SurfaceGui")
	sg.Face = cara
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	if brillo then
		sg.LightInfluence = 0
		sg.Brightness = brillo
	end
	sg.Parent = p
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = colorFondo or Color3.new(0, 0, 0)
	fondo.BackgroundTransparency = colorFondo and 0 or 1
	fondo.BorderSizePixel = 0
	fondo.Parent = sg
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.94, 0.8)
	t.Position = UDim2.fromScale(0.03, 0.1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = fuente or Enum.Font.Arcade
	t.TextColor3 = colorTexto or C3(240, 240, 230)
	t.Text = contenido
	t.Parent = fondo
	return t
end

local function luz(padre, color, rango, brillo, tipo)
	local l = Instance.new(tipo or "PointLight")
	l.Color = color
	l.Range = rango
	l.Brightness = brillo
	l.Shadows = false
	l.Parent = padre
	return l
end

-- Neón: parte brillante (parpadea según el atributo Periodo con el tag NeonParpadeo: lo hace Client/Calle).
local function neon(nombre, tam, pos, color, padre, periodo, rango, brillo)
	local p = parte(nombre, tam, pos, color, Enum.Material.Neon, padre, DECO)
	if periodo then
		p:SetAttribute("Periodo", periodo)
		CollectionService:AddTag(p, "NeonParpadeo")
	end
	if rango then
		luz(p, color, rango, brillo or 0.7)
	end
	return p
end

-- Rótulo luminoso: panel oscuro con texto que brilla (el SurfaceGui no recibe luz ambiente).
local function rotulo(nombre, tam, cf, lineas, caras, padre, periodo, colorLuz, rango)
	local panel = parte(nombre, tam, cf, C3(14, 12, 18), Enum.Material.SmoothPlastic, padre, DECO)
	local total = 0
	for _, l in lineas do
		total += l.alto
	end
	for _, cara in caras do
		local sg = Instance.new("SurfaceGui")
		sg.Face = cara
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.LightInfluence = 0
		sg.Brightness = 3
		sg.Parent = panel
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
	end
	if periodo then
		panel:SetAttribute("Periodo", periodo)
		CollectionService:AddTag(panel, "NeonParpadeo")
	end
	if colorLuz then
		luz(panel, colorLuz, rango or 14, 0.35)
	end
	return panel
end

-- ===== Afiches (hechos en Blender: 8 imágenes de 512x768; índice 0..7) =====

local function imagenAfiche(p, cara, idx)
	local sg = Instance.new("SurfaceGui")
	sg.Face = cara
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 120
	sg.Parent = p
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = TEX.Afiches[idx % #TEX.Afiches + 1]
	img.Parent = sg
end

-- cara: la cara del afiche (Right/Left en las paredes laterales, Front/Back en las de adelante y atrás).
local function afiche(padre, idx, pos, cara, ancho, alto)
	ancho = ancho or 2.4
	alto = alto or 3.6
	local lateral = cara == Enum.NormalId.Right or cara == Enum.NormalId.Left
	local tam = lateral and V3(0.1, alto, ancho) or V3(ancho, alto, 0.1)
	local marco = lateral and V3(0.08, alto + 0.3, ancho + 0.3) or V3(ancho + 0.3, alto + 0.3, 0.08)
	local desfase = lateral and V3(cara == Enum.NormalId.Right and -0.05 or 0.05, 0, 0) or V3(0, 0, cara == Enum.NormalId.Back and -0.05 or 0.05)
	parte("AficheMarco", marco, pos + desfase, C3(24, 20, 18), Enum.Material.Wood, padre, DECO).MaterialVariant = ""
	local p = parte("Afiche", tam, pos, C3(255, 255, 255), Enum.Material.SmoothPlastic, padre, DECO)
	imagenAfiche(p, cara, idx)
	return p
end

local afiches = carpeta("Afiches")
do
	local i = 0
	-- Paredes laterales (sobre los estantes): se saltea la zona de las puertas de la cocina y el patio (z -13..-6.5).
	for _, z in { -26, -21, -16.5, 3, 12.5, 19, 23.5, 28, 32 } do
		afiche(afiches, i % 8, V3(-23.88, 9.3, z), Enum.NormalId.Right)
		i += 3
		afiche(afiches, i % 8, V3(23.88, 9.3, z), Enum.NormalId.Left)
		i += 2
	end
	-- Pared del fondo (divisoria): grandes, a los lados de las puertas del depósito y el baño.
	for k, x in { -21, -17, -13, -1.5, 3, 7.5, 21.5 } do
		afiche(afiches, (k * 3) % 8, V3(x, 5.2, Z_ATRAS + 0.12), Enum.NormalId.Back, 3.2, 4.8)
	end
	-- Puntas de las góndolas: cada pasillo anuncia su género (un afiche por extremo).
	local GENERO_IDX = { [-14] = 1, [-7] = 0, [0] = 2, [7] = 3, [14] = 4 }
	for x, idx in GENERO_IDX do
		afiche(afiches, idx, V3(x, 4.2, -6.15), Enum.NormalId.Front, 2, 3)
		afiche(afiches, 5 - idx % 3, V3(x, 4.2, -13.85), Enum.NormalId.Back, 2, 3)
		afiche(afiches, idx, V3(x, 4.2, Z_ATRAS + 4 - 0.15), Enum.NormalId.Front, 2, 3)
	end
end

-- ===== Zócalo de paneles con guarda rosa, y cielorraso =====

local paredes = carpeta("Paredes")
local COL_PANEL, COL_GUARDA, COL_BASE = C3(24, 60, 74), C3(214, 58, 142), C3(16, 16, 20)

-- eje "X": pared que corre a lo largo de x en z = fijo; "Z": a lo largo de z en x = fijo. signo: hacia el interior del salón.
local function paneles(eje, fijo, signo, a, b)
	local largo, c = b - a, (a + b) / 2
	local function una(y0, y1, prof, color, material)
		local tam = eje == "X" and V3(largo, y1 - y0, prof) or V3(prof, y1 - y0, largo)
		local pos = eje == "X" and V3(c, (y0 + y1) / 2, fijo + signo * prof / 2) or V3(fijo + signo * prof / 2, (y0 + y1) / 2, c)
		return parte("Panel", tam, pos, color, material, paredes, DECO)
	end
	una(0.45, 3.4, 0.14, COL_PANEL, Enum.Material.Fabric)
	una(3.4, 3.7, 0.2, COL_GUARDA, Enum.Material.SmoothPlastic)
	una(0, 0.45, 0.22, COL_BASE, Enum.Material.SmoothPlastic)
	-- Moldura fina arriba, bajo el cielorraso.
	una(11.55, 12, 0.18, C3(70, 52, 60), Enum.Material.SmoothPlastic)
end
paneles("Z", -24, 1, Z_ATRAS, -11.5)
paneles("Z", -24, 1, -8, ZI)
paneles("Z", 24, -1, Z_ATRAS, -11.5)
paneles("Z", 24, -1, -8, ZI)
paneles("X", ZI, -1, -24, -3.3)
paneles("X", ZI, -1, 3.3, 24)
paneles("X", Z_ATRAS, 1, -24, -8.3)
paneles("X", Z_ATRAS, 1, -3.7, 13.7)
paneles("X", Z_ATRAS, 1, 18.3, 24)

local techo = raiz:FindFirstChild("Estructura") and raiz.Estructura:FindFirstChild("Techo")
if techo then
	-- Tablero del cielorraso: juntas de 4 x 4 studs.
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Tablero"
	sg.Face = Enum.NormalId.Bottom
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 12
	sg.Parent = techo
	local PPS, paso = 12, 4
	for i = 0, math.floor(techo.Size.X / paso) do
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(i * paso * PPS, 0)
		f.Size = UDim2.fromOffset(2, techo.Size.Z * PPS)
		f.BackgroundColor3 = C3(120, 116, 106)
		f.BackgroundTransparency = 0.3
		f.BorderSizePixel = 0
		f.Parent = sg
	end
	for j = 0, math.floor(techo.Size.Z / paso) do
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(0, j * paso * PPS)
		f.Size = UDim2.fromOffset(techo.Size.X * PPS, 2)
		f.BackgroundColor3 = C3(120, 116, 106)
		f.BackgroundTransparency = 0.3
		f.BorderSizePixel = 0
		f.Parent = sg
	end
end

local alto = carpeta("Cielorraso")
-- Caños a lo largo del salón, pegados a las paredes (uno blanco y uno oxidado), con abrazaderas.
for _, c in { { -23.2, C3(190, 190, 184) }, { 23.2, C3(120, 70, 50) } } do
	local largoTotal = ZI - Z_ATRAS - 2
	local cano = parte("Cano", V3(largoTotal, 0.7, 0.7), CF(c[1], 11.15, (ZI + Z_ATRAS) / 2) * CFrame.Angles(0, math.rad(90), 0), c[2], Enum.Material.Metal, alto, DECO)
	cano.Shape = Enum.PartType.Cylinder
	for z = Z_ATRAS + 4, ZI - 4, 9 do
		parte("Abrazadera", V3(0.9, 0.3, 0.35), V3(c[1], 11.15, z), C3(60, 60, 62), Enum.Material.Metal, alto, DECO)
		parte("AbrazaderaPata", V3(0.12, 0.5, 0.12), V3(c[1], 11.6, z), C3(60, 60, 62), Enum.Material.Metal, alto, DECO)
	end
end
-- Conducto de aire a lo ancho del fondo y rejillas de ventilación.
parte("Conducto", V3(46, 1.3, 1.8), V3(0, 11.2, Z_ATRAS + 2.2), C3(150, 154, 156), Enum.Material.Metal, alto, DECO)
for x = -18, 18, 12 do
	parte("ConductoJunta", V3(0.25, 1.4, 1.95), V3(x, 11.2, Z_ATRAS + 2.2), C3(110, 114, 116), Enum.Material.Metal, alto, DECO)
end
for _, p in { V3(-8, 0, -2), V3(8, 0, 12), V3(0, 0, 26), V3(-14, 0, -20), V3(14, 0, -24) } do
	parte("Rejilla", V3(2.8, 0.15, 1.8), V3(p.X, 11.9, p.Z), C3(60, 62, 62), Enum.Material.Metal, alto, DECO)
	for i = -3, 3 do
		parte("RejillaBarra", V3(2.6, 0.06, 0.1), V3(p.X, 11.78, p.Z + i * 0.22), C3(150, 152, 152), Enum.Material.Metal, alto, DECO)
	end
end

-- ===== Neones y luces de color =====

local neones = carpeta("Neones")
-- Tira de LED arriba de los estantes de pared (celeste a la izquierda, rosa a la derecha).
for _, tramo in { { -26, -14 }, { -3, 17 } } do
	local largo = tramo[2] - tramo[1]
	local z = (tramo[1] + tramo[2]) / 2
	neon("TiraIzq", V3(0.18, 0.18, largo), V3(-22.9, 6.6, z), C3(60, 240, 255), neones, 17, 11, 0.45)
	neon("TiraDer", V3(0.18, 0.18, largo), V3(22.9, 6.6, z), C3(255, 70, 190), neones, 23, 11, 0.45)
end
-- Cartel principal sobre la puerta (adentro) y "ABIERTO" en la ventana.
rotulo("CartelPrincipal", V3(14, 2.6, 0.3), CF(0, 10.4, ZI - 0.2), {
	{ texto = "VIDEO CLUB", alto = 1.7, color = C3(255, 214, 80), borde = C3(255, 90, 160) },
	{ texto = "ALQUILER · VENTA · ESTRENOS", alto = 0.8, color = C3(110, 240, 255), fuente = Enum.Font.Code },
}, { Enum.NormalId.Front }, neones, 29, C3(255, 120, 150), 18)
rotulo("CartelAbierto", V3(6, 1.5, 0.3), CF(15.5, 7.4, ZI - 0.5), {
	{ texto = "ABIERTO", alto = 1, color = C3(255, 60, 70) },
	{ texto = "24 HS", alto = 0.6, color = C3(120, 255, 200), fuente = Enum.Font.Code },
}, { Enum.NormalId.Front, Enum.NormalId.Back }, neones, 13, C3(255, 80, 80), 14)
-- Salidas de emergencia sobre las puertas de la cocina y el patio.
for _, lado in { -1, 1 } do
	rotulo("Salida", V3(0.25, 0.9, 2.4), CF(lado * 23.8, 9.7, -9.75), {
		{ texto = "SALIDA", alto = 1, color = C3(80, 255, 130), fuente = Enum.Font.SourceSansBold },
	}, { lado < 0 and Enum.NormalId.Right or Enum.NormalId.Left }, neones, nil, C3(80, 255, 130), 10)
end
rotulo("SalidaDeposito", V3(2.4, 0.9, 0.25), CF(-6, 9.7, Z_ATRAS + 0.2), {
	{ texto = "DEPÓSITO", alto = 1, color = C3(255, 214, 80), fuente = Enum.Font.SourceSansBold },
}, { Enum.NormalId.Back }, neones, nil, nil)
rotulo("SalidaBano", V3(2.4, 0.9, 0.25), CF(16, 9.7, Z_ATRAS + 0.2), {
	{ texto = "BAÑO", alto = 1, color = C3(110, 240, 255), fuente = Enum.Font.SourceSansBold },
}, { Enum.NormalId.Back }, neones, nil, nil)
-- Letras en la vidriera.
local vidrios = raiz:FindFirstChild("Estructura") and raiz.Estructura:FindFirstChild("Vidrios")
if vidrios then
	for _, v in vidrios:GetChildren() do
		if v.Name == "VentanaDerecha" or v.Name == "VentanaIzquierda" then
			for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local sg = Instance.new("SurfaceGui")
				sg.Face = cara
				sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sg.PixelsPerStud = 40
				sg.LightInfluence = 0.3
				sg.Parent = v
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(0.8, 0.22)
				t.Position = UDim2.fromScale(0.1, 0.12)
				t.TextScaled = true
				t.Font = Enum.Font.Arcade
				t.TextColor3 = v.Name == "VentanaDerecha" and C3(255, 214, 80) or C3(255, 110, 190)
				t.Text = v.Name == "VentanaDerecha" and "VHS · BETA · ESTRENOS" or "SOCIO 2x1 LOS MARTES"
				t.Parent = sg
			end
		end
	end
end

-- ===== Arcades (junto a la pared derecha) =====

local arcades = carpeta("Arcades")
local function arcade(x, z, color, titulo, lineas)
	local cf = CF(x, 0, z) * CFrame.Angles(0, math.rad(90), 0) -- el frente (-Z local) mira hacia -X (hacia el salón)
	local m = Instance.new("Model")
	m.Name = "Arcade"
	m.Parent = arcades
	parte("ArcadeCuerpo", V3(2.5, 3.4, 2.5), cf * CF(0, 1.7, 0.2), color, Enum.Material.SmoothPlastic, m, SOLIDO)
	parte("ArcadeTablero", V3(2.5, 0.35, 1.5), cf * CF(0, 3.6, -0.9) * CFrame.Angles(math.rad(-14), 0, 0), C3(24, 24, 30), Enum.Material.SmoothPlastic, m, DECO)
	parte("ArcadeTorre", V3(2.5, 2.9, 1.7), cf * CF(0, 5.0, 0.55), color, Enum.Material.SmoothPlastic, m, SOLIDO)
	parte("ArcadeMarco", V3(2.2, 2.0, 0.15), cf * CF(0, 4.75, -0.31) * CFrame.Angles(math.rad(-8), 0, 0), C3(10, 10, 14), Enum.Material.SmoothPlastic, m, DECO)
	local pantalla = parte("ArcadePantalla", V3(1.9, 1.6, 0.06), cf * CF(0, 4.78, -0.4) * CFrame.Angles(math.rad(-8), 0, 0), C3(10, 14, 30), Enum.Material.SmoothPlastic, m, DECO)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.Brightness = 2.2
	sg.Parent = pantalla
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = C3(8, 10, 30)
	fondo.BorderSizePixel = 0
	fondo.Parent = sg
	for i, l in lineas do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.9, 0.2)
		t.Position = UDim2.fromScale(0.05, 0.08 + (i - 1) * 0.24)
		t.TextScaled = true
		t.Font = Enum.Font.Arcade
		t.TextColor3 = l
		t.Text = ({ "SCORE 004210", "¡¡ INSERT COIN !!", "HI 099990", "PRESS START" })[i] or ""
		t.Parent = fondo
		if i == 2 or i == 4 then
			CollectionService:AddTag(t, "ArcadeParpadeo") -- Client/VidaLocal lo hace titilar
		end
	end
	-- Invasores de pixeles en la pantalla.
	for i = 0, 5 do
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(0.07, 0.06)
		f.Position = UDim2.fromScale(0.12 + i * 0.14, 0.78 + (i % 2) * 0.07)
		f.BackgroundColor3 = i % 2 == 0 and C3(80, 255, 140) or C3(255, 80, 190)
		f.BorderSizePixel = 0
		f.Parent = fondo
	end
	luz(pantalla, C3(90, 170, 255), 13, 0.8, "SurfaceLight").Face = Enum.NormalId.Front
	local marquesina = parte("ArcadeMarquesina", V3(2.5, 0.7, 0.5), cf * CF(0, 6.35, 0.1), C3(14, 12, 18), Enum.Material.SmoothPlastic, m, DECO)
	texto(marquesina, Enum.NormalId.Front, titulo, Enum.Font.Arcade, C3(255, 230, 90), nil, 3)
	-- Palanca y botones.
	cilindro("ArcadePalancaBase", 0.35, 0.1, cf * CF(-0.5, 3.85, -1.15), C3(10, 10, 12), Enum.Material.Metal, m, DECO)
	cilindro("ArcadePalanca", 0.1, 0.6, cf * CF(-0.5, 4.15, -1.15), C3(60, 60, 64), Enum.Material.Metal, m, DECO)
	bola("ArcadePalancaBola", 0.38, cf * CF(-0.5, 4.5, -1.15), C3(230, 40, 50), Enum.Material.SmoothPlastic, m, DECO)
	for i, c in { C3(255, 220, 50), C3(60, 200, 255), C3(255, 90, 190) } do
		cilindro("ArcadeBoton", 0.3, 0.1, cf * CF(0.1 + i * 0.4, 3.85, -1.0), c, Enum.Material.Neon, m, DECO)
	end
	-- Franjas de color a los costados.
	for _, dx in { -1.26, 1.26 } do
		parte("ArcadeFranja", V3(0.04, 3.4, 2.0), cf * CF(dx, 1.7, 0.3), C3(255, 210, 60), Enum.Material.Neon, m, DECO)
	end
	return m
end
arcade(22.7, 26.4, C3(26, 40, 110), "GALAXY WARS", { C3(255, 240, 120), C3(255, 80, 120), C3(120, 255, 200), C3(255, 255, 255) })
arcade(22.7, 29.2, C3(110, 26, 70), "STREET BOXER", { C3(120, 255, 200), C3(255, 240, 120), C3(255, 80, 120), C3(255, 255, 255) })
arcade(22.7, 32, C3(30, 90, 50), "SNAKE RALLY", { C3(255, 80, 120), C3(120, 255, 200), C3(255, 240, 120), C3(255, 255, 255) })

-- ===== Máquina de pochoclos =====

do
	local pochoclos = carpeta("Pochoclos")
	local cf = CF(22.6, 0, 20.4) * CFrame.Angles(0, math.rad(90), 0)
	parte("Gabinete", V3(2.8, 3.1, 2.4), cf * CF(0, 1.55, 0), C3(176, 30, 36), Enum.Material.SmoothPlastic, pochoclos, SOLIDO)
	parte("GabineteZocalo", V3(2.9, 0.3, 2.5), cf * CF(0, 0.15, 0), C3(30, 28, 30), Enum.Material.SmoothPlastic, pochoclos, DECO)
	parte("Vidriera", V3(2.7, 2.5, 2.3), cf * CF(0, 4.35, 0), C3(220, 235, 240), Enum.Material.Glass, pochoclos, { Transparency = 0.7, CanCollide = false, CanTouch = false })
	for _ = 1, 70 do
		bola("Pochoclo", rng:NextNumber(0.3, 0.5), cf * CF(rng:NextNumber(-1.1, 1.1), 3.25 + rng:NextNumber(0, 1.8), rng:NextNumber(-0.9, 0.9)), C3(rng:NextInteger(244, 255), rng:NextInteger(226, 244), rng:NextInteger(170, 200)), Enum.Material.SmoothPlastic, pochoclos, DECO)
	end
	for i = -1, 1 do
		parte("Franja", V3(2.9, 0.6, 0.05), cf * CF(i * 0.9, 5.9, -1.2), i % 2 == 0 and C3(255, 220, 60) or C3(190, 30, 36), Enum.Material.SmoothPlastic, pochoclos, DECO)
	end
	parte("Techo", V3(3, 0.35, 2.6), cf * CF(0, 5.75, 0), C3(255, 214, 60), Enum.Material.SmoothPlastic, pochoclos, DECO)
	local cartel = parte("Cartel", V3(2.6, 0.7, 0.12), cf * CF(0, 2.6, -1.25), C3(255, 214, 60), Enum.Material.SmoothPlastic, pochoclos, DECO)
	texto(cartel, Enum.NormalId.Front, "POCHOCLOS", Enum.Font.Arcade, C3(150, 20, 24))
	local foco = parte("FocoVidriera", V3(0.5, 0.2, 0.5), cf * CF(0, 5.5, 0), C3(255, 230, 150), Enum.Material.Neon, pochoclos, DECO)
	luz(foco, C3(255, 200, 110), 12, 0.9)
end

-- ===== Sala de espera (esquina izquierda del frente) =====

do
	local sala = carpeta("SalaDeEspera")
	local TELA, MADERA = C3(150, 38, 70), C3(52, 36, 28)
	-- Sofá de tres cuerpos contra la pared izquierda, mirando hacia +X.
	parte("SofaBase", V3(2.8, 1.3, 7), V3(-22.4, 0.85, 28), TELA, Enum.Material.Fabric, sala, SOLIDO)
	parte("SofaRespaldo", V3(0.9, 2.6, 7), V3(-23.4, 2.4, 28), C3(128, 30, 58), Enum.Material.Fabric, sala, SOLIDO)
	for _, dz in { -3.3, 3.3 } do
		parte("SofaBrazo", V3(2.8, 2.1, 0.7), V3(-22.4, 1.7, 28 + dz), C3(128, 30, 58), Enum.Material.Fabric, sala, SOLIDO)
	end
	for i = -1, 1 do
		parte("SofaCojin", V3(2.2, 0.35, 2), V3(-22.2, 1.65, 28 + i * 2.2), C3(170, 48, 82), Enum.Material.Fabric, sala, DECO)
	end
	bola("Almohadon", 1.2, V3(-22.5, 2.4, 25.8), C3(255, 200, 60), Enum.Material.Fabric, sala, DECO)
	-- Mesa baja con revistas.
	parte("MesaBaja", V3(2.4, 0.3, 4), V3(-18.6, 1.55, 28), MADERA, Enum.Material.Wood, sala, SOLIDO)
	for _, dz in { -1.6, 1.6 } do
		for _, dx in { -0.9, 0.9 } do
			parte("MesaBajaPata", V3(0.25, 1.4, 0.25), V3(-18.6 + dx, 0.7, 28 + dz), C3(30, 26, 24), Enum.Material.Wood, sala, DECO)
		end
	end
	local COL_REV = { C3(220, 60, 60), C3(60, 150, 220), C3(240, 200, 60), C3(90, 190, 120), C3(200, 90, 200) }
	for i = 1, 7 do
		parte("Revista", V3(0.9, 0.05, 1.2), CF(-18.6 + rng:NextNumber(-0.7, 0.7), 1.74 + i * 0.045, 28 + rng:NextNumber(-1.4, 1.4)) * CFrame.Angles(0, rng:NextNumber(-0.7, 0.7), 0), COL_REV[(i - 1) % #COL_REV + 1], Enum.Material.SmoothPlastic, sala, DECO)
	end
	-- Lámpara de pie con luz cálida.
	cilindro("LamparaBase", 1.1, 0.15, CF(-22.5, 0.08, 22.5), C3(30, 28, 26), Enum.Material.Metal, sala, DECO)
	cilindro("LamparaPie", 0.14, 6.2, CF(-22.5, 3.2, 22.5), C3(60, 58, 54), Enum.Material.Metal, sala, DECO)
	local pantalla = parte("LamparaPantalla", V3(1.6, 1.3, 1.6), CF(-22.5, 6.6, 22.5), C3(255, 214, 150), Enum.Material.Neon, sala, DECO)
	pantalla.Transparency = 0.25
	luz(pantalla, C3(255, 190, 120), 20, 0.9)
	-- Banco bajo las ventanas del frente.
	parte("BancoAsiento", V3(10, 0.35, 1.5), V3(-15, 1.7, ZI - 1), C3(60, 44, 34), Enum.Material.Wood, sala, SOLIDO)
	for _, dx in { -4.5, 0, 4.5 } do
		parte("BancoPata", V3(0.35, 1.6, 1.2), V3(-15 + dx, 0.8, ZI - 1), C3(30, 28, 28), Enum.Material.Metal, sala, DECO)
	end
	for i = 0, 3 do
		parte("BancoCojin", V3(2, 0.3, 1.2), V3(-18.4 + i * 2.5, 1.97, ZI - 1), i % 2 == 0 and C3(40, 70, 130) or C3(200, 160, 50), Enum.Material.Fabric, sala, DECO)
	end
end

-- ===== Torre de televisores (zona derecha, de cara a la puerta) =====

do
	local torre = carpeta("TorreTV")
	local cf0 = CF(16, 0, 7.5) * CFrame.Angles(0, math.rad(180), 0) -- el frente (-Z local) mira hacia +Z (hacia la entrada)
	local NIVELES, COLS = { 0.5, 3.4 }, { -1.7, 1.7 }
	for _, dx in { -3.6, 3.6 } do
		for _, dz in { -0.9, 0.9 } do
			parte("TorrePoste", V3(0.25, 6.2, 0.25), cf0 * CF(dx, 3.1, dz), C3(34, 34, 38), Enum.Material.Metal, torre, SOLIDO)
		end
	end
	for _, y in NIVELES do
		parte("TorreEstante", V3(7.4, 0.2, 2.2), cf0 * CF(0, y, 0), C3(60, 60, 66), Enum.Material.Metal, torre, SOLIDO)
	end
	local PROGRAMAS = { "barras", "estatica", "play", "barras" }
	local n = 0
	for _, y in NIVELES do
		for _, dx in COLS do
			n += 1
			local cf = cf0 * CF(dx, y + 1.3, 0)
			parte("TVCuerpo", V3(3.1, 2.4, 2), cf * CF(0, 0, 0.2), C3(52, 50, 48), Enum.Material.Plastic, torre, DECO)
			local pantalla = parte("TVPantalla", V3(2.4, 1.8, 0.08), cf * CF(0, 0.05, -0.8), C3(14, 18, 20), Enum.Material.SmoothPlastic, torre, DECO)
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 40
			sg.LightInfluence = 0
			sg.Brightness = 2
			sg.Parent = pantalla
			local fondo = Instance.new("Frame")
			fondo.Size = UDim2.fromScale(1, 1)
			fondo.BorderSizePixel = 0
			fondo.Parent = sg
			local prog = PROGRAMAS[n]
			if prog == "barras" then
				fondo.BackgroundColor3 = C3(20, 20, 24)
				local BARRAS = { C3(230, 230, 230), C3(230, 230, 40), C3(40, 230, 230), C3(40, 230, 40), C3(230, 40, 230), C3(230, 40, 40), C3(40, 40, 230) }
				for i, c in BARRAS do
					local f = Instance.new("Frame")
					f.Size = UDim2.fromScale(1 / 7, 0.7)
					f.Position = UDim2.fromScale((i - 1) / 7, 0)
					f.BackgroundColor3 = c
					f.BorderSizePixel = 0
					f.Parent = fondo
				end
			elseif prog == "estatica" then
				CollectionService:AddTag(fondo, "TVEstatica") -- Client/VidaLocal mueve las rayas
				fondo.BackgroundColor3 = C3(120, 120, 124)
				for _ = 1, 60 do
					local f = Instance.new("Frame")
					local g = rng:NextInteger(30, 230)
					f.Size = UDim2.fromScale(rng:NextNumber(0.05, 0.3), 0.025)
					f.Position = UDim2.fromScale(rng:NextNumber(0, 0.8), rng:NextNumber(0, 1))
					f.BackgroundColor3 = C3(g, g, g)
					f.BorderSizePixel = 0
					f.Parent = fondo
				end
			else
				fondo.BackgroundColor3 = C3(20, 30, 130)
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(0.5, 0.2)
				t.Position = UDim2.fromScale(0.06, 0.08)
				t.TextScaled = true
				t.Font = Enum.Font.Code
				t.TextColor3 = C3(240, 240, 240)
				t.Text = "▶ PLAY"
				t.Parent = fondo
			end
			luz(pantalla, C3(130, 170, 255), 9, 0.55, "SurfaceLight").Face = Enum.NormalId.Front
		end
	end
	local carteles = parte("TorreCartel", V3(5, 0.9, 0.12), cf0 * CF(0, 6.8, 0), C3(180, 30, 40), Enum.Material.SmoothPlastic, torre, DECO)
	texto(carteles, Enum.NormalId.Front, "LOS MÁS ALQUILADOS", Enum.Font.Arcade, C3(255, 230, 120))
end

-- ===== Figuras de cartón, exhibidores giratorios y plantas =====

local figuras = carpeta("Figuras")
local function figura(x, z, idx, giro)
	local cf = CF(x, 0, z) * CFrame.Angles(0, giro, 0)
	for _, dx in { -0.9, 0.9 } do
		parte("FiguraPie", V3(0.3, 0.35, 1.8), cf * CF(dx, 0.18, 0.3), C3(30, 28, 28), Enum.Material.SmoothPlastic, figuras, DECO)
	end
	parte("FiguraBase", V3(2.4, 0.3, 0.9), cf * CF(0, 0.15, 0.4), C3(30, 28, 28), Enum.Material.SmoothPlastic, figuras, SOLIDO)
	local p = parte("FiguraCarton", V3(3, 4.6, 0.14), cf * CF(0, 2.55, 0), C3(255, 255, 255), Enum.Material.SmoothPlastic, figuras, DECO)
	imagenAfiche(p, Enum.NormalId.Front, idx)
	local dorso = parte("FiguraDorso", V3(3, 4.6, 0.1), cf * CF(0, 2.55, 0.12), C3(150, 120, 80), Enum.Material.Cardboard, figuras, DECO)
	return p
end
figura(-10.5, 25.5, 1, math.rad(180))
figura(10.5, 25.5, 4, math.rad(180))
figura(-23, 17.5, 2, math.rad(90)) -- a la izquierda, al lado de los estantes: mira hacia +X
figura(-3.5, Z_ATRAS + 1.2, 7, math.rad(180)) -- el Socio de cartón, al final del pasillo largo, mirando hacia +Z

local function exhibidor(x, z)
	cilindro("ExhibidorBase", 2.2, 0.3, CF(x, 0.15, z), C3(30, 28, 30), Enum.Material.Metal, figuras, SOLIDO)
	cilindro("ExhibidorPoste", 0.4, 6.4, CF(x, 3.2, z), C3(60, 60, 66), Enum.Material.Metal, figuras, SOLIDO)
	local COL = { C3(210, 60, 50), C3(240, 200, 50), C3(60, 150, 220), C3(80, 190, 120), C3(200, 90, 200), C3(30, 30, 36) }
	for nivel = 0, 3 do
		local y = 1.4 + nivel * 1.3
		parte("ExhibidorEstante", V3(2.4, 0.1, 2.4), CF(x, y - 0.55, z) * CFrame.Angles(0, nivel * 0.4, 0), C3(54, 40, 32), Enum.Material.Wood, figuras, DECO)
		for lado = 0, 3 do
			local base = CFrame.new(x, y, z) * CFrame.Angles(0, nivel * 0.4 + lado * math.pi / 2, 0)
			for k = -2, 2 do
				local c = COL[rng:NextInteger(1, #COL)]
				parte("ExhibidorCasete", V3(0.38, 1.0, 0.1), base * CF(k * 0.42, 0, 1.1) * CFrame.Angles(math.rad(-10), 0, 0), c, Enum.Material.SmoothPlastic, figuras, DECO)
			end
		end
	end
	local tope = parte("ExhibidorCartel", V3(2.2, 0.7, 2.2), CF(x, 6.7, z), C3(30, 28, 32), Enum.Material.SmoothPlastic, figuras, DECO)
	for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		texto(tope, cara, "ESTRENOS", Enum.Font.Arcade, C3(255, 214, 80))
	end
end
exhibidor(-13, 21)
exhibidor(11.5, 21)
exhibidor(-12, -9.5) -- en el cruce de las puertas, entre los dos bloques de góndolas

local function ficus(x, z, k)
	k = k or 1
	cilindro("FicusMaceta", 1.7 * k, 1.4 * k, CF(x, 0.7 * k, z), C3(150, 78, 54), Enum.Material.Concrete, figuras, SOLIDO)
	cilindro("FicusTronco", 0.3 * k, 3 * k, CF(x, 2.6 * k, z), C3(78, 56, 40), Enum.Material.Wood, figuras, DECO)
	for i = 1, 9 do
		local a = i * 2.4
		local r = rng:NextNumber(0.4, 1.2) * k
		bola("FicusHojas", rng:NextNumber(1.1, 1.8) * k, V3(x + math.cos(a) * r, (3.2 + rng:NextNumber(0, 2)) * k, z + math.sin(a) * r), C3(rng:NextInteger(32, 52), rng:NextInteger(86, 120), rng:NextInteger(40, 60)), Enum.Material.Grass, figuras, DECO)
	end
end
ficus(-22.5, 33, 1.1)
ficus(22.5, 15, 1)
ficus(-22.5, -8.2, 0.9)
ficus(22.5, -28.5, 1)
ficus(-6.2, 31.5, 0.9)
ficus(6.2, 31.5, 0.9)

-- ===== Bebedero, matafuegos y reloj =====

do
	local varios = carpeta("Varios")
	local bx, bz = 1.5, Z_ATRAS + 1.2
	parte("BebederoCuerpo", V3(1.5, 3.3, 1.4), V3(bx, 1.65, bz), C3(232, 232, 228), Enum.Material.SmoothPlastic, varios, SOLIDO)
	cilindro("BebederoBotellon", 1.2, 1.8, CF(bx, 4.2, bz), C3(120, 190, 240), Enum.Material.Glass, varios, { Transparency = 0.45, CanCollide = false, CanTouch = false })
	parte("BebederoCanilla", V3(0.3, 0.3, 0.3), V3(bx, 2.3, bz + 0.8), C3(60, 150, 230), Enum.Material.Plastic, varios, DECO)
	luz(parte("BebederoLed", V3(0.15, 0.15, 0.1), V3(bx + 0.4, 2.8, bz + 0.72), C3(80, 200, 255), Enum.Material.Neon, varios, DECO), C3(80, 200, 255), 5, 0.4)
	-- Matafuegos (con cartel) en la pared izquierda y en la divisoria.
	for _, m in { { V3(-23.55, 3.8, 19), Enum.NormalId.Right }, { V3(10.5, 3.8, Z_ATRAS + 0.55), Enum.NormalId.Back } } do
		local pos = m[1]
		cilindro("Matafuego", 0.9, 2.2, CF(pos), C3(196, 28, 30), Enum.Material.Metal, varios, DECO)
		parte("MatafuegoManija", V3(0.6, 0.2, 0.2), pos + V3(0, 1.2, 0), C3(20, 20, 22), Enum.Material.Metal, varios, DECO)
		local cartel = parte("MatafuegoCartel", m[2] == Enum.NormalId.Right and V3(0.05, 0.9, 0.9) or V3(0.9, 0.9, 0.05), pos + V3(m[2] == Enum.NormalId.Right and -0.42 or 0, 1.9, m[2] == Enum.NormalId.Back and -0.42 or 0), C3(200, 30, 30), Enum.Material.SmoothPlastic, varios, DECO)
		texto(cartel, m[2], "SOS", Enum.Font.Arcade, C3(255, 255, 255))
	end
	-- Reloj de pared (analógico) sobre el cartel del fondo.
	local reloj = parte("Reloj", V3(0.15, 2.6, 2.6), CF(-12, 9, Z_ATRAS + 0.12) * CFrame.Angles(0, math.rad(90), 0), C3(240, 236, 224), Enum.Material.SmoothPlastic, varios, DECO)
	reloj.Shape = Enum.PartType.Cylinder
	parte("RelojAguja", V3(0.1, 0.9, 0.05), CF(-12, 9.3, Z_ATRAS + 0.2), C3(10, 10, 10), Enum.Material.SmoothPlastic, varios, DECO)
	parte("RelojAgujaCorta", V3(0.7, 0.1, 0.05), CF(-11.65, 9, Z_ATRAS + 0.2) * CFrame.Angles(0, 0, math.rad(-8)), C3(10, 10, 10), Enum.Material.SmoothPlastic, varios, DECO)
end

-- ===== Desorden de un local abierto de noche =====

do
	local piso = carpeta("Desorden")
	-- Cintas tiradas.
	local VHS = { C3(22, 22, 24), C3(34, 30, 30), C3(28, 34, 44), C3(50, 28, 28) }
	local ETIQ = { C3(236, 230, 210), C3(210, 70, 56), C3(230, 200, 80), C3(90, 140, 190) }
	local function cinta(x, z, giro)
		local cf = CF(x, 0.15, z) * CFrame.Angles(0, giro, 0)
		parte("CintaTirada", V3(1.1, 0.3, 0.8), cf, VHS[rng:NextInteger(1, #VHS)], Enum.Material.SmoothPlastic, piso, DECO)
		parte("CintaTiradaEtiqueta", V3(0.7, 0.02, 0.5), cf * CF(0, 0.16, 0), ETIQ[rng:NextInteger(1, #ETIQ)], Enum.Material.SmoothPlastic, piso, DECO)
	end
	for _ = 1, 22 do
		local carril = ({ -18.9, -10.5, -3.5, 3.5, 10.5, 18.9 })[rng:NextInteger(1, 6)]
		cinta(carril + rng:NextNumber(-1.3, 1.3), rng:NextNumber(Z_ATRAS + 4, -14) , rng:NextNumber(0, 6.28))
	end
	for _ = 1, 8 do
		cinta(rng:NextNumber(-20, 20), rng:NextNumber(4, 32), rng:NextNumber(0, 6.28))
	end
	-- Cinta magnética desenrollada: un hilo oscuro que serpentea por el pasillo.
	local function hilo(x, z, largo, dir)
		local pos, ang = V3(x, 0.06, z), dir
		for _ = 1, largo do
			ang += rng:NextNumber(-0.5, 0.5)
			local paso = 0.8
			local sig = pos + V3(math.sin(ang), 0, math.cos(ang)) * paso
			parte("CintaMagnetica", V3(0.12, 0.03, paso + 0.05), CF((pos + sig) / 2, sig) , C3(36, 26, 22), Enum.Material.SmoothPlastic, piso, DECO)
			pos = sig
		end
	end
	hilo(-10.5, -26, 28, 0)
	hilo(3.5, -22, 22, 0.15)
	hilo(18.9, -12, 18, 0.3)
	hilo(-18.9, 8, 14, 3.2)
	-- Piso mojado: cartel amarillo y un charco.
	do
		local x, z = 3.5, -9.5
		local charco = parte("Charco", V3(4.4, 0.03, 3), V3(x, 0.07, z), C3(26, 34, 44), Enum.Material.Glass, piso, { Transparency = 0.25, CanCollide = false, CanTouch = false, CanQuery = false })
		charco.Shape = Enum.PartType.Cylinder
		charco.CFrame = CF(x, 0.07, z) * CFrame.Angles(0, 0, math.rad(90))
		charco.Size = V3(0.03, 3.4, 4.4)
		for _, s in { -1, 1 } do
			local panel = parte("PisoMojadoPanel", V3(1.6, 2.4, 0.08), CF(x + 3.4, 1.2, z) * CFrame.Angles(0, 0, 0) * CF(0, 0, s * 0.45) * CFrame.Angles(s * math.rad(-14), 0, 0), C3(255, 210, 40), Enum.Material.SmoothPlastic, piso, DECO)
			texto(panel, s == 1 and Enum.NormalId.Back or Enum.NormalId.Front, "PISO MOJADO", Enum.Font.Arcade, C3(30, 30, 30))
		end
	end
	-- Balde con trapeador junto al depósito.
	cilindro("Balde", 1.4, 1.5, CF(-1, 0.75, Z_ATRAS + 1.2), C3(240, 200, 30), Enum.Material.Plastic, piso, SOLIDO)
	parte("TrapeadorPalo", V3(0.14, 5, 0.14), CF(-0.7, 3.3, Z_ATRAS + 1.5) * CFrame.Angles(math.rad(8), 0, math.rad(6)), C3(150, 108, 62), Enum.Material.Wood, piso, DECO)
	-- Cajas apiladas en el pasillo de atrás.
	for i, p in { V3(-21.5, 0, Z_ATRAS + 2.2), V3(-19.6, 0, Z_ATRAS + 2.2), V3(22, 0, Z_ATRAS + 2.2) } do
		parte("CajaApilada", V3(1.8, 1.4, 1.6), CF(p.X, 0.7, p.Z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), C3(168, 130, 84), Enum.Material.Cardboard, piso, SOLIDO)
		if i < 3 then
			parte("CajaApilada", V3(1.4, 1.1, 1.3), CF(p.X + 0.1, 1.95, p.Z) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), C3(152, 118, 76), Enum.Material.Cardboard, piso, DECO)
		end
	end
end

-- ===== Polvo flotando en el aire (se ve a contraluz de los tubos) =====

do
	local aire = carpeta("Aire")
	for _, z in { -14, 6, 24 } do
		local caja = parte("PolvoFuente", V3(44, 6, 18), V3(0, 6, z), C3(255, 255, 255), nil, aire, { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false })
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(C3(200, 196, 170))
		e.LightEmission = 0.1
		e.LightInfluence = 1
		e.Rate = 5
		e.Lifetime = NumberRange.new(7, 12)
		e.Speed = NumberRange.new(0.05, 0.3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.07)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.7), NumberSequenceKeypoint.new(0.8, 0.7), NumberSequenceKeypoint.new(1, 1) })
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = caja
	end
end

deco.Parent = raiz

-- ===== Waypoints (se regeneran: los muebles sólidos nuevos cambian por dónde puede pasar el Socio) =====

for _, w in CollectionService:GetTagged("Waypoint") do
	w:Destroy()
end
local waypoints = raiz:FindFirstChild("Waypoints")
if not waypoints then
	waypoints = Instance.new("Folder")
	waypoints.Name = "Waypoints"
	waypoints.Parent = raiz
end
local function generarWaypoints()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { raiz }
	local function libre(x, z)
		for _, p in workspace:GetPartBoundsInBox(CF(x, 3.6, z), V3(3.4, 5.2, 3.4), params) do
			if p.CanCollide and p.Name ~= "Techo" then
				return false
			end
		end
		return true
	end
	local n = 0
	local function punto(x, z)
		local w = Instance.new("Part")
		w.Name = "Waypoint"
		w.Size = V3(0.6, 0.6, 0.6)
		w.Anchored = true
		w.Transparency = 1
		w.CanCollide, w.CanTouch, w.CanQuery = false, false, false
		w.Position = V3(x, 3, z)
		w.Parent = waypoints
		CollectionService:AddTag(w, "Waypoint")
		n += 1
	end
	local PASO = 4.5
	for _, r in {
		{ -22.5, 22.5, Z_ATRAS + 2, ZI - 1.5 },
		{ -22.5, 5, -20.5 - PROF + 1.5, -13 - PROF },
		{ 9, 22.5, -20.5 - PROF + 1.5, -13 - PROF },
		{ -50.5, -26, -19.5, -2.5 },
		{ 26.5, 50.5, -19.5, -2.5 },
	} do
		local x = r[1]
		while x <= r[2] do
			local z = r[3]
			while z <= r[4] do
				if libre(x, z) then
					punto(x, z)
				end
				z += PASO
			end
			x += PASO
		end
	end
	for _, w in { { -22.5, -9.75 }, { -26.5, -9.75 }, { 22.5, -9.75 }, { 26.5, -9.75 }, { -6, -13 - PROF }, { -6, -17 - PROF }, { 16, -13 - PROF }, { 16, -17 - PROF } } do
		punto(w[1], w[2])
	end
	return n
end
local nWaypoints = generarWaypoints()

local partes = 0
for _, d in deco:GetDescendants() do
	if d:IsA("BasePart") then
		partes += 1
	end
end
return "Decoración: " .. partes .. " partes, " .. nWaypoints .. " waypoints"
