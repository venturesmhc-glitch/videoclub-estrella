--!nonstrict
--[[
	Rendimiento (cliente): calidad gráfica para que el juego ande bien en celulares y compus flojas.
	  Alta   todo: las luces del local proyectan sombras
	  Media  sin sombras de luces (lo que más pesa)
	  Baja   sin sombras y con menos estrellas, matorrales y autos
	  Auto   Media en dispositivos táctiles (celulares), Alta en el resto
	El menú de ajustes cambia el nivel con Rendimiento.siguiente().
]]

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local Rendimiento = {}

local NIVELES = { "Auto", "Alta", "Media", "Baja" }
local elegido = "Auto"
local aplicado = "Alta"
local estrellasQuitadas = {}

local function nivelReal(): string
	if elegido ~= "Auto" then
		return elegido
	end
	return UserInputService.TouchEnabled and "Media" or "Alta"
end

local function ajustarLuz(luz: Instance)
	if luz:IsA("Light") then
		-- Las luces de las partes (tubos, faros, neones) solo proyectan sombra en calidad Alta.
		luz.Shadows = aplicado == "Alta" and luz:GetAttribute("SombraOriginal") == true
	end
end

local function registrarLuz(luz: Instance)
	if luz:IsA("Light") then
		if luz:GetAttribute("SombraOriginal") == nil then
			luz:SetAttribute("SombraOriginal", luz.Shadows) -- recuerda cómo la armó el mapa
		end
		ajustarLuz(luz)
	end
end

local function aplicar()
	aplicado = nivelReal()
	for _, d in workspace:GetDescendants() do
		if d:IsA("Light") then
			registrarLuz(d)
		end
	end
	-- Calidad baja: se saca parte del decorado lejano.
	local calle = workspace:FindFirstChild("Videoclub") and workspace.Videoclub:FindFirstChild("CalleDeAfuera")
	local estrellas = calle and calle:FindFirstChild("Estrellas")
	if estrellas then
		local lista = estrellas:GetChildren()
		for i, e in lista do
			if e:IsA("BasePart") and e.Name == "Estrella" then
				local quitar = aplicado == "Baja" and i % 3 ~= 0
				e.Transparency = quitar and 1 or 0
			end
		end
	end
end

function Rendimiento.nivel(): string
	return elegido
end

function Rendimiento.nivelAplicado(): string
	return aplicado
end

function Rendimiento.setNivel(nivel: string)
	if table.find(NIVELES, nivel) then
		elegido = nivel
		aplicar()
	end
end

--- Pasa al siguiente nivel de la lista y devuelve su nombre.
function Rendimiento.siguiente(): string
	local i = table.find(NIVELES, elegido) or 1
	Rendimiento.setNivel(NIVELES[i % #NIVELES + 1])
	return elegido
end

function Rendimiento.init()
	aplicar()
	-- Las luces que aparecen después (faros de los autos, linterna) también se ajustan.
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Light") then
			registrarLuz(d)
		end
	end)
	-- El mapa se arma al empezar: se reaplica cuando llegan los tubos.
	CollectionService:GetInstanceAddedSignal("Tubo"):Connect(function(tubo)
		for _, hijo in tubo:GetChildren() do
			registrarLuz(hijo)
		end
	end)
	task.delay(3, aplicar)
end

return Rendimiento
