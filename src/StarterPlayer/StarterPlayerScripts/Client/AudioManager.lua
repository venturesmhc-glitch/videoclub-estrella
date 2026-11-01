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
	return capa.cortada and 0 or capa.volumenBase * (grupos[capa.grupo] or 1)
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
	-- Cuando el Socio está muy cerca, el zumbido se corta: el silencio es la señal de peligro.
	local proximaAlerta = 0
	Net.obtener("Danger").OnClientEvent:Connect(function(valor)
		if typeof(valor) == "number" and valor >= Config.Audio.PeligroParaCortar and os.clock() >= proximaAlerta then
			proximaAlerta = os.clock() + Config.Audio.EntreCortesSeg
			AudioManager.cortar("Zumbido", Config.Audio.CorteSeg)
		end
	end)
	if next(capas) == nil and Config.Debug.LogSistemas then
		print("[AudioManager] Sin audios en Config.Audio.Capas: ambiente en silencio")
	end
end

return AudioManager
