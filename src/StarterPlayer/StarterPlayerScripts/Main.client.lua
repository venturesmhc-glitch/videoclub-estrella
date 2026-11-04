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
	"Tele",
	"CursedTapeSystem",
	"RulesUI",
	"PhoneUI",
	"Calle",
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
