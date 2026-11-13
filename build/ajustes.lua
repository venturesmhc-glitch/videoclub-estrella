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
	  - el cartel de neón "DEPÓSITO" quedaba debajo del letrero "STAR VIDEOCLUB" y le tapaba la S
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
	ubicar(figuras:FindFirstChild("Ficus 5"), 20.96, -26.39)
	ubicar(figuras:FindFirstChild("Ficus 4"), 3.67, 29.82)
	ubicar(figuras:FindFirstChild("ExhibidorGiratorio 2"), -13, 23)
	ubicar(figuras:FindFirstChild("FiguraDeCarton 1"), -21.5, 17.5)
	-- el ficus de la esquina de la sala de espera (el que está pegado al muro izquierdo, z ≈ 33) se saca
	for _, m in figuras:GetChildren() do
		if m:IsA("Model") and string.sub(m.Name, 1, 5) == "Ficus" then
			local p = m:GetPivot().Position
			if p.X < -20 and p.Z > 28 then
				table.insert(log, m.Name .. " eliminado")
				m:Destroy()
			end
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
	neon.Position = Vector3.new(-7.3, neon.Position.Y, neon.Position.Z)
end
local afiches = raiz:FindFirstChild("Afiches")
local letrero = afiches and afiches:FindFirstChild("LetreroVideoclub")
if letrero then
	letrero.Position = Vector3.new(1.4, letrero.Position.Y, letrero.Position.Z)
end

print("[ajustes] " .. #log .. " cambios")
return table.concat(log, "\n")
