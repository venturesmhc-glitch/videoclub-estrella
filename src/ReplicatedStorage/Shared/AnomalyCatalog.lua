--!strict
--[[
	AnomalyCatalog: genera las anomalías de un jugador a partir de una semilla.
	Cliente y servidor llaman a la misma función con la misma semilla y la misma escena, así que el servidor
	puede validar lo que reporta el cliente sin confiar en él.

	Tipos:
	  TituloCambiado   una portada de las góndolas muestra un título que no existe
	  CaratulaAlterada una portada cambia de color y se tapa el título
	  ObjetoMovido     un objeto del local aparece desplazado y girado
	  FiguraAlFondo    una silueta al fondo de un pasillo (desaparece si se la mira fijo)
	Cada anomalía se activa en un minuto distinto de la noche.
]]

local CollectionService = game:GetService("CollectionService")

local Catalogo = require(script.Parent.Catalogo)
local Config = require(script.Parent.Config)

export type Anomalia = {
	id: string,
	tipo: string,
	objetivo: string, -- id de la portada, del objeto movible o del punto de figura
	minuto: number, -- minuto de la noche en que se activa
	variante: number, -- qué título o color extraño
	dx: number,
	dz: number,
	rotacion: number,
}

export type Escena = {
	portadas: { string },
	movibles: { string },
	figuras: { string },
	instancias: { [string]: Instance },
}

local AnomalyCatalog = {}

AnomalyCatalog.Tipos = { "TituloCambiado", "CaratulaAlterada", "ObjetoMovido", "FiguraAlFondo" }
AnomalyCatalog.ColoresExtranos = {
	Color3.fromRGB(235, 235, 235),
	Color3.fromRGB(8, 8, 8),
	Color3.fromRGB(120, 0, 0),
	Color3.fromRGB(0, 90, 60),
}

local function recolectar(etiqueta: string, atributo: string, ids: { string }, instancias: { [string]: Instance })
	for _, instancia in CollectionService:GetTagged(etiqueta) do
		local id = instancia:GetAttribute(atributo)
		if typeof(id) == "string" then
			table.insert(ids, id)
			instancias[id] = instancia
		end
	end
	table.sort(ids)
end

--- Reúne los objetivos posibles del mapa, con ids estables y ordenados.
function AnomalyCatalog.escena(): Escena
	local escena: Escena = { portadas = {}, movibles = {}, figuras = {}, instancias = {} }
	recolectar("Portada", "PortadaId", escena.portadas, escena.instancias)
	recolectar("Movible", "AnomaliaId", escena.movibles, escena.instancias)
	recolectar("PuntoFigura", "FiguraId", escena.figuras, escena.instancias)
	return escena
end

local function sacar(lista: { string }, rng: Random): string?
	if #lista == 0 then
		return nil
	end
	return table.remove(lista, rng:NextInteger(1, #lista))
end

--- Las anomalías del jugador para la noche indicada. 'escena' viene de AnomalyCatalog.escena().
function AnomalyCatalog.generar(semilla: number, noche: number, escena: Escena): { Anomalia }
	local cfg = Config.Anomalias
	local cantidad = cfg.PorNoche[noche] or 0
	local rng = Random.new(semilla)
	local libres = {
		portadas = table.clone(escena.portadas),
		movibles = table.clone(escena.movibles),
		figuras = table.clone(escena.figuras),
	}
	local lista: { Anomalia } = {}
	for i = 1, cantidad do
		local tipo = AnomalyCatalog.Tipos[rng:NextInteger(1, #AnomalyCatalog.Tipos)]
		local fuente = if tipo == "ObjetoMovido" then libres.movibles elseif tipo == "FiguraAlFondo" then libres.figuras else libres.portadas
		local objetivo = sacar(fuente, rng)
		if objetivo then
			local variante = if tipo == "TituloCambiado"
				then rng:NextInteger(1, #Catalogo.TitulosExtranos)
				else rng:NextInteger(1, #AnomalyCatalog.ColoresExtranos)
			local signo = if rng:NextInteger(0, 1) == 0 then -1 else 1
			table.insert(lista, {
				id = "A" .. i,
				tipo = tipo,
				objetivo = objetivo,
				minuto = 0,
				variante = variante,
				dx = signo * cfg.OffsetMovido * rng:NextNumber(0.6, 1),
				dz = -signo * cfg.OffsetMovido * rng:NextNumber(0.3, 1),
				rotacion = signo * cfg.RotacionMovida * rng:NextNumber(0.5, 1),
			})
		end
	end
	-- Se reparten a lo largo de la noche.
	for i, anomalia in lista do
		local tramo = (cfg.MinutoHasta - cfg.MinutoDesde) / #lista
		anomalia.minuto = cfg.MinutoDesde + tramo * (i - 1) + tramo * rng:NextNumber(0.1, 0.9)
	end
	return lista
end

return AnomalyCatalog
