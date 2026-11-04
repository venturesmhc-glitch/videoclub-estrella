--!strict
-- Arranque del servidor: crea los Remotes e inicia cada sistema en orden.
-- Un sistema que falla no tumba a los demás: el error se registra y se sigue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

Net.crearTodos()

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
	"Screamers",
	"Tienda",
	"Cosmeticos",
	"Insignias",
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
