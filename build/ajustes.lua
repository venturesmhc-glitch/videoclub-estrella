--[[
	Ajustes de la decoración del salón para que no haya objetos superpuestos. Se corre DESPUÉS de build/videoclub.lua,
	build/decoracion.lua y build/agrupar.lua:
	  node mcp-call.js execute_luau @build/ajustes.lua

	Es idempotente: pone cada objeto en una posición absoluta (X, Z; la altura no se toca), así que correrlo dos veces no mueve nada de más.
	Lo que corrige:
	  - el cartel "2x1" tapaba la máquina de pochoclos (se corrió 1,5 studs hacia el salón) y la planta chica estaba pegada a la máquina y al arcade
	  - un ficus atravesaba los estantes de la pared derecha (Ficus 6), otro el muro del fondo y el afiche (Ficus 5) y otro el pilar de ofertas (Ficus 4)
	  - el ficus de la sala de espera (Ficus 2) atravesaba la pared y el sofá en una esquina ya llena: se elimina
	  - un exhibidor giratorio entraba en el mostrador y una figura de cartón en los estantes de la pared izquierda
	  - los arcades se hundían en la pared derecha y la mesa baja rozaba el exhibidor de ofertas
	  - el cartel de neón "DEPÓSITO" quedaba debajo del letrero "STAR VIDEOCLUB" y le tapaba la S: ahora "DEPÓSITO" está centrado sobre la
	    puerta (x = -6) y el letrero grande corrido a la derecha (x = 3)
	Y quita lo que estorbaba o no tenía sentido: las dos plantas de la entrada (tapaban la caja de devoluciones y las instrucciones), el
	estante giratorio de estrenos entre los dos tramos de la góndola ACCIÓN, la figura de cartón del Socio N° 0000 frente al depósito, el
	cartel SOS del matafuego izquierdo, los dos neones "SALIDA" (no dan a ninguna salida) y la caja junto a la puerta del baño.
	La planta de la puerta de la cocina se corrió a lo largo de la pared, fuera del hueco, y la del baño quedó en la esquina.
	Junto a los pochoclos: se sacan las dos plantas (Ficus 6 y la planta chica), la máquina se corre 2,6 studs hacia los arcades (z = 23) y el
	cartel 2x1 queda en el hueco que se forma entre la máquina y los estantes de la pared. También se saca el póster "Dos locos y un destino"
	de la pared del fondo (el que queda pegado al matafuego con el cartel SOS).
	En la pared del frente la guarda rosa (Decoracion/Paredes/Panel, y = 3,55) tapaba la ranura de la caja de devoluciones y la primera
	instrucción de "EL TURNO" del cartel: la ranura baja a y = 2,95 (entre la caja y la guarda), el cartel de instrucciones se adelanta
	para quedar por delante de la guarda, y la franja crema "DEVOLUCIONES" lleva el texto en negro de cara al salón.
]]

local raiz = workspace:FindFirstChild("Videoclub")
assert(raiz, "Primero hay que correr build/videoclub.lua")
local deco = raiz:FindFirstChild("Decoracion")
assert(deco, "Primero hay que correr build/decoracion.lua")

local log = {}

-- Pone el pivote del objeto en (x, z), sin cambiar su altura ni su giro.
local function ubicar(objeto: Instance?, x: number, z: number)
	if not objeto then
		return
	end
	if objeto:IsA("Model") then
		local p = objeto:GetPivot()
		objeto:PivotTo(p + Vector3.new(x - p.Position.X, 0, z - p.Position.Z))
	elseif objeto:IsA("BasePart") then
		objeto.Position = Vector3.new(x, objeto.Position.Y, z)
	end
	table.insert(log, string.format("%s -> (%.2f, %.2f)", objeto.Name, x, z))
end

local figuras = deco:FindFirstChild("Figuras")
local props = raiz:FindFirstChild("Props")
local espera = deco:FindFirstChild("SalaDeEspera")

-- Cartel 2x1, planta chica y ficus
if props then
	ubicar(props:FindFirstChild("CartelDeOferta"), 22.2, 19.2) -- entre los estantes de la pared (z < 17) y la máquina de pochoclos (z 21,7 a 24,3)
	local planta = props:FindFirstChild("PlantaDeOfertas")
	if planta then
		table.insert(log, "PlantaDeOfertas eliminada")
		planta:Destroy()
	end
end
-- máquina de pochoclos (con su letrero) más a la derecha, contra los arcades
local pochoclos = deco:FindFirstChild("Pochoclos")
if pochoclos then
	ubicar(pochoclos:FindFirstChild("MaquinaDePochoclos"), 22.6, 23.0)
	local letreroMaquina = pochoclos:FindFirstChild("CartelPochoclos")
	if letreroMaquina then
		letreroMaquina.Position = Vector3.new(letreroMaquina.Position.X, letreroMaquina.Position.Y, 23.0)
	end
end
-- póster "Dos locos y un destino" (pared del fondo, x = 7,5) con su marco
local afichesDeco = deco:FindFirstChild("Afiches")
if afichesDeco then
	for _, a in afichesDeco:GetChildren() do
		if a:IsA("BasePart") and (a.Name == "Afiche" or a.Name == "AficheMarco") and math.abs(a.Position.X - 7.5) < 0.2 and a.Position.Z < -28 then
			table.insert(log, "póster de la pared del fondo eliminado")
			a:Destroy()
		end
	end
end
if figuras then
	local ficus6 = figuras:FindFirstChild("Ficus 6") -- junto a los pochoclos
	if ficus6 then
		table.insert(log, "Ficus 6 eliminado")
		ficus6:Destroy()
	end
	ubicar(figuras:FindFirstChild("Ficus 5"), 22.0, -27.6) -- esquina del fondo derecho, junto a la puerta del baño
	ubicar(figuras:FindFirstChild("Ficus 1"), -22.4, -5.5) -- puerta de la cocina: fuera del hueco (z de -11,5 a -8)
	ubicar(figuras:FindFirstChild("ExhibidorGiratorio 2"), -13, 23)
	ubicar(figuras:FindFirstChild("FiguraDeCarton 1"), -21.5, 17.5)
	-- los ficus de la entrada (z > 28: dos junto a los pilares y uno en la esquina de la sala de espera) se sacan
	for _, m in figuras:GetChildren() do
		if m:IsA("Model") and string.sub(m.Name, 1, 5) == "Ficus" and m:GetPivot().Position.Z > 28 then
			table.insert(log, m.Name .. " eliminado")
			m:Destroy()
		end
	end
	-- estante giratorio de estrenos entre los tramos de la góndola ACCIÓN (z < 0) y figura de cartón frente al depósito (z < -20)
	for _, m in figuras:GetChildren() do
		if m:IsA("Model") then
			local z = m:GetPivot().Position.Z
			local x = m:GetPivot().Position.X
			-- figuras de cartón: la del depósito (z < -20) y las dos de la entrada que miran a las ventanas (z > 20, a los costados)
			local cartonSobra = string.sub(m.Name, 1, 14) == "FiguraDeCarton" and (z < -20 or (z > 20 and math.abs(x) > 8))
			if (string.sub(m.Name, 1, 18) == "ExhibidorGiratorio" and z < 0) or cartonSobra then
				table.insert(log, m.Name .. " eliminado")
				m:Destroy()
			end
		end
	end
end

-- cartel SOS del matafuego izquierdo, neones SALIDA y caja junto al baño
local varios = deco:FindFirstChild("Varios")
if varios then
	for _, m in varios:GetChildren() do
		if m:IsA("Model") and string.sub(m.Name, 1, 9) == "Matafuego" and m:GetPivot().Position.X < -20 then
			local cartel = m:FindFirstChild("MatafuegoCartel")
			if cartel then
				table.insert(log, "cartel SOS eliminado")
				cartel:Destroy()
			end
		end
	end
end
local neonesFolder = deco:FindFirstChild("Neones")
if neonesFolder then
	for _, p in neonesFolder:GetChildren() do
		if p.Name == "Salida" then
			table.insert(log, "neon SALIDA eliminado")
			p:Destroy()
		end
	end
end
local desorden = deco:FindFirstChild("Desorden")
if desorden then
	for _, p in desorden:GetChildren() do
		if p.Name == "CajaApilada" and p:IsA("BasePart") and p.Position.X > 19 and p.Position.Z < -25 then
			table.insert(log, "caja junto al baño eliminada")
			p:Destroy()
		end
	end
end

-- Arcades (contra la pared derecha) y mesa baja
local arcades = deco:FindFirstChild("Arcades")
if arcades then
	local lista = arcades:GetChildren()
	table.sort(lista, function(a, b)
		return a:GetPivot().Position.Z < b:GetPivot().Position.Z
	end)
	for i, m in lista do
		ubicar(m, 22.4, 26.4 + (i - 1) * 2.8)
	end
end
if espera then
	ubicar(espera:FindFirstChild("MesaBaja"), -19, 28)
end

-- Neón "DEPÓSITO" y letrero principal de la pared del fondo
local neones = deco:FindFirstChild("Neones")
local neon = neones and neones:FindFirstChild("SalidaDeposito")
if neon then
	neon.Position = Vector3.new(-6.0, neon.Position.Y, neon.Position.Z)
end
local afiches = raiz:FindFirstChild("Afiches")
local letrero = afiches and afiches:FindFirstChild("LetreroVideoclub")
if letrero then
	letrero.Position = Vector3.new(3.0, letrero.Position.Y, letrero.Position.Z)
end

-- ===== Pared del frente: caja de devoluciones e instrucciones =====
local devoluciones = raiz:FindFirstChild("Devoluciones")
if devoluciones then
	local interior = devoluciones:FindFirstChild("RanuraInterior")
	local exterior = devoluciones:FindFirstChild("RanuraExterior")
	if interior then
		-- más abajo (la guarda rosa pasa a y = 3,4 a 3,7) y por delante de la cara de la pared (z = 34) para que se vea
		interior.Position = Vector3.new(interior.Position.X, 2.95, 33.92)
	end
	if exterior then
		exterior.Position = Vector3.new(exterior.Position.X, 2.95, exterior.Position.Z)
	end
	local franja = devoluciones:FindFirstChild("CartelDevoluciones")
	if franja then
		-- el texto estaba solo en la cara de atrás (la que mira a la pared): se agrega el de la cara que mira al salón, en negro
		local frente
		for _, g in franja:GetChildren() do
			if g:IsA("SurfaceGui") and g.Face == Enum.NormalId.Front then
				frente = g
			end
		end
		if not frente then
			frente = Instance.new("SurfaceGui")
			frente.Name = "TextoFrente"
			frente.Face = Enum.NormalId.Front
			frente.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			frente.PixelsPerStud = 100
			frente.LightInfluence = 0
			frente.Parent = franja
		end
		local etiqueta = frente:FindFirstChildWhichIsA("TextLabel", true)
		if not etiqueta then
			etiqueta = Instance.new("TextLabel")
			etiqueta.Name = "Texto"
			etiqueta.Size = UDim2.fromScale(1, 1)
			etiqueta.BackgroundTransparency = 1
			etiqueta.Parent = frente
		end
		etiqueta.Text = "DEVOLUCIONES"
		etiqueta.Font = Enum.Font.Arcade
		etiqueta.TextScaled = true
		etiqueta.TextColor3 = Color3.new(0, 0, 0)
		table.insert(log, "DEVOLUCIONES (texto negro) en la cara del salón")
	end
end
local cartelInstrucciones = raiz:FindFirstChild("Afiches") and raiz.Afiches:FindFirstChild("CartelInstrucciones")
local marcoInstrucciones = raiz:FindFirstChild("Afiches") and raiz.Afiches:FindFirstChild("CartelInstruccionesMarco")
if cartelInstrucciones and marcoInstrucciones then
	-- por delante de la guarda rosa (su cara del salón está en z = 33,8)
	cartelInstrucciones.Position = Vector3.new(cartelInstrucciones.Position.X, cartelInstrucciones.Position.Y, 33.70)
	marcoInstrucciones.Position = Vector3.new(marcoInstrucciones.Position.X, marcoInstrucciones.Position.Y, 33.76)
end

print("[ajustes] " .. #log .. " cambios")
return table.concat(log, "\n")
