--!nonstrict
--[[
	Cinematicas: los clips de promoción (TikTok / Reels / YouTube Shorts) como DATOS. Los reproduce Client/Cinematica
	(solo existe con Config.Debug.ModoGrabacion = true) y se lanzan con:  node dbg.js cine NOMBRE

	Para cambiar un clip no hace falta tocar código: se retocan los números de acá y se corre node push.js.

	Clip = {
		titulo = "Turno noche",
		duracion = 20,              -- segundos; al llegar se corta a negro
		fov = 66,                   -- campo de visión base (por defecto Config.Jugador.CamaraFOV)
		ambiente = 0.3,             -- (opcional) multiplica la luz ambiente del local: más bajo = sombras más cerradas
		mano = 1,                   -- cuánto tiembla la cámara en mano (0 = trípode, 1 = normal, 2 = nervioso)
		osd = {                     -- videocasetera (Client/OSD)
			estado = "PLAY",        --   PLAY | PAUSE | REW | FF | REC
			hora = { noche = 2, minuto = 316, escala = 1 / 60 },
			                        --   reloj de la cinta: noche (fija el día), minuto desde las 22:00 (316 = 03:16) y minutos de reloj por
			                        --   segundo real (1/60 = reloj de verdad). Alternativa: fecha = "NOV 16 1997  03:16" (texto fijo).
			contador = 0,           --   segundos del contador "CTR"
		},
		vhs = { intensidad = 1, peligro = nil },   -- filtro VHS (peligro 0..1 fuerza la estática; nil = la de siempre)
		camara = {                  -- puntos de cámara, en orden de t
			{ t = 0, pos = V(x, y, z), mira = V(x, y, z), fov = 66, giro = 0, ease = "Sine" },
			...
		},
		eventos = {                 -- sincronizados con el tiempo t (en segundos desde el primer cuadro)
			{ t = 2, tipo = "osd", estado = "PAUSE" },
			...
		},
	}

	Cámara: entre dos puntos la posición y la mira pasan por una curva suave (Catmull-Rom) que cruza todos los puntos. `ease` de un
	punto es el easing de TweenService del tramo que TERMINA en él ("Linear" por defecto; "Sine", "Quad", "Cubic"... con
	dirección InOut). Para quedarse quieto, dos puntos seguidos iguales. `giro` = inclinación del horizonte en grados.
	Modo vertical (Config.Cinematicas.Vertical): la cámara se abre y retrocede un poco y el OSD queda en la franja central; en el
	punto se puede poner `sinAjuste = true` para que ese plano no se toque.
	Corte de plano: un punto con `corte = true` no se alcanza con una curva: la cámara se queda en el punto anterior hasta su t y ahí salta.

	Eventos (todos llevan t):
		{ tipo = "osd", estado = "PAUSE", fecha = "texto" | false, hora = {...}, contador = 0 }
		{ tipo = "luz", patron = { oscuro, luz, oscuro, ... } }   -- parpadeo fluorescente a medida (segundos por tramo)
		{ tipo = "luz", corte = true | false }                    -- corte de luz (como la noche 4)
		{ tipo = "socio", accion = "aparecer", pos = V(), rot = grados | mira = V(), encara = true, quieto = true, azar = false }
		{ tipo = "socio", accion = "quitar" }
		{ tipo = "socio", accion = "mover", pos = V(), dur = 5, tirones = { 0.25, 0.4 } }  -- avanza a sacudidas (dur 0 = de golpe)
		{ tipo = "socio", accion = "parar" } | { tipo = "socio", accion = "quieto", valor = true }  -- "observado": cabeza clavada, ladeada
		{ tipo = "linterna", on = true | false }                  -- la luz del jugador (sale de la cámara)
		{ tipo = "socio", accion = "gesto", gesto = "crujido", lado = 1 }
		{ tipo = "casete", accion = "aparecer", pos = V(), rot = V(90, 0, 0) }   -- el casete sin etiqueta (rot en grados)
		{ tipo = "casete", accion = "mover", pos = V(), rot = V(), dur = 1, estilo = "Quad" | "Bounce" ... }
		{ tipo = "casete", accion = "quitar" }
		{ tipo = "portada", id = "P_TERROR_1_3_7", titulo = "MIRAME" }   -- una portada con un título que no existe (P_GÉNERO_lado_fila_col)
		{ tipo = "sonido", id = "rbxassetid://...", volumen = 0.2, duracion = 3, apagado = true }
		{ tipo = "estatica", peligro = 0.8, dur = 0.6 }           -- ráfaga de estática del filtro VHS
		{ tipo = "negro", alfa = 1, dur = 0 }                     -- corte (dur 0) o fundido a negro / desde negro
]]

local Config = require(script.Parent.Config)

local V = Vector3.new

local Cinematicas = {}

-- ===== 1. Turno noche =====
-- Cámara lenta por el pasillo central de las góndolas (entre COMEDIA y DRAMA), la radio de fondo, OSD "NOV 16 1997 03:16".
-- Al fondo, entre los estantes, el Socio quieto. La luz parpadea y cuando vuelve ya no está. Corte a negro.
-- Las góndolas están en x = -14, -7, 0, 7, 14 (z de -6 a 3): el pasillo entre la de 0 y la de 7 está centrado en x = 3.5.
local PARPADEO_1 = { 0.07, 0.1, 0.06, 0.13, 0.12, 0.08, 1.0 } -- el último tramo (1,0 s) es a oscuras: ahí desaparece

local turnoNoche = {
	titulo = "Turno noche",
	duracion = 20,
	fov = 66,
	mano = 1,
	ambiente = 0.3, -- multiplica la luz ambiente: sombras más cerradas, el local se siente más solo
	osd = { estado = "PLAY", hora = { noche = 2, minuto = 316, escala = 1 / 60 }, contador = 0 },
	vhs = { intensidad = 1 },
	camara = {
		{ t = 0, pos = V(3.5, 4.4, 12), mira = V(3.5, 3.9, -8.5) },
		{ t = 6, pos = V(3.4, 4.3, 8.8), mira = V(3.5, 4.0, -8.5) },
		{ t = 12, pos = V(3.6, 4.2, 5.8), mira = V(3.5, 4.2, -9) },
		{ t = 19, pos = V(3.5, 4.1, 3.6), mira = V(3.5, 4.3, -9), ease = "Sine" },
	},
	eventos = {
		{ t = 0, tipo = "socio", accion = "aparecer", pos = V(3.5, 0, -8.5), mira = V(3.5, 0, 30), quieto = true },
		-- La luz se va 4 veces; en el último apagón (de 11.56 a 12.56 s) el Socio desaparece y cuando vuelve la luz ya no está.
		{ t = 11, tipo = "luz", patron = PARPADEO_1 },
		{ t = 11.8, tipo = "socio", accion = "quitar" },
		{ t = 18.6, tipo = "negro", alfa = 1, dur = 0 },
	},
}

-- ===== 2. La cinta de las 3:33 =====
-- El buzón (en la pared del frente, x = 6): el casete sin etiqueta entra por la ranura y cae sobre la caja de devoluciones, igual que
-- en el juego (Config.Casetes.Buzon*). Corte a la videocasetera del mostrador (x = -10.5, la ranura mira hacia -Z): el casete se
-- mete solo, el OSD pasa de PAUSE a "▶ PLAY", estática y corte a negro.
local sinEtiqueta = Config.Casetes
local ACOSTADO = V(90, 0, 0) -- el casete se mueve acostado, carátula hacia arriba (como en TapeItem.entregarPorBuzon)
local VCR_Z = 16 + Config.Local.MostradorAvance -- eje del mostrador; la ranura de la videocasetera está en VCR_Z - 0.92
local CLIC = Config.Sustos.Glitch.Id

local cinta333 = {
	titulo = "La cinta de las 3:33",
	duracion = 19,
	fov = 64,
	mano = 1,
	ambiente = 0.3,
	osd = { estado = "PAUSE", hora = { noche = 1, minuto = 333, escala = 1 / 60 }, contador = 0 },
	vhs = { intensidad = 1 },
	camara = {
		-- Plano A (0 a 7 s): el buzón desde adentro, empuje lento hacia la ranura.
		-- (El pilar de la estructura está en x 7.5, z 29.5: la cámara se queda del lado de adentro, antes de llegar a él.)
		{ t = 0, pos = V(5.3, 4.5, 29.6), mira = V(6, 3.3, 34) },
		{ t = 7, pos = V(5.6, 3.9, 31), mira = V(6, 3, 34), ease = "Sine" },
		-- Plano B (7 a 18 s): la videocasetera, desde el lado del empleado.
		{ t = 7, pos = V(-10.5, 4.3, 15.6), mira = V(-10.5, 3.9, VCR_Z), corte = true },
		{ t = 18, pos = V(-10.1, 4.15, 16.6), mira = V(-10.3, 3.95, VCR_Z - 0.4), ease = "Sine" },
	},
	eventos = {
		-- El casete entra por la ranura (afuera, atraviesa la pared) y cae sobre la caja de devoluciones.
		{ t = 3.2, tipo = "casete", accion = "aparecer", pos = sinEtiqueta.BuzonEntrada, rot = ACOSTADO },
		{ t = 3.3, tipo = "casete", accion = "mover", pos = sinEtiqueta.BuzonRanura, rot = ACOSTADO, dur = 1.1, estilo = "Quad" },
		{ t = 4.0, tipo = "sonido", id = CLIC, volumen = 0.3, velocidad = 0.7 },
		{ t = 4.4, tipo = "casete", accion = "mover", pos = sinEtiqueta.BuzonCaida, rot = ACOSTADO + V(0, 14, 0), dur = 1.0, estilo = "Bounce" },
		{ t = 5.0, tipo = "sonido", id = CLIC, volumen = 0.4, velocidad = 0.5 },
		-- Videocasetera: el casete está a medio meter y la máquina se lo traga.
		{ t = 7, tipo = "casete", accion = "aparecer", pos = V(-10.5, 3.97, VCR_Z - 1.0), rot = ACOSTADO },
		{ t = 8, tipo = "casete", accion = "mover", pos = V(-10.5, 3.97, VCR_Z + 0.5), rot = ACOSTADO, dur = 1.6, estilo = "Quad" },
		{ t = 8.2, tipo = "sonido", id = CLIC, volumen = 0.3, velocidad = 0.6 },
		{ t = 10.4, tipo = "casete", accion = "quitar" },
		-- Arranca: PAUSE -> PLAY con una ráfaga de estática, y la estática va creciendo hasta el corte.
		{ t = 10.5, tipo = "osd", estado = "PLAY", contador = 0 },
		{ t = 10.5, tipo = "estatica", peligro = 0.9, dur = 0.5 },
		{ t = 10.5, tipo = "sonido", id = Config.Sustos.Estatica.Id, volumen = 0.5, duracion = 2 },
		{ t = 13, tipo = "estatica", peligro = 0.55, dur = 3 },
		{ t = 16, tipo = "estatica", peligro = 1, dur = 2.2 },
		{ t = 16, tipo = "sonido", id = Config.Sustos.Estatica.Id, volumen = 1.2, duracion = 2.4 },
		{ t = 18.1, tipo = "negro", alfa = 1, dur = 0 },
	},
}

-- ===== 3. No mirés arriba =====
-- Plano del mostrador (lado de los clientes, el local en calma); la cámara sube despacio hasta el techo y ahí está el Trepador,
-- cabeza abajo (pies en el techo, mirando a la cámara). Gira la cabeza 180° (su gesto "giro") y corte.
local TECHO = Config.Anomalias.Reptar.Techo

local noMiresArriba = {
	titulo = "No mirés arriba",
	duracion = 15,
	fov = 64,
	mano = 1,
	ambiente = 0.3,
	osd = { estado = "PLAY", hora = { noche = 2, minuto = 228, escala = 1 / 60 }, contador = 0 },
	vhs = { intensidad = 1 },
	camara = {
		-- Empieza mirando hacia abajo, al mostrador (el techo queda fuera del cuadro), y sube de a poco.
		{ t = 0, pos = V(-8.5, 5.4, 22.5), mira = V(-10.2, 2.6, 19.4) },
		{ t = 4, pos = V(-8.5, 5.35, 22.2), mira = V(-10.1, 2.9, 19.2) },
		{ t = 12.5, pos = V(-8.5, 5, 18.5), mira = V(-8.7, 9, 11.5), ease = "Sine" },
		{ t = 15, pos = V(-8.5, 5, 18.1), mira = V(-8.7, 9.1, 11.5), ease = "Sine" },
	},
	eventos = {
		{ t = 0, tipo = "trepador", accion = "aparecer", pos = V(-8.5, TECHO, 11.5), adelante = V(0, 0, 1), azar = false },
		{ t = 8, tipo = "sonido", id = Config.Sustos.Tension.Id, volumen = 0.25, velocidad = 0.8, duracion = 7 },
		{ t = 12.9, tipo = "trepador", accion = "gesto", gesto = "giro", lado = 1, dur = 1.8 },
		{ t = 13.1, tipo = "sonido", id = CLIC, volumen = 0.5, velocidad = 0.6 },
		{ t = 14.2, tipo = "estatica", peligro = 1, dur = 0.4 },
		{ t = 14.35, tipo = "negro", alfa = 1, dur = 0 },
	},
}

-- ===== 4. Mirá bien =====
-- Local vacío y en calma. Una portada de la góndola de TERROR (lado +x, fila 3, columna 7: x -6.15, y 4.05, z 1.5) dice "MIRAME":
-- un título que no existe, desde el primer cuadro. La cámara se desliza por el pasillo (entre TERROR y COMEDIA, x -3.5) y llega
-- a ella hacia el segundo 3 a 4 (para "¿viste lo que hay en el segundo 3?"); sigue de largo, vuelve y se queda quieta encima
-- 2 segundos de más, sin que pase nada. Corte.
local PORTADA = V(-6.15, 4.05, 1.5)

local mirarBien = {
	titulo = "Mirá bien",
	duracion = 16,
	fov = 62,
	mano = 0.8,
	ambiente = 0.35,
	osd = { estado = "PLAY", hora = { noche = 2, minuto = 262, escala = 1 / 60 }, contador = 0 },
	vhs = { intensidad = 1 },
	camara = {
		{ t = 0, pos = V(-3.5, 4.3, 10), mira = V(-6, 3.8, -3) },
		{ t = 4, pos = V(-3.5, 4.2, 4.6), mira = V(-6.1, 3.9, 0.5) },
		{ t = 8, pos = V(-3.5, 4.1, 0.2), mira = V(-6.1, 4, 1.5), ease = "Sine" },
		-- Se frena de cara a la portada y se queda quieta (con apenas el temblor de la mano).
		{ t = 10.5, pos = V(-3.7, 4.05, 1.5), mira = PORTADA, ease = "Sine" },
		{ t = 15.5, pos = V(-3.78, 4.05, 1.5), mira = PORTADA },
	},
	eventos = {
		{ t = 0, tipo = "portada", id = "P_TERROR_1_3_7", titulo = "MIRAME" },
		{ t = 10.5, tipo = "sonido", id = Config.Sustos.Tension.Id, volumen = 0.2, velocidad = 0.8, duracion = 5 },
		{ t = 15.3, tipo = "estatica", peligro = 1, dur = 0.3 },
		{ t = 15.5, tipo = "negro", alfa = 1, dur = 0 },
	},
}

-- ===== 5. Socio N° 0000 =====
-- A oscuras (noche 4): del fondo del pasillo central (x -3.5) solo se ven sus ojos blancos. Avanza a tirones. Se prende la linterna: lo
-- alumbra y se frena, ladea la cabeza (su pose de "observado" del juego). Se corta la luz un instante y reaparece más cerca; vuelve a
-- avanzar a sacudidas y, a menos de Config.Socio.BocaDistancia (7 studs) de la cámara, la cara se parte y se abre: corte en ese momento,
-- sin mostrar el screamer completo. La cámara no se mueve del lugar (z 8.5): el Socio llega hasta ella.
local SOCIO_X = -3.5
local OSCURO = 17 -- segundos a oscuras (tubos y ambiente), hasta el final del clip

local socio0000 = {
	titulo = "Socio N° 0000",
	duracion = 16,
	fov = 64,
	mano = 1.2,
	osd = { estado = "PLAY", hora = { noche = 4, minuto = 290, escala = 1 / 60 }, contador = 0 },
	vhs = { intensidad = 1 },
	camara = {
		{ t = 0, pos = V(SOCIO_X, 4.5, 9), mira = V(SOCIO_X, 4.2, -8) },
		{ t = 12.5, pos = V(SOCIO_X, 4.4, 8.5), mira = V(SOCIO_X, 4.3, -6), ease = "Sine" },
		-- Al final levanta la vista (la cara del Socio está a 7 studs de altura): la boca se abre dentro del cuadro.
		{ t = 15.5, pos = V(SOCIO_X, 4.4, 8.3), mira = V(SOCIO_X, 7, 1.5), ease = "Sine" },
	},
	eventos = {
		{ t = 0, tipo = "luz", patron = { OSCURO } },
		{ t = 0, tipo = "socio", accion = "aparecer", pos = V(SOCIO_X, 0.02, -11), encara = true, azar = false },
		-- 1) A oscuras: solo los ojos. Avanza a tirones.
		{ t = 3, tipo = "socio", accion = "mover", pos = V(SOCIO_X, 0.02, -5.5), dur = 5.4, tirones = { 0.25, 0.45 } },
		-- 2) Linterna: lo alumbra, se frena y ladea la cabeza.
		{ t = 8.6, tipo = "linterna", on = true },
		{ t = 8.6, tipo = "sonido", id = CLIC, volumen = 0.3 },
		{ t = 8.6, tipo = "socio", accion = "parar" },
		{ t = 8.6, tipo = "socio", accion = "quieto", valor = true },
		{ t = 8.8, tipo = "sonido", id = Config.Sustos.Tension.Id, volumen = 0.3, velocidad = 0.8, duracion = 7 },
		-- 3) La linterna titila: en el apagón se acerca.
		{ t = 11.1, tipo = "linterna", on = false },
		{ t = 11.2, tipo = "socio", accion = "mover", pos = V(SOCIO_X, 0.02, -2.4), dur = 0 },
		{ t = 11.55, tipo = "linterna", on = true },
		{ t = 11.55, tipo = "sonido", id = CLIC, volumen = 0.3, velocidad = 0.8 },
		-- 4) Vuelve a avanzar a sacudidas hasta la cámara: a menos de 7 studs la cara se abre.
		{ t = 12.8, tipo = "socio", accion = "quieto", valor = false },
		{ t = 12.8, tipo = "socio", accion = "mover", pos = V(SOCIO_X, 0.02, 2.3), dur = 3, tirones = { 0.22, 0.3 } },
		{ t = 15.25, tipo = "estatica", peligro = 1, dur = 0.4 },
		{ t = 15.25, tipo = "sonido", id = Config.Screamer.Sonidos[1].Id, volumen = 0.8, duracion = 0.35 },
		{ t = 15.5, tipo = "negro", alfa = 1, dur = 0 },
	},
}

Cinematicas.Clips = {
	turno_noche = turnoNoche,
	cinta_333 = cinta333,
	no_mires_arriba = noMiresArriba,
	mira_bien = mirarBien,
	socio_0000 = socio0000,
}

-- Orden en que se listan (node dbg.js cine lista).
Cinematicas.orden = { "turno_noche", "cinta_333", "no_mires_arriba", "mira_bien", "socio_0000" }

return Cinematicas
