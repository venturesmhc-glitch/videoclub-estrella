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
	ubicar(props:FindFirstChild("CartelDeOferta"), 18.7, 19.5)
	ubicar(props:FindFirstChild("PlantaDeOfertas"), 18.5, 23.5)
end
if figuras then
	ubicar(figuras:FindFirstChild("Ficus 6"), 19.68, 14.85)
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

print("[ajustes] " .. #log .. " cambios")
return table.concat(log, "\n")
