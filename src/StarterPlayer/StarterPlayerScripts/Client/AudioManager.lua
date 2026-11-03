--!nonstrict
--[[
	AudioManager (cliente): capas de audio ambiente (zumbido eléctrico, hiss de cinta, aire pesado, ondas beta)
	y música de fondo. Los Ids viven en Config.Audio.Capas; una capa sin Id queda deshabilitada.
	Los cortes de sonido son una señal de peligro: AudioManager.cortar(capa, segundos).
	Cada capa pertenece a un grupo ("Ambiente" o "Musica") que el menú de ajustes puede subir o bajar.

	API:
	  AudioManager.cortar(nombre, segundos)   -- silencia una capa un rato y la vuelve a subir
	  AudioManager.setVolumen(nombre, 0..1)
	  AudioManager.setGrupo(grupo, 0..1)      -- multiplicador del grupo (ajustes)
	  AudioManager.getGrupo(grupo) -> 0..1
	  AudioManager.estado() -> string         -- para depurar: qué capas cargaron
	  AudioManager.radio(estacion)            -- 0 = apagada; si no, la estación de Config.Radio.Estaciones (la elige la radio del local)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local AudioManager = {}

local capas = {} -- nombre -> { sonido = Sound, volumenBase = number, grupo = string, cortada = boolean }
local grupos = { Ambiente = 1, Musica = 1 }

local function volumenFinal(capa)
	return (capa.cortada or capa.silenciada) and 0 or capa.volumenBase * (grupos[capa.grupo] or 1)
end

local function crearCapa(nombre, definicion)
	if definicion.Id == "" then
		return
	end
	local sonido = Instance.new("Sound")
	sonido.Name = nombre
	sonido.SoundId = definicion.Id
	sonido.Looped = definicion.Loop
	sonido.Volume = 0
	sonido.Parent = SoundService
	local capa = { sonido = sonido, volumenBase = definicion.Volumen, grupo = definicion.Grupo or "Ambiente", cortada = false }
	capas[nombre] = capa
	sonido.Volume = volumenFinal(capa)
	sonido:Play()
end

local function fundir(capa, duracion: number?)
	TweenService:Create(capa.sonido, TweenInfo.new(duracion or Config.Audio.FundidoSeg), { Volume = volumenFinal(capa) }):Play()
end

function AudioManager.setVolumen(nombre: string, volumen: number)
	local capa = capas[nombre]
	if capa then
		capa.volumenBase = volumen
		fundir(capa)
	end
end

function AudioManager.setGrupo(grupo: string, valor: number)
	grupos[grupo] = math.clamp(valor, 0, 1)
	for _, capa in capas do
		if capa.grupo == grupo then
			fundir(capa, 0.1)
		end
	end
end

function AudioManager.getGrupo(grupo: string): number
	return grupos[grupo] or 1
end

function AudioManager.cortar(nombre: string, segundos: number)
	local capa = capas[nombre]
	if not capa then
		return
	end
	capa.cortada = true
	fundir(capa)
	task.delay(segundos, function()
		capa.cortada = false
		fundir(capa)
	end)
end

-- ===== Cambios bruscos (estilo analog horror) =====
-- Cuando algo cambia de golpe no hay grito: el ambiente se va (a veces como una cinta que se frena, bajando de velocidad
-- y de tono) y queda casi silencio; el cuarto se oye vacío. Después vuelve de a poco, con un chasquido de estática.

--- La cinta se frena: todas las capas bajan de velocidad (y de tono) y de volumen hasta casi nada.
--- 'excepto' = capas que no se tocan (por ejemplo { Beta = true }).
function AudioManager.cintaSeDetiene(segundos: number, excepto: { [string]: boolean }?)
	for nombre, capa in capas do
		if not (excepto and excepto[nombre]) then
			capa.cortada = true
			TweenService:Create(capa.sonido, TweenInfo.new(segundos, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				PlaybackSpeed = 0.35,
				Volume = 0,
			}):Play()
		end
	end
end

--- La cinta arranca de nuevo: vuelven la velocidad y el volumen (más rápido o más lento según 'segundos').
function AudioManager.cintaArranca(segundos: number, excepto: { [string]: boolean }?)
	for nombre, capa in capas do
		if not (excepto and excepto[nombre]) then
			capa.cortada = false
			TweenService:Create(capa.sonido, TweenInfo.new(segundos, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				PlaybackSpeed = capa.velocidad or 1,
				Volume = volumenFinal(capa),
			}):Play()
		end
	end
end

--- Sonido suelto (un solo disparo). opciones: { volumen, velocidad, duracion, retardo, apagado, posicion }
---   apagado = true: lo apaga como si estuviera en otra habitación (quita los agudos), para que no suene "limpio".
---   duracion: corta el sonido (con un fundido) pasado ese tiempo; útil para sonidos largos.
function AudioManager.efecto(id: string, opciones)
	opciones = opciones or {}
	task.delay(opciones.retardo or 0, function()
		local sonido = Instance.new("Sound")
		sonido.SoundId = id
		sonido.Volume = opciones.volumen or 0.2
		sonido.PlaybackSpeed = opciones.velocidad or 1
		sonido.TimePosition = opciones.posicion or 0
		if opciones.apagado then
			local filtro = Instance.new("EqualizerSoundEffect")
			filtro.HighGain = -30
			filtro.MidGain = -6
			filtro.LowGain = 4
			filtro.Parent = sonido
		end
		sonido.Parent = SoundService
		sonido:Play()
		local duracion = opciones.duracion
		if duracion then
			task.delay(duracion, function()
				TweenService:Create(sonido, TweenInfo.new(0.25), { Volume = 0 }):Play()
				task.delay(0.3, function()
					sonido:Destroy()
				end)
			end)
		else
			sonido.Ended:Once(function()
				sonido:Destroy()
			end)
			task.delay(30, function()
				sonido:Destroy()
			end)
		end
	end)
end

--- La radio del local: la capa de música de fondo suena la estación elegida (o se apaga).
function AudioManager.radio(estacion: number)
	local capa = capas.Radio
	if not capa then
		return
	end
	local definicion = Config.Radio.Estaciones[estacion]
	if not definicion then
		capa.volumenBase = 0
		fundir(capa, 0.4)
		return
	end
	if capa.sonido.SoundId ~= definicion.Id then
		capa.sonido.SoundId = definicion.Id
	end
	capa.volumenBase = Config.Radio.Volumen
	if not capa.sonido.IsPlaying then
		capa.sonido:Play()
	end
	fundir(capa, 0.4)
end

-- ===== La música cuando el Socio está presente =====
-- Mientras el Socio está en el local la radio se funde a nada y entra una pista propia (capa RadioSocio): grave, lenta,
-- distorsionada y con eco, con un temblor de velocidad como una cinta mal tensada. Suena aunque la radio esté apagada.
-- Al irse, la pista sale de a poco y vuelve la radio. Los efectos viven en la pista, así que no dependen de la radio.
local cfgMusica = Config.Audio.MusicaSocio
local distorsionActiva = false
local distorsionToken = 0

local function prepararMusicaSocio()
	local capa = capas.RadioSocio
	if not capa then
		return
	end
	local sonido = capa.sonido
	sonido.PlaybackSpeed = cfgMusica.Velocidad
	capa.velocidad = cfgMusica.Velocidad -- a esta velocidad vuelve cuando la cinta arranca de nuevo
	local distorsion = Instance.new("DistortionSoundEffect")
	distorsion.Name = "DistorsionSocio"
	distorsion.Level = cfgMusica.Distorsion
	distorsion.Parent = sonido
	local tono = Instance.new("PitchShiftSoundEffect")
	tono.Name = "TonoSocio"
	tono.Octave = cfgMusica.Octava
	tono.Parent = sonido
	local filtro = Instance.new("EqualizerSoundEffect")
	filtro.Name = "OpacoSocio"
	filtro.HighGain = -14
	filtro.MidGain = -4
	filtro.LowGain = 5
	filtro.Parent = sonido
	local eco = Instance.new("ReverbSoundEffect")
	eco.Name = "EcoSocio"
	eco.DecayTime = 4
	eco.DryLevel = -2
	eco.WetLevel = -4
	eco.Parent = sonido
end

function AudioManager.distorsionarMusica(activar: boolean)
	if activar == distorsionActiva then
		return
	end
	local socio = capas.RadioSocio
	local radio = capas.Radio
	if not socio then
		return -- sin pista exclusiva (Id vacío en Config.Audio.Capas.RadioSocio): la radio sigue como siempre
	end
	distorsionActiva = activar
	distorsionToken += 1
	local token = distorsionToken
	local duracion = activar and cfgMusica.EntraSeg or cfgMusica.SaleSeg
	if radio then
		radio.silenciada = activar
		fundir(radio, duracion)
	end
	socio.volumenBase = activar and cfgMusica.Volumen or 0
	fundir(socio, duracion)
	if activar then
		-- Temblor de velocidad mientras dure.
		task.spawn(function()
			local rng = Random.new()
			while distorsionActiva and distorsionToken == token do
				local objetivo = cfgMusica.Velocidad + rng:NextNumber(-0.12, 0.08)
				TweenService:Create(socio.sonido, TweenInfo.new(rng:NextNumber(0.2, 0.7)), { PlaybackSpeed = objetivo }):Play()
				task.wait(rng:NextNumber(0.25, 0.8))
			end
		end)
	else
		TweenService:Create(socio.sonido, TweenInfo.new(duracion), { PlaybackSpeed = cfgMusica.Velocidad }):Play()
	end
end

function AudioManager.estado(): string
	local lineas = {}
	for nombre, capa in capas do
		table.insert(lineas, string.format("%s: cargado=%s dur=%.1fs vol=%.2f", nombre, tostring(capa.sonido.IsLoaded), capa.sonido.TimeLength, capa.sonido.Volume))
	end
	table.sort(lineas)
	return table.concat(lineas, "\n")
end

function AudioManager.init()
	for nombre, definicion in Config.Audio.Capas do
		crearCapa(nombre, definicion)
	end
	prepararMusicaSocio()
	-- La radio del local decide la música de fondo (atributo de Workspace que pone Radio.lua).
	AudioManager.radio(workspace:GetAttribute("RadioEstacion") or 0)
	workspace:GetAttributeChangedSignal("RadioEstacion"):Connect(function()
		AudioManager.radio(workspace:GetAttribute("RadioEstacion") or 0)
	end)
	-- Cuando el Socio está muy cerca, el zumbido se corta: el silencio es la señal de peligro.
	local proximaAlerta = 0
	Net.obtener("Danger").OnClientEvent:Connect(function(valor)
		if typeof(valor) == "number" and valor >= Config.Audio.PeligroParaCortar and os.clock() >= proximaAlerta then
			proximaAlerta = os.clock() + Config.Audio.EntreCortesSeg
			AudioManager.cortar("Zumbido", Config.Audio.CorteSeg)
		end
	end)
	Net.obtener("SocioPresencia").OnClientEvent:Connect(function(presente)
		AudioManager.distorsionarMusica(presente == true)
	end)
	-- El susto de la captura: la cinta se corta de golpe, queda una ráfaga de estática apagada y el ambiente vuelve de a poco.
	Net.obtener("Scare").OnClientEvent:Connect(function()
		AudioManager.cintaSeDetiene(0.12)
		AudioManager.efecto(Config.Sustos.Estatica.Id, { volumen = Config.Sustos.Estatica.Volumen * 1.6, duracion = 1.3, apagado = true })
		task.delay(1.9, function()
			AudioManager.cintaArranca(1.6)
		end)
	end)

	if next(capas) == nil and Config.Debug.LogSistemas then
		print("[AudioManager] Sin audios en Config.Audio.Capas: ambiente en silencio")
	end
end

return AudioManager
