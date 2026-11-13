--!strict
-- Arranque del cliente: inicia cada sistema en orden. Un fallo no tumba a los demás.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config") :: ModuleScript) :: any

local ORDEN = {
	"JugadorLocal",
	"Sprint",
	"Traductor",
	"VHSEffects",
	"Cordura",
	"Temblor",
	"Parpadeo",
	"SocioAnimacion",
	"SocioSentidos",
	"OSD",
	"AudioManager",
	"Rendimiento",
	"Filtro",
	"TiendaUI",
	"MenuUI",
	"Linterna",
	"LuzFluorescente",
	"DialogUI",
	"TaskCard",
	"AnomalySystem",
	"CriaturaVista",
	"Pistas",
	"Tele",
	"CursedTapeSystem",
	"RulesUI",
	"PhoneUI",
	"Calle",
	"VidaLocal",
	"Sustos",
	"Screamers",
	"Espectador",
	"Raton",
}

local carpeta = script.Parent:WaitForChild("Client")

for _, nombre in ORDEN do
	local ok, err = pcall(function()
		local modulo = require(carpeta:WaitForChild(nombre) :: ModuleScript) :: any
		modulo.init()
	end)
	if not ok then
		warn(string.format("[Cliente] Falló el sistema %s: %s", nombre, tostring(err)))
	elseif Config.Debug.LogSistemas then
		print("[Cliente] Sistema iniciado: " .. nombre)
	end
end

-- Modo grabación (clips para TikTok/Reels/Shorts): con Config.Debug.ModoGrabacion en false esto ni se carga.
if Config.Debug.ModoGrabacion then
	local ok, err = pcall(function()
		(require(carpeta:WaitForChild("Cinematica") :: ModuleScript) :: any).init()
	end)
	if not ok then
		warn("[Cliente] Falló Cinematica: " .. tostring(err))
	end
end
