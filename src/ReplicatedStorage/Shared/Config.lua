--!strict
--[[
	Config: único lugar para tiempos, distancias e intensidades del juego.
	El resto del código no debe tener "números mágicos": todo se lee de acá.
]]

local Config = {}

Config.Juego = {
	Nombre = "Star Videoclub",
	Version = "Alpha 0.1",
	NochesTotales = 5,
	JugadoresMax = 4,
}

-- El reloj del juego se cuenta en minutos desde el inicio del turno (22:00).
Config.Noche = {
	InicioHora = 22, -- hora de reloj en la que arranca el turno
	DuracionMinutosJuego = 360, -- 22:00 -> 04:00
	DuracionRealSegundos = 600, -- 10 minutos reales por noche (rango de diseño: 8 a 12)
	MinutoEventoCinta = 333, -- 03:33: llega la cinta sin etiqueta
	Fecha = { Dia = 14, Mes = "NOV", Anio = 1997 }, -- fecha de la noche 1; cada noche suma un día
	NocheInicial = 1,
	NochesImplementadas = 5, -- al terminar la última noche sin llegar a un final, el turno se repite
	RetardoInicioSeg = 1, -- espera desde que se elige jugar hasta que arranca el turno (la pantalla sigue negra: ver MenuUI)
	PausaFinSeg = 14, -- pantalla de resumen entre un turno y el siguiente
	IntervaloSincronizacionSeg = 1,
}

-- Casetes (TapeItem): tamaño, cómo se llevan y por dónde entran al local.
-- Susto suave de la noche 1 (Client/Sustos): un gancho para que los primeros minutos no sean todos tranquilos.
Config.Sustos = {
	DuracionSeg = 1.8, -- cuánto dura la oscuridad con la criatura
	DistanciaCriatura = 16, -- a cuántos studs adelante aparece (si hay pared antes, más cerca)
	DistanciaMinima = 6, -- si no hay lugar libre, el susto sigue sin criatura
	PeligroTracking = 0.85, -- cuánto se deforma el filtro VHS mientras dura
	-- Audio analógico, sin gritos: el ambiente se va como una cinta que se frena, queda casi silencio con un
	-- zumbido grave apagado y estática de fondo, y al volver hay un chasquido de cinta.
	FrenadoSeg = 0.5, -- lo que tarda el ambiente en frenarse y apagarse
	ReanudarSeg = 1.1, -- lo que tarda en volver cuando se prende la luz
	Glitch = { Id = "rbxassetid://109276224186592", Volumen = 0.14 }, -- chasquido de cinta (0,3 s)
	Estatica = { Id = "rbxassetid://96891705634188", Volumen = 0.1 }, -- estática de TV, de fondo
	Tension = { Id = "rbxassetid://9114353038", Volumen = 0.2, Velocidad = 0.8 }, -- zumbido grave que crece
}

-- La entidad que se ve a lo lejos, al costado del motel (Client/Calle): casi invisible en la oscuridad; solo se le
-- ven los ojos brillantes, y únicamente si el jugador se acerca a la ventana. Es solo para dar miedo, no hace nada.
Config.EntidadLejana = {
	Posiciones = { Vector3.new(-66, 0, 104), Vector3.new(68, 0, 106), Vector3.new(-72, 0, 90), Vector3.new(74, 0, 92) },
	IntervaloMin = 35, -- cada cuántos segundos aparece (al azar entre los dos)
	IntervaloMax = 80,
	VisibleSegMin = 6, -- cuánto tiempo se queda
	VisibleSegMax = 12,
	DistanciaVentana = 7, -- los ojos se ven cuando la cámara está a esta distancia (en z) de la ventana
	TamanoOjo = Vector3.new(1.5, 0.75, 0.4), -- grandes: a ~90 studs de distancia tienen que verse como dos puntos
}

-- Sonidos de feedback (pequeñas recompensas): al completar una tarea suena un "ding" de caja registradora.
Config.Feedback = {
	DingId = "rbxassetid://18264787819",
	DingVolumen = 0.35,
}

-- La calle de afuera (Calle): autos que pasan y neones del motel. Solo decorado.
Config.Calle = {
	CarrilZ = { 40.5, 48 }, -- z de cada carril: el primero va hacia +X, el segundo hacia -X
	LargoRuta = 220, -- los autos aparecen y desaparecen fuera de la vista
	IntervaloMin = 18,
	IntervaloMax = 40,
	MaxAutos = 2,
	VelocidadMin = 24,
	VelocidadMax = 40,
	Volumen = 0.5,
	Sonidos = { "rbxassetid://120099233898356" }, -- auto pasando, 9 s (Creator Store)
	Colores = {
		Color3.fromRGB(150, 30, 30), Color3.fromRGB(30, 50, 100), Color3.fromRGB(190, 190, 180),
		Color3.fromRGB(40, 70, 50), Color3.fromRGB(200, 170, 60), Color3.fromRGB(30, 30, 34),
	},
}

-- Menú de inicio y sala de espera (Partida / MenuUI).
Config.Partida = {
	MenuActivo = true, -- false: el turno arranca solo al entrar el primer jugador (útil para pruebas)
	MaxJugadores = 4,
}

-- Salas de multijugador entre servidores (Salas.lua). Cada sala es un servidor reservado; se anotan en un MemoryStore.
Config.Salas = {
	ForzarLocal = false, -- true: la sala es el propio servidor aunque no sea Studio (pruebas)
	SimularNube = false, -- true (solo para probar en Studio): el servidor actúa como servidor de entrada con un MemoryStore y un teletransporte simulados
	LargoCodigo = 5,
	Mapa = "SalasVideoclub",
	VencimientoSeg = 45, -- una sala de espera que nadie renueva desaparece a los 45 s
	LatidoSeg = 15, -- cada cuánto se renueva el registro de una sala mientras alguien la mira
	SondeoSeg = 1, -- cada cuánto un servidor de entrada lee el registro de las salas en las que tiene jugadores
	CierreSalaSeg = 25, -- tras iniciar, el registro se borra a los 25 s (tiempo para que todos los servidores vean el cambio)
	EsperaEquipoSeg = 20, -- el servidor de juego espera tanto al equipo completo antes de empezar igual
	MaxListadas = 40,
	RefrescoListaSeg = 4, -- la lista de salas del cliente se actualiza cada tanto
}

Config.Casetes = {
	Tamano = Vector3.new(1, 1.45, 0.3), -- la cara frontal (-Z) es la carátula
	DistanciaPrompt = 6,
	-- En la mano: abajo a la derecha de la vista, con la carátula hacia el jugador (relativo a HumanoidRootPart).
	OffsetEnMano = CFrame.new(0.75, 0.95, -1.7) * CFrame.Angles(math.rad(-12), math.rad(180), math.rad(6)),
	-- Donde queda la cinta que devuelve un cliente: 3.6 studs a un costado del punto de atención
	-- (x -4.2), para que su botón "Tomar" no se superponga con "Atender" / "Rechazar cliente".
	PosicionMostrador = Vector3.new(-7.8, 3.95, 16.2),
	VidaMostradorSeg = 45, -- una cinta que nadie levanta del mostrador se retira sola pasado este tiempo
	BuzonEntrada = Vector3.new(6, 3.5, 27.9), -- afuera de la ranura
	BuzonRanura = Vector3.new(6, 3.5, 25.9), -- atravesando la ranura
	BuzonCaida = Vector3.new(6, 2.75, 25.1), -- sobre la caja de devoluciones
	BuzonAnimSeg = 0.5,
	ColorCarcasa = Color3.fromRGB(28, 28, 32), -- carcasa de todos los VHS (el género va en la franja de la carátula)
	ColorSinEtiqueta = Color3.fromRGB(14, 14, 16),
	MostrarDanoEnEtiqueta = true, -- en la noche 1 la cinta dañada se nota; después se puede volver sutil
}

Config.Tareas = {
	RebobinadoSeg = 2.5, -- tiempo que hay que mantener apretado en la videocasetera
	LimpiezaSeg = 3, -- tiempo que hay que mantener apretado para limpiar una mancha
	BolsaEnMano = CFrame.new(0.55, -0.5, -1.6), -- bolsa de basura en las manos (relativo a HumanoidRootPart)
	DistanciaPrompt = 8,
	SincronizacionSeg = 2, -- reenvío periódico del estado a los clientes (por si alguno entró tarde)
}

-- Escoba (ChoreSystem / Escoba.lua): está apoyada contra la pared del baño; hace falta llevarla para limpiar una mancha.
-- (El nombre Cepillo y el tag CepilloColgado se conservan por compatibilidad con el mundo.)
Config.Cepillo = {
	LargoPalo = 4.3, -- studs; con el cabezal y las cerdas mide unos 5,5 (una escoba de tamaño normal)
	-- Relativo a HumanoidRootPart: el palo sale en diagonal hacia adelante y las cerdas casi tocan el piso, delante del jugador.
	EnMano = CFrame.new(0.85, -0.9, -2.3) * CFrame.Angles(math.rad(62), 0, math.rad(-6)),
	-- Apoyada en el baño: inclinación hacia la pared y distancia al fondo.
	InclinacionGrados = 7,
	PisoY = 0.1,
	DistanciaPrompt = 6,
}

-- Modo "Sin fin" (NightData.sinFin / NightManager): noches que se encadenan sin final hasta que el equipo entero cae.
-- Se desbloquea al llegar a cualquiera de los finales del modo Historia.
Config.SinFin = {
	NocheTopeDificultad = 12, -- a partir de esta noche la dificultad deja de crecer (lo que sigue es resistir)
	ProgresoSocioPorNoche = 0.05, -- cuánto más rápido arranca el Socio cada noche después de la 5
	PausaReinicioSeg = 14, -- pantalla de "te grabaron" antes de que el turno sin fin vuelva a empezar en la noche 1
}

-- Clientes NPC. Las posiciones tienen y = 3 (altura del HumanoidRootPart).
Config.Clientes = {
	PacienciaSeg = 90, -- tiempo que espera en el mostrador antes de irse
	VelocidadCaminar = 9,
	MaxEnCola = 4,
	TimeoutCaminarSeg = 12, -- si se traba, se lo teletransporta al destino
	Entrada = Vector3.new(0, 3, 31),
	AfueraPuerta = Vector3.new(0, 3, 28.8),
	AdentroPuerta = Vector3.new(0, 3, 24.2),
	ColaBase = Vector3.new(-4.2, 3, 19.4),
	ColaPaso = 1.7,
	PuertaAbiertaTransparencia = 1,
	PaletaRopa = {
		Color3.fromRGB(110, 40, 40), Color3.fromRGB(40, 70, 110), Color3.fromRGB(70, 90, 60),
		Color3.fromRGB(120, 110, 70), Color3.fromRGB(80, 60, 100), Color3.fromRGB(60, 60, 64),
	},
	PaletaPantalon = { Color3.fromRGB(40, 48, 70), Color3.fromRGB(60, 52, 44), Color3.fromRGB(30, 30, 34) },
	PaletaPiel = { Color3.fromRGB(224, 172, 140), Color3.fromRGB(190, 140, 110), Color3.fromRGB(150, 104, 80) },
	PaletaPelo = {
		Color3.fromRGB(34, 26, 22), Color3.fromRGB(80, 54, 34), Color3.fromRGB(150, 110, 56),
		Color3.fromRGB(150, 150, 146), Color3.fromRGB(20, 20, 22),
	},
	EstilosPelo = { "corto", "corto", "largo", "gorra" },
	EscalaMin = 0.92,
	EscalaMax = 1.08,
}

-- Interfaz diegética.
Config.Ficha = {
	Ancho = 0.27, -- fracción de la pantalla
	TamanoRelativo = 0.024,
	ColorFondo = Color3.fromRGB(184, 148, 98),
	ColorBorde = Color3.fromRGB(110, 80, 46),
	ColorTexto = Color3.fromRGB(66, 46, 28),
	ColorTitulo = Color3.fromRGB(140, 30, 30),
	Inclinacion = -1.5, -- grados
	MaxTareas = 8,
}

Config.Dialogos = {
	CaracteresPorSeg = 45,
	DuracionExtraSeg = 2.5,
	AvisoSeg = 3.5,
	MaxAvisos = 3,
	IntroSeg = 5, -- cartel "NOCHE n" al empezar el turno
	FundidoSeg = 1.2,
}

Config.Jugador = {
	PrimeraPersona = true,
	CamaraFOV = 70,
	VelocidadCaminar = 12,
	AlturaSalto = 3.5,
}

-- Filtro VHS. La intensidad base es 1; la cinta la sube (VHSEffects.setIntensidad).
Config.VHS = {
	Calidad = "Auto", -- "Auto" | "Alta" | "Media" | "Baja" (Auto baja a Media en móviles)
	Perfiles = {
		Alta = { Lineas = 120, RuidoMarcas = 70, RuidoHz = 24 },
		Media = { Lineas = 70, RuidoMarcas = 30, RuidoHz = 14 },
		Baja = { Lineas = 40, RuidoMarcas = 12, RuidoHz = 8 },
	},
	Color = {
		Saturacion = -0.35,
		Contraste = 0.12,
		Brillo = 0.02,
		Tinte = Color3.fromRGB(214, 240, 232),
	},
	Bloom = { Intensidad = 0.35, Tamano = 24, Umbral = 0.9 },
	Desenfoque = 1.5,
	NegrosLevantados = { Color = Color3.fromRGB(34, 40, 42), Transparencia = 0.9 },
	Scanlines = { Transparencia = 0.94, Grosor = 0.0035 }, -- grosor como fracción de la altura de pantalla
	-- La estática es casi invisible en calma; sube con el peligro y cuando hay una anomalía a la vista.
	Ruido = { TransparenciaMin = 0.94, TransparenciaMax = 0.99, AumentoPorPeligro = 0.4 },
	AnomaliaPeso = 0.65, -- cuánto peligro "equivale" a tener una anomalía enfrente (0..1)
	Tracking = {
		AlturaMin = 0.012,
		AlturaMax = 0.10,
		VelocidadMin = 0.08,
		VelocidadMax = 0.55,
		TransparenciaMin = 0.965, -- banda casi invisible sin peligro
		TransparenciaMax = 0.72, -- banda bien marcada con peligro máximo
		RafagaTransparenciaMin = 0.9, -- ráfagas de interferencia: sin peligro / con peligro máximo
		RafagaTransparenciaMax = 0.6,
		Rafagas = 6,
		UmbralRafagas = 0.12, -- peligro a partir del cual la banda se "rompe"
	},
	Aberracion = { Ancho = 0.05, Transparencia = 0.82 },
	Vineta = { Ancho = 0.11, Transparencia = 0.55 },
	SuavizadoPeligro = 4, -- cuánto sigue el filtro al peligro real (1/segundo)
}

-- Interfaz estilo videocasetera (OSD).
Config.OSD = {
	Fuente = Enum.Font.Code,
	TamanoRelativo = 0.034, -- fracción de la altura de pantalla
	Color = Color3.fromRGB(236, 236, 226),
	ContornoGrosor = 2,
	MargenLateral = 0.035,
	MargenSuperior = 0.035,
	MargenInferior = 0.035,
	SeparacionLineas = 0.06, -- altura de una línea de texto (fracción de la pantalla)
	ParpadeoSeg = 0.6,
	IntervaloActualizacion = 0.1,
}

-- Tubos fluorescentes (parpadeo del lado del cliente).
Config.Luces = {
	ColorApagado = Color3.fromRGB(70, 75, 70),
	SocioApagonRadio = 12, -- los tubos a esta distancia del Socio se apagan
	SocioParpadeoRadio = 26, -- y hasta acá parpadean (más cuanto más cerca)
	Normal = { IntervaloMin = 25, IntervaloMax = 70, RafagaMin = 1, RafagaMax = 3 },
	Defectuoso = { IntervaloMin = 2, IntervaloMax = 6, RafagaMin = 3, RafagaMax = 8 },
	ParpadeoMin = 0.03,
	ParpadeoMax = 0.12,
}

-- Capas de audio ambiente. Id vacío = capa deshabilitada.
Config.Audio = {
	-- Grupo "Ambiente" (zumbidos y ondas) o "Musica": cada uno tiene su volumen en el menú de ajustes.
	Capas = {
		Zumbido = { Id = "rbxassetid://9112823813", Volumen = 0.22, Loop = true, Grupo = "Ambiente" }, -- tubo fluorescente
		Hiss = { Id = "rbxassetid://104015211368023", Volumen = 0.06, Loop = true, Grupo = "Ambiente" }, -- cinta
		Presencia = { Id = "rbxassetid://9112775175", Volumen = 0.14, Loop = true, Grupo = "Ambiente" }, -- aire pesado
		Beta = { Id = "rbxassetid://70986673915317", Volumen = 0.16, Loop = true, Grupo = "Ambiente" }, -- ondas beta: estado de alerta
		Radio = { Id = "rbxassetid://75201584395115", Volumen = 0.2, Loop = true, Grupo = "Musica" }, -- música de fondo
		-- La canción exclusiva de cuando aparece el Socio: reemplaza a la radio mientras está en el local. Por ahora es la
		-- misma canción con efectos fuertes (MusicaSocio abajo); para usar una pista propia basta con cambiar este Id.
		RadioSocio = { Id = "rbxassetid://75201584395115", Volumen = 0, Loop = true, Grupo = "Musica" },
	},
	FundidoSeg = 0.15,
	-- La pista RadioSocio: más grave, lenta, distorsionada y con eco, con un temblor de velocidad. Suena aunque la radio esté apagada.
	MusicaSocio = { Velocidad = 0.72, Distorsion = 0.85, Octava = 0.8, Volumen = 0.3, EntraSeg = 0.6, SaleSeg = 2.5 },
	PeligroParaCortar = 0.7, -- con tanto peligro se corta el zumbido
	CorteSeg = 3,
	EntreCortesSeg = 12,
}

-- El Socio N° 0000 (SocioEntity). Solo se mueve cuando ningún jugador lo está mirando.
Config.Socio = {
	Color = Color3.fromRGB(10, 10, 12),
	Escala = 1.45, -- mucho más alto que un cliente
	Ancho = 0.78, -- y más flaco
	Cabeza = 0.9,
	Proporcion = 1, -- brazos y piernas largos
	ColorOjos = Color3.fromRGB(235, 240, 225),
	-- Cuerpo generado con IA en Studio (criatura encorvada con capucha, mira hacia -Z). Si no carga se usa el cuerpo humano.
	MeshId = "rbxassetid://139106538467255",
	TextureId = "rbxassetid://138757344705907",
	AlturaMalla = 8.2, -- altura en studs
	Tinte = Color3.fromRGB(58, 60, 66), -- oscurece la textura
	PasoSeg = 0.3, -- avanza a tirones: cada tanto da un paso corto de golpe
	VelocidadBase = 3.2, -- studs/seg con progreso 0
	VelocidadPorProgreso = 7.4, -- se suma con progreso 1 (los jugadores corren a 12: no los alcanza si no se frenan)
	PersecucionSeg = 30, -- cada aparición dura 30 s: después se va
	EntreApariciones = { 55, 90 }, -- una vez que la noche lo activó, vuelve a aparecer pasado este rango (s) desde que se fue
	DistanciaCaptura = 3.4,
	DistanciaPeligro = 45, -- a esta distancia el peligro empieza a subir
	AnguloVision = 58, -- grados: mitad del cono de visión de cada jugador
	LookReportHz = 5, -- frecuencia con la que el cliente informa hacia dónde mira
	LookVencimientoSeg = 0.8, -- un reporte más viejo que esto no cuenta como "mirando"
	LookToleranciaCamara = 10, -- la cámara informada debe estar cerca de la cabeza del personaje
	TickSeg = 0.1,
	RecalcularRutaSeg = 1.5,
	PeligroEnvioSeg = 0.2,
	CapturasPorJugador = 2, -- a la segunda captura el jugador queda fuera de la noche (pasa a ser espectador); si caen todos, la noche fracasa
	AturdimientoSeg = 3.5,
	GraciaAparicionSeg = 8, -- al aparecer, no puede capturar durante este tiempo (da lugar a reaccionar)
	GraciaCintaSeg = 90, -- desde que llega la cinta sin etiqueta no puede capturar: tiempo para agarrarla y verla con calma
	ProgresoMax = 1.5,
	-- Progreso (0 a ProgresoMax): sube la velocidad del Socio. Se reinicia cada noche con PorNoche[noche].
	PorNoche = { 0.05, 0.15, 0.3, 0.45, 0.6 },
	PorCinta = 0.12,
	PorContaminacion = 0.06,
	PorRegla = 0.12,
	PorSocioAtendido = 0.3, -- atender al Socio disfrazado de cliente
	PorSocioRechazado = -0.1,
	PorAnomaliaNoDetectada = 0.03,
	PorAnomaliaDetectada = -0.04,
	PorCaptura = -0.12,
	DistanciaAparicion = 14, -- "presentarse" en un pasillo: a cuántos studs del fondo aparece
	AlturaModelo = 7,
}

-- Los bordes de la pantalla (Client/Cordura): se oscurecen y enrojecen con el progreso del Socio, sin mostrar ningún número.
Config.Cordura = {
	Desde = 0.08, -- presión (progreso / ProgresoMax) a partir de la cual empieza a notarse
	OpacidadMax = 0.6, -- cuán cerrado queda el borde con la presión máxima
	AnchoMin = 0.1, -- ancho del borde (fracción de la pantalla) al empezar a notarse
	AnchoMax = 0.3, -- y con la presión máxima
	ColorBase = Color3.fromRGB(4, 2, 2),
	ColorRojo = Color3.fromRGB(70, 4, 6),
	RespiraMin = 0.45, -- respiraciones por segundo al empezar
	RespiraMax = 1.3, -- y con la presión máxima
	RespiraAmplitud = 0.22,
	Suavizado = 1.2, -- qué tan rápido sigue los cambios de presión
}

-- Temblor de la cámara cuando el Socio se acerca (Client/Temblor): crece con el peligro (0..1) que manda el servidor.
Config.Temblor = {
	Desde = 0.12, -- peligro a partir del cual empieza a temblar
	AmplitudMaxGrados = 2.6, -- sacudida máxima de la cámara (grados) con el Socio encima
	GiroRelativo = 0.6, -- cuánto del temblor es inclinación lateral
	FrecuenciaMin = 5, -- velocidad del ruido al empezar
	FrecuenciaMax = 17, -- y con el Socio encima
	LatidoMin = 70, -- latidos por minuto al empezar
	LatidoMax = 165, -- y con el Socio encima
	LatidoGrados = 1.2, -- cuánto empuja la cámara cada latido
	Suavizado = 3, -- qué tan rápido sigue los cambios de peligro
	SobresaltoSeg = 1.4, -- la sacudida brusca cuando el Socio aparece dura esto
	SobresaltoFuerza = 0.7, -- y vale como este tanto de peligro
}

-- Jugador fuera de la noche (Fantasmas): él pasa a ser espectador (ve el local distorsionado, sin el monstruo) y una
-- estatua traslúcida de su personaje queda quieta en el estacionamiento del motel de enfrente, mirando al local.
Config.Fantasma = {
	EstacionamientoOculto = Vector3.new(0, -120, 0), -- donde se guarda el cuerpo real del espectador (invisible y quieto)
	Translucidez = 0.55, -- transparencia de la skin
	PisoY = -0.35, -- altura del asfalto del estacionamiento
	Plazas = { -- una por jugador, delante de las puertas del motel (frente en z = 105)
		Vector3.new(-4.5, 0, 101),
		Vector3.new(4.5, 0, 101),
		Vector3.new(-13.5, 0, 101),
		Vector3.new(13.5, 0, 101),
	},
	ColorLuz = Color3.fromRGB(190, 220, 255),
	BrilloLuz = 0.8,
	AlcanceLuz = 14,
	RellenoContorno = 0.78,
	BordeContorno = 0.45,
}

-- Espectador: lo que ve un jugador que quedó fuera de la noche.
Config.Espectador = {
	Distancia = 7, -- la cámara va detrás del compañero que mira
	Altura = 3,
	Saturacion = -0.85,
	Contraste = 0.25,
	Tinte = Color3.fromRGB(150, 175, 255),
	Desenfoque = 3,
	Peligro = 0.55, -- nivel fijo del filtro VHS (estática y tracking) mientras se es espectador
	OndaGrados = 2.2, -- el mundo se bambolea apenas
}

-- Compras con Robux (Tienda.lua). Los ids son de los "Developer Products" de la experiencia (Centro de creación > Monetización).
-- Con 0 el producto no está creado: en Studio la compra se simula sin gastar nada y en el juego publicado no está disponible.
Config.Tienda = {
	Productos = { Asustar = 3726792104, Revivir = 3726792548 },
	Precios = { Asustar = 10, Revivir = 15 }, -- solo para mostrarlos en los botones (el precio real es el del producto)
	EnfriamientoAsustarSeg = 45, -- entre un "asustar a todos" y otro (para todo el servidor)
	-- La máscara de Ghostface del depósito (Tienda.lua): mantener E sobre ella abre la compra de "Asustar a todos".
	Mascara = { MantenerSeg = 1.2, Distancia = 8 },
}

-- Insignias (Insignias.lua / Catalogo.Insignias): ids de las insignias de la experiencia (Centro de creación > Insignias).
-- Con 0 la insignia no está creada en Roblox: igual se avisa en pantalla y queda anotada en el perfil, pero no se otorga
-- la de Roblox.
Config.Insignias = {
	Ids = {
		PRIMER_TURNO = 1447396606648832,
		NOCHE_5 = 0, -- pendiente: Roblox deja crear 5 insignias gratis cada 24 h (las demás cuestan 100 Robux)
		FINAL_REBOBINAR = 3629946071895543,
		FINAL_DEVOLVER = 4284849697446367,
		FINAL_MIRAR = 9166582595813,
		TODOS_LOS_FINALES = 2598464511858468,
		SIN_FIN_5 = 0,
		SIN_FIN_10 = 0,
		NOCHE_3 = 0, -- pendiente: crear la insignia en Roblox y pegar acá el id
		RECHAZAR_SOCIO = 0,
		EN_EQUIPO = 0,
		SIN_FIN_20 = 0,
	},
}

-- Idioma (Idioma.lua): por defecto sigue el de Roblox del jugador (español si empieza con "es", inglés en cualquier otro).
-- Forzar = "en" o "es" fuerza uno (para pruebas).
Config.Idioma = {
	Forzar = nil,
}

-- Radio del local (Radio.lua / AudioManager): solo prende o apaga la música de fondo de siempre (la capa "Radio" de
-- Config.Audio, que es la distorsionada). Estación 0 = apagada.
Config.Radio = {
	Inicial = 1,
	Volumen = 0.2,
	Estaciones = {
		{ Nombre = "Radio", Id = "rbxassetid://75201584395115" },
	},
}

-- Screamers (Screamers.lua / Client/Screamers): sustos fuertes con la cara de la criatura a pantalla completa.
Config.Screamer = {
	Sonidos = { "rbxassetid://130285917830946", "rbxassetid://93093877629089", "rbxassetid://118385772421763" },
	Volumen = 1.2,
	DuracionSeg = 1.5,
	EntreAutomaticosSeg = 120, -- tiempo mínimo entre screamers automáticos
}

-- La cinta sin etiqueta (CursedTapeSystem).
Config.Cinta = {
	DuracionSeg = 40,
	DuracionFinalSeg = 90, -- en la noche 5 la cinta dura más: verla entera es el final "Mirar"
	Camara = CFrame.lookAt(Vector3.new(-21, 10.8, 24.5), Vector3.new(2, 2, -6)), -- desde arriba de las estanterías
	FOV = 78,
	Intensidad = 2.2, -- intensidad del filtro VHS mientras se ve
	PeligroBase = 0.3,
	RetardoPrediccionSeg = 75, -- cuánto tarda en cumplirse lo que muestra la cinta
	MovimientoAmplitud = 0.35, -- el "temblor" de la cámara fija
	MovimientoVelocidad = 0.5,
	HistorialSeg = 20, -- noche 2: los fantasmas repiten lo que hicieron hace tanto tiempo
	HistorialHz = 2,
	AdelantoSeg = 6, -- noche 5: la cinta va unos segundos adelantada
}

-- Anomalías por jugador (AnomalySystem). La cantidad por noche está en PorNoche.
Config.Anomalias = {
	PorNoche = { 0, 5, 6, 7, 8 }, -- más anomalías: menos tiempos muertos (en el modo Sin fin, desde la noche 6 se repite la última cantidad)
	MinutoDesde = 22,
	MinutoHasta = 290,
	DistanciaReporte = 35,
	EstaticaDistancia = 28, -- una anomalía a esta distancia (y de frente) sube la estática del filtro
	VidaFiguraSeg = 25,
	MirarParaDesaparecerSeg = 4, -- da tiempo a apuntarle y apretar Q antes de que se esfume
	OffsetMovido = 1.4,
	RotacionMovida = 28, -- grados
	LimiteFalsosReportes = 4, -- por noche; pasado esto el jugador pierde progreso del equipo
	-- La sombra quieta de la anomalía "FiguraAlFondo": una persona normal, negra, con contorno de estática (Client/Silueta).
	Figura = {
		Color = Color3.fromRGB(5, 5, 7),
		ColorContorno = Color3.fromRGB(175, 205, 255),
		Escala = 1.12,
		Ancho = 0.95,
		Transparencia = 0.12,
	},
}

Config.Telefono = {
	SonarSeg = 18, -- cuánto suena antes de cortarse solo
	MensajeSeg = 9, -- duración en pantalla de cada mensaje
	LecturaExtraSeg = 1, -- segundos que se suman a cada línea del mensaje para poder leerla completa
	Sonido = { Id = "rbxassetid://94426589952590", Volumen = 0.9, DistanciaMax = 70 }, -- timbre del teléfono (Creator Store)
}

Config.Final = {
	GrabarEncimaSeg = 6, -- mantener apretado en la videocasetera con la cinta en la mano
	PausaFinalSeg = 30, -- tiempo que dura la pantalla del final antes de reiniciar
}

Config.Debug = {
	LogSistemas = true,
	Comandos = true, -- crea ServerStorage.Depurar (BindableFunction) para probar desde la consola de Studio
}

return Config
