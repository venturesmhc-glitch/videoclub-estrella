--!nonstrict
--[[
	SocioHuesos: mueve a tirones el esqueleto del Socio (modelo con huesos de Personajes.crearSocioMalla).
	Nada se suaviza: cada cambio de pose es un golpe seco (cabeza que se tuerce de golpe, dedos que se crispan,
	brazos que se sacuden, piernas que dan el paso), como en el terror analógico.

	La cara se parte por el medio: dos mitades (huesos FaceL y FaceR) que se abren hacia los lados, como una puerta doble,
	con colmillos en los bordes y el interior de carne. Se abre del todo cuando un jugador está cerca (opciones.distanciaBoca).
	Los ojos (Parts anchoradas) siguen a la mitad de la cara donde están.

	  local huesos = SocioHuesos.nuevo(modelo, { distanciaBoca = 7, anguloBoca = 75 })   -- el modelo ya tiene que estar en el Workspace
	  huesos.actualizar(dt, activo, observado, dioPaso, distanciaAlJugador)
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

	function ctl.sincronizarOjos()
		if not iniciado then
			return
		end
		local pivote = modelo:GetPivot()
		for _, o in ojos do
			local ahora = pivote:ToObjectSpace(mundoDe(huesos[o.hueso].bone, true))
			o.parte.CFrame = pivote * (Qinv * (ahora * o.desfase) * Q)
		end
	end

	function ctl.reposo()
		for _, h in huesos do
			h.bone.Transform = CFrame.new()
		end
		ctl.sincronizarOjos()
	end

	-- La cara se abre girando cada mitad sobre su bisagra vertical (el eje Y del modelo), una hacia cada lado.
	local function boca(angulo: number)
		rotar("FaceL", 0, angulo, 0)
		rotar("FaceR", 0, -angulo, 0)
	end

	local proxCabeza, proxBoca, proxDedos, proxCuerpo = 0, 0, 0, 0
	local parLado = false
	local ultimoPaso = 0
	local estabaObservado = false
	local estabaCerca = false

	local function cabezaAlAzar(fuerte: boolean)
		local k = fuerte and 1.6 or 1
		rotar("Neck2", rad(rng:NextNumber(-8, 8)) * k, rad(rng:NextNumber(-14, 14)) * k, rad(rng:NextNumber(-6, 6)) * k)
		rotar("Head", rad(rng:NextNumber(-14, 24)) * k, rad(rng:NextNumber(-38, 38)) * k, rad(rng:NextNumber(-16, 16)) * k)
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

	-- Ataque: la cara se abre del todo, los brazos van hacia adelante y los dedos se vuelven garras.
	local function ataque()
		boca(anguloBoca * rng:NextNumber(0.8, 1.0))
		rotar("Neck2", rad(rng:NextNumber(-4, 6)), rad(rng:NextNumber(-6, 6)), 0)
		rotar("Head", rad(rng:NextNumber(4, 22)), rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(-6, 6)))
		rotar("Spine2", rad(rng:NextNumber(8, 18)), 0, rad(rng:NextNumber(-4, 4)))
		for _, lado in { "L", "R" } do
			local s = afuera(lado)
			rotar("UpperArm_" .. lado, rad(rng:NextNumber(40, 70)), 0, rad(rng:NextNumber(5, 25)) * s)
			rotar("Forearm_" .. lado, rad(rng:NextNumber(10, 35)), 0, 0)
		end
		dedosAlAzar(0.9, 1.4)
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

	--- dt: segundos desde la última llamada. activo: está en escena. observado: algún jugador lo mira.
	--- dioPaso: este tick avanzó de golpe. distancia: studs hasta el jugador más cercano (nil si no se sabe).
	function ctl.actualizar(dt: number, activo: boolean, observado: boolean, dioPaso: boolean, distancia: number?)
		if not iniciado then
			iniciar()
		end
		if not activo then
			return
		end
		local t = os.clock()

		-- Cerca de un jugador (o encima): ataca, mire quien mire.
		if distancia and distancia < distanciaBoca then
			estabaCerca = true
			estabaObservado = false
			ataque()
			ctl.sincronizarOjos()
			return
		elseif estabaCerca then
			estabaCerca = false
			boca(rad(4))
			dedosAlAzar()
		end

		if observado then
			if not estabaObservado then
				-- Lo miran: se clava la cabeza de frente, un poco ladeada, y la cara queda apenas entreabierta. No hace más.
				estabaObservado = true
				rotar("Neck2", 0, 0, 0)
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
		estabaObservado = false

		if t >= proxCabeza then
			proxCabeza = t + rng:NextNumber(0.12, 0.7)
			cabezaAlAzar(rng:NextNumber() < 0.2)
		end
		if t >= proxBoca then
			proxBoca = t + rng:NextNumber(0.15, 0.9)
			-- La cara tiembla entreabierta; de a ratos se abre un poco más.
			boca(rng:NextNumber() < 0.7 and rad(rng:NextNumber(2, 10)) or rad(rng:NextNumber(14, 26)))
		end
		if t >= proxDedos then
			proxDedos = t + rng:NextNumber(0.15, 0.5)
			dedosAlAzar()
		end
		if t >= proxCuerpo then
			proxCuerpo = t + rng:NextNumber(0.25, 0.9)
			cuerpoAlAzar()
		end

		-- Piernas: cada paso de golpe cambia de pierna.
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
		ctl.sincronizarOjos()
	end

	return ctl
end

return SocioHuesos
