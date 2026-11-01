--!strict
-- Tipos compartidos entre cliente y servidor.

local Types = {}

export type EstadoNoche = {
	noche: number, -- 1 a 5
	minuto: number, -- minutos de juego desde las 22:00
	fase: string, -- "espera" | "turno" | "fin"
	titulo: string?,
	resumen: { string }?, -- líneas del resumen (solo cuando fase = "fin")
}

-- "danado" = cinta arrugada que hay que separar; "anomalo" lo usa AnomalySystem (Fase 3).
export type EstadoCasete = "normal" | "danado" | "anomalo"

export type Casete = {
	id: string,
	titulo: string,
	genero: string,
	estado: EstadoCasete,
	rebobinado: boolean,
	sinEtiqueta: boolean,
	vivo: boolean,
}

-- Lo que ve el cliente en su ficha de socio.
export type TareaPublica = { id: string, texto: string, actual: number, meta: number }
export type ManoPublica = { titulo: string, genero: string, estado: string, rebobinado: boolean, sinEtiqueta: boolean }
export type PedidoPublico = { tipo: string, genero: string }
export type ActualizacionTareas = {
	tareas: { TareaPublica },
	enMano: ManoPublica | false,
	pedido: PedidoPublico | false,
}

return Types
