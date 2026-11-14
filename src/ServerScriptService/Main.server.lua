--!strict
-- Arranque del servidor: crea los Remotes e inicia cada sistema en orden.
-- Un sistema que falla no tumba a los demás: el error se registra y se sigue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

Net.crearTodos()

-- Los jugadores no pueden activar el "Shift Lock" de Roblox (el bloqueo de mouse): el juego maneja el mouse solo (Client/Raton, tecla Ctrl).
-- También está apagado en las propiedades de StarterPlayer del lugar; esto lo garantiza aunque ese valor cambie.
pcall(function()
	game:GetService("StarterPlayer").EnableMouseLockOption = false
end)

local ORDEN = {
	"Persistencia",
	"Jugadores",
	"Sprint",
	"NightManager",
	"Partida",
	"Mundo",
	"RulesSystem",
	"PhoneSystem",
	"TaskSystem",
	"TapeItem",
	"ChoreSystem",
	"TareasMenores",
	"Radio",
	"AnomalyJudge",
	"SocioEntity",
	"Criatura",
	"Screamers",
	"Tienda",
	"Insignias",
	"Pistas",
	"CursedTapeSystem",
	"CustomerSystem",
	"EndingSystem",
	"Depurar",
}

local carpeta = ServerScriptService:WaitForChild("Server")

for _, nombre in ORDEN do
	local ok, err = pcall(function()
		local modulo = require(carpeta:WaitForChild(nombre) :: ModuleScript) :: any
		modulo.init()
	end)
	if not ok then
		warn(string.format("[Servidor] Falló el sistema %s: %s", nombre, tostring(err)))
	elseif Config.Debug.LogSistemas then
		print("[Servidor] Sistema iniciado: " .. nombre)
	end
end
