--!nonstrict
--[[
	Trepador (cliente): la criatura de las anomalías "FiguraAlFondo". Modelo con esqueleto de 70 huesos hecho en Blender
	(blender/trepador.py): piel negra y húmeda, cráneo largo y demacrado con la boca abierta y seis extremidades larguísimas
	(cuatro brazos con manos de cinco dedos y dos patas). Se mueve pegado a la superficie que le dé Client/Reptante.

	  local c = Trepador.crear()               -- nil si ReplicatedStorage.TrepadorModelo no está (se usa la criatura vieja)
	  c.modelo.Parent = workspace
	  c.actualizar(cf, dt, mirarA?)            -- cf: pies en la superficie, "arriba" del cf = la normal de la superficie
	  c.ataque(true)                           -- salta sobre la cámara: patas recogidas, brazos y mandíbula abiertos
	  c.gritar(u, abre)                        -- screamer (u de 0 a 1): a partir de `abre` abre la boca del todo y alza los brazos
	  c.destruir()

	Animación (todo a tirones, como el resto de las criaturas del juego):
	  * Marcha en trípode: los seis pies quedan apoyados en el mundo y dan pasos por cinemática inversa de dos tramos (hombro ->
	    codo -> mano). Se mueven dos grupos de tres que se turnan, así nunca quedan menos de tres apoyos.
	  * Cabeza que sigue al jugador, pero a tirones: cada 0,1 a 0,55 s salta a un nuevo ángulo (con ruido), repartido por el cuello.
	  * Mandíbula que castañetea, dedos que se crispan al azar y, quieta, un gesto de vez en cuando (giro de cabeza de 180°,
	  	olfateo, tamborileo, temblor, mano en alto).
	Cada hueso se maneja con una rotación absoluta en el marco del modelo (X derecha, Y arriba, Z atrás): T = R⁻¹ · P⁻¹ · A · R,
	con R la orientación de reposo del hueso, P la rotación efectiva de su padre y A la que queremos.
	Los valores están en Config.Anomalias.Trepador. Todas las partes son consultables para poder marcarlas con Q.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Trepador = {}

local cfg = Config.Anomalias.Trepador
local rng = Random.new()
local ID = CFrame.new()

local function rad(g: number): number
	return math.rad(g)
end

local function giro(eje: Vector3, ang: number): CFrame
	if eje.Magnitude < 1e-6 or ang == 0 then
		return ID
	end
	return CFrame.fromAxisAngle(eje.Unit, ang)
end

-- Rotación mínima que lleva la dirección a en la dirección b.
local function arco(a: Vector3, b: Vector3): CFrame
	a, b = a.Unit, b.Unit
	local d = math.clamp(a:Dot(b), -1, 1)
	local eje = a:Cross(b)
	if eje.Magnitude < 1e-6 then
		if d > 0 then
			return ID
		end
		local perp = if math.abs(a.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		return CFrame.fromAxisAngle(a:Cross(perp).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(eje.Unit, math.acos(d))
end

-- Dos huesos (hombro -> codo -> mano) hacia el objetivo; la articulación se dobla hacia `flexion`. Devuelve el codo y la mano alcanzada.
local function ik(origen: Vector3, objetivo: Vector3, l1: number, l2: number, flexion: Vector3): (Vector3, Vector3)
	local delta = objetivo - origen
	local distancia = delta.Magnitude
	if distancia < 1e-3 then
		return origen + flexion.Unit * l1, objetivo
	end
	local dir = delta / distancia
	local d = math.clamp(distancia, math.abs(l1 - l2) + 0.05, l1 + l2 - 0.05)
	local a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
	local h = math.sqrt(math.max(l1 * l1 - a * a, 0))
	local ortogonal = flexion - dir * flexion:Dot(dir)
	if ortogonal.Magnitude < 1e-3 then
		ortogonal = Vector3.yAxis
	end
	return origen + dir * a + ortogonal.Unit * h, origen + dir * d
end

-- Las seis extremidades. grupo: el trípode al que pertenece. alzar: hacia dónde sube la mano en el screamer y en el salto (marco del modelo).
local DEFINICION = {
	{ id = "AL", lado = 1, grupo = 0, brazo = true, huesos = { "Up_AL", "Fo_AL", "Ma_AL" }, alzar = Vector3.new(0.8, 4.3, -3.2) },
	{ id = "AR", lado = -1, grupo = 1, brazo = true, huesos = { "Up_AR", "Fo_AR", "Ma_AR" }, alzar = Vector3.new(-0.8, 4.3, -3.2) },
	{ id = "BL", lado = 1, grupo = 1, brazo = true, huesos = { "Up_BL", "Fo_BL", "Ma_BL" }, alzar = Vector3.new(0.6, 5.0, -1.8) },
	{ id = "BR", lado = -1, grupo = 0, brazo = true, huesos = { "Up_BR", "Fo_BR", "Ma_BR" }, alzar = Vector3.new(-0.6, 5.0, -1.8) },
	{ id = "PL", lado = 1, grupo = 0, brazo = false, huesos = { "Mu_L", "Pi_L", "Pie_L" }, alzar = Vector3.new(0, 1.4, 0) },
	{ id = "PR", lado = -1, grupo = 1, brazo = false, huesos = { "Mu_R", "Pi_R", "Pie_R" }, alzar = Vector3.new(0, 1.4, 0) },
}

function Trepador.disponible(): boolean
	return ReplicatedStorage:FindFirstChild("TrepadorModelo") ~= nil
end

--- Arma la criatura. Devuelve { modelo, actualizar, ataque, gritar, destruir, alturaCuerpo, distanciaAtaque, esTrepador } o nil si falta el molde.
function Trepador.crear()
	local molde = ReplicatedStorage:FindFirstChild("TrepadorModelo")
	if not molde then
		return nil
	end
	local modelo = molde:Clone()
	local malla = modelo:FindFirstChild("Trepador_Malla")
	if not (malla and malla:IsA("MeshPart")) then
		modelo:Destroy()
		return nil
	end
	modelo.Name = "Trepador"
	modelo.PrimaryPart = malla
	modelo:ScaleTo(modelo:GetScale() * cfg.Escala)
	malla.Anchored = true
	malla.CanCollide = false
	malla.CanTouch = false
	malla.CanQuery = true -- se la puede apuntar con Q
	malla.Massless = true
	malla.CastShadow = false
	-- El importador deja el pivote girado: se fija uno derecho en el centro de la base (los pies), mirando a -Z.
	malla.PivotOffset = CFrame.new(0, -malla.Size.Y / 2, 0)
	local P0inv = malla.PivotOffset:Inverse()

	local luz = Instance.new("PointLight")
	luz.Range = cfg.Luz.Rango
	luz.Brightness = cfg.Luz.Brillo
	luz.Color = cfg.Luz.Color
	luz.Shadows = false
	luz.Parent = malla

	-- ===== Esqueleto: orientación y posición de reposo de cada hueso en el marco del modelo =====
	local function relMalla(bone: Bone, conTransform: boolean): CFrame
		local cadena = {}
		local b = bone
		while b and b:IsA("Bone") do
			table.insert(cadena, 1, b)
			b = b.Parent
		end
		local cf = CFrame.new()
		for _, x in cadena do
			cf = cf * x.CFrame * (if conTransform then x.Transform else ID)
		end
		return cf
	end
	local function enModelo(bone: Bone, conTransform: boolean): CFrame
		return P0inv * relMalla(bone, conTransform)
	end

	local huesos = {}
	for _, d in malla:GetDescendants() do
		if d:IsA("Bone") then
			local cf = enModelo(d, false)
			huesos[d.Name] = { bone = d, R = cf.Rotation, Rinv = cf.Rotation:Inverse(), pos = cf.Position, padre = if d.Parent:IsA("Bone") then d.Parent.Name else nil }
		end
	end

	local rot = {} -- rotación absoluta deseada de cada hueso (marco del modelo); sin entrada = sigue a su padre
	local function efectiva(nombre: string?): CFrame
		while nombre do
			local r = rot[nombre]
			if r then
				return r
			end
			nombre = huesos[nombre] and huesos[nombre].padre
		end
		return ID
	end
	local function rel(nombre: string, cf: CFrame) -- rotación relativa a la de su padre
		local h = huesos[nombre]
		if h then
			rot[nombre] = efectiva(h.padre) * cf
		end
	end
	local function aplicar(nombre: string)
		local h = huesos[nombre]
		if not h then
			return
		end
		local r = rot[nombre]
		if not r then
			h.bone.Transform = ID
			return
		end
		h.bone.Transform = h.Rinv * efectiva(h.padre):Inverse() * r * h.R
	end
	local function posicionPosada(nombre: string): Vector3
		return enModelo(huesos[nombre].bone, true).Position
	end

	-- ===== Extremidades =====
	local miembros = {}
	for _, def in DEFINICION do
		local h1, h2, h3 = huesos[def.huesos[1]], huesos[def.huesos[2]], huesos[def.huesos[3]]
		if h1 and h2 and h3 then
			local m = {
				id = def.id,
				lado = def.lado,
				grupo = def.grupo,
				brazo = def.brazo,
				huesos = def.huesos,
				alzar = def.alzar,
				S0 = h1.pos,
				E0 = h2.pos,
				W0 = h3.pos,
				l1 = (h2.pos - h1.pos).Magnitude,
				l2 = (h3.pos - h2.pos).Magnitude,
				pie = nil, -- posición mundial donde está apoyado
				paso = nil, -- { desde, hasta, t, dur } mientras da un paso
				levantar = 0, -- cuánto está en alto (0 a 1) por un gesto
				dedos = {}, -- por dedo: { h1, h2, eje, curva }
			}
			if def.brazo then
				for i = 0, 4 do
					local a, b = huesos[string.format("D%d_1_%s", i, def.id)], huesos[string.format("D%d_2_%s", i, def.id)]
					if a and b then
						local eje = (b.pos - a.pos):Cross(Vector3.yAxis)
						if eje.Magnitude < 1e-4 then
							eje = Vector3.xAxis
						end
						table.insert(m.dedos, { n1 = string.format("D%d_1_%s", i, def.id), n2 = string.format("D%d_2_%s", i, def.id), eje = eje.Unit, curva = 0.3 })
					end
				end
			end
			table.insert(miembros, m)
		end
	end

	-- ===== Pasos: chasquidos secos (3D, salen del cuerpo) =====
	local chasquidos = {}
	for i = 1, 4 do
		local s = Instance.new("Sound")
		s.SoundId = Config.Sustos.Glitch.Id
		s.Volume = cfg.VolumenPaso
		s.RollOffMaxDistance = 60
		s.RollOffMinDistance = 6
		s.Parent = malla
		chasquidos[i] = s
	end
	local siguienteChasquido = 1

	-- ===== Estado de la animación =====
	local objeto = {
		modelo = modelo,
		alturaCuerpo = cfg.AlturaCuerpo,
		distanciaAtaque = cfg.DistanciaSalto,
		esTrepador = true,
	}
	local posAnterior: Vector3? = nil
	local velocidad = 0
	local direccion = Vector3.new(0, 0, -1)
	local reloj = rng:NextNumber(0, 10)
	local atacando = false
	local gritoU: number? = nil
	local gritoAbre = 0.45

	local yawObj, pitchObj = 0, 0 -- hacia dónde mira la cabeza (a tirones)
	local proxCabeza, proxMandibula, proxDedos, proxGesto = 0, 0, 0, reloj + 2
	local mandibula = rad(24) -- cuánto se cierra la mandíbula respecto de la pose de reposo (que ya viene abierta)
	local temblor = Vector3.zero
	local proxTemblor = 0
	local gesto = nil -- { nombre, t0, dur, lado }

	local GESTOS
	local function pose0()
		return { yaw = nil, pitch = nil, roll = 0, mandibula = nil, temblor = 0, onda = nil }
	end

	-- Gestos: f(a, k, p): a de 0 a 1 durante el gesto; modifica la tabla de pose p. Los cortes son siempre de golpe.
	GESTOS = {
		-- La cabeza da la vuelta entera (180° sobre su eje) mirando al jugador, se queda así y vuelve de golpe.
		giro = { dur = { 1.4, 2.0 }, f = function(a, k, p)
			if a > 0.12 and a < 0.8 then
				p.roll = math.pi * k.lado
				p.mandibula = rad(rng:NextNumber(-8, 12))
				p.temblor = 0.4
			elseif a >= 0.8 then
				p.roll = 0
			end
		end },
		-- Olfatea: picotea el aire con la cabeza.
		olfateo = { dur = { 1.0, 1.5 }, f = function(a, k, p)
			local pico = math.floor(a * 14) % 2 == 0
			p.pitch = if pico then rad(-34) else rad(8)
			p.yaw = rad(rng:NextNumber(-10, 10))
			p.mandibula = rad(if pico then 38 else 20)
		end },
		-- Tamborilea con los dedos de los brazos delanteros, en onda.
		tambor = { dur = { 1.3, 2.0 }, f = function(a, k, p)
			p.onda = a
		end },
		-- Todo el cuerpo se sacude y la mandíbula castañetea.
		temblor = { dur = { 0.8, 1.3 }, f = function(a, k, p)
			p.temblor = 1
			p.mandibula = rad(rng:NextNumber(-6, 40))
		end },
		-- Levanta una mano delantera y la crispa, como llamándote.
		mano = { dur = { 1.2, 1.8 }, f = function(a, k, p)
			local m = k.mano
			if m then
				m.levantar = if a < 0.15 then a / 0.15 elseif a < 0.8 then 1 else 0
			end
			p.onda = a * 0.6
		end },
	}
	local NOMBRES_GESTOS = { "giro", "olfateo", "tambor", "temblor", "mano" }

	local function elegirGesto()
		local nombre = NOMBRES_GESTOS[rng:NextInteger(1, #NOMBRES_GESTOS)]
		local def = GESTOS[nombre]
		local k = { lado = if rng:NextNumber() < 0.5 then 1 else -1 }
		if nombre == "mano" then
			for _, m in miembros do
				if m.id == (if k.lado > 0 then "AL" else "AR") then
					k.mano = m
				end
			end
		end
		gesto = { def = def, t0 = reloj, dur = rng:NextNumber(def.dur[1], def.dur[2]), k = k }
	end

	function objeto.ataque(activo: boolean)
		atacando = activo
	end

	function objeto.gritar(u: number, abre: number?)
		gritoU = u
		gritoAbre = abre or gritoAbre
	end

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
		local movimiento = math.clamp(velocidad / 8, 0, 1)
		local gritando = gritoU ~= nil
		local abierto = gritando and gritoU >= gritoAbre
		table.clear(rot)

		-- ===== Pose del cuerpo: balanceo al andar, cabeza, mandíbula =====
		local p = pose0()
		-- Gestos solo cuando está parada (no atacando ni gritando).
		if not atacando and not gritando then
			if gesto then
				local a = (reloj - gesto.t0) / gesto.dur
				if a >= 1 or movimiento > 0.3 then
					gesto = nil
					for _, m in miembros do
						m.levantar = 0
					end
					proxGesto = reloj + rng:NextNumber(cfg.GestoCadaSeg[1], cfg.GestoCadaSeg[2])
				else
					gesto.def.f(a, gesto.k, p)
				end
			elseif movimiento < 0.15 and reloj >= proxGesto then
				elegirGesto()
			end
		end

		-- Cabeza hacia el jugador: salta a un nuevo ángulo cada tanto (a tirones).
		if reloj >= proxCabeza then
			proxCabeza = reloj + rng:NextNumber(0.1, 0.55)
			local yaw, pitch = 0, 0
			if mirarA then
				local cabeza0 = huesos.Head and huesos.Head.pos or Vector3.new(0, 4, -3.6)
				local v = cf:PointToObjectSpace(mirarA) - cabeza0
				yaw = math.clamp(math.atan2(-v.X, -v.Z), -rad(115), rad(115))
				pitch = math.clamp(math.atan2(v.Y, math.sqrt(v.X * v.X + v.Z * v.Z)), -rad(40), rad(75))
			end
			yawObj = yaw + rad(rng:NextNumber(-9, 9))
			pitchObj = pitch + rad(rng:NextNumber(-7, 7))
		end
		local yaw, pitch, roll = p.yaw or yawObj, p.pitch or pitchObj, p.roll
		if gritando then
			-- La cabeza se echa hacia atrás con la boca al frente y tiembla.
			yaw = if abierto then rad(rng:NextNumber(-8, 8)) else yawObj * 0.5
			pitch = if abierto then rad(rng:NextNumber(12, 32)) else pitchObj * 0.5
			roll = rad(rng:NextNumber(-5, 5)) * (if abierto then 2 else 1)
		elseif atacando then
			yaw, pitch = rad(rng:NextNumber(-6, 6)), rad(rng:NextNumber(8, 24))
		end

		-- Temblor de cuerpo (24 cuadros por segundo): solo si el gesto, el grito o el ataque lo piden.
		local fuerzaTemblor = math.max(p.temblor, if abierto then 1 elseif atacando then 0.5 else 0)
		if reloj >= proxTemblor then
			proxTemblor = reloj + 1 / 24
			temblor = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		end
		local tem = temblor * fuerzaTemblor

		-- Mandíbula: castañetea a golpes sueltos; en el grito y el salto se abre del todo.
		if reloj >= proxMandibula then
			proxMandibula = reloj + rng:NextNumber(0.07, 0.45)
			mandibula = rad(if rng:NextNumber() < 0.7 then rng:NextNumber(14, 30) else rng:NextNumber(32, 44))
		end
		local cierre = p.mandibula or mandibula
		if abierto then
			cierre = rad(rng:NextNumber(-14, -4))
		elseif atacando then
			cierre = rad(rng:NextNumber(-10, 0))
		elseif gritando then
			cierre = rad(rng:NextNumber(20, 40))
		end

		local fase = reloj * 9
		local sway = movimiento
		rel("Spine1", CFrame.Angles(rad(tem.X * 3), math.sin(fase) * rad(5) * sway + rad(tem.Y * 3), math.sin(fase) * rad(3) * sway + rad(tem.Z * 3)))
		rel("Spine2", CFrame.Angles(math.sin(reloj * 1.2) * rad(1.5) + rad(tem.X * 4), -math.sin(fase) * rad(6) * sway, rad(tem.Z * 4)))
		rel("Neck1", CFrame.Angles(pitch * 0.25, yaw * 0.3, roll * 0.2))
		rel("Neck2", CFrame.Angles(pitch * 0.3, yaw * 0.3, roll * 0.3))
		rel("Head", CFrame.Angles(pitch * 0.45, yaw * 0.4, roll * 0.5))
		rel("Jaw", CFrame.Angles(cierre, 0, 0))
		for _, n in { "Spine1", "Spine2", "Neck1", "Neck2", "Head", "Jaw" } do
			aplicar(n)
		end

		-- ===== Cuerpo en el mundo: flota un poco sobre la superficie y respira =====
		local altura = math.sin(reloj * 1.6) * 0.07 + math.sin(fase * 0.5) * 0.14 * sway
		if atacando then
			altura = 0
		end
		local pivote = cf * CFrame.new(tem.X * 0.05, altura + tem.Y * 0.06, 0)
		modelo:PivotTo(pivote)

		-- ===== Brazos y patas: cada pie queda apoyado y da un paso cuando se aleja de su posición de reposo =====
		local enPaso = { [0] = false, [1] = false }
		for _, m in miembros do
			if m.paso then
				enPaso[m.grupo] = true
			end
		end
		local umbral = cfg.UmbralPaso * (1 - 0.6 * (1 - movimiento))
		local levantaTodo = 0
		if gritando then
			levantaTodo = math.clamp((gritoU - 0.12) / 0.2, 0, 1)
		elseif atacando then
			levantaTodo = 1
		end

		for _, m in miembros do
			local reposoMundo = cf * m.W0 -- (cf = superficie; W0 está en el marco del modelo con el pivote en los pies)
			if not m.pie then
				m.pie = reposoMundo
			end
			local libre = math.max(m.levantar, if m.brazo then levantaTodo else levantaTodo * 0.6)
			if atacando then
				-- En el aire: las patas se recogen bajo el cuerpo, sin pasos.
				m.paso = nil
				m.pie = reposoMundo
			elseif m.paso then
				local s = m.paso
				s.t += dt / s.dur
				if s.t >= 1 then
					m.pie = s.hasta
					m.paso = nil
					local snd = chasquidos[siguienteChasquido]
					siguienteChasquido = siguienteChasquido % #chasquidos + 1
					snd.PlaybackSpeed = rng:NextNumber(1.7, 3)
					snd.TimePosition = 0
					snd:Play()
				else
					m.pie = s.desde:Lerp(s.hasta, s.t) + arriba * math.sin(s.t * math.pi) * cfg.AlturaPaso
				end
			elseif libre < 0.05 then
				local desvio = (m.pie - reposoMundo).Magnitude
				local otroGrupoCaminando = enPaso[1 - m.grupo]
				if desvio > cfg.AlcanceMax then
					m.pie = reposoMundo -- se quedó muy atrás (por ejemplo, un cambio brusco de superficie)
				elseif desvio > umbral and not otroGrupoCaminando then
					local adelanto = direccion * math.min(velocidad * 0.18, cfg.AdelantoMax)
					m.paso = {
						desde = m.pie,
						hasta = reposoMundo + adelanto,
						t = 0,
						dur = math.clamp(cfg.PasoSeg / (1 + velocidad * 0.06), 0.07, cfg.PasoSeg),
					}
					enPaso[m.grupo] = true
				end
			end

			-- Objetivo de la mano o el pie en el marco del modelo.
			local objetivo = pivote:PointToObjectSpace(m.pie)
			if libre > 0.001 then
				local alto = m.W0 + m.alzar * libre
				if atacando and not m.brazo then
					alto = m.W0 + Vector3.new(0, 1.6, 0)
				end
				if abierto then
					alto += Vector3.new(tem.X, tem.Y, tem.Z) * 0.35
				end
				objetivo = objetivo:Lerp(alto, libre)
			end

			local S = posicionPosada(m.huesos[1])
			local flexion = Vector3.new(m.lado * 0.6, 1, if m.brazo then 0 else 0.3)
			local E, W = ik(S, objetivo, m.l1, m.l2, flexion)
			rot[m.huesos[1]] = arco(m.E0 - m.S0, E - S)
			rot[m.huesos[2]] = arco(m.W0 - m.E0, W - E)
			rot[m.huesos[3]] = ID -- la mano o el pie se queda plano
			for _, n in m.huesos do
				aplicar(n)
			end

			-- Dedos: se crispan al azar, se cierran al levantar la mano y hacen la onda del tamborileo.
			if m.brazo then
				local enAire = m.paso ~= nil or libre > 0.1
				if reloj >= proxDedos then
					for _, f in m.dedos do
						f.curva = if enAire then rng:NextNumber(0.5, 1.2) else rng:NextNumber(0.0, 0.7)
					end
				end
				for i, f in m.dedos do
					local c = f.curva
					if p.onda and (m.id == "AL" or m.id == "AR") then
						c = math.clamp(math.sin((p.onda * 3.4 - (i - 1) * 0.3) * math.pi), 0, 1) * 1.1
					end
					rel(f.n1, giro(f.eje, c * 0.7))
					rel(f.n2, giro(f.eje, c * 1.0))
					aplicar(f.n1)
					aplicar(f.n2)
				end
			end
		end
		if reloj >= proxDedos then
			proxDedos = reloj + rng:NextNumber(0.12, 0.45)
		end
	end

	function objeto.destruir()
		modelo:Destroy()
	end

	return objeto
end

return Trepador
