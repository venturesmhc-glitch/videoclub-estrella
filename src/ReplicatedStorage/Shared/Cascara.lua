--!nonstrict
--[[
	Cascara (compartido): la geometría por la que anda la criatura de las anomalías (Server/Criatura).
	El local se trata como una caja: el techo y las cuatro paredes (el piso no cuenta: la criatura nunca baja a caminar por el
	piso). Va hacia el punto de esa "cáscara" más cercano al jugador (con preferencia por el techo); si hay que cambiar de
	superficie pasa por la arista (techo -> pared, pared -> pared por el techo). Con los pies sobre la superficie, el cuerpo
	sale hacia adentro del local y mira hacia donde camina. Las medidas están en Config.Anomalias.Reptar.

	Superficies: "T" techo · "EP" pared x = +X · "EN" pared x = -X · "NP" pared del frente (z+) · "NN" pared del fondo (z-)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Cascara = {}

local cfg = Config.Anomalias.Reptar

-- Normal (hacia adentro del local) de cada superficie.
Cascara.NORMAL = {
	T = Vector3.new(0, -1, 0),
	EP = Vector3.new(-1, 0, 0),
	EN = Vector3.new(1, 0, 0),
	NP = Vector3.new(0, 0, -1),
	NN = Vector3.new(0, 0, 1),
}

--- Lleva un punto adentro de la caja.
function Cascara.limitar(p: Vector3): Vector3
	return Vector3.new(
		math.clamp(p.X, -cfg.X, cfg.X),
		math.clamp(p.Y, 0, cfg.Techo),
		math.clamp(p.Z, cfg.ZFondo, cfg.ZFrente)
	)
end

--- Punto de la superficie `s` más cercano a `p` (ya dentro de la caja).
function Cascara.puntoEn(s: string, p: Vector3): Vector3
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

--- La superficie (techo o pared) más cercana al jugador, con una ventaja para el techo y la superficie actual
--- (histéresis: no cambia de pared por una diferencia chica).
function Cascara.elegirSuperficie(p: Vector3, actual: string?): string
	local mejor, mejorPeso = "T", math.huge
	for s in Cascara.NORMAL do
		local d = (Cascara.puntoEn(s, p) - p).Magnitude
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

-- Punto de la arista entre el techo y la pared `pared` a la altura de lado `p`.
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

--- Tramos del camino desde (superficieActual, pos) hasta (superficieMeta, meta): { { hasta = Vector3, sup = string } }.
--- Cada tramo se recorre sobre la superficie `sup`.
function Cascara.armarCamino(superficieActual: string, pos: Vector3, superficieMeta: string, meta: Vector3)
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

--- Orientación con los pies en `pos`, el cuerpo hacia `arriba` (la normal) y mirando hacia `adelante`.
function Cascara.orientacion(pos: Vector3, arriba: Vector3, adelante: Vector3): CFrame
	local f = adelante - arriba * adelante:Dot(arriba)
	if f.Magnitude < 1e-3 then
		-- Mirando justo hacia la normal (no debería pasar): cualquier tangente sirve.
		f = if math.abs(arriba.Y) > 0.9 then Vector3.new(0, 0, -1) else Vector3.new(0, 1, 0)
	end
	f = f.Unit
	return CFrame.fromMatrix(pos, f:Cross(arriba), arriba, -f)
end

return Cascara
