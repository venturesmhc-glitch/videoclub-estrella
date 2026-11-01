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
	local modelo = Personajes.crear({
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
	if not modelo then
		return Instance.new("Model") -- sin cuerpo: que el resto del sistema siga andando
	end
	modelo.Name = "Silueta"
	Personajes.convertirEnTitere(modelo, color)
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = consultable
			if sombraHumana then
				d.Transparency = math.max(d.Transparency, 0.5) -- la sombra de una anomalía es medio translúcida: se nota que no es el Socio
			end
		end
	end
	local raiz = modelo.PrimaryPart
	if raiz then
		raiz.PivotOffset = CFrame.new(0, -(modelo:GetAttribute("AlturaRaiz") or 3), 0)
	end
	Personajes.animar(modelo)
	return modelo
end

-- Precarga la malla (tarda un poco la primera vez) para que crear() no espere.
task.spawn(Personajes.crearSocioMalla, Config.Socio)

return Silueta
