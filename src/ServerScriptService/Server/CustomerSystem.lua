--!nonstrict
--[[
	CustomerSystem (servidor) — Fases 2 y 6.
	Clientes NPC: entran por la puerta, hacen cola frente al mostrador y se van.
	  - "alquiler": piden un género; hay que sacar un casete de esa góndola y entregárselo en el mostrador.
	  - "devolucion": al atenderlos dejan su casete en el mostrador (rebobinar y reponer, o separar si está dañado).
	Si nadie los atiende en Config.Clientes.PacienciaSeg se van enojados.

	El mostrador tiene dos prompts: "Atender" (E) y "Rechazar cliente" (R, mantener).

	Modos de clientes según la noche (NightData.clientesModo):
	  normal   cada cliente es distinto
	  repetir  noche 3: todos repiten la misma frase, palabra por palabra
	  mismo    noches 4 y 5: todos tienen el mismo aspecto y dicen un número de socio; el del Socio es 0000.
	           Atenderlo suma mucho progreso al Socio; rechazarlo lo baja (regla "R_NUMERO" de Darío).
	Noche 5: a las 3:30 el Socio hace cola como un cliente más y espera su cinta. Entregársela (devolver) es un final.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalogo = require(ReplicatedStorage.Shared.Catalogo)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local NightData = require(ReplicatedStorage.Shared.NightData)
local Personajes = require(ReplicatedStorage.Shared.Personajes)
local NightManager = require(script.Parent.NightManager)
local Prompts = require(script.Parent.Prompts)
local SocioEntity = require(script.Parent.SocioEntity)
local TapeItem = require(script.Parent.TapeItem)
local TaskSystem = require(script.Parent.TaskSystem)

local CustomerSystem = {}

local cfg = Config.Clientes
local rng = Random.new()
local cola = {} -- clientes que ya entraron, en orden de llegada (cola[1] está en el mostrador)
local activos = {} -- todos los clientes vivos (incluye los que están entrando o saliendo)
local enMostrador = nil
local contadorId = 0
local carpeta
local puerta
local transparenciaCerrada = 0.55
local usosPuerta = 0
local modoNoche = "normal"
local fraseRepetida = {} -- noche 3: plantilla de frase elegida por grupo (PedirAlquiler, Devolver...)

local function elegir(lista)
	return lista[rng:NextInteger(1, #lista)]
end

local function hablar(texto: string)
	Net.obtener("CustomerDialog"):FireAllClients({ speaker = "Cliente", texto = texto })
end

-- Dice la frase del grupo 'clave'. En la noche 3 todos repiten la primera que se dijo.
local function decir(cliente, clave: string, argumento: string?)
	local texto
	if modoNoche == "repetir" then
		-- Repiten las mismas palabras, pero el género es el que realmente pidió (si no, la frase confunde el pedido).
		local plantilla = fraseRepetida[clave]
		if not plantilla then
			plantilla = Catalogo.plantilla(clave, rng)
			fraseRepetida[clave] = plantilla
		end
		texto = Catalogo.rellenar(plantilla, argumento)
	else
		texto = Catalogo.frase(clave, rng, argumento)
	end
	if modoNoche == "mismo" and cliente.numero and (clave == "PedirAlquiler" or clave == "Devolver" or clave == "DevolverDanada") then
		texto = string.format("Socio N° %s. %s", cliente.numero, texto)
	end
	hablar(texto)
end

-- Mientras un cliente pasa, la puerta de vidrio deja de colisionar: para que los jugadores no salgan al mismo tiempo
-- hay una barrera invisible en el hueco que solo los clientes (grupo de colisión "Clientes") atraviesan.
local GRUPO_CLIENTES = "Clientes"
local GRUPO_BARRERA = "BarreraPuerta"

local function prepararBarreraDePuerta()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GRUPO_CLIENTES)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GRUPO_BARRERA)
	end)
	PhysicsService:CollisionGroupSetCollidable(GRUPO_CLIENTES, GRUPO_BARRERA, false)
	if not puerta then
		return
	end
	local barrera = Instance.new("Part")
	barrera.Name = "BarreraPuertaJugadores"
	barrera.Anchored = true
	barrera.CanCollide = true
	barrera.CanQuery = false
	barrera.CanTouch = false
	barrera.Transparency = 1
	barrera.Size = Vector3.new(puerta.Size.X, puerta.Size.Y + 2, 1.5) -- más gruesa que la puerta: no se la atraviesa corriendo
	barrera.CFrame = puerta.CFrame
	barrera.CollisionGroup = GRUPO_BARRERA
	barrera.Parent = puerta.Parent
end

-- La puerta está cerrada con llave para los jugadores; solo se abre mientras pasa un cliente.
local function usarPuerta(delta: number)
	if not puerta then
		return
	end
	usosPuerta = math.max(0, usosPuerta + delta)
	local abierta = usosPuerta > 0
	puerta.CanCollide = not abierta
	local destino = abierta and cfg.PuertaAbiertaTransparencia or transparenciaCerrada
	TweenService:Create(puerta, TweenInfo.new(0.4), { Transparency = destino }):Play()
end

local function posicionCola(indice: number): Vector3
	return cfg.ColaBase + Vector3.new(0, 0, cfg.ColaPaso * (indice - 1))
end

local function crearModelo(cliente): boolean
	local piel, ropa, pantalon = elegir(cfg.PaletaPiel), elegir(cfg.PaletaRopa), elegir(cfg.PaletaPantalon)
	local pelo, estilo = elegir(cfg.PaletaPelo), elegir(cfg.EstilosPelo)
	local sinCara = false
	if cliente.final then
		-- El Socio: todo oscuro.
		piel, ropa, pantalon, pelo = Config.Socio.Color, Config.Socio.Color, Config.Socio.Color, Config.Socio.Color
		estilo, sinCara = "corto", true
	elseif modoNoche == "mismo" then
		-- Todos iguales (y sin cara): no se los puede distinguir.
		piel, ropa, pantalon = cfg.PaletaPiel[1], cfg.PaletaRopa[6], cfg.PaletaPantalon[3]
		pelo, estilo, sinCara = cfg.PaletaPelo[1], "corto", true
	end

	local modelo = Personajes.crear({
		piel = piel,
		ropa = ropa,
		pantalon = pantalon,
		pelo = pelo,
		estilo = estilo,
		sinCara = sinCara,
		escala = modoNoche == "mismo" and 1 or rng:NextNumber(cfg.EscalaMin, cfg.EscalaMax),
	})
	if not modelo then
		return false
	end

	modelo.Name = "Cliente_" .. cliente.id
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	cliente.animacion = Personajes.animar(modelo)
	humanoide.WalkSpeed = cfg.VelocidadCaminar
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	modelo:PivotTo(CFrame.new(cfg.Entrada))
	modelo.Parent = carpeta
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = GRUPO_CLIENTES -- los clientes atraviesan la barrera de la puerta; los jugadores no
		end
	end

	local raiz = modelo:WaitForChild("HumanoidRootPart")
	pcall(function()
		raiz:SetNetworkOwner(nil)
	end)
	cliente.modelo, cliente.humanoide, cliente.raiz = modelo, humanoide, raiz
	return true
end

-- Camina hasta el destino; si se traba (por ejemplo con un jugador en el medio) lo teletransporta.
local function caminarA(cliente, destino: Vector3)
	if not cliente.vivo then
		return
	end
	local humanoide = cliente.humanoide
	local llego = false
	local conexion = humanoide.MoveToFinished:Connect(function()
		llego = true
	end)
	humanoide:MoveTo(destino)
	local inicio = os.clock()
	while cliente.vivo and not llego and os.clock() - inicio < cfg.TimeoutCaminarSeg do
		task.wait(0.1)
	end
	conexion:Disconnect()
	if cliente.vivo and not llego then
		cliente.modelo:PivotTo(CFrame.new(destino))
	end
end

local function mirar(cliente, punto: Vector3)
	if not cliente.vivo then
		return
	end
	local posicion = cliente.raiz.Position
	cliente.modelo:PivotTo(CFrame.lookAt(posicion, Vector3.new(punto.X, posicion.Y, punto.Z)))
end

local function destruir(cliente)
	cliente.vivo = false
	if cliente.usandoPuerta then
		cliente.usandoPuerta = false
		usarPuerta(-1)
	end
	local lugar = table.find(cola, cliente)
	if lugar then
		table.remove(cola, lugar)
	end
	if enMostrador == cliente then
		enMostrador = nil
	end
	activos[cliente.id] = nil
	if cliente.casete and cliente.casete.vivo and not cliente.casete.dueno then
		TapeItem.consumir(cliente.casete)
	end
	if cliente.modelo then
		cliente.modelo:Destroy()
	end
end

local function salir(cliente)
	usarPuerta(1)
	cliente.usandoPuerta = true
	caminarA(cliente, cfg.AdentroPuerta)
	caminarA(cliente, cfg.AfueraPuerta)
	caminarA(cliente, cfg.Entrada)
	destruir(cliente)
	TaskSystem.sincronizar()
end

local function ciclo(cliente)
	if not crearModelo(cliente) then
		destruir(cliente)
		return
	end

	-- Entrar por la puerta.
	caminarA(cliente, cfg.AfueraPuerta)
	usarPuerta(1)
	cliente.usandoPuerta = true
	caminarA(cliente, cfg.AdentroPuerta)
	cliente.usandoPuerta = false
	usarPuerta(-1)

	-- Esperar el turno en la cola.
	table.insert(cola, cliente)
	while cliente.vivo do
		local indice = table.find(cola, cliente)
		if not indice then
			return
		end
		local destino = posicionCola(indice)
		if (cliente.raiz.Position - destino).Magnitude > 1.2 then
			caminarA(cliente, destino)
		end
		if indice == 1 then
			break
		end
		task.wait(0.5)
	end
	if not cliente.vivo then
		return
	end

	-- En el mostrador.
	mirar(cliente, cfg.ColaBase + Vector3.new(0, 0, -10))
	enMostrador = cliente
	cliente.limite = cliente.final and math.huge or (os.clock() + cfg.PacienciaSeg)
	if cliente.final then
		hablar("Vengo por mi cinta. La del socio cero.")
	elseif cliente.tipo == "alquiler" then
		decir(cliente, "PedirAlquiler", Catalogo.Nombres[cliente.genero])
	else
		decir(cliente, cliente.danado and "DevolverDanada" or "Devolver")
	end
	TaskSystem.sincronizar()

	while cliente.vivo and not cliente.atendido and os.clock() < cliente.limite do
		task.wait(0.25)
	end
	if not cliente.vivo then
		return
	end
	if not cliente.atendido then
		decir(cliente, "Impaciente")
		TaskSystem.registrarPerdido()
	end

	-- Se va.
	local lugar = table.find(cola, cliente)
	if lugar then
		table.remove(cola, lugar)
	end
	if enMostrador == cliente then
		enMostrador = nil
	end
	TaskSystem.sincronizar()
	salir(cliente)
end

--- Un cliente llega al local (lo dispara el evento CLIENTE de NightData).
function CustomerSystem.llegar(datos)
	if #cola >= cfg.MaxEnCola then
		TaskSystem.registrarPerdido()
		return
	end
	contadorId += 1
	local cliente = {
		id = tostring(contadorId),
		tipo = datos.tipo,
		genero = datos.genero,
		danado = datos.danado == true,
		anomalo = datos.anomalo == true,
		socio = datos.socio == true,
		final = datos.final == true,
		vivo = true,
		atendido = false,
	}
	if modoNoche == "mismo" then
		cliente.numero = cliente.socio and "0000" or string.format("%04d", rng:NextInteger(100, 987))
	end
	activos[cliente.id] = cliente
	task.spawn(ciclo, cliente)
end

--- Lo que pide el cliente del mostrador (o nil). TaskSystem lo usa para las góndolas y la ficha.
function CustomerSystem.pedidoActual()
	local cliente = enMostrador
	if not cliente or cliente.atendido then
		return nil
	end
	return {
		tipo = cliente.final and "final" or cliente.tipo,
		genero = cliente.genero,
		casete = cliente.casete,
		asignarCasete = function(casete)
			cliente.casete = casete
			casete.alquiler = true
		end,
	}
end

--- El Socio, disfrazado de cliente, fue atendido como uno más: lo paga el equipo.
local function servidoElSocio(jugador: Player)
	SocioEntity.agregarProgreso(Config.Socio.PorSocioAtendido)
	NightManager.emitir("SERVIDO_SOCIO", { jugador = jugador })
end

--- Prompt "Atender": recibe una devolución, entrega el casete pedido o (noche 5) devuelve la cinta al Socio.
function CustomerSystem.usarMostrador(jugador: Player)
	local cliente = enMostrador
	if not cliente or cliente.atendido then
		Net.aviso(jugador, "No hay nadie en el mostrador.")
		return
	end

	if cliente.final then
		local mano = TapeItem.enMano(jugador)
		if mano and mano.sinEtiqueta then
			cliente.atendido = true
			TapeItem.consumir(mano)
			NightManager.emitir("FINAL_DEVOLVER", { jugador = jugador })
		else
			Net.aviso(jugador, "Espera algo: la cinta sin etiqueta. Tenés que tenerla en la mano.")
		end
		return
	end

	if cliente.tipo == "devolucion" then
		cliente.atendido = true
		local estado = if cliente.anomalo then "anomalo" elseif cliente.danado then "danado" else "normal"
		local casete = TapeItem.crear({
			titulo = Catalogo.tituloPara(cliente.genero, estado, rng),
			genero = cliente.genero,
			estado = estado,
			rebobinado = false,
		})
		local giro = CFrame.Angles(0, math.rad(rng:NextInteger(-20, 20)), 0)
		TapeItem.dejarEnMostrador(casete, CFrame.new(Config.Casetes.PosicionMostrador) * CFrame.Angles(math.rad(90), 0, 0) * giro)
		decir(cliente, "Gracias")
		TaskSystem.registrar("atender")
		if cliente.socio then
			servidoElSocio(jugador)
		end
		return
	end

	local mano = TapeItem.enMano(jugador)
	if mano and mano == cliente.casete then
		cliente.atendido = true
		TapeItem.consumir(mano)
		decir(cliente, "Gracias")
		TaskSystem.registrar("atender")
		if cliente.socio then
			servidoElSocio(jugador)
		end
	elseif mano then
		Net.aviso(jugador, "Ese no es el que pidió: quiere algo de " .. Catalogo.Nombres[cliente.genero] .. ".")
	else
		Net.aviso(jugador, "Pidió algo de " .. Catalogo.Nombres[cliente.genero] .. ". Sacale un casete de esa góndola.")
	end
end

--- Prompt "Rechazar cliente": sirve para echar al Socio; con un cliente normal se pierde la venta.
function CustomerSystem.rechazar(jugador: Player)
	local cliente = enMostrador
	if not cliente or cliente.atendido then
		Net.aviso(jugador, "No hay nadie en el mostrador.")
		return
	end
	if cliente.final then
		Net.aviso(jugador, "Este no se va a ir así nomás.")
		return
	end
	cliente.atendido = true
	if cliente.socio then
		hablar("Ya veo. Nos vemos pronto.")
		SocioEntity.agregarProgreso(Config.Socio.PorSocioRechazado)
		NightManager.emitir("RECHAZADO_SOCIO", { jugador = jugador })
		Net.aviso(jugador, "El cliente se fue sin decir nada más.")
	else
		TaskSystem.registrarPerdido()
		hablar("¿Cómo que no? Qué mala atención.")
		Net.aviso(jugador, "Rechazaste a un cliente normal.")
	end
end

-- Cuando termina la noche (o empieza otra) se borra todo lo que hubiera en el local.
local function reiniciar()
	for _, cliente in activos do
		destruir(cliente)
	end
	table.clear(cola)
	enMostrador = nil
	usosPuerta = 0
	fraseRepetida = {}
	if puerta then
		puerta.CanCollide = true
		puerta.Transparency = transparenciaCerrada
	end
end

function CustomerSystem.init()
	local local_ = workspace:FindFirstChild("Videoclub")
	puerta = local_ and local_:FindFirstChild("PuertaEntrada", true) or nil
	if puerta then
		transparenciaCerrada = puerta.Transparency
	else
		warn("[CustomerSystem] No se encontró la puerta de entrada (Workspace.Videoclub.PuertaEntrada)")
	end
	prepararBarreraDePuerta()

	carpeta = workspace:FindFirstChild("Clientes") or Instance.new("Folder")
	carpeta.Name = "Clientes"
	carpeta.Parent = workspace

	TaskSystem.registrarFuentePedido(CustomerSystem.pedidoActual)
	NightManager.suscribir("CLIENTE", CustomerSystem.llegar)
	NightManager.suscribir("NOCHE_INICIA", function(datos)
		-- El modo se fija antes de limpiar: si algo fallara al limpiar no puede quedar el de la noche anterior.
		local noche = NightData[datos.noche]
		modoNoche = noche and noche.clientesModo or "normal"
		reiniciar()
	end)
	NightManager.suscribir("NOCHE_TERMINA", reiniciar)
	NightManager.suscribir("SOCIO_MOSTRADOR", function()
		-- El Socio deja de moverse por el local y hace cola como un cliente más.
		SocioEntity.desactivar()
		CustomerSystem.llegar({ tipo = "alquiler", genero = "TERROR", socio = true, final = true })
	end)

	for _, instancia in CollectionService:GetTagged("PuntoMostrador") do
		if instancia:IsA("BasePart") then
			Prompts.crear(instancia, {
				clave = "mostrador",
				accion = "Atender",
				objeto = "Mostrador",
				distancia = 5.5,
				alActivar = CustomerSystem.usarMostrador,
			})
			Prompts.crear(instancia, {
				clave = "rechazar",
				accion = "Rechazar cliente",
				objeto = "Mostrador",
				hold = 1,
				distancia = 5.5,
				tecla = Enum.KeyCode.R,
				offset = Vector2.new(0, -100),
				alActivar = CustomerSystem.rechazar,
			})
		end
	end
end

return CustomerSystem
