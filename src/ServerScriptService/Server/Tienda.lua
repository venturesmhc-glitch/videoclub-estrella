--!nonstrict
--[[
	Tienda (servidor): compras con Robux (Developer Products de la experiencia, ids en Config.Tienda.Productos; lo que se
	vende y cómo se ve está en Config.Tienda.Catalogo). Se abre en el cliente con B (TiendaUI).

	  Ayudas (se pagan cada vez, solo durante el turno):
	    amuleto    absorbe una captura del Socio esta noche
	    pausa      congela al Socio unos segundos (con enfriamiento para todo el servidor)
	    companero  un espectador (a elección) vuelve a jugar al instante
	    revivir    un espectador (uno mismo) vuelve a jugar al instante
	    asustar    un screamer a todos los demás que siguen en la noche (también con la máscara del depósito)
	  Aspecto (permanentes, quedan en el perfil): filtros de cinta (Client/Filtro). La ropa se sacó: no se puede vender sin Premium.
	  Radio: paseradio desbloquea las estaciones premium (Radio.lua)
	  Propinas: no hacen nada en el juego, solo agradecen.

	El cliente pide ("Comprar" { producto, objetivo? }); acá se valida, se abre la compra y recién cuando Roblox confirma el
	pago (ProcessReceipt) se aplica el efecto. En Studio, si el producto todavía no tiene id (0), la compra se simula para
	poder probar el efecto sin gastar nada. "Equipar" { ranura, clave? } se pone o saca algo ya comprado.
]]

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Prompts = require(script.Parent.Prompts)
local Fantasmas = require(script.Parent.Fantasmas)
local Persistencia = require(script.Parent.Persistencia)
local NightManager = require(script.Parent.NightManager)
local Persistencia = require(script.Parent.Persistencia)
local Screamers = require(script.Parent.Screamers)
local SocioEntity = require(script.Parent.SocioEntity)

local Tienda = {}

local cfg = Config.Tienda
local ultimoAsustar = -math.huge
local ultimaPausa = -math.huge
local procesados = {} -- PurchaseId -> true (Roblox puede repetir un recibo si el servidor no confirmó a tiempo)
local pendientes = {} -- UserId -> { clave, objetivo } (a quién va el "revivir a un compañero" que se está pagando)
local porClave = {} -- clave -> artículo del catálogo
local RANURAS = { filtro = true }

for _, articulo in cfg.Catalogo do
	porClave[articulo.clave] = articulo
end

local function idDe(articulo): number
	return cfg.Productos[articulo.producto] or 0
end

local function articuloDeProducto(id: number)
	for _, articulo in cfg.Catalogo do
		local propio = idDe(articulo)
		if propio ~= 0 and propio == id then
			return articulo
		end
	end
	return nil
end

local function enTurno(): boolean
	return NightManager.obtenerEstado().fase == "turno"
end

local function espectadores(excepto: Player?): { Player }
	local lista = {}
	for _, otro in Players:GetPlayers() do
		if otro ~= excepto and Fantasmas.esFantasma(otro) then
			table.insert(lista, otro)
		end
	end
	return lista
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

function EFECTOS.companero(jugador: Player, extra)
	local elegido = extra and extra.objetivo and Players:GetPlayerByUserId(extra.objetivo)
	if not elegido or elegido == jugador or not Fantasmas.esFantasma(elegido) then
		elegido = espectadores(jugador)[1] -- el elegido ya volvió (o se fue) mientras se pagaba: va al primero que siga fuera
	end
	if not elegido then
		-- Nadie quedó fuera: la compra no se pierde, se convierte en un amuleto para quien pagó.
		SocioEntity.darAmuleto(jugador)
		Net.aviso(jugador, "Ya no había nadie fuera: recibiste un amuleto.")
		return
	end
	SocioEntity.revivirJugador(elegido)
	Net.avisoATodos(string.format("%s revivió a %s.", jugador.DisplayName, elegido.DisplayName))
end

function EFECTOS.amuleto(jugador: Player)
	if SocioEntity.darAmuleto(jugador) then
		Net.aviso(jugador, "Tenés un amuleto: absorbe la próxima captura.")
	end
end

function EFECTOS.pausa(jugador: Player)
	ultimaPausa = os.clock()
	SocioEntity.pausar(cfg.PausaSeg)
	Net.avisoATodos(jugador.DisplayName .. " frenó la cinta: el Socio quedó congelado.")
end

local function propina(jugador: Player)
	Net.avisoATodos(jugador.DisplayName .. " dejó una propina para Don Ernesto. ¡Gracias!")
end
EFECTOS.propinachica = propina
EFECTOS.propinamedia = propina
EFECTOS.propinagrande = propina

-- Lo permanente se anota en el perfil; los filtros además se ponen al comprarlos.
local function permanente(jugador: Player, articulo)
	Persistencia.marcarCompra(jugador, articulo.clave)
	if articulo.ranura then
		Persistencia.equipar(jugador, articulo.ranura, articulo.valor or articulo.clave)
	end
	Net.aviso(jugador, "Compraste: " .. articulo.nombre .. ".")
end

-- Lo que se pide antes de abrir la compra: devuelve un texto si no se puede.
local function motivoPara(jugador: Player, articulo, extra): string?
	local clave = articulo.clave
	if articulo.tipo == "permanente" then
		if Persistencia.tieneCompra(jugador, clave) then
			return "Ya lo tenés: equipalo desde la tienda."
		end
		return nil
	end
	if clave == "asustar" then
		if not enTurno() then
			return "Solo se puede asustar durante el turno."
		end
		if Fantasmas.esFantasma(jugador) then
			return "Los espectadores no pueden asustar."
		end
		local espera = cfg.EnfriamientoAsustarSeg - (os.clock() - ultimoAsustar)
		if espera > 0 then
			return string.format("Alguien acaba de asustar a todos. Probá en %d s.", math.ceil(espera))
		end
	elseif clave == "revivir" then
		if not Fantasmas.esFantasma(jugador) then
			return "Solo podés revivir si quedaste fuera de la noche."
		end
	elseif clave == "companero" then
		if #espectadores(jugador) == 0 then
			return "No hay ningún compañero fuera de la noche."
		end
		local objetivo = extra and extra.objetivo and Players:GetPlayerByUserId(extra.objetivo)
		if extra and extra.objetivo and (not objetivo or objetivo == jugador or not Fantasmas.esFantasma(objetivo)) then
			return "Ese jugador ya no está fuera de la noche."
		end
	elseif clave == "amuleto" then
		if not enTurno() or Fantasmas.esFantasma(jugador) then
			return "El amuleto se compra durante el turno, estando en pie."
		end
		if SocioEntity.tieneAmuleto(jugador) then
			return "Ya tenés un amuleto."
		end
	elseif clave == "pausa" then
		if not enTurno() or Fantasmas.esFantasma(jugador) then
			return "La pausa de cinta se usa durante el turno, estando en pie."
		end
		if not SocioEntity.estaActivo() then
			return "El Socio no está en el local."
		end
		local espera = cfg.EnfriamientoPausaSeg - (os.clock() - ultimaPausa)
		if espera > 0 then
			return string.format("La cinta ya se frenó hace poco. Probá en %d s.", math.ceil(espera))
		end
	end
	return nil
end

local function aplicar(jugador: Player, articulo, extra)
	if articulo.tipo == "permanente" then
		permanente(jugador, articulo)
	else
		EFECTOS[articulo.clave](jugador, extra)
	end
end

local function pedirCompra(jugador: Player, clave: string, extra)
	local articulo = porClave[clave]
	if not articulo then
		Net.aviso(jugador, "Producto desconocido.")
		return
	end
	local motivo = motivoPara(jugador, articulo, extra)
	if motivo then
		Net.aviso(jugador, motivo)
		return
	end
	local id = idDe(articulo)
	if id == 0 then
		if RunService:IsStudio() then
			aplicar(jugador, articulo, extra) -- prueba en Studio: sin pago
		else
			Net.aviso(jugador, "Esta compra todavía no está disponible.")
		end
		return
	end
	pendientes[jugador.UserId] = { clave = clave, objetivo = extra and extra.objetivo }
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(jugador, id)
	end)
	if not ok then
		pendientes[jugador.UserId] = nil
		warn("[Tienda] No se pudo abrir la compra: " .. tostring(err))
		Net.aviso(jugador, "No se pudo abrir la compra. Probá de nuevo.")
	end
end

-- ===== Pase cosmético: colores de linterna =====

local function pasesDisponibles(): boolean
	return cfg.Pases.LinternaColor ~= 0 or RunService:IsStudio()
end

local function verificarPase(jugador: Player)
	local id = cfg.Pases.LinternaColor
	local tiene = false
	if id == 0 then
		tiene = RunService:IsStudio() -- sin pase creado: en Studio se regala para probar
	else
		local ok, resultado = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(jugador.UserId, id)
		end)
		tiene = ok and resultado == true
	end
	jugador:SetAttribute("PaseLinterna", tiene)
end

local function pedirPase(jugador: Player)
	if jugador:GetAttribute("PaseLinterna") then
		return
	end
	local id = cfg.Pases.LinternaColor
	if id == 0 then
		Net.aviso(jugador, "Esta compra todavía no está disponible.")
		return
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(jugador, id)
	end)
	if not ok then
		warn("[Tienda] No se pudo abrir la compra del pase: " .. tostring(err))
		Net.aviso(jugador, "No se pudo abrir la compra. Probá de nuevo.")
	end
end

function Tienda.pedirCompra(jugador: Player, producto: string, extra)
	pedirCompra(jugador, producto, extra)
end

--- Pone o saca algo de una ranura (solo si lo compró).
local function equipar(jugador: Player, ranura, clave)
	if typeof(ranura) ~= "string" or not RANURAS[ranura] then
		return
	end
	if clave == nil then
		Persistencia.equipar(jugador, ranura, nil)
		return
	end
	local articulo = typeof(clave) == "string" and porClave[clave]
	if not articulo or articulo.ranura ~= ranura or not Persistencia.tieneCompra(jugador, articulo.clave) then
		Net.aviso(jugador, "Todavía no compraste eso.")
		return
	end
	Persistencia.equipar(jugador, ranura, articulo.valor or articulo.clave)
end

Tienda.pasesDisponibles = pasesDisponibles

function Tienda.init()
	-- La máscara de Ghostface del depósito: mantener E abre la compra de "Asustar a todos".
	for _, mascara in CollectionService:GetTagged("MascaraAsustar") do
		if mascara:IsA("BasePart") then
			Prompts.crear(mascara, {
				clave = "mascara",
				accion = "Asustar a todos",
				objeto = string.format("Máscara · R$ %d", cfg.Precios.Asustar),
				hold = cfg.Mascara.MantenerSeg,
				distancia = cfg.Mascara.Distancia,
				alActivar = function(jugador)
					if Net.limitar(jugador, "comprar", 1.5) then
						pedirCompra(jugador, "asustar")
					end
				end,
			})
		end
	end

	Net.obtener("Comprar").OnServerEvent:Connect(function(jugador, datos)
		if typeof(datos) ~= "table" or typeof(datos.producto) ~= "string" then
			return
		end
		if not Net.limitar(jugador, "comprar", 1.5) then
			return
		end
		if datos.producto == "pase_linterna" then
			pedirPase(jugador)
			return
		elseif datos.producto == "color_linterna" then
			local indice = math.floor(tonumber(datos.indice) or 1)
			-- El color de siempre es gratis; los demás piden el pase.
			if indice == 1 or jugador:GetAttribute("PaseLinterna") then
				Persistencia.fijarColorLinterna(jugador, indice)
			end
			return
		end
		local objetivo = typeof(datos.objetivo) == "number" and datos.objetivo or nil
		pedirCompra(jugador, datos.producto, { objetivo = objetivo })
	end)

	Net.obtener("Equipar").OnServerEvent:Connect(function(jugador, datos)
		if typeof(datos) ~= "table" or not Net.limitar(jugador, "equipar", 0.4) then
			return
		end
		equipar(jugador, datos.ranura, datos.clave)
	end)

	Players.PlayerRemoving:Connect(function(jugador)
		pendientes[jugador.UserId] = nil
	end)

	-- El pase se verifica al entrar y se activa en el momento de la compra.
	Players.PlayerAdded:Connect(function(jugador)
		task.spawn(verificarPase, jugador)
	end)
	for _, jugador in Players:GetPlayers() do
		task.spawn(verificarPase, jugador)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(jugador, idPase, comprado)
		if comprado and idPase == cfg.Pases.LinternaColor and idPase ~= 0 then
			jugador:SetAttribute("PaseLinterna", true)
			Net.aviso(jugador, "¡Gracias! Ya podés elegir el color de la linterna en Ajustes.")
		end
	end)

	MarketplaceService.ProcessReceipt = function(recibo)
		if procesados[recibo.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local jugador = Players:GetPlayerByUserId(recibo.PlayerId)
		if not jugador then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- se fue: Roblox lo vuelve a intentar cuando vuelva
		end
		local articulo = articuloDeProducto(recibo.ProductId)
		if not articulo then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local pendiente = pendientes[jugador.UserId]
		local extra = pendiente and pendiente.clave == articulo.clave and { objetivo = pendiente.objetivo } or nil
		local ok, err = pcall(aplicar, jugador, articulo, extra)
		if not ok then
			warn("[Tienda] Falló el efecto de " .. articulo.clave .. ": " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		pendientes[jugador.UserId] = nil
		procesados[recibo.PurchaseId] = true
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Tienda
