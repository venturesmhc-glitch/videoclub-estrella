--!strict
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
]]

local Config = require(script.Parent.Config)

export type Evento = { minuto: number, id: string, datos: any? }
export type Objetivo = { id: string, texto: string, meta: number }
export type Noche = {
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
	local atender, normales, separar, basura, manchas = 0, 0, 0, 0, 0
	for _, e in eventos do
		local datos = e.datos
		if e.id == "BASURA" then
			basura += #datos.zonas
		elseif e.id == "DERRAME" then
			manchas += #datos.zonas
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
		table.insert(lista, { id = "limpiar", texto = "Limpiar manchas", meta = manchas })
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
		buzon(80, "COMEDIA"),
		cliente(95, "alquiler", "TERROR"),
		buzon(130, "DRAMA", { danado = true }),
		cliente(145, "devolucion", "DRAMA", { danado = true }),
		evento(100, "AVISO", { texto = "Alguien dejó basura. Las bolsas se llevan al contenedor del patio (puerta del fondo, a la derecha)." }),
		evento(101, "BASURA", { zonas = { "LOCAL" } }),
		evento(150, "AVISO", { texto = "Una mancha: mantené E encima para limpiarla." }),
		evento(151, "DERRAME", { zonas = { "BANO" } }),
		buzon(180, "ACCION"),
		cliente(195, "alquiler", "INFANTIL"),
		buzon(230, "TERROR"),
		cliente(245, "devolucion", "TERROR"),
		evento(Config.Noche.MinutoEventoCinta, "CINTA_LLEGA"),
	}),

	-- Noche 2: anomalías chicas. La cinta muestra a los jugadores trabajando esa misma noche.
	[2] = noche("Anomalías", "Detectar anomalías", "normal", {
		evento(30, "AVISO", { texto = "Si ves algo fuera de lugar, apuntale y apretá Q." }),
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
		evento(330, "SOCIO_MOSTRADOR"),
	}),
}

return NightData
