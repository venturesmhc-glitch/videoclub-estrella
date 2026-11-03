--!strict
--[[
	Catalogo: géneros, títulos (inventados) y frases de los clientes del videoclub.
	Lo usan el servidor (casetes y clientes) y el cliente (interfaz).
]]

local Catalogo = {}

Catalogo.Generos = { "ACCION", "TERROR", "COMEDIA", "DRAMA", "INFANTIL" }

Catalogo.Nombres = {
	ACCION = "ACCIÓN",
	TERROR = "TERROR",
	COMEDIA = "COMEDIA",
	DRAMA = "DRAMA",
	INFANTIL = "INFANTIL",
}

-- Color de la caja de cada género (coincide con las góndolas del local).
Catalogo.Colores = {
	ACCION = Color3.fromRGB(160, 40, 36),
	TERROR = Color3.fromRGB(70, 18, 24),
	COMEDIA = Color3.fromRGB(220, 190, 50),
	DRAMA = Color3.fromRGB(110, 70, 90),
	INFANTIL = Color3.fromRGB(70, 130, 220),
}

Catalogo.Titulos = {
	ACCION = { "Puño de Acero III", "Operación Cóndor Negro", "El Último Marine", "Dinamita en Retiro" },
	TERROR = { "La Casa del Lago Seco", "Noche de Muñecos", "El Sótano de Don Aldo", "Pesadilla en Villa Ballester" },
	COMEDIA = { "Los Vecinos del 4°B", "Mi Suegra es Marciana", "Tango y Cachetadas", "Cuidado con el Gerente" },
	DRAMA = { "Cartas desde Rosario", "Lluvia en Mataderos", "El Silencio de Marta", "Un Verano Sin Vos" },
	INFANTIL = { "Los Aventureros del Delta", "Pipo y la Luna", "El Dragón de Papel", "Mini Detectives" },
}

-- Títulos que no corresponden a ninguna película: delatan a una cinta o una carátula anómala.
Catalogo.TitulosExtranos = {
	"NO MIRES ATRÁS",
	"SOCIO 0000",
	"VOLVÉ",
	"MIRAME",
	"ESTÁS EN LA CINTA",
	"NO REBOBINES",
	"03:33",
	"ÉL YA ESTÁ ADENTRO",
}

Catalogo.Frases = {
	PedirAlquiler = {
		"Buenas noches. ¿Tenés algo de %s?",
		"Hola, busco una de %s para esta noche.",
		"¿Me recomendás una de %s?",
	},
	Devolver = { "Vengo a devolver esto. Perdón por la demora.", "Te traigo esto de vuelta, ya la vimos." },
	DevolverDanada = {
		"Se trabó un poco... creo que quedó arrugada.",
		"Ojo que esta se comió la cinta. Perdoná.",
	},
	Gracias = { "Gracias, che. Hasta mañana.", "Buenísimo. ¡Que andes bien!" },
	Impaciente = { "Qué lento... mejor me voy.", "Uf, vuelvo otro día." },
}

-- Notas de Darío pegadas en las paredes. veraz = false: es una trampa, seguirla trae consecuencias.
Catalogo.Reglas = {
	R_TITULO = { veraz = true, texto = "No repongas ninguna cinta cuyo título no pegue con el género. Ninguna." },
	R_INTERNO = { veraz = true, texto = "Pasadas las 2:00, el teléfono del depósito NO se atiende. No importa quién llame." },
	F_TV = { veraz = false, texto = "A las 3:00 apagá la tele del mostrador. Le hace mal a la cinta." },
	R_NUMERO = { veraz = true, texto = "Ningún socio tiene cuatro ceros. Si alguien lo dice, no lo atiendas." },
	F_SIEMPRE = { veraz = false, texto = "Atendé SIEMPRE a todos los clientes. Sin excepciones. Don Ernesto lo pide." },
	R_FINAL = { veraz = true, texto = "La cinta se va de dos maneras: se devuelve o se le graba encima. (R en la videocasetera)" },
	F_FINAL = { veraz = false, texto = "Mirá la cinta hasta el final. No pasa nada, te lo juro." },
}

-- Mensajes del teléfono. "mensaje" es el contestador de Don Ernesto; "voz" son las llamadas raras.
Catalogo.Telefono = {
	Mensajes = {
		-- Noche 1: Don Ernesto llama en vivo y explica el trabajo y los controles.
		Bienvenida = {
			speaker = "Don Ernesto (por teléfono)",
			lineas = {
				"¿Hola? ¿Ya llegaste? Soy Don Ernesto, el dueño. Te llamo rápido porque esta noche no puedo ir.",
				"Esto es lo que tenés que hacer. Cuando entre un cliente, andá al mostrador y apretá E para atenderlo.",
				"Si quiere alquilar, te dice qué género busca. Andá a esa góndola, apretá E para sacar un casete y llevásselo al mostrador.",
				"Si viene a devolver, deja la cinta en el mostrador. Agarrala con E, rebobinala en la videocasetera (mantené E) y ponela en su góndola.",
				"Si una cinta está arrugada, no se rebobina: va a la caja de dañadas. Lo mismo con las que caen por el buzón.",
				"Cuando no haya clientes, hay laburo de limpieza. Las bolsas de basura van al contenedor del patio: puerta del fondo, a la derecha.",
				"Y si ves una mancha en el piso, agarrá la escoba que está apoyada en el baño y mantené E encima hasta que desaparezca. Lo que no hagas vos, que lo haga tu compañero.",
				"Tu ficha de socio está a la izquierda: ahí figura todo lo que falta. Con Tab la mostrás o la ocultás. Y con G soltás lo que tengas en la mano.",
				"Si alguna vez la luz se corta, F es la linterna. Y si ves algo fuera de lugar, apuntale y apretá Q. Después hablamos de eso.",
				"Hasta las cuatro de la mañana. No me llamen, yo los llamo. Suerte, che.",
			},
		},
		-- Noche 2: explica las anomalías y la tecla Q.
		Anomalias = {
			speaker = "Don Ernesto (por teléfono)",
			lineas = {
				"Soy Ernesto otra vez. Escuchame bien: desde anoche pasan cosas raras en el local.",
				"A veces algo aparece cambiado: un título que no existe, una carátula rara, un objeto fuera de lugar, o una sombra parada al fondo de un pasillo.",
				"Eso son anomalías. Cuando veas una, apuntale y apretá Q. Si acertás, queda registrada y el Socio se calma un poco. Si las dejás, se enoja.",
				"En tu ficha, abajo de todo, figura cuántas encontraste. Cada uno ve las suyas, así que no se las puede copiar al compañero.",
				"Ojo: la sombra quieta es una anomalía, no es él. El Socio es otra cosa: solo se mueve cuando nadie lo mira. A ese no se le apunta con la Q: se lo mira y no se le saca la vista de encima.",
			},
		},
		[1] = {
			speaker = "CONTESTADOR - Don Ernesto",
			lineas = {
				"Habla Don Ernesto. Las llaves están en el cajón. No me llamen: yo los llamo.",
				"Es un turno tranquilo. Rebobinen, repongan y atiendan a los socios.",
			},
		},
		[2] = {
			speaker = "CONTESTADOR - Don Ernesto",
			lineas = {
				"Ernesto otra vez. Si llama Darío, no le atiendan. Renunció, ya está.",
				"Y no toquen nada de lo que dejó pegado en las paredes... bueno, léanlo, nomás.",
			},
		},
	},
	VozCinta = {
		speaker = "(estática)",
		lineas = {
			"...bienvenido a Star Videoclub... turno noche...",
			"...ya estás en la cinta...",
		},
	},
	VozCompanero = {
		lineas = {
			"No mires hacia atrás.",
			"Ya te vi trabajar esta noche. Dejá la cinta donde está.",
		},
	},
}

Catalogo.Finales = {
	REBOBINAR = {
		titulo = "FINAL 1/3: REBOBINAR",
		lineas = {
			"Le grabás encima. La imagen se llena de estática y, después, de nada.",
			"El Socio N° 0000 no vuelve a aparecer.",
			"A las 22:00 el local abre otra vez. En la ficha del mostrador falta un nombre.",
			"Alguien empieza un turno que ya empezó.",
		},
	},
	DEVOLVER = {
		titulo = "FINAL 2/3: DEVOLVER (final verdadero)",
		lineas = {
			"Le devolvés la cinta. El Socio N° 0000 la mira un momento y asiente.",
			"Cerrás su cuenta. En la ficha aparece, por fin, el nombre que faltaba: DARÍO.",
			"Darío fue el primero en encontrar la cinta. No renunció: lo grabaron. Su último turno seguía repitiéndose adentro.",
			"Ahora el socio cero puede irse. Y Darío con él.",
			"En el contestador, Don Ernesto: «Gracias por cerrar la cuenta. Dejen las llaves en el cajón.»",
		},
	},
	MIRAR = {
		titulo = "FINAL 3/3: MIRAR HASTA EL FINAL",
		lineas = {
			"Mirás hasta el final. La tele se vuelve el local, y en el local estás vos, de espaldas, mirando la tele.",
			"El turno noche sigue grabado.",
			"Mañana empieza alguien nuevo.",
		},
	},
}

-- Insignias (Insignias.lua). El orden es el de la lista de logros; los ids de Roblox están en Config.Insignias.Ids.
Catalogo.Insignias = {
	{ clave = "PRIMER_TURNO", nombre = "Primer turno", descripcion = "Sobreviví tu primera noche en el Videoclub Estrella." },
	{ clave = "NOCHE_5", nombre = "En vivo", descripcion = "Llegá a la quinta noche, cuando el Socio ya está adentro." },
	{ clave = "FINAL_REBOBINAR", nombre = "Grabar encima", descripcion = "Alcanzá el final REBOBINAR." },
	{ clave = "FINAL_DEVOLVER", nombre = "Cuenta cerrada", descripcion = "Alcanzá el final verdadero: DEVOLVER." },
	{ clave = "FINAL_MIRAR", nombre = "Hasta el final", descripcion = "Alcanzá el final MIRAR HASTA EL FINAL." },
	{ clave = "TODOS_LOS_FINALES", nombre = "Cinta completa", descripcion = "Alcanzá los tres finales del Videoclub Estrella." },
	{ clave = "SIN_FIN_5", nombre = "Insomnio", descripcion = "Sobreviví 5 noches seguidas en el modo Sin fin." },
	{ clave = "SIN_FIN_10", nombre = "Turno eterno", descripcion = "Sobreviví 10 noches seguidas en el modo Sin fin." },
	{ clave = "NOCHE_3", nombre = "Mitad de camino", descripcion = "Sobreviví la tercera noche en el modo Historia." },
	{ clave = "RECHAZAR_SOCIO", nombre = "Te vi venir", descripcion = "Rechazá al Socio cuando se presenta como cliente." },
	{ clave = "EN_EQUIPO", nombre = "Turno compartido", descripcion = "Sobreviví una noche con otro jugador en el local." },
	{ clave = "SIN_FIN_20", nombre = "Sin descanso", descripcion = "Sobreviví 20 noches seguidas en el modo Sin fin." },
}

--- Título al azar de un género.
function Catalogo.tituloAleatorio(genero: string, rng: Random): string
	local lista = Catalogo.Titulos[genero :: any] :: { string }
	return lista[rng:NextInteger(1, #lista)]
end

--- Título de un casete: las cintas anómalas llevan un título que no existe.
function Catalogo.tituloPara(genero: string, estado: string, rng: Random): string
	if estado == "anomalo" then
		return Catalogo.TitulosExtranos[rng:NextInteger(1, #Catalogo.TitulosExtranos)]
	end
	return Catalogo.tituloAleatorio(genero, rng)
end

--- Frase al azar de un grupo (Catalogo.Frases[clave]); si lleva %s se reemplaza por 'argumento'.
--- Frase al azar de un grupo, sin reemplazar el %s (para poder repetirla con otro argumento).
function Catalogo.plantilla(clave: string, rng: Random): string
	local lista = Catalogo.Frases[clave :: any] :: { string }
	return lista[rng:NextInteger(1, #lista)]
end

--- Reemplaza el %s de una plantilla por 'argumento' (si lo hay).
function Catalogo.rellenar(texto: string, argumento: string?): string
	if argumento then
		return string.format(texto, argumento)
	end
	return texto
end

function Catalogo.frase(clave: string, rng: Random, argumento: string?): string
	local texto = Catalogo.plantilla(clave, rng)
	if argumento then
		return string.format(texto, argumento)
	end
	return texto
end

return Catalogo
