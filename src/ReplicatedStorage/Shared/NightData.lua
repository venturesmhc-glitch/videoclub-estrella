--!nonstrict
--[[
	NightData: contenido de cada noche (objetivos, modo de los clientes y eventos por horario).
	"minuto" se cuenta desde las 22:00 (360 = 04:00). Los eventos los dispara NightManager.
	Los objetivos se calculan solos a partir de los eventos (ver objetivosDe).

	Eventos:
	  CLIENTE        { tipo = "alquiler" | "devolucion", genero, danado?, anomalo?, socio? }  llega un cliente
	  BUZON          { genero, danado?, anomalo? }                                         cae un casete por la ranura
	  CINTA_LLEGA                                                                          la cinta sin etiqueta
	  SOCIO_ACTIVA                                                                         el Socio empieza a moverse
	  SOCIO_MOSTRADOR                                                                      noche 5: el Socio hace cola
	  NOTAS          { ids }                                                               notas de Darío en las paredes
	  TELEFONO       { linea = "mostrador" | "interno", mensaje?, voz? }                   suena un teléfono
	  CORTE_LUZ      { valor }                                                             se corta la luz
	  DEPOSITO_LARGO                                                                       el depósito se alarga
	  AVISO          { texto }                                                             mensaje corto para todos
	  BASURA         { zonas = { "LOCAL" | "MOSTRADOR" | "BANO" | "COCINA" | "DEPOSITO" } }  aparecen bolsas (ChoreSystem)
	  DERRAME        { zonas = { ..., "PATIO" } }                                          aparecen manchas para limpiar
	  TAREA_MENOR    { ids = { "PLANTA" | "FICHAS" | "CARTEL" | "VIDRIO" | "CAJA" } }        pequeñas tareas del local (TareasMenores)
	  SUSTO_SUAVE    { tipo = "tele" | "luces" | "ventana" }                                un susto chico (Client/Sustos)
	  SCREAMER       { variante? }                                                          screamer a pantalla completa (Screamers)

	NightData.paraJugadores(noche, cantidad) devuelve la noche con tareas extra según cuántos jugadores hay.
]]

local Config = require(script.Parent.Config)

export type Evento = { minuto: number, id: string, datos: any? }
export type Objetivo = { id: string, texto: string, meta: number }
export type Noche = {
	duracionSeg: number?, -- minutos reales que dura la noche (si no, Config.Noche.DuracionRealSegundos)
	titulo: string,
	objetivo: string,
	clientesModo: string, -- "normal" | "repetir" (repiten la misma frase) | "mismo" (todos iguales, con número de socio)
	objetivos: { Objetivo },
	eventos: { Evento },
}

local function cliente(minuto: number, tipo: string, genero: string, extra: any?): Evento
	local datos: any = { tipo = tipo, genero = genero }
	for k, v in extra or {} do
		datos[k] = v
	end
	return { minuto = minuto, id = "CLIENTE", datos = datos }
end

local function buzon(minuto: number, genero: string, extra: any?): Evento
	local datos: any = { genero = genero }
	for k, v in extra or {} do
		datos[k] = v
	end
	return { minuto = minuto, id = "BUZON", datos = datos }
end

local function evento(minuto: number, id: string, datos: any?): Evento
	return { minuto = minuto, id = id, datos = datos }
end

-- Cuenta lo que hay que hacer: clientes, cintas normales (rebobinar y reponer) y cintas a separar.
local function objetivosDe(eventos: { Evento }): { Objetivo }
	local atender, normales, separar, basura, manchas, menores = 0, 0, 0, 0, 0, 0
	for _, e in eventos do
		local datos = e.datos
		if e.id == "BASURA" then
			basura += #datos.zonas
		elseif e.id == "DERRAME" then
			manchas += #datos.zonas
		elseif e.id == "TAREA_MENOR" then
			menores += #datos.ids
		end
		if e.id == "CLIENTE" then
			atender += 1
		end
		if e.id == "BUZON" or (e.id == "CLIENTE" and datos.tipo == "devolucion") then
			if datos.danado or datos.anomalo then
				separar += 1
			else
				normales += 1
			end
		end
	end
	local lista: { Objetivo } = {
		{ id = "atender", texto = "Atender clientes", meta = atender },
		{ id = "rebobinar", texto = "Rebobinar casetes", meta = normales },
		{ id = "reponer", texto = "Reponer por género", meta = normales },
	}
	if separar > 0 then
		table.insert(lista, { id = "separar", texto = "Separar cintas dañadas", meta = separar })
	end
	if basura > 0 then
		table.insert(lista, { id = "basura", texto = "Tirar la basura (patio)", meta = basura })
	end
	if manchas > 0 then
		table.insert(lista, { id = "limpiar", texto = "Limpiar manchas (cepillo del baño)", meta = manchas })
	end
	if menores > 0 then
		table.insert(lista, { id = "menores", texto = "Cuidar el local", meta = menores })
	end
	return lista
end

local function noche(titulo: string, objetivo: string, modo: string, eventos: { Evento }): Noche
	return { titulo = titulo, objetivo = objetivo, clientesModo = modo, objetivos = objetivosDe(eventos), eventos = eventos }
end

local NightData: { [number]: Noche } = {
	-- Noche 1: turno normal (tutorial). A las 3:33 llega la cinta sin etiqueta.
	[1] = noche("Primer turno", "Enseñar mecánicas", "normal", {
		-- El teléfono suena hasta que alguien lo atiende: Don Ernesto explica el trabajo y los controles.
		evento(1, "TELEFONO", { linea = "mostrador", mensaje = "Bienvenida", espera = true }),
		evento(29, "AVISO", { texto = "Cuando llegue un cliente, atendelo en el mostrador (E)." }),
		evento(62, "AVISO", { texto = "Los casetes devueltos se rebobinan en la videocasetera (mantené E) y se reponen en su góndola." }),
		evento(132, "AVISO", { texto = "Una cinta arrugada no se rebobina: va a la caja de dañadas." }),
		cliente(30, "alquiler", "COMEDIA"),
		cliente(60, "devolucion", "ACCION"),
		-- Sustos analógicos de a poco desde el principio (cada tipo es distinto, ninguno hace daño):
		evento(40, "SUSTO_SUAVE", { tipo = "tele" }),
		evento(88, "SUSTO_SUAVE", { tipo = "luces" }), -- a los ~2.5 min reales: gancho temprano
		evento(150, "SUSTO_SUAVE", { tipo = "ventana" }),
		evento(215, "SUSTO_SUAVE", { tipo = "tele" }),
		evento(285, "SUSTO_SUAVE", { tipo = "luces" }),
		buzon(80, "COMEDIA"),
		cliente(95, "alquiler", "TERROR"),
		buzon(130, "DRAMA", { danado = true }),
		cliente(145, "devolucion", "DRAMA", { danado = true }),
		evento(101, "BASURA", { zonas = { "LOCAL" } }),
		evento(151, "DERRAME", { zonas = { "BANO" } }),
		buzon(180, "ACCION"),
		cliente(195, "alquiler", "INFANTIL"),
		buzon(230, "TERROR"),
		cliente(245, "devolucion", "TERROR"),
		evento(Config.Noche.MinutoEventoCinta, "CINTA_LLEGA"),
	}),

	-- Noche 2: anomalías chicas. La cinta muestra a los jugadores trabajando esa misma noche.
	[2] = noche("Anomalías", "Detectar anomalías", "normal", {
		-- Don Ernesto llama y explica las anomalías (Q); suena hasta que alguien atiende.
		evento(2, "TELEFONO", { linea = "mostrador", mensaje = "Anomalias", espera = true }),
		evento(30, "AVISO", { texto = "Algo fuera de lugar: apuntale y apretá Q. Tu ficha cuenta las que encontraste." }),
		cliente(10, "alquiler", "COMEDIA"),
		buzon(25, "COMEDIA"),
		cliente(40, "devolucion", "TERROR"),
		evento(45, "CINTA_LLEGA"),
		buzon(60, "DRAMA", { anomalo = true }),
		cliente(85, "alquiler", "ACCION"),
		buzon(105, "INFANTIL", { danado = true }),
		cliente(125, "devolucion", "COMEDIA", { anomalo = true }),
		buzon(150, "ACCION"),
		cliente(165, "alquiler", "DRAMA"),
		evento(180, "SOCIO_ACTIVA"),
		buzon(190, "TERROR", { anomalo = true }),
		cliente(205, "devolucion", "INFANTIL", { danado = true }),
		evento(70, "BASURA", { zonas = { "MOSTRADOR", "DEPOSITO" } }),
		evento(140, "DERRAME", { zonas = { "LOCAL", "COCINA" } }),
		evento(60, "SUSTO_SUAVE", { tipo = "tele" }),
		evento(140, "SUSTO_SUAVE", { tipo = "ventana" }),
		evento(230, "SUSTO_SUAVE", { tipo = "luces" }),
		cliente(245, "alquiler", "TERROR"),
		buzon(260, "COMEDIA"),
	}),

	-- Noche 3: reglas de Darío, teléfono con audio de la cinta, clientes que repiten frases.
	[3] = noche("Las reglas de Darío", "Reglas de Darío", "repetir", {
		evento(3, "NOTAS", { ids = { "R_TITULO", "R_INTERNO", "F_TV" } }),
		cliente(10, "alquiler", "ACCION"),
		evento(35, "CINTA_LLEGA"),
		evento(40, "TELEFONO", { linea = "mostrador", mensaje = 1 }),
		buzon(50, "COMEDIA", { anomalo = true }),
		cliente(60, "devolucion", "DRAMA"),
		evento(80, "SOCIO_ACTIVA"),
		cliente(95, "alquiler", "INFANTIL"),
		buzon(105, "TERROR"),
		evento(110, "TELEFONO", { linea = "interno", mensaje = 2 }),
		cliente(130, "devolucion", "ACCION", { anomalo = true }),
		evento(170, "TELEFONO", { linea = "mostrador", voz = "cinta" }),
		cliente(165, "alquiler", "TERROR"),
		buzon(185, "DRAMA", { danado = true }),
		cliente(205, "devolucion", "COMEDIA"),
		buzon(225, "INFANTIL", { anomalo = true }),
		evento(250, "TELEFONO", { linea = "interno", voz = "companero" }),
		evento(90, "BASURA", { zonas = { "BANO", "COCINA" } }),
		evento(120, "DERRAME", { zonas = { "BANO" } }),
		evento(200, "DERRAME", { zonas = { "DEPOSITO" } }),
		evento(70, "SUSTO_SUAVE", { tipo = "ventana" }),
		evento(150, "SUSTO_SUAVE", { tipo = "tele" }),
		evento(240, "SUSTO_SUAVE", { tipo = "luces" }),
		cliente(245, "alquiler", "COMEDIA"),
		buzon(270, "ACCION"),
	}),

	-- Noche 4: corte de luz, depósito más largo, clientes que son el mismo cliente (uno es el Socio).
	[4] = noche("Sin luz", "Sobrevivir sin ver", "mismo", {
		evento(3, "NOTAS", { ids = { "R_TITULO", "R_INTERNO", "F_TV", "R_NUMERO" } }),
		cliente(10, "alquiler", "TERROR"),
		evento(30, "CINTA_LLEGA"),
		buzon(45, "ACCION"),
		evento(60, "SOCIO_ACTIVA"),
		cliente(70, "devolucion", "COMEDIA"),
		evento(95, "TELEFONO", { linea = "mostrador", voz = "cinta" }),
		evento(100, "CORTE_LUZ", { valor = true }),
		evento(100, "DEPOSITO_LARGO"),
		cliente(115, "alquiler", "DRAMA"),
		buzon(130, "INFANTIL", { anomalo = true }),
		evento(150, "NOTAS", { ids = { "F_SIEMPRE" } }),
		cliente(165, "devolucion", "TERROR", { anomalo = true }),
		evento(190, "TELEFONO", { linea = "interno", voz = "companero" }),
		cliente(200, "alquiler", "ACCION", { socio = true }),
		buzon(215, "DRAMA"),
		cliente(235, "devolucion", "INFANTIL"),
		evento(40, "BASURA", { zonas = { "LOCAL", "COCINA" } }),
		evento(80, "DERRAME", { zonas = { "COCINA" } }),
		evento(210, "DERRAME", { zonas = { "BANO", "LOCAL" } }),
		evento(55, "SUSTO_SUAVE", { tipo = "tele" }),
		evento(125, "SUSTO_SUAVE", { tipo = "ventana" }),
		evento(245, "SUSTO_SUAVE", { tipo = "ventana" }),
		cliente(275, "alquiler", "COMEDIA"),
		buzon(290, "TERROR", { danado = true }),
	}),

	-- Noche 5: la cinta en tiempo real, el Socio ya está adentro. Final.
	[5] = noche("En vivo", "Final", "mismo", {
		evento(1, "CORTE_LUZ", { valor = true }),
		evento(1, "SOCIO_ACTIVA"),
		evento(3, "NOTAS", { ids = { "R_TITULO", "R_NUMERO", "R_FINAL", "F_FINAL" } }),
		evento(20, "CINTA_LLEGA"),
		cliente(15, "alquiler", "COMEDIA"),
		buzon(50, "ACCION"),
		cliente(90, "devolucion", "DRAMA"),
		evento(120, "TELEFONO", { linea = "mostrador", voz = "cinta" }),
		buzon(150, "TERROR", { anomalo = true }),
		cliente(180, "alquiler", "INFANTIL"),
		evento(230, "TELEFONO", { linea = "interno", voz = "companero" }),
		cliente(250, "devolucion", "ACCION", { anomalo = true }),
		evento(60, "BASURA", { zonas = { "BANO", "MOSTRADOR" } }),
		evento(100, "DERRAME", { zonas = { "PATIO" } }),
		evento(200, "DERRAME", { zonas = { "LOCAL" } }),
		evento(80, "SUSTO_SUAVE", { tipo = "ventana" }),
		evento(160, "SUSTO_SUAVE", { tipo = "tele" }),
		evento(250, "SUSTO_SUAVE", { tipo = "ventana" }),
		evento(330, "SOCIO_MOSTRADOR"),
	}),
}

-- Suma eventos a una noche y recalcula sus objetivos.
local function ampliar(n: Noche, extra: { Evento })
	for _, e in extra do
		table.insert(n.eventos, e)
	end
	n.objetivos = objetivosDe(n.eventos)
end

-- Las dos primeras noches tenían mucho tiempo muerto: más clientes y cintas, basura, manchas y las pequeñas tareas
-- del local (regar la planta, ordenar las fichas, enderezar el cartel, limpiar el vidrio, contar la caja).
-- La noche 1 dura la mitad (5 minutos reales): es la que tiene que enganchar, así que va más al hilo y con menos relleno.
NightData[1].duracionSeg = 300
ampliar(NightData[1], {
	evento(48, "AVISO", { texto = "El local también necesita cuidados: regá la planta, ordená las fichas, contá la caja... (se marcan con un contorno)." }),
	evento(50, "TAREA_MENOR", { ids = { "PLANTA" } }),
	evento(70, "BASURA", { zonas = { "MOSTRADOR" } }),
	cliente(120, "alquiler", "ACCION"),
	evento(125, "TAREA_MENOR", { ids = { "FICHAS" } }),
	evento(200, "DERRAME", { zonas = { "MOSTRADOR" } }),
	evento(210, "TAREA_MENOR", { ids = { "CAJA" } }),
})

ampliar(NightData[2], {
	evento(18, "TAREA_MENOR", { ids = { "FICHAS" } }),
	evento(35, "BASURA", { zonas = { "LOCAL" } }),
	cliente(55, "alquiler", "INFANTIL"),
	evento(55, "TAREA_MENOR", { ids = { "PLANTA" } }),
	buzon(75, "TERROR"),
	evento(95, "DERRAME", { zonas = { "MOSTRADOR" } }),
	evento(100, "TAREA_MENOR", { ids = { "VIDRIO" } }),
	cliente(115, "alquiler", "TERROR"),
	buzon(125, "COMEDIA", { danado = true }),
	evento(155, "TAREA_MENOR", { ids = { "CARTEL" } }),
	evento(165, "BASURA", { zonas = { "COCINA" } }),
	cliente(175, "devolucion", "ACCION"),
	evento(195, "DERRAME", { zonas = { "BANO" } }),
	evento(200, "TAREA_MENOR", { ids = { "CAJA" } }),
	buzon(210, "INFANTIL"),
	cliente(225, "alquiler", "DRAMA"),
	evento(240, "BASURA", { zonas = { "MOSTRADOR" } }),
	evento(250, "TAREA_MENOR", { ids = { "PLANTA" } }),
	cliente(270, "devolucion", "TERROR"),
	buzon(280, "DRAMA"),
	evento(90, "SCREAMER"),
})

-- Screamers a pantalla completa en las noches 3 a 5 (los sustos suaves de antes siguen).
ampliar(NightData[3], { evento(135, "SCREAMER") })
ampliar(NightData[4], { evento(115, "SCREAMER"), evento(260, "SCREAMER") })
ampliar(NightData[5], { evento(110, "SCREAMER"), evento(210, "SCREAMER"), evento(300, "SCREAMER") })

-- Con más jugadores hay más trabajo: por cada jugador de más se suman clientes, cintas, basura, manchas y tareas del local,
-- repartidos por toda la noche. Las noches de 1 jugador quedan como están escritas arriba.
local GENEROS = { "COMEDIA", "ACCION", "DRAMA", "TERROR", "INFANTIL" }
local ZONAS_BASURA = { "LOCAL", "MOSTRADOR", "BANO", "COCINA", "DEPOSITO" }
local ZONAS_DERRAME = { "MOSTRADOR", "LOCAL", "COCINA", "BANO", "DEPOSITO", "PATIO" }
local TAREAS_MENORES = { "PLANTA", "FICHAS", "CARTEL", "VIDRIO", "CAJA" }
local porJugadores: { [string]: Noche } = {}

-- Suma a una noche las tareas de los jugadores de más (cantidad >= 2) y recalcula sus objetivos.
local function conJugadores(base: Noche, numero: number, cantidad: number): Noche
	local eventos: { Evento } = table.clone(base.eventos)
	for p = 1, cantidad - 1 do
		local corrimiento = (p * 17) % 41 -- cada jugador extra desplaza sus tareas para que no caigan todas juntas
		local g = (numero + p) % #GENEROS + 1
		local anomalo = numero >= 2 and p % 2 == 0
		table.insert(eventos, cliente(26 + corrimiento, "alquiler", GENEROS[g]))
		table.insert(eventos, cliente(135 + corrimiento, "devolucion", GENEROS[g % #GENEROS + 1]))
		table.insert(eventos, buzon(78 + corrimiento, GENEROS[(g + 1) % #GENEROS + 1], anomalo and { anomalo = true } or nil))
		table.insert(eventos, evento(48 + corrimiento, "BASURA", { zonas = { ZONAS_BASURA[(numero + p) % #ZONAS_BASURA + 1] } }))
		table.insert(eventos, evento(108 + corrimiento, "DERRAME", { zonas = { ZONAS_DERRAME[(numero + p * 2) % #ZONAS_DERRAME + 1] } }))
		table.insert(eventos, evento(180 + corrimiento, "TAREA_MENOR", { ids = { TAREAS_MENORES[(numero + p) % #TAREAS_MENORES + 1] } }))
	end
	local noche: Noche = {
		duracionSeg = base.duracionSeg,
		titulo = base.titulo,
		objetivo = base.objetivo,
		clientesModo = base.clientesModo,
		objetivos = objetivosDe(eventos),
		eventos = eventos,
	}
	return noche
end

function NightData.paraJugadores(numero: number, cantidad: number): Noche?
	local base = NightData[numero]
	if not base or cantidad <= 1 then
		return base
	end
	cantidad = math.min(cantidad, 4)
	local clave = numero .. ":" .. cantidad
	if not porJugadores[clave] then
		porJugadores[clave] = conJugadores(base, numero, cantidad)
	end
	return porJugadores[clave]
end

-- ===== Modo Sin fin =====
-- Las noches se arman solas con la misma receta (clientes, cintas, basura, manchas, tareas del local, sustos, Socio) y
-- van subiendo de dificultad hasta la noche Config.SinFin.NocheTopeDificultad. No hay final ni cinta final: la
-- cinta sin etiqueta sigue llegando, pero ver la cinta no termina nada.
local MODOS_CLIENTES = { "normal", "repetir", "mismo" }
local TIPOS_SUSTO = { "tele", "luces", "ventana" }
local sinFinCache: { [string]: Noche } = {}

local function generarSinFin(n: number): Noche
	local rng = Random.new(n * 7919 + 13)
	local d = math.min(n, Config.SinFin.NocheTopeDificultad)
	local eventos: { Evento } = {}

	-- Reparte 'cantidad' minutos entre 'desde' y 'hasta' con un poco de desorden.
	local function repartir(cantidad: number, desde: number, hasta: number): { number }
		local lista = {}
		local paso = (hasta - desde) / cantidad
		for i = 1, cantidad do
			table.insert(lista, math.floor(desde + (i - 1) * paso + rng:NextNumber(0, paso * 0.6)))
		end
		return lista
	end
	local function genero(): string
		return GENEROS[rng:NextInteger(1, #GENEROS)]
	end

	-- Clientes (alquilan y devuelven, de a uno) y cintas por el buzón.
	local probDanada = math.min(0.12 + 0.02 * d, 0.32)
	local probAnomala = if n >= 2 then math.min(0.08 + 0.03 * d, 0.34) else 0
	local function estadoDeCinta(): any?
		local x = rng:NextNumber()
		if x < probDanada then
			return { danado = true }
		elseif x < probDanada + probAnomala then
			return { anomalo = true }
		end
		return nil
	end
	for i, minuto in repartir(math.min(7 + d // 2, 13), 10, 285) do
		if i % 2 == 0 then
			table.insert(eventos, cliente(minuto, "devolucion", genero(), estadoDeCinta()))
		else
			table.insert(eventos, cliente(minuto, "alquiler", genero()))
		end
	end
	for _, minuto in repartir(math.min(5 + d // 3, 9), 20, 295) do
		table.insert(eventos, buzon(minuto, genero(), estadoDeCinta()))
	end
	local modoClientes = MODOS_CLIENTES[(n - 1) % #MODOS_CLIENTES + 1]
	if modoClientes == "mismo" then
		table.insert(eventos, cliente(rng:NextInteger(190, 230), "alquiler", "ACCION", { socio = true }))
	end

	-- Trabajo extra del local.
	local cantidadExtra = math.min(2 + d // 2, 6)
	for _, minuto in repartir(cantidadExtra, 25, 280) do
		table.insert(eventos, evento(minuto, "BASURA", { zonas = { ZONAS_BASURA[rng:NextInteger(1, #ZONAS_BASURA)] } }))
	end
	for _, minuto in repartir(cantidadExtra, 40, 290) do
		table.insert(eventos, evento(minuto, "DERRAME", { zonas = { ZONAS_DERRAME[rng:NextInteger(1, #ZONAS_DERRAME)] } }))
	end
	for _, minuto in repartir(math.min(2 + d // 3, 5), 20, 285) do
		table.insert(eventos, evento(minuto, "TAREA_MENOR", { ids = { TAREAS_MENORES[rng:NextInteger(1, #TAREAS_MENORES)] } }))
	end

	-- Sustos: los suaves de siempre y screamers separados por más que el enfriamiento (Config.Screamer.EntreAutomaticosSeg).
	for _, minuto in repartir(3, 30, 300) do
		table.insert(eventos, evento(minuto, "SUSTO_SUAVE", { tipo = TIPOS_SUSTO[rng:NextInteger(1, #TIPOS_SUSTO)] }))
	end
	for i = 1, math.min(1 + d // 3, 4) do
		table.insert(eventos, evento(70 + (i - 1) * 75 + rng:NextInteger(0, 15), "SCREAMER"))
	end

	-- El Socio se activa cada vez más temprano; la cinta llega siempre.
	table.insert(eventos, evento(math.max(15, 110 - d * 9) + rng:NextInteger(0, 10), "SOCIO_ACTIVA"))
	table.insert(eventos, evento(35 + rng:NextInteger(0, 40), "CINTA_LLEGA"))

	-- Reglas de Darío, llamadas y corte de luz según avanza la dificultad.
	if n >= 3 then
		local ids = { "R_TITULO", "R_INTERNO", "F_TV" }
		if n >= 4 then
			table.insert(ids, "R_NUMERO")
			table.insert(eventos, evento(150, "NOTAS", { ids = { "F_SIEMPRE" } }))
		end
		table.insert(eventos, evento(3, "NOTAS", { ids = ids }))
		table.insert(eventos, evento(40 + rng:NextInteger(0, 20), "TELEFONO", { linea = "mostrador", mensaje = 1 + n % 2 }))
		table.insert(eventos, evento(190 + rng:NextInteger(0, 20), "TELEFONO", { linea = "interno", voz = "companero" }))
	end
	if n >= 2 then
		table.insert(eventos, evento(95 + rng:NextInteger(0, 25), "TELEFONO", { linea = "mostrador", voz = "cinta" }))
	end
	if n >= 4 then
		local minutoCorte = math.max(60, 160 - d * 8) + rng:NextInteger(0, 20)
		table.insert(eventos, evento(minutoCorte, "CORTE_LUZ", { valor = true }))
		table.insert(eventos, evento(minutoCorte, "DEPOSITO_LARGO"))
	end
	if n == 1 then
		table.insert(eventos, evento(5, "AVISO", { texto = "Sin fin: cada noche es peor y no hay final. Aguantá todo lo que puedas." }))
	end

	return noche("Turno sin fin", "Resistir", modoClientes, eventos)
end

--- La noche del modo Sin fin (la cantidad de jugadores suma tareas igual que en la historia).
function NightData.sinFin(numero: number, cantidad: number): Noche
	cantidad = math.clamp(cantidad, 1, 4)
	local clave = numero .. ":" .. cantidad
	if not sinFinCache[clave] then
		local base = generarSinFin(numero)
		sinFinCache[clave] = if cantidad > 1 then conJugadores(base, numero, cantidad) else base
	end
	return sinFinCache[clave]
end

--- La noche 'numero' del modo indicado ("historia" | "sinfin") para esa cantidad de jugadores.
function NightData.deModo(modo: string, numero: number, cantidad: number): Noche?
	if modo == "sinfin" then
		return NightData.sinFin(numero, cantidad)
	end
	return NightData.paraJugadores(numero, cantidad)
end

return NightData
