--!nonstrict
--[[
	Reptante (cliente): mueve una figura (la sombra de una anomalía) pegada a las superficies del local: camina por el techo
	cabeza abajo y por las paredes, y te sigue desde ahí. Es solo visual y solo en esta pantalla.

	El local se trata como una caja: el techo y las cuatro paredes (el piso no cuenta: la figura nunca baja a caminar por el
	piso). La figura va hacia el punto de esa "cáscara" más cercano al jugador (con preferencia por el techo); si hay que
	cambiar de superficie, pasa por la arista (techo -> pared, pared -> pared por el techo). Con los pies sobre la
	superficie, el cuerpo sale hacia adentro del local y mira hacia donde camina.

	  Reptante.iniciar(modelo, posicionInicial, opciones?) -> detener()
	    modelo: modelo con el pivote en los pies (Silueta.crear). posicionInicial: de dónde parte (se lleva a la cáscara).
	    opciones.caminar(bool): se llama con true mientras anda y false cuando se queda quieta (animación de caminar).
	Los valores (velocidad, medidas de la caja) están en Config.Anomalias.Reptar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Reptante = {}

local cfg = Config.Anomalias.Reptar

-- Normal (hacia adentro del local) de cada superficie.
local NORMAL = {
	T = Vector3.new(0, -1, 0), -- techo
	EP = Vector3.new(-1, 0, 0), -- pared x = +X
	EN = Vector3.new(1, 0, 0), -- pared x = -X
	NP = Vector3.new(0, 0, -1), -- pared z = +Z (la del frente)
	NN = Vector3.new(0, 0, 1), -- pared z = -Z (la del fondo)
}

local function limitar(p: Vector3): Vector3
	return Vector3.new(
		math.clamp(p.X, -cfg.X, cfg.X),
		math.clamp(p.Y, 0, cfg.Techo),
		math.clamp(p.Z, cfg.ZFondo, cfg.ZFrente)
	)
end

-- Punto de la superficie `s` más cercano a `p` (ya dentro de la caja).
local function puntoEn(s: string, p: Vector3): Vector3
	if s == "T" then
		return Vector3.new(p.X, cfg.Techo, p.Z)
	elseif s == "EP" then
		return Vector3.new(cfg.X, p.Y, p.Z)
	elseif s == "EN" then
		return Vector3.new(-cfg.X, p.Y, p.Z)
	elseif s == "NP" then
		return Vector3.new(p.X, p.Y, cfg.ZFrente)
	end
	return Vector3.new(p.X, p.Y, cfg.ZFondo)
end

-- La superficie (techo o pared) más cercana al jugador, con una ventaja para el techo y la superficie actual
-- (histéresis: no cambia de pared por una diferencia chica).
local function elegirSuperficie(p: Vector3, actual: string?): string
	local mejor, mejorPeso = "T", math.huge
	for s in NORMAL do
		local d = (puntoEn(s, p) - p).Magnitude
		if s == "T" then
			d -= cfg.VentajaTecho
		end
		if s == actual then
			d -= cfg.Histeresis
		end
		if d < mejorPeso then
			mejor, mejorPeso = s, d
		end
	end
	return mejor
end

-- Punto de la arista entre el techo y la pared `pared` que está a la altura de lado `p` (sobre la arista).
local function puntoDeArista(pared: string, p: Vector3): Vector3
	if pared == "EP" then
		return Vector3.new(cfg.X, cfg.Techo, p.Z)
	elseif pared == "EN" then
		return Vector3.new(-cfg.X, cfg.Techo, p.Z)
	elseif pared == "NP" then
		return Vector3.new(p.X, cfg.Techo, cfg.ZFrente)
	end
	return Vector3.new(p.X, cfg.Techo, cfg.ZFondo)
end

-- Tramos del camino desde (superficieActual, pos) hasta (superficieMeta, meta): { { hasta = Vector3, sup = string } }.
-- Cada tramo se recorre sobre la superficie `sup`.
local function armarCamino(superficieActual: string, pos: Vector3, superficieMeta: string, meta: Vector3)
	if superficieActual == superficieMeta then
		return { { hasta = meta, sup = superficieMeta } }
	end
	if superficieActual == "T" then
		return { { hasta = puntoDeArista(superficieMeta, meta), sup = "T" }, { hasta = meta, sup = superficieMeta } }
	end
	if superficieMeta == "T" then
		return { { hasta = puntoDeArista(superficieActual, pos), sup = superficieActual }, { hasta = meta, sup = "T" } }
	end
	-- De una pared a otra: por el techo.
	return {
		{ hasta = puntoDeArista(superficieActual, pos), sup = superficieActual },
		{ hasta = puntoDeArista(superficieMeta, meta), sup = "T" },
		{ hasta = meta, sup = superficieMeta },
	}
end

-- Orientación con los pies en `pos`, el cuerpo hacia `arriba` (la normal) y mirando hacia `adelante`.
local function orientacion(pos: Vector3, arriba: Vector3, adelante: Vector3): CFrame
	local f = adelante - arriba * adelante:Dot(arriba)
	if f.Magnitude < 1e-3 then
		-- Mirando justo hacia la normal (no debería pasar): cualquier tangente sirve.
		f = if math.abs(arriba.Y) > 0.9 then Vector3.new(0, 0, -1) else Vector3.new(0, 1, 0)
	end
	f = f.Unit
	return CFrame.fromMatrix(pos, f:Cross(arriba), arriba, -f)
end

--- Empieza a mover el modelo. Devuelve la función que lo detiene.
function Reptante.iniciar(modelo: Model, inicio: Vector3, opciones)
	opciones = opciones or {}
	local jugador = Players.LocalPlayer
	local pos = puntoEn("T", limitar(Vector3.new(inicio.X, cfg.Techo, inicio.Z)))
	local superficie = "T"
	local camino = {}
	local tramoSup = "T"
	local siguienteCalculo = 0
	local activo = true
	local avanza = false
	local comienzo = os.clock()
	local adelante = Vector3.new(0, 0, -1)
	local cf = orientacion(pos, NORMAL.T, adelante)
	modelo:PivotTo(cf)

	local function posicionJugador(): Vector3?
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
		return raiz and (raiz.Position + Vector3.new(0, 1.5, 0)) or nil
	end

	local conexion
	conexion = RunService.RenderStepped:Connect(function(dt)
		if not activo or not modelo.Parent then
			conexion:Disconnect()
			return
		end
		local ahora = os.clock()
		local objetivo = posicionJugador()

		-- Cada tanto vuelve a pensar el camino hacia el punto de la cáscara más cercano al jugador.
		if objetivo and ahora >= siguienteCalculo then
			siguienteCalculo = ahora + cfg.RecalculoSeg
			local dentro = limitar(objetivo)
			local meta = elegirSuperficie(dentro, superficie)
			camino = armarCamino(superficie, pos, meta, puntoEn(meta, dentro))
		end

		-- Se queda colgada un momento antes de empezar a andar.
		local puedeAndar = ahora - comienzo >= cfg.EsperaInicialSeg
		local tramo = camino[1]
		local mueve = puedeAndar and tramo ~= nil
		if mueve then
			local falta = tramo.hasta - pos
			local paso = cfg.Velocidad * dt
			tramoSup = tramo.sup
			if falta.Magnitude <= paso then
				pos = tramo.hasta
				superficie = tramo.sup
				table.remove(camino, 1)
			else
				adelante = falta.Unit
				pos += adelante * paso
				superficie = tramo.sup
			end
		elseif objetivo then
			-- Quieta: mira hacia el jugador (en el plano de su superficie).
			adelante = objetivo - pos
		end

		if mueve ~= avanza and opciones.caminar then
			avanza = mueve
			opciones.caminar(mueve)
		end

		-- La orientación sigue a la superficie y a la dirección con suavidad (en las esquinas "da la vuelta").
		local meta = orientacion(pos, NORMAL[tramoSup] or NORMAL.T, adelante)
		cf = cf:Lerp(meta, 1 - math.exp(-cfg.Suavizado * dt))
		modelo:PivotTo(cf.Rotation + pos)
	end)

	return function()
		activo = false
		if conexion then
			conexion:Disconnect()
		end
	end
end

return Reptante
