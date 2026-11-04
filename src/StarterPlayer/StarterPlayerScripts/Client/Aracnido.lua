--!nonstrict
--[[
	Aracnido (cliente): el modelo de las anomalías "FiguraAlFondo". No es el Socio: es una criatura pálida de torso
	delgado, cabeza chica con cara casi humana y ocho patas larguísimas y finas (dos tramos con la rodilla bien alta, como
	una araña grande). Se arma solo con partes (sin malla externa) y las patas se animan por cinemática inversa: cada pie
	queda apoyado en la superficie y da pasos cuando el cuerpo se aleja, así que camina de verdad por el techo y las paredes.

	  local c = Aracnido.crear()               -- c.modelo (parent: Workspace)
	  c.actualizar(cf, dt, mirarA?)            -- cf: pies en la superficie, "arriba" del cf = la normal de la superficie
	  c.destruir()
	Todas las partes son consultables (CanQuery) para poder marcarlas con Q. Los pasos suenan como chasquidos secos y
	agudos (el chasquido de cinta del juego, a otra velocidad) y se oyen en 3D.
	Los valores están en Config.Anomalias.Aracnido.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trepador = require(script.Parent.Trepador)

local Aracnido = {}

local cfg = Config.Anomalias.Aracnido
local rng = Random.new()

local COLOR_PIEL = Color3.fromRGB(176, 172, 163)
local COLOR_PATA = Color3.fromRGB(148, 144, 136)
local COLOR_CABEZA = Color3.fromRGB(196, 192, 184)
local COLOR_HUECO = Color3.fromRGB(8, 8, 10)

local function parte(nombre: string, tam: Vector3, color: Color3, padre: Instance, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true -- se la puede apuntar con Q
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

local function elipsoide(nombre: string, tam: Vector3, color: Color3, padre: Instance)
	local p = parte(nombre, tam, color, padre)
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = p
	return p
end

-- Dos huesos (cadera -> rodilla -> pie) en el plano que contiene la dirección de "flexion". Devuelve la rodilla.
local function ik(cadera: Vector3, pie: Vector3, l1: number, l2: number, flexion: Vector3): (Vector3, Vector3)
	local delta = pie - cadera
	local distancia = delta.Magnitude
	if distancia < 1e-3 then
		return cadera + flexion.Unit * l1, pie
	end
	local dir = delta / distancia
	local d = math.clamp(distancia, math.abs(l1 - l2) + 0.05, l1 + l2 - 0.05)
	local a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
	local h = math.sqrt(math.max(l1 * l1 - a * a, 0))
	local ortogonal = flexion - dir * flexion:Dot(dir)
	if ortogonal.Magnitude < 1e-3 then
		ortogonal = Vector3.new(0, 1, 0)
	end
	return cadera + dir * a + ortogonal.Unit * h, cadera + dir * d -- (el pie efectivo no pasa del alcance)
end

local function segmento(p: Part, a: Vector3, b: Vector3, grosor: number)
	local largo = math.max((b - a).Magnitude, 0.05)
	p.Size = Vector3.new(grosor, grosor, largo)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
end

--- Arma la criatura. Devuelve { modelo, actualizar(cf, dt, mirarA?), destruir() }.
function Aracnido.crear()
	-- La criatura nueva (modelo con esqueleto, Client/Trepador) si el molde está en el lugar; si no, esta de partes.
	local trepador = Trepador.crear()
	if trepador then
		return trepador
	end
	local modelo = Instance.new("Model")
	modelo.Name = "Aracnido"

	local torso = elipsoide("Torso", Vector3.new(1.5, 1.3, 3.1), COLOR_PIEL, modelo)
	local cuello = parte("Cuello", Vector3.new(0.34, 0.34, 1.3), COLOR_PATA, modelo)
	local cabeza = elipsoide("Cabeza", Vector3.new(1.05, 1.55, 1.05), COLOR_CABEZA, modelo)
	-- Cara: dos cuencas negras con un punto blanco brillante, y una boca fina y ancha.
	local rasgos = {}
	for _, lado in { -1, 1 } do
		local cuenca = elipsoide("Cuenca", Vector3.new(0.42, 0.34, 0.2), COLOR_HUECO, modelo)
		local pupila = parte("Pupila", Vector3.new(0.12, 0.12, 0.08), Color3.fromRGB(255, 255, 255), modelo, Enum.Material.Neon)
		table.insert(rasgos, { parte = cuenca, local_ = CFrame.new(lado * 0.27, 0.22, -0.46) })
		table.insert(rasgos, { parte = pupila, local_ = CFrame.new(lado * 0.27, 0.22, -0.56) })
	end
	local boca = parte("Boca", Vector3.new(0.62, 0.07, 0.1), COLOR_HUECO, modelo)
	table.insert(rasgos, { parte = boca, local_ = CFrame.new(0, -0.38, -0.5) })
	local mandibula = parte("Mandibula", Vector3.new(0.34, 0.5, 0.12), COLOR_HUECO, modelo) -- boca abierta, larga, hacia abajo
	table.insert(rasgos, { parte = mandibula, local_ = CFrame.new(0, -0.66, -0.47) })

	-- Ocho patas: cuatro de cada lado.
	local patas = {}
	for _, lado in { -1, 1 } do
		for i = 1, 4 do
			local def = cfg.Patas[i]
			local pata = {
				lado = lado,
				grupo = (i + (lado == 1 and 1 or 0)) % 2,
				cadera = Vector3.new(lado * 0.55, 0.1, def.cadera), -- relativo al torso
				reposo = Vector3.new(lado * def.apoyo, 0, def.z), -- relativo a los pies del cuerpo (en la superficie)
				muslo = parte("Muslo", Vector3.new(0.26, 0.26, 1), COLOR_PATA, modelo),
				pierna = parte("Pierna", Vector3.new(0.19, 0.19, 1), COLOR_PATA, modelo),
				rodilla = elipsoide("Rodilla", Vector3.new(0.46, 0.46, 0.46), COLOR_HUECO, modelo),
				garra = parte("Garra", Vector3.new(0.1, 0.1, 0.5), COLOR_HUECO, modelo),
				pie = nil, -- posición mundial donde está apoyado
				paso = nil, -- { desde, hasta, t, dur } mientras da un paso
			}
			table.insert(patas, pata)
		end
	end

	-- Sonidos de los pasos: un par de chasquidos que se turnan (3D, salen del torso).
	local chasquidos = {}
	for i = 1, 4 do
		local s = Instance.new("Sound")
		s.SoundId = Config.Sustos.Glitch.Id
		s.Volume = cfg.VolumenPaso
		s.RollOffMaxDistance = 55
		s.RollOffMinDistance = 6
		s.Parent = torso
		chasquidos[i] = s
	end
	local siguienteChasquido = 1

	local objeto = { modelo = modelo }
	local posAnterior: Vector3? = nil
	local velocidad = 0
	local direccion = Vector3.new(0, 0, -1)
	local reloj = rng:NextNumber(0, 10)

	function objeto.actualizar(cf: CFrame, dt: number, mirarA: Vector3?)
		reloj += dt
		local pos = cf.Position
		if posAnterior and dt > 0 then
			local v = (pos - posAnterior) / dt
			velocidad += (v.Magnitude - velocidad) * math.min(1, dt * 10)
			if v.Magnitude > 0.3 then
				direccion = v.Unit
			end
		end
		posAnterior = pos
		local arriba = cf.UpVector

		-- Cuerpo: flota a cierta altura de la superficie, con un leve vaivén.
		local altura = cfg.AlturaCuerpo + math.sin(reloj * 3.1) * 0.08
		local cfTorso = cf * CFrame.new(0, altura, 0)
		torso.CFrame = cfTorso

		-- Cabeza al frente, mirando al jugador; el cuello la une al torso.
		local ancla = cfTorso * Vector3.new(0, 0.1, -1.35)
		local posCabeza = cfTorso * Vector3.new(0, 0.5, -2.05)
		cabeza.CFrame = if mirarA and (mirarA - posCabeza).Magnitude > 0.1
			then CFrame.lookAt(posCabeza, mirarA)
			else CFrame.lookAt(posCabeza, posCabeza + cf.LookVector)
		segmento(cuello, ancla, posCabeza - cabeza.CFrame.LookVector * 0.2, 0.34)
		for _, r in rasgos do
			r.parte.CFrame = cabeza.CFrame * r.local_
		end

		-- Patas: cada pie queda apoyado y da un paso cuando se aleja de su posición de reposo.
		local enPaso = {}
		for _, pata in patas do
			if pata.paso then
				enPaso[pata.lado .. "_" .. pata.grupo] = true
			end
		end
		local movimiento = math.clamp(velocidad / 8, 0, 1)
		local umbral = cfg.UmbralPaso * (1 - 0.65 * (1 - movimiento))
		for _, pata in patas do
			local reposoMundo = cf * pata.reposo
			if not pata.pie then
				pata.pie = reposoMundo
			end
			if pata.paso then
				local p = pata.paso
				p.t += dt / p.dur
				if p.t >= 1 then
					pata.pie = p.hasta
					pata.paso = nil
					local s = chasquidos[siguienteChasquido]
					siguienteChasquido = siguienteChasquido % #chasquidos + 1
					s.PlaybackSpeed = rng:NextNumber(1.7, 3)
					s.TimePosition = 0
					s:Play()
				else
					pata.pie = p.desde:Lerp(p.hasta, p.t) + arriba * math.sin(p.t * math.pi) * cfg.AlturaPaso
				end
			else
				local desvio = (pata.pie - reposoMundo).Magnitude
				local libre = not enPaso[pata.lado .. "_" .. (1 - pata.grupo)] -- no levanta una pata del mismo lado y del otro grupo a la vez
				if desvio > cfg.AlcanceMax then
					pata.pie = reposoMundo -- se quedó muy atrás (por ejemplo, un cambio brusco de superficie)
				elseif desvio > umbral and libre then
					local adelanto = direccion * math.min(velocidad * 0.18, cfg.AdelantoMax)
					pata.paso = {
						desde = pata.pie,
						hasta = reposoMundo + adelanto,
						t = 0,
						dur = math.clamp(cfg.PasoSeg / (1 + velocidad * 0.06), 0.07, cfg.PasoSeg),
					}
					enPaso[pata.lado .. "_" .. pata.grupo] = true
				end
			end

			local cadera = cfTorso * pata.cadera
			local flexion = cf:VectorToWorldSpace(Vector3.new(pata.lado * 0.55, 1, 0)) -- la rodilla sube y se abre
			local rodilla, pieEfectivo = ik(cadera, pata.pie, cfg.LargoMuslo, cfg.LargoPierna, flexion)
			segmento(pata.muslo, cadera, rodilla, 0.26)
			segmento(pata.pierna, rodilla, pieEfectivo, 0.19)
			pata.rodilla.CFrame = CFrame.new(rodilla)
			segmento(pata.garra, pieEfectivo, pieEfectivo + (pieEfectivo - rodilla).Unit * 0.35, 0.1)
		end
	end

	function objeto.destruir()
		modelo:Destroy()
	end

	return objeto
end

return Aracnido
