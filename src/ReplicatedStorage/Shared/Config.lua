--!strict
--[[
	Config: único lugar para tiempos, distancias e intensidades del juego.
	El resto del código no debe tener "números mágicos": todo se lee de acá.
]]

local Config = {}

Config.Juego = {
	Nombre = "Videoclub Estrella",
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
	RetardoInicioSeg = 5, -- espera desde que entra el primer jugador hasta que arranca el turno
	PausaFinSeg = 14, -- pantalla de resumen entre un turno y el siguiente
	IntervaloSincronizacionSeg = 1,
}

-- Casetes (TapeItem): tamaño, cómo se llevan y por dónde entran al local.
-- Menú de inicio y sala de espera (Partida / MenuUI).
Config.Partida = {
	MenuActivo = true, -- false: el turno arranca solo al entrar el primer jugador (útil para pruebas)
	MaxJugadores = 4,
}

Config.Casetes = {
	Tamano = Vector3.new(1, 1.45, 0.3), -- la cara frontal (-Z) es la carátula
	DistanciaPrompt = 6,
	-- En la mano: abajo a la derecha de la vista, con la carátula hacia el jugador (relativo a HumanoidRootPart).
	OffsetEnMano = CFrame.new(0.75, 0.95, -1.7) * CFrame.Angles(math.rad(-12), math.rad(180), math.rad(6)),
	PosicionMostrador = Vector3.new(-4.2, 3.95, 10.2), -- donde queda la cinta que devuelve un cliente
	BuzonEntrada = Vector3.new(6, 3.5, 21.9), -- afuera de la ranura
	BuzonRanura = Vector3.new(6, 3.5, 19.9), -- atravesando la ranura
	BuzonCaida = Vector3.new(6, 2.75, 19.1), -- sobre la caja de devoluciones
	BuzonAnimSeg = 0.5,
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

-- Clientes NPC. Las posiciones tienen y = 3 (altura del HumanoidRootPart).
Config.Clientes = {
	PacienciaSeg = 90, -- tiempo que espera en el mostrador antes de irse
	VelocidadCaminar = 9,
	MaxEnCola = 4,
	TimeoutCaminarSeg = 12, -- si se traba, se lo teletransporta al destino
	Entrada = Vector3.new(0, 3, 25),
	AfueraPuerta = Vector3.new(0, 3, 22.8),
	AdentroPuerta = Vector3.new(0, 3, 18.2),
	ColaBase = Vector3.new(-4.2, 3, 13.4),
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
	},
	FundidoSeg = 0.15,
	PeligroParaCortar = 0.7, -- con tanto peligro se corta el zumbido
	CorteSeg = 3,
	EntreCortesSeg = 12,
}

-- El Socio N° 0000 (SocioEntity). Solo se mueve cuando ningún jugador lo está mirando.
Config.Socio = {
	Color = Color3.fromRGB(10, 10, 12),
	Escala = 1.2, -- más alto que un cliente
	VelocidadBase = 0.9, -- studs/seg con progreso 0
	VelocidadPorProgreso = 4.2, -- se suma con progreso 1
	DistanciaCaptura = 3.4,
	DistanciaPeligro = 45, -- a esta distancia el peligro empieza a subir
	AnguloVision = 58, -- grados: mitad del cono de visión de cada jugador
	LookReportHz = 5, -- frecuencia con la que el cliente informa hacia dónde mira
	LookVencimientoSeg = 0.8, -- un reporte más viejo que esto no cuenta como "mirando"
	LookToleranciaCamara = 10, -- la cámara informada debe estar cerca de la cabeza del personaje
	TickSeg = 0.1,
	RecalcularRutaSeg = 1.5,
	PeligroEnvioSeg = 0.2,
	CapturasMax = 3, -- capturas del equipo que hacen fracasar la noche
	AturdimientoSeg = 3.5,
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

-- La cinta sin etiqueta (CursedTapeSystem).
Config.Cinta = {
	DuracionSeg = 40,
	DuracionFinalSeg = 90, -- en la noche 5 la cinta dura más: verla entera es el final "Mirar"
	Camara = CFrame.lookAt(Vector3.new(-21, 10.8, 18.5), Vector3.new(2, 2, -6)), -- desde arriba de las estanterías
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
	PorNoche = { 0, 3, 4, 5, 6 },
	MinutoDesde = 40,
	MinutoHasta = 290,
	DistanciaReporte = 35,
	EstaticaDistancia = 28, -- una anomalía a esta distancia (y de frente) sube la estática del filtro
	VidaFiguraSeg = 25,
	MirarParaDesaparecerSeg = 1.2,
	OffsetMovido = 1.4,
	RotacionMovida = 28, -- grados
	LimiteFalsosReportes = 4, -- por noche; pasado esto el jugador pierde progreso del equipo
}

Config.Telefono = {
	SonarSeg = 18, -- cuánto suena antes de cortarse solo
	MensajeSeg = 9, -- duración en pantalla de cada mensaje
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
