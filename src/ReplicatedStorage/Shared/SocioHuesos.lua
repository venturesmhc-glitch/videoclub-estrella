--!nonstrict
--[[
	SocioHuesos: mueve a tirones el esqueleto del Socio (modelo con huesos de Personajes.crearSocioMalla).
	Nada se suaviza: cada cambio de pose es un golpe seco (cabeza que se tuerce de golpe, dedos que se crispan,
	brazos que se sacuden, piernas que dan el paso), como en el terror analógico.

	La cara se parte por el medio: dos mitades (huesos FaceL y FaceR) que se abren hacia los lados, como una puerta doble,
	con colmillos en los bordes y el interior de carne. Se abre del todo cuando un jugador está cerca (opciones.distanciaBoca).
	Los ojos (Parts anchoradas) siguen a la mitad de la cara donde están y se apagan cuando la cara se abre del todo.

	Animaciones (todas a tirones): temblor de cara, cabeza al azar que sigue al jugador, pasos de las piernas, el ataque (zarpazos
	alternados con la cara abierta) y un grupo de gestos que hace de vez en cuando mientras nadie lo mira: crujido de cuello, mirada
	por encima del hombro, olfateo, arco hacia atrás, rugido, zarpazo, temblor, onda de dedos y caída de títere.

	  local huesos = SocioHuesos.nuevo(modelo, { distanciaBoca = 7, anguloBoca = 75 })   -- el modelo ya tiene que estar en el Workspace
	  huesos.actualizar(dt, activo, observado, dioPaso, distanciaAlJugador, posicionDelJugador)  -- la posición es opcional: con ella la cabeza lo sigue
	  huesos.sincronizarOjos()                        -- llamar después de cada PivotTo del modelo
	  huesos.reposo()                                 -- vuelve a la pose original
	  huesos.gritar(u, abre)                          -- screamer: u de 0 a 1, la cara se abre de golpe cuando u llega a `abre`
]]

local SocioHuesos = {}

local rng = Random.new()

-- Q pasa del marco del modelo (X derecha, Y arriba, Z atrás) al espacio de los huesos. Con el pivote derecho que deja
-- Personajes.crearSocioMalla los huesos ya están en el marco de la malla, así que es la identidad (por si un día cambia el import).
-- Los ejes de cada hueso son los de Blender (Y a lo largo del hueso).
local Q = CFrame.new()
local Qinv = Q:Inverse()

local function rad(g: number): number
	return math.rad(g)
end

function SocioHuesos.nuevo(modelo: Model, opciones)
	opciones = opciones or {}
	local distanciaBoca = opciones.distanciaBoca or 7 -- studs (unos 2 m)
	local anguloBoca = rad(opciones.anguloBoca or 75)

	local huesos = {} -- nombre -> { bone, R (rotación de reposo respecto del pivote del modelo), afuera }
	local ojos = {} -- { parte, hueso (nombre), reposo (hueso en reposo respecto del pivote), desfase (ojo respecto del hueso) }
	local iniciado = false
	local pivote0

	-- Pose de un hueso en el mundo, calculada encadenando CFrame (reposo) y Transform desde la malla:
	-- no depende de que el motor haya actualizado TransformedWorldCFrame (el servidor no renderiza).
	local function mundoDe(bone: Bone, conTransform: boolean): CFrame
		local cadena = {}
		local b = bone
		while b and b:IsA("Bone") do
			table.insert(cadena, 1, b)
			b = b.Parent
		end
		local cf = modelo.PrimaryPart.CFrame
		for _, x in cadena do
			cf = cf * x.CFrame * (conTransform and x.Transform or CFrame.new())
		end
		return cf
	end

	local function iniciar()
		pivote0 = modelo:GetPivot()
		for _, d in modelo:GetDescendants() do
			if d:IsA("Bone") then
				huesos[d.Name] = { bone = d, R = pivote0:ToObjectSpace(mundoDe(d, false)).Rotation, afuera = 1 }
			end
		end
		-- Cada ojo va con la mitad de la cara de su lado (la que tiene la bisagra del mismo signo de X); si no hay, con la cabeza.
		for _, d in modelo:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Ojo" then
				local x = pivote0:PointToObjectSpace(d.Position).X
				local elegido = "Head"
				for _, n in { "FaceL", "FaceR" } do
					local h = huesos[n]
					if h and pivote0:PointToObjectSpace(mundoDe(h.bone, false).Position).X * x > 0 then
						elegido = n
					end
				end
				if huesos[elegido] then
					local reposo = pivote0:ToObjectSpace(mundoDe(huesos[elegido].bone, false))
					local enHuesos = Q * pivote0:ToObjectSpace(d.CFrame) * Qinv
					table.insert(ojos, { parte = d, hueso = elegido, reposo = reposo, desfase = reposo:ToObjectSpace(enHuesos) })
				end
			end
		end
		-- Hacia dónde queda "afuera" para cada brazo: el lado donde está su hombro respecto del eje del cuerpo.
		for _, lado in { "L", "R" } do
			local h = huesos["UpperArm_" .. lado]
			if h then
				h.afuera = pivote0:PointToObjectSpace(mundoDe(h.bone, false).Position).X >= 0 and 1 or -1
			end
		end
		iniciado = true
	end

	-- Gira el hueso con ángulos en el marco del modelo (X = derecha, Y = arriba, Z = atrás), da igual cómo vengan orientados los huesos.
	local function rotar(nombre: string, rx: number, ry: number, rz: number)
		local h = huesos[nombre]
		if h then
			h.bone.Transform = h.R:Inverse() * (Q * CFrame.fromEulerAnglesXYZ(rx, ry, rz) * Qinv) * h.R
		end
	end

	local function afuera(lado: string): number
		local h = huesos["UpperArm_" .. lado]
		return h and h.afuera or 1
	end

	local ctl = { mundoDe = mundoDe }
	ctl.rotar = function(...)
		rotar(...)
	end

	local apertura = 0 -- cuánto está abierta la cara (radianes, por mitad)
	local OJOS_VISIBLES_HASTA = rad(20) -- con la cara entreabierta los ojos siguen; al abrirse del todo se apagan
	local OJOS_APAGADOS_DESDE = rad(36)

	function ctl.sincronizarOjos()
		if not iniciado then
			return
		end
		local pivote = modelo:GetPivot()
		-- Con la cara abierta ya no hay órbitas donde estén: los ojos desaparecen (volver a cerrarla los devuelve).
		local transparencia = math.clamp((apertura - OJOS_VISIBLES_HASTA) / (OJOS_APAGADOS_DESDE - OJOS_VISIBLES_HASTA), 0, 1)
		for _, o in ojos do
			local ahora = pivote:ToObjectSpace(mundoDe(huesos[o.hueso].bone, true))
			o.parte.CFrame = pivote * (Qinv * (ahora * o.desfase) * Q)
			if o.parte.Transparency ~= transparencia then
				o.parte.Transparency = transparencia
			end
		end
	end

	function ctl.reposo()
		for _, h in huesos do
			h.bone.Transform = CFrame.new()
		end
		apertura = 0
		ctl.sincronizarOjos()
	end

	-- La cara se abre girando cada mitad sobre su bisagra vertical (el eje Y del modelo), una hacia cada lado.
	local function boca(angulo: number)
		apertura = angulo
		rotar("FaceL", 0, angulo, 0)
		rotar("FaceR", 0, -angulo, 0)
	end

	local proxCabeza, proxBoca, proxDedos, proxCuerpo = 0, 0, 0, 0
	local parLado = false
	local ultimoPaso = 0
	local estabaObservado = false
	local estabaCerca = false
	local sesgoCabeza = 0 -- hacia dónde mira el Socio con la cabeza (radianes respecto de su frente): sigue al jugador a tirones

	local function cabezaAlAzar(fuerte: boolean)
		local k = fuerte and 1.6 or 1
		rotar("Neck2", rad(rng:NextNumber(-8, 8)) * k, rad(rng:NextNumber(-14, 14)) * k + sesgoCabeza * 0.3, rad(rng:NextNumber(-6, 6)) * k)
		rotar("Head", rad(rng:NextNumber(-14, 24)) * k, rad(rng:NextNumber(-38, 38)) * k + sesgoCabeza * 0.7, rad(rng:NextNumber(-16, 16)) * k)
	end

	local function dedosAlAzar(minimo: number?, maximo: number?)
		for _, lado in { "L", "R" } do
			local curva = rng:NextNumber(minimo or 0.1, maximo or 1.15)
			for f = 0, 4 do
				local c = curva * rng:NextNumber(0.6, 1.3) * (f == 0 and 0.5 or 1)
				rotar(string.format("Finger%d_1_%s", f, lado), c * 0.8, 0, 0)
				rotar(string.format("Finger%d_2_%s", f, lado), c * 1.2, 0, 0)
			end
		end
	end

	local function cuerpoAlAzar()
		rotar("Spine1", rad(rng:NextNumber(-4, 8)), rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(-4, 4)))
		rotar("Spine2", rad(rng:NextNumber(-4, 10)), rad(rng:NextNumber(-12, 12)), rad(rng:NextNumber(-5, 5)))
		for _, lado in { "L", "R" } do
			local s = afuera(lado)
			rotar("Shoulder_" .. lado, 0, 0, rad(rng:NextNumber(-8, 8)) * s)
			rotar("UpperArm_" .. lado, rad(rng:NextNumber(-12, 38)), rad(rng:NextNumber(-12, 12)), rad(rng:NextNumber(0, 30)) * s)
			rotar("Forearm_" .. lado, rad(rng:NextNumber(4, 55)), 0, 0)
			rotar("Hand_" .. lado, rad(rng:NextNumber(-25, 25)), rad(rng:NextNumber(-20, 20)), 0)
		end
	end

	local PARTES_ARRIBA = {
		"Neck2", "Head", "Spine1", "Spine2",
		"Shoulder_L", "Shoulder_R", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R",
	}
	local function reposoArriba()
		for _, n in PARTES_ARRIBA do
			rotar(n, 0, 0, 0)
		end
	end

	-- Brazos: ángulos en el marco del modelo; rx positivo lleva el brazo hacia adelante, rz abre hacia afuera.
	local function brazo(lado: string, adelante: number, afueraGrados: number, codo: number, giro: number?)
		local s = afuera(lado)
		rotar("UpperArm_" .. lado, rad(adelante), rad(giro or 0), rad(afueraGrados) * s)
		rotar("Forearm_" .. lado, rad(codo), 0, 0)
	end

	-- Dedos que se cierran de a uno, en onda (fase 0 a 1 recorre la mano).
	local function ondaDedos(fase: number)
		for _, lado in { "L", "R" } do
			for f = 0, 4 do
				local c = math.clamp(math.sin((fase * 2.2 - f * 0.28) * math.pi), 0, 1) * 1.3
				rotar(string.format("Finger%d_1_%s", f, lado), c * 0.8, 0, 0)
				rotar(string.format("Finger%d_2_%s", f, lado), c * 1.2, 0, 0)
			end
		end
	end

	-- ===== Gestos: movimientos con principio y fin que el Socio hace de vez en cuando mientras no lo miran =====
	-- f(a, k): a avanza de 0 a 1 durante el gesto; k.s es el lado (±1). Cada gesto da poses fijas y los cortes entre una y otra son
	-- de golpe (con el tick de 0,1 s se ve como cuadros salteados), nunca un movimiento suave.
	local GESTOS = {
		-- El cuello se inclina despacio y truena de golpe hacia el otro lado.
		crujido = { dur = { 0.9, 1.4 }, peso = 3, f = function(a, k)
			if a < 0.35 then
				local p = a / 0.35
				rotar("Head", 0, 0, rad(34) * p * k.s)
				rotar("Neck2", 0, 0, rad(10) * p * k.s)
			elseif a < 0.7 then
				rotar("Head", rad(6), rad(26) * k.s, -rad(52) * k.s)
				rotar("Neck2", 0, rad(10) * k.s, -rad(14) * k.s)
			else
				rotar("Head", rad(rng:NextNumber(-3, 3)), 0, 0)
				rotar("Neck2", 0, 0, 0)
			end
		end },
		-- Mira por encima del hombro hasta quedar casi de espaldas, se queda ahí y salta al otro lado.
		miradaAtras = { dur = { 1.5, 2.2 }, peso = 3, f = function(a, k)
			local s = k.s
			if a < 0.25 then
				rotar("Neck2", 0, rad(35) * s, 0)
				rotar("Head", rad(-4), rad(52) * s, rad(6) * s)
				rotar("Spine2", 0, rad(14) * s, 0)
			elseif a < 0.6 then
				rotar("Head", rad(rng:NextNumber(-6, 2)), rad(rng:NextNumber(48, 60)) * s, rad(rng:NextNumber(-4, 10)) * s)
			elseif a < 0.7 then
				rotar("Neck2", 0, -rad(30) * s, 0)
				rotar("Head", 0, -rad(45) * s, 0)
				rotar("Spine2", 0, -rad(10) * s, 0)
			else
				reposoArriba()
			end
		end },
		-- Olfatea: picotea el aire con la cabeza, inclinado hacia adelante.
		olfateo = { dur = { 1.0, 1.5 }, peso = 2, f = function(a, k)
			local pico = math.floor(a * 14) % 2 == 0
			rotar("Spine2", -rad(pico and 16 or 6), 0, 0)
			rotar("Neck2", pico and -rad(10) or 0, 0, 0)
			rotar("Head", pico and -rad(30) or rad(4), rad(rng:NextNumber(-8, 8)), 0)
			brazo("L", pico and 14 or 4, 12, 40)
			brazo("R", pico and 14 or 4, 12, 40)
		end },
		-- Se estira hacia atrás con los brazos caídos y la cara se entreabre un momento (como un bostezo roto).
		arco = { dur = { 1.5, 2.0 }, peso = 2, f = function(a, k)
			local p = math.min(a / 0.3, 1)
			rotar("Spine1", rad(14) * p, 0, 0)
			rotar("Spine2", rad(18) * p, 0, 0)
			rotar("Neck2", rad(10) * p, 0, 0)
			rotar("Head", rad(40) * p + rad(rng:NextNumber(-3, 3)), 0, rad(rng:NextNumber(-4, 4)))
			brazo("L", -18 * p, 38 * p, 8)
			brazo("R", -18 * p, 38 * p, 8)
			if a > 0.45 and a < 0.8 then
				boca(rad(rng:NextNumber(22, 38)))
			elseif a >= 0.8 then
				boca(rad(rng:NextNumber(1, 4)))
			end
		end },
		-- Rugido sin sonido: la cara se abre del todo, los brazos se abren y todo tiembla.
		rugido = { dur = { 1.1, 1.6 }, peso = 2, f = function(a, k)
			if a < 0.12 then
				rotar("Head", rad(18), 0, 0)
				rotar("Spine2", rad(8), 0, 0)
				boca(rad(rng:NextNumber(8, 16)))
			elseif a < 0.82 then
				boca(anguloBoca * rng:NextNumber(0.8, 1.0))
				rotar("Head", rad(rng:NextNumber(26, 38)), rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(-6, 6)))
				rotar("Neck2", rad(rng:NextNumber(4, 10)), 0, 0)
				rotar("Spine2", rad(rng:NextNumber(12, 20)), 0, 0)
				brazo("L", rng:NextNumber(10, 30), rng:NextNumber(40, 60), rng:NextNumber(10, 30))
				brazo("R", rng:NextNumber(10, 30), rng:NextNumber(40, 60), rng:NextNumber(10, 30))
			else
				boca(rad(rng:NextNumber(1, 6)))
				rotar("Head", 0, 0, 0)
				rotar("Spine2", 0, 0, 0)
			end
		end },
		-- Un zarpazo con cada brazo, de afuera hacia adelante.
		zarpazo = { dur = { 0.8, 1.1 }, peso = 2, f = function(a, k)
			local primero = k.s > 0 and "L" or "R"
			local segundo = k.s > 0 and "R" or "L"
			rotar("Spine2", -rad(8), 0, 0)
			if a < 0.2 then
				brazo(primero, -20, 55, 50)
				brazo(segundo, 4, 12, 40)
			elseif a < 0.45 then
				brazo(primero, 85, 0, 8, -10)
				rotar("Spine2", -rad(12), rad(10) * k.s, 0)
			elseif a < 0.65 then
				brazo(primero, 30, 20, 40)
				brazo(segundo, -20, 55, 50)
			else
				brazo(segundo, 85, 0, 8, 10)
				rotar("Spine2", -rad(12), -rad(10) * k.s, 0)
			end
			dedosAlAzar(1.0, 1.5)
		end },
		-- Tiembla entero, como una cinta que se traba.
		temblor = { dur = { 0.7, 1.1 }, peso = 3, f = function(a, k)
			rotar("Spine1", rad(rng:NextNumber(-4, 4)), rad(rng:NextNumber(-6, 6)), rad(rng:NextNumber(-4, 4)))
			rotar("Spine2", rad(rng:NextNumber(-5, 5)), rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(-5, 5)))
			rotar("Head", rad(rng:NextNumber(-12, 12)), rad(rng:NextNumber(-18, 18)), rad(rng:NextNumber(-14, 14)))
			brazo("L", rng:NextNumber(0, 30), rng:NextNumber(5, 25), rng:NextNumber(5, 50))
			brazo("R", rng:NextNumber(0, 30), rng:NextNumber(5, 25), rng:NextNumber(5, 50))
			boca(rad(rng:NextNumber(4, 18)))
			dedosAlAzar(0.2, 1.3)
		end },
		-- Levanta las manos frente a la cara y mueve los dedos uno por uno.
		dedos = { dur = { 1.2, 1.8 }, peso = 2, f = function(a, k)
			local p = math.min(a / 0.15, 1)
			local q = a > 0.85 and 0 or 1
			brazo("L", 58 * p * q, 14, 78 * p * q)
			brazo("R", 58 * p * q, 14, 78 * p * q)
			rotar("Head", rad(rng:NextNumber(-4, 8)), rad(rng:NextNumber(-10, 10)), rad(rng:NextNumber(-8, 8)))
			ondaDedos((a * 3) % 1)
			if a > 0.85 then
				reposoArriba()
			end
		end },
		-- Se deja caer como un títere sin hilos y de golpe se endereza.
		colgar = { dur = { 1.3, 1.9 }, peso = 2, f = function(a, k)
			if a < 0.75 then
				rotar("Spine1", -rad(12), 0, 0)
				rotar("Spine2", -rad(22), 0, rad(6) * k.s)
				rotar("Neck2", -rad(18), 0, 0)
				rotar("Head", -rad(36), rad(8) * k.s, rad(10) * k.s)
				brazo("L", 12, 6, 6)
				brazo("R", 12, 6, 6)
				dedosAlAzar(0.05, 0.35)
			else
				rotar("Spine1", 0, 0, 0)
				rotar("Spine2", rad(6), 0, 0)
				rotar("Neck2", 0, 0, 0)
				rotar("Head", rad(22), 0, 0)
				brazo("L", -6, 20, 20)
				brazo("R", -6, 20, 20)
			end
		end },
	}
	local gestoActual = nil -- { def, inicio, dur, k }
	local proxGesto = 0
	local ultimoGesto = ""
	local GESTO_ESPERA = { 1.8, 5 } -- segundos entre un gesto y el siguiente

	local function elegirGesto(distancia: number?)
		local total = 0
		local pesos = {}
		for nombre, g in GESTOS do
			local p = g.peso
			if nombre == ultimoGesto then
				p = 0 -- nunca el mismo dos veces seguidas
			elseif nombre == "rugido" or nombre == "zarpazo" then
				p = p * ((distancia and distancia < 30) and 2.5 or 0.4) -- las amenazas, más cuando hay alguien cerca
			end
			pesos[nombre] = p
			total += p
		end
		local r = rng:NextNumber() * total
		for nombre, p in pesos do
			r -= p
			if r <= 0 and p > 0 then
				return nombre
			end
		end
		return "temblor"
	end

	local function terminarGesto()
		if gestoActual then
			gestoActual = nil
			reposoArriba()
			boca(rad(3))
			proxGesto = os.clock() + rng:NextNumber(GESTO_ESPERA[1], GESTO_ESPERA[2])
		end
	end

	-- Ataque: la cara se abre del todo y el Socio se echa encima: cuerpo hacia adelante, cabeza atrás para que la boca mire a la
	-- víctima y los brazos zarpando uno después del otro.
	local function ataque(t: number)
		boca(anguloBoca * rng:NextNumber(0.85, 1.0))
		local fase = math.floor(t / 0.28) % 2
		rotar("Head", rad(rng:NextNumber(16, 30)), rad(rng:NextNumber(-6, 6)) + sesgoCabeza * 0.5, rad(rng:NextNumber(-5, 5)))
		rotar("Neck2", rad(rng:NextNumber(-4, 4)), rad(rng:NextNumber(-6, 6)), 0)
		rotar("Spine1", -rad(rng:NextNumber(4, 8)), 0, 0)
		rotar("Spine2", -rad(rng:NextNumber(10, 18)), rad(fase == 0 and 8 or -8), 0)
		for _, lado in { "L", "R" } do
			if (lado == "L") == (fase == 0) then
				brazo(lado, rng:NextNumber(80, 100), rng:NextNumber(0, 12), rng:NextNumber(0, 15))
			else
				brazo(lado, rng:NextNumber(35, 55), rng:NextNumber(20, 35), rng:NextNumber(30, 50))
			end
		end
		dedosAlAzar(0.9, 1.4)
	end

	-- Piernas: cada paso de golpe cambia de pierna.
	local function piernas(dioPaso: boolean, t: number)
		if dioPaso then
			ultimoPaso = t
			parLado = not parLado
			local a, b = parLado and "L" or "R", parLado and "R" or "L"
			rotar("UpperLeg_" .. a, rad(34), 0, 0)
			rotar("LowerLeg_" .. a, -rad(46), 0, 0)
			rotar("Foot_" .. a, rad(10), 0, 0)
			rotar("UpperLeg_" .. b, -rad(18), 0, 0)
			rotar("LowerLeg_" .. b, rad(6), 0, 0)
			rotar("Foot_" .. b, 0, 0, 0)
			rotar("Pelvis", 0, rad(parLado and 5 or -5), rad(parLado and 3 or -3))
		elseif t - ultimoPaso > 0.5 and t - ultimoPaso < 0.7 then
			for _, n in { "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R", "Pelvis" } do
				rotar(n, 0, 0, 0)
			end
		end
	end

	-- Screamer: antes de abrir, la cara tiembla casi cerrada y se agrieta; en `abre` se parte de golpe, del todo, y queda
	-- abierta sacudiéndose, con el cuerpo echado hacia adelante y los brazos tirados hacia la cámara.
	local proxGrito = 0
	local gritoAbierto = false

	--- u: avance del screamer (0 a 1). abre: valor de u en el que la cara se abre. Cada llamada puede dar un tirón nuevo.
	function ctl.gritar(u: number, abre: number)
		if not iniciado then
			iniciar()
		end
		local t = os.clock()
		local abierta = u >= abre
		local cambio = abierta ~= gritoAbierto
		gritoAbierto = abierta
		if t >= proxGrito or cambio then
			proxGrito = t + (abierta and 1 / 28 or rng:NextNumber(0.05, 0.16))
			if abierta then
				-- Se abre hasta el tope y aletea un poco: nunca se queda quieta.
				boca(anguloBoca * (rng:NextNumber() < 0.25 and rng:NextNumber(0.72, 0.85) or rng:NextNumber(0.92, 1.04)))
				rotar("Neck2", rad(rng:NextNumber(-6, 4)), rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(-5, 5)))
				-- El cuerpo se echa hacia adelante y la cabeza se tira hacia atrás: la boca queda mirando de frente a la cámara.
				rotar("Head", rad(rng:NextNumber(24, 40)), rad(rng:NextNumber(-12, 12)), rad(rng:NextNumber(-10, 10)))
				rotar("Spine1", -rad(rng:NextNumber(2, 6)), rad(rng:NextNumber(-5, 5)), 0)
				rotar("Spine2", -rad(rng:NextNumber(4, 10)), rad(rng:NextNumber(-6, 6)), rad(rng:NextNumber(-4, 4)))
				for _, lado in { "L", "R" } do
					local s = afuera(lado)
					rotar("Shoulder_" .. lado, 0, 0, rad(rng:NextNumber(-6, 10)) * s)
					rotar("UpperArm_" .. lado, rad(rng:NextNumber(70, 105)), rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(10, 45)) * s)
					rotar("Forearm_" .. lado, rad(rng:NextNumber(0, 25)), 0, 0)
					rotar("Hand_" .. lado, rad(rng:NextNumber(-20, 20)), rad(rng:NextNumber(-15, 15)), 0)
				end
				dedosAlAzar(1.0, 1.5)
			else
				-- La cara se va agrietando a medida que se acerca el momento.
				local grieta = math.clamp(u / abre, 0, 1)
				boca(rad(rng:NextNumber(1, 5) + 20 * grieta ^ 3 * rng:NextNumber(0.2, 1)))
				cabezaAlAzar(rng:NextNumber() < 0.3)
				rotar("Spine2", rad(rng:NextNumber(-4, 8)), rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(-4, 4)))
				rotar("UpperArm_L", rad(rng:NextNumber(-6, 20)), 0, rad(rng:NextNumber(0, 18)) * afuera("L"))
				rotar("UpperArm_R", rad(rng:NextNumber(-6, 20)), 0, rad(rng:NextNumber(0, 18)) * afuera("R"))
				dedosAlAzar(0.2, 1.1)
			end
		end
		ctl.sincronizarOjos()
	end

	-- Hacia dónde queda un punto del mundo respecto del frente del Socio (radianes; positivo = a su izquierda).
	local function anguloHacia(objetivo: Vector3): number
		local rel = modelo:GetPivot():PointToObjectSpace(objetivo)
		return math.atan2(-rel.X, -rel.Z)
	end

	--- dt: segundos desde la última llamada. activo: está en escena. observado: algún jugador lo mira.
	--- dioPaso: este tick avanzó de golpe. distancia: studs hasta el jugador más cercano (nil si no se sabe).
	--- objetivo: posición en el mundo de ese jugador (para mirarlo con la cabeza).
	function ctl.actualizar(dt: number, activo: boolean, observado: boolean, dioPaso: boolean, distancia: number?, objetivo: Vector3?)
		if not iniciado then
			iniciar()
		end
		if not activo then
			return
		end
		local t = os.clock()

		-- La cabeza se vuelve hacia el jugador (nunca más allá de lo que da el cuello): a tirones, porque solo se actualiza al azar.
		if objetivo then
			sesgoCabeza = math.clamp(anguloHacia(objetivo), -rad(75), rad(75))
		else
			sesgoCabeza = 0
		end

		-- Cerca de un jugador (o encima): ataca, mire quien mire.
		if distancia and distancia < distanciaBoca then
			estabaCerca = true
			estabaObservado = false
			gestoActual = nil
			ataque(t)
			piernas(dioPaso, t)
			ctl.sincronizarOjos()
			return
		elseif estabaCerca then
			estabaCerca = false
			reposoArriba()
			boca(rad(4))
			dedosAlAzar()
			proxGesto = t + rng:NextNumber(0.6, 1.5)
		end

		if observado then
			gestoActual = nil
			if not estabaObservado then
				-- Lo miran: se clava la cabeza de frente, un poco ladeada, y la cara queda apenas entreabierta. No hace más.
				estabaObservado = true
				reposoArriba()
				rotar("Head", rad(6), 0, rad(rng:NextNumber(-12, 12)))
				boca(rad(rng:NextNumber(5, 10)))
			end
			if t >= proxDedos then
				proxDedos = t + rng:NextNumber(0.6, 1.6)
				dedosAlAzar() -- los dedos nunca se quedan quietos del todo
			end
			ctl.sincronizarOjos()
			return
		end
		if estabaObservado then
			estabaObservado = false
			proxGesto = math.max(proxGesto, t + rng:NextNumber(0.4, 1.2)) -- apenas dejan de mirarlo, tarda un poco en hacer algo
		end

		if gestoActual then
			-- En pleno gesto: la pose la manda el gesto (la cabeza y el cuerpo ya no se mueven al azar).
			local a = (t - gestoActual.inicio) / gestoActual.dur
			if a >= 1 then
				terminarGesto()
			else
				gestoActual.def.f(a, gestoActual.k)
			end
		else
			if t >= proxCabeza then
				proxCabeza = t + rng:NextNumber(0.12, 0.7)
				cabezaAlAzar(rng:NextNumber() < 0.2)
			end
			if t >= proxBoca then
				proxBoca = t + rng:NextNumber(0.15, 0.9)
				-- La cara tiembla entreabierta; de a ratos se abre un poco más.
				boca(rng:NextNumber() < 0.7 and rad(rng:NextNumber(2, 10)) or rad(rng:NextNumber(14, 26)))
			end
			if t >= proxCuerpo then
				proxCuerpo = t + rng:NextNumber(0.25, 0.9)
				cuerpoAlAzar()
			end
			if t >= proxDedos then
				proxDedos = t + rng:NextNumber(0.15, 0.5)
				dedosAlAzar()
			end
			if t >= proxGesto then
				local nombre = elegirGesto(distancia)
				ultimoGesto = nombre
				local def = GESTOS[nombre]
				gestoActual = { def = def, inicio = t, dur = rng:NextNumber(def.dur[1], def.dur[2]), k = { s = rng:NextNumber() < 0.5 and 1 or -1 } }
			end
		end

		piernas(dioPaso, t)
		ctl.sincronizarOjos()
	end

	-- Para pruebas y vistas previas: los gestos por nombre (f(a, {s = lado})) y la pose de ataque.
	ctl.gestos = GESTOS
	ctl.ataque = ataque

	return ctl
end

return SocioHuesos
