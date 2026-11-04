--!nonstrict
--[[
	Silueta (cliente): la figura oscura del Socio, un cuerpo humano alto y sin cara. La usan la cinta y las anomalías.
	Silueta.crear(consultable, sombraHumana?): si consultable es true los raycasts la detectan (para poder "marcarla" con Q).
	sombraHumana = true arma una sombra humana oscura en vez de la criatura del Socio (la usan las anomalías).
	El pivote del modelo está a la altura de los pies: PivotTo(CFrame en el piso) la apoya en el piso.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Personajes = require(ReplicatedStorage.Shared.Personajes)

local Silueta = {}

local animaciones = setmetatable({}, { __mode = "k" }) -- modelo -> controlador de animaciones (Personajes.animar)

--- El controlador de animaciones de una silueta humana (caminar(bool)), o nil si no tiene.
function Silueta.animacion(modelo: Model)
	return animaciones[modelo]
end

function Silueta.crear(consultable: boolean, sombraHumana: boolean?): Model
	local color = Config.Socio.Color
	-- La criatura generada con IA, si carga en el cliente; si no, el cuerpo humano de respaldo.
	-- (Las anomalías piden "sombraHumana": una figura quieta distinta del Socio, para no confundirlas con él.)
	local malla = not sombraHumana and Personajes.crearSocioMalla(Config.Socio) or nil
	if malla then
		malla.Name = "Silueta"
		for _, d in malla:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanQuery = consultable
			end
		end
		return malla
	end
	local figura = Config.Anomalias.Figura
	local modelo
	if sombraHumana then
		-- Sombra de anomalía: una persona de tamaño normal, negra como el hueco de una cinta, sin cara ni ojos.
		-- Se distingue del Socio (alto, encorvado, de ojos blancos) y se reconoce por el contorno de estática.
		modelo = Personajes.crear({
			piel = figura.Color,
			ropa = figura.Color,
			pantalon = figura.Color,
			sinCara = true,
			escala = figura.Escala,
			ancho = figura.Ancho,
		})
	else
		modelo = Personajes.crear({
			piel = color,
			ropa = color,
			pantalon = color,
			sinCara = true,
			escala = Config.Socio.Escala,
			ancho = Config.Socio.Ancho,
			cabeza = Config.Socio.Cabeza,
			proporcion = Config.Socio.Proporcion,
			ojos = Config.Socio.ColorOjos,
		})
	end
	if not modelo then
		return Instance.new("Model") -- sin cuerpo: que el resto del sistema siga andando
	end
	modelo.Name = "Silueta"
	Personajes.convertirEnTitere(modelo, sombraHumana and figura.Color or color)
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = consultable
			if sombraHumana then
				d.Material = Enum.Material.SmoothPlastic
				d.Transparency = figura.Transparencia
			end
		end
	end
	if sombraHumana then
		-- Contorno de estática: parpadea como una imagen mal sintonizada, con cortes más fuertes de tanto en tanto.
		local contorno = Instance.new("Highlight")
		contorno.Name = "ContornoEstatica"
		contorno.FillColor = figura.Color
		contorno.FillTransparency = 0.1
		contorno.OutlineColor = figura.ColorContorno
		contorno.OutlineTransparency = 0.5
		contorno.DepthMode = Enum.HighlightDepthMode.Occluded
		contorno.Parent = modelo
		task.spawn(function()
			local azar = Random.new()
			while contorno.Parent do
				local corte = azar:NextNumber() < 0.18
				contorno.OutlineTransparency = corte and azar:NextNumber(0.02, 0.15) or azar:NextNumber(0.35, 0.8)
				contorno.FillTransparency = corte and azar:NextNumber(0.4, 0.7) or azar:NextNumber(0.05, 0.2)
				task.wait(corte and azar:NextNumber(0.04, 0.09) or azar:NextNumber(0.08, 0.45))
			end
		end)
	end
	local raiz = modelo.PrimaryPart
	if raiz then
		raiz.PivotOffset = CFrame.new(0, -(modelo:GetAttribute("AlturaRaiz") or 3), 0)
	end
	animaciones[modelo] = Personajes.animar(modelo)
	return modelo
end

-- Precarga la malla (tarda un poco la primera vez) para que crear() no espere.
task.spawn(Personajes.crearSocioMalla, Config.Socio)

return Silueta
