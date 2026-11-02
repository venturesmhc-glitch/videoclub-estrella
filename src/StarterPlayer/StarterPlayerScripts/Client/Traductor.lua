--!nonstrict
--[[
	Traductor (cliente): si el jugador usa Roblox en otro idioma que no sea el español, traduce al inglés todo lo que se
	muestra: la interfaz (PlayerGui), los carteles y etiquetas del mundo (SurfaceGui en Workspace) y los textos de los
	botones de interacción (ProximityPrompt). El juego manda y escribe todo en español; acá se mira cada TextLabel /
	TextButton / ProximityPrompt, se traduce con Idioma.t y se vuelve a traducir cada vez que el texto cambia.
	En español no hace nada (cero costo).

	  Traductor.traducir(texto) -> texto en el idioma del jugador
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Idioma = require(ReplicatedStorage.Shared.Idioma)

local Traductor = {}

local aplicando = {} -- instancias que estamos tocando (para no reaccionar a nuestro propio cambio)
local vigiladas = {} -- instancia -> { propiedades }: se repasan cada tanto por si un cambio de texto se les escapó
setmetatable(vigiladas, { __mode = "k" })
local REPASO_SEG = 1.5

function Traductor.traducir(texto: string): string
	return Idioma.t(texto)
end

local function traducirPropiedad(instancia: Instance, propiedad: string)
	local actual = instancia[propiedad]
	if typeof(actual) ~= "string" or actual == "" then
		return
	end
	local nuevo = Idioma.t(actual)
	if nuevo ~= actual then
		aplicando[instancia] = true
		instancia[propiedad] = nuevo
		aplicando[instancia] = nil
	end
end

local function vigilar(instancia: Instance, propiedades: { string })
	vigiladas[instancia] = propiedades
	for _, propiedad in propiedades do
		traducirPropiedad(instancia, propiedad)
		instancia:GetPropertyChangedSignal(propiedad):Connect(function()
			if not aplicando[instancia] then
				traducirPropiedad(instancia, propiedad)
			end
		end)
	end
end

local function alAparecer(instancia: Instance)
	if instancia:IsA("TextBox") then
		-- Lo que escribe el jugador no se toca; solo el texto de ayuda.
		vigilar(instancia, { "PlaceholderText" })
	elseif instancia:IsA("TextLabel") or instancia:IsA("TextButton") then
		vigilar(instancia, { "Text" })
	elseif instancia:IsA("ProximityPrompt") then
		vigilar(instancia, { "ActionText", "ObjectText" })
	end
end

local function observar(raiz: Instance)
	for _, d in raiz:GetDescendants() do
		alAparecer(d)
	end
	raiz.DescendantAdded:Connect(alAparecer)
end

function Traductor.init()
	if not Idioma.enIngles() then
		return
	end
	observar(Players.LocalPlayer:WaitForChild("PlayerGui"))
	observar(workspace)
	-- Red de seguridad: un texto en español que se escapó (por ejemplo, uno que se escribió justo antes de que el
	-- observador estuviera listo) se traduce en el próximo repaso.
	task.spawn(function()
		while true do
			task.wait(REPASO_SEG)
			for instancia, propiedades in vigiladas do
				if instancia.Parent then
					for _, propiedad in propiedades do
						traducirPropiedad(instancia, propiedad)
					end
				end
			end
		end
	end)
end

return Traductor
