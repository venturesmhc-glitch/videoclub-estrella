--!nonstrict
--[[
	Tienda (servidor): compras con Robux (Developer Products de la experiencia, ids en Config.Tienda.Productos).
	  asustar  10 Robux: un screamer a todos los demás que siguen en la noche (con enfriamiento para todo el servidor)
	  revivir  15 Robux: un espectador vuelve a jugar al instante (no hace falta esperar a la noche siguiente)

	El cliente solo pide ("Comprar" { producto }); acá se valida, se abre la compra y recién cuando Roblox confirma el
	pago (ProcessReceipt) se aplica el efecto. En Studio, si el producto todavía no tiene id (0), la compra se simula para
	poder probar el efecto sin gastar nada.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Fantasmas = require(script.Parent.Fantasmas)
local NightManager = require(script.Parent.NightManager)
local Screamers = require(script.Parent.Screamers)
local SocioEntity = require(script.Parent.SocioEntity)

local Tienda = {}

local cfg = Config.Tienda
local ultimoAsustar = -math.huge
local procesados = {} -- PurchaseId -> true (Roblox puede repetir un recibo si el servidor no confirmó a tiempo)

local function claveDeProducto(id: number): string?
	for nombre, valor in cfg.Productos do
		if valor ~= 0 and valor == id then
			return string.lower(nombre)
		end
	end
	return nil
end

local EFECTOS = {}

function EFECTOS.asustar(jugador: Player)
	ultimoAsustar = os.clock()
	Net.avisoATodos(jugador.DisplayName .. " asustó a todos.")
	Screamers.disparar(function(otro)
		return otro ~= jugador
	end)
end

function EFECTOS.revivir(jugador: Player)
	if not Fantasmas.esFantasma(jugador) then
		return -- ya estaba de pie (por ejemplo, la noche se repitió mientras compraba)
	end
	SocioEntity.revivirJugador(jugador)
	Net.avisoATodos(jugador.DisplayName .. " volvió a la noche.")
end

-- Lo que se pide antes de abrir la compra: devuelve un texto si no se puede.
local function motivoPara(jugador: Player, producto: string): string?
	if producto == "asustar" then
		if NightManager.obtenerEstado().fase ~= "turno" then
			return "Solo se puede asustar durante el turno."
		end
		if Fantasmas.esFantasma(jugador) then
			return "Los espectadores no pueden asustar."
		end
		local espera = cfg.EnfriamientoAsustarSeg - (os.clock() - ultimoAsustar)
		if espera > 0 then
			return string.format("Alguien acaba de asustar a todos. Probá en %d s.", math.ceil(espera))
		end
	elseif producto == "revivir" then
		if not Fantasmas.esFantasma(jugador) then
			return "Solo podés revivir si quedaste fuera de la noche."
		end
	else
		return "Producto desconocido."
	end
	return nil
end

local function pedirCompra(jugador: Player, producto: string)
	local motivo = motivoPara(jugador, producto)
	if motivo then
		Net.aviso(jugador, motivo)
		return
	end
	local nombre = producto == "asustar" and "Asustar" or "Revivir"
	local id = cfg.Productos[nombre]
	if id == 0 then
		if RunService:IsStudio() then
			EFECTOS[producto](jugador) -- prueba en Studio: sin pago
		else
			Net.aviso(jugador, "Esta compra todavía no está disponible.")
		end
		return
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(jugador, id)
	end)
	if not ok then
		warn("[Tienda] No se pudo abrir la compra: " .. tostring(err))
		Net.aviso(jugador, "No se pudo abrir la compra. Probá de nuevo.")
	end
end

function Tienda.init()
	Net.obtener("Comprar").OnServerEvent:Connect(function(jugador, datos)
		if typeof(datos) ~= "table" or typeof(datos.producto) ~= "string" then
			return
		end
		if not Net.limitar(jugador, "comprar", 1.5) then
			return
		end
		pedirCompra(jugador, datos.producto)
	end)

	MarketplaceService.ProcessReceipt = function(recibo)
		if procesados[recibo.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local jugador = Players:GetPlayerByUserId(recibo.PlayerId)
		if not jugador then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- se fue: Roblox lo vuelve a intentar cuando vuelva
		end
		local producto = claveDeProducto(recibo.ProductId)
		if not producto then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = pcall(EFECTOS[producto], jugador)
		if not ok then
			warn("[Tienda] Falló el efecto de " .. producto .. ": " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		procesados[recibo.PurchaseId] = true
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Tienda
