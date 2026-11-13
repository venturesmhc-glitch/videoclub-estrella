--!nonstrict
--[[
	Depurar (servidor): comandos de prueba. Solo existe si Config.Debug.Comandos es true.
	Crea ServerStorage.Depurar (BindableFunction). Se usa desde la consola de Studio durante el Play,
	en el contexto del servidor:
	  game.ServerStorage.Depurar:Invoke("estado")
	  game.ServerStorage.Depurar:Invoke("saltar", 120)     -- avanza el reloj hasta ese minuto
	  game.ServerStorage.Depurar:Invoke("tomar")           -- el primer jugador toma un casete del mundo
	  game.ServerStorage.Depurar:Invoke("gondola", "TERROR")
	  game.ServerStorage.Depurar:Invoke("vcr") / "danadas" / "mostrador"
	Los comandos ejecutan la misma lógica que los prompts, como si el primer jugador los hubiera activado.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AnomalyJudge = require(script.Parent.AnomalyJudge)
local ChoreSystem = require(script.Parent.ChoreSystem)
local Partida = require(script.Parent.Partida)
local CursedTapeSystem = require(script.Parent.CursedTapeSystem)
local Criatura = require(script.Parent.Criatura)
local CustomerSystem = require(script.Parent.CustomerSystem)
local EndingSystem = require(script.Parent.EndingSystem)
local Mundo = require(script.Parent.Mundo)
local NightManager = require(script.Parent.NightManager)
local Persistencia = require(script.Parent.Persistencia)
local PhoneSystem = require(script.Parent.PhoneSystem)
local RulesSystem = require(script.Parent.RulesSystem)
local Salas = require(script.Parent.Salas)
local Fantasmas = require(script.Parent.Fantasmas)
local Insignias = require(script.Parent.Insignias)
local Screamers = require(script.Parent.Screamers)
local TareasMenores = require(script.Parent.TareasMenores)
local NightData = require(ReplicatedStorage.Shared.NightData)
local SocioEntity = require(script.Parent.SocioEntity)
local Tienda = require(script.Parent.Tienda)
local TapeItem = require(script.Parent.TapeItem)
local TaskSystem = require(script.Parent.TaskSystem)

local Depurar = {}

local function jugador(): Player?
	return Players:GetPlayers()[1]
end

local function descripcionMano(j: Player): string
	local c = TapeItem.enMano(j)
	if not c then
		return "nada"
	end
	return string.format("%s [%s, %s, rebobinado=%s]", c.titulo, c.genero, c.estado, tostring(c.rebobinado))
end

local comandos = {}

function comandos.estado()
	local e = NightManager.obtenerEstado()
	local lineas = { string.format("noche %d, fase %s, minuto %.1f", e.noche, e.fase, e.minuto) }
	for _, l in TaskSystem.resumen() do
		table.insert(lineas, "  " .. l)
	end
	local p = TaskSystem.pedidoActual()
	table.insert(lineas, "pedido: " .. (p and (p.tipo .. " " .. p.genero) or "ninguno"))
	local j = jugador()
	if j then
		table.insert(lineas, "en mano: " .. descripcionMano(j))
	end
	table.insert(lineas, "casetes en el mundo: " .. #TapeItem.enElMundo())
	return table.concat(lineas, "\n")
end

function comandos.saltar(minuto)
	NightManager.saltarA(tonumber(minuto) or 0)
	return "reloj -> " .. tostring(minuto)
end

function comandos.tomar()
	local j = jugador()
	local lista = TapeItem.enElMundo()
	if not j or #lista == 0 then
		return "no hay casetes para tomar"
	end
	TapeItem.tomar(j, lista[1])
	return "en mano: " .. descripcionMano(j)
end

function comandos.gondola(genero)
	TaskSystem.usarGondola(jugador(), genero)
	return "en mano: " .. descripcionMano(jugador())
end

function comandos.vcr()
	TaskSystem.usarVideocasetera(jugador())
	return "en mano: " .. descripcionMano(jugador())
end

function comandos.danadas()
	TaskSystem.usarCajaDanadas(jugador())
	return "en mano: " .. descripcionMano(jugador())
end

function comandos.mostrador()
	CustomerSystem.usarMostrador(jugador())
	return "en mano: " .. descripcionMano(jugador())
end

function comandos.cinta()
	local j = jugador()
	if TapeItem.enMano(j) then
		TapeItem.consumir(TapeItem.enMano(j))
	end
	TapeItem.tomar(j, TapeItem.crear({ titulo = "", genero = "TERROR", sinEtiqueta = true }))
	return "en mano: " .. descripcionMano(j)
end

--- Pruebas de las salas con Config.Salas.SimularNube: "salasim" resume la lista y los teletransportes anotados;
--- "salasim amigo" suma a un jugador falso a la primera sala pública (como si entrara desde otro servidor).
function comandos.salasim(accion)
	local lista = Salas.listar() or {}
	local partes = {}
	if accion == "amigo" and lista[1] then
		local registro, err = Salas.agregar({ UserId = 999, DisplayName = "Amigo" }, lista[1].codigo)
		table.insert(partes, "agregar=" .. tostring(registro ~= nil) .. " " .. tostring(err or ""))
	end
	table.insert(partes, "lista=" .. #lista .. (lista[1] and (" cod=" .. lista[1].codigo .. " " .. lista[1].jugadores .. "/" .. lista[1].maximo) or ""))
	table.insert(partes, "teleportes=" .. #Salas.teleportesSimulados)
	for _, t in Salas.teleportesSimulados do
		local nombres = {}
		for _, j in t.jugadores do
			table.insert(nombres, j.Name)
		end
		table.insert(partes, string.format("[%s -> %s tipo=%s sala=%s max=%s esperados=%s]", table.concat(nombres, ","), t.accessCode, t.datos.tipo, t.datos.sala, tostring(t.datos.maximo), tostring(t.datos.esperados)))
	end
	return table.concat(partes, " ")
end

--- "noches": cuántas tareas tiene cada noche según la cantidad de jugadores (1 a 4).
function comandos.noches()
	local partes = {}
	for n = 1, 5 do
		for cantidad = 1, 4, 3 do
			local d = NightData.paraJugadores(n, cantidad)
			local metas = {}
			for _, o in d.objetivos do
				table.insert(metas, o.id .. "=" .. o.meta)
			end
			table.insert(partes, string.format("N%d/%dJ eventos=%d {%s}", n, cantidad, #d.eventos, table.concat(metas, ",")))
		end
	end
	return table.concat(partes, " | ")
end

function comandos.radio(n)
	workspace:SetAttribute("RadioEstacion", tonumber(n) or 0)
	return "radio=" .. tostring(workspace:GetAttribute("RadioEstacion"))
end

--- "tareamenor ID": pide una tarea pequeña del local (PLANTA, FICHAS, CARTEL, VIDRIO, CAJA).
function comandos.tareamenor(id)
	TareasMenores.pedir(tostring(id or "PLANTA"))
	return "pedida " .. tostring(id or "PLANTA")
end

function comandos.screamer()
	Screamers.disparar()
	return "screamer enviado"
end

--- "espectador": deja fuera de la noche al jugador (sin pasar por las capturas); "revivir" lo trae de vuelta.
function comandos.espectador()
	Fantasmas.convertir(jugador())
	return "espectador=" .. tostring(Fantasmas.esFantasma(jugador()))
end

function comandos.revivir()
	SocioEntity.revivirJugador(jugador())
	return "espectador=" .. tostring(Fantasmas.esFantasma(jugador()))
end

--- comprar CLAVE [userId]: prueba una compra de la tienda (en Studio sin id de producto se aplica sin pagar).
function comandos.comprar(clave, objetivo)
	Tienda.pedirCompra(jugador(), clave or "", { objetivo = tonumber(objetivo) })
	return "compra pedida: " .. tostring(clave)
end

function comandos.socio()
	return SocioEntity.estadoTexto()
end

-- La criatura compartida del techo: la hace aparecer ahora.
function comandos.criatura()
	Criatura.forzar()
	return Criatura.estadoTexto()
end

function comandos.capturar()
	SocioEntity.capturarJugador(jugador())
	return SocioEntity.estadoTexto()
end

function comandos.socioaparecer(x, z)
	SocioEntity.activar(Vector3.new(tonumber(x) or 0, 0, tonumber(z) or -10))
	return SocioEntity.estadoTexto()
end

function comandos.progreso(valor)
	SocioEntity.agregarProgreso((tonumber(valor) or 0) - SocioEntity.progreso())
	return SocioEntity.estadoTexto()
end

function comandos.noche(n)
	NightManager.iniciarNoche(tonumber(n) or 1)
	return "noche " .. tostring(n)
end

--- Modo Sin fin: si todavía no empezó la partida la arranca en este modo; si no, salta a esa noche (por defecto la 1).
function comandos.sinfin(n)
	if Partida.estado().fase ~= "jugando" then
		Partida.forzarInicio("solo", "sinfin")
		return "arranca el modo Sin fin (noche 1)"
	end
	NightManager.fijarModo("sinfin")
	NightManager.iniciarNoche(tonumber(n) or 1)
	return "sin fin, noche " .. tostring(tonumber(n) or 1)
end

--- Marca un final (por defecto REBOBINAR) en el perfil del primer jugador: habilita el modo Sin fin sin jugar la historia.
function comandos.desbloquear(id)
	local j = jugador()
	if not j then
		return "no hay jugadores"
	end
	Persistencia.marcarFinal(j, id or "REBOBINAR")
	return Persistencia.estadoTexto()
end

function comandos.insignia(clave)
	local j = jugador()
	if not j then
		return "no hay jugadores"
	end
	return tostring(Insignias.otorgar(j, clave or "PRIMER_TURNO"))
end

function comandos.todo()
	return table.concat({
		comandos.estado(),
		comandos.socio(),
		"mundo: " .. Mundo.estadoTexto(),
		"reglas: " .. RulesSystem.estadoTexto(),
		"teléfono: " .. PhoneSystem.estadoTexto(),
		"cinta: reproducciones=" .. CursedTapeSystem.reproducciones(),
		"anomalías:\n" .. AnomalyJudge.estadoTexto(),
		"persistencia:\n" .. Persistencia.estadoTexto(),
	}, "\n")
end

function comandos.cliente(tipo, genero, extra)
	local datos = { tipo = tipo or "alquiler", genero = genero or "COMEDIA" }
	if extra == "socio" then
		datos.socio = true
	elseif extra == "anomalo" then
		datos.anomalo = true
	elseif extra == "danado" then
		datos.danado = true
	end
	CustomerSystem.llegar(datos)
	return "llega cliente " .. datos.tipo .. " " .. datos.genero
end

function comandos.rechazar()
	CustomerSystem.rechazar(jugador())
	return comandos.estado()
end

function comandos.final(id)
	EndingSystem.disparar(id)
	return "final " .. tostring(id)
end

function comandos.sonar(linea, mensaje)
	PhoneSystem.sonar({ linea = linea or "mostrador", mensaje = tonumber(mensaje), voz = tonumber(mensaje) == nil and mensaje or nil })
	return PhoneSystem.estadoTexto()
end

function comandos.atender(linea)
	PhoneSystem.atender(linea or "mostrador", jugador())
	return PhoneSystem.estadoTexto()
end

function comandos.anomalias()
	local j = jugador()
	local lineas = {}
	for _, a in AnomalyJudge.listaDe(j) do
		table.insert(lineas, string.format("%s %s -> %s (min %.0f)", a.id, a.tipo, a.objetivo, a.minuto))
	end
	return table.concat(lineas, "\n")
end

function comandos.reportar(id)
	AnomalyJudge.reportar(jugador(), { id = id })
	return AnomalyJudge.estadoTexto()
end

function comandos.evento(id, valor)
	NightManager.emitir(id, { valor = valor ~= "false", texto = valor, ids = { valor }, linea = valor })
	return "evento " .. tostring(id)
end

function comandos.empezar()
	Partida.forzarInicio("solo")
	return "partida iniciada (modo solo)"
end

function comandos.basura(zona)
	ChoreSystem.crearBolsa(zona or "LOCAL")
	return ChoreSystem.estadoTexto()
end

function comandos.derrame(zona)
	ChoreSystem.crearMancha(zona or "LOCAL")
	return ChoreSystem.estadoTexto()
end

function comandos.tarea(accion)
	ChoreSystem.probar(accion, jugador())
	return ChoreSystem.estadoTexto()
end

function comandos.pos()
	local j = jugador()
	local raiz = j and j.Character and j.Character:FindFirstChild("HumanoidRootPart")
	return raiz and tostring(raiz.Position) or "sin personaje"
end

function comandos.mover(x, z)
	local j = jugador()
	if j and j.Character then
		j.Character:PivotTo(CFrame.new(tonumber(x) or 0, 3.5, tonumber(z) or 0))
	end
	return comandos.pos()
end

--- Cinemáticas (solo con Config.Debug.ModoGrabacion): cine NOMBRE lanza el clip (arranca a los Config.Cinematicas.InicioSeg),
--- cine lista muestra los que hay, cine parar corta el que esté andando. El cliente (Client/Cinematica) lo recibe por atributos.
function comandos.cine(nombre, desde, foto)
	if not Config.Debug.ModoGrabacion then
		return "ModoGrabacion está apagado: poné Config.Debug.ModoGrabacion = true, node push.js y reiniciá el Play"
	end
	local Cinematicas = require(ReplicatedStorage.Shared.Cinematicas)
	if nombre == nil or nombre == "lista" then
		local lineas = {}
		for _, id in Cinematicas.orden do
			local clip = Cinematicas.Clips[id]
			table.insert(lineas, string.format("  %s  (%ds)  %s", id, clip.duracion, clip.titulo))
		end
		return "clips:\n" .. table.concat(lineas, "\n")
	end
	if nombre ~= "parar" and not Cinematicas.Clips[nombre] then
		return "no existe el clip '" .. tostring(nombre) .. "' (node dbg.js cine lista)"
	end
	ReplicatedStorage:SetAttribute("CineDesde", tonumber(desde) or 0) -- segundo por el que empezar (para revisar un plano)
	ReplicatedStorage:SetAttribute("CineFoto", foto == "foto" or foto == true) -- congela el clip en ese segundo
	ReplicatedStorage:SetAttribute("CineClip", nombre == "parar" and "" or nombre)
	ReplicatedStorage:SetAttribute("CineId", (ReplicatedStorage:GetAttribute("CineId") or 0) + 1)
	if nombre == "parar" then
		return "cinemática detenida"
	end
	return string.format("clip '%s' arranca en %d s: apretá REC en OBS", nombre, Config.Cinematicas.InicioSeg)
end

function Depurar.init()
	if not Config.Debug.Comandos then
		return
	end
	local funcion = ServerStorage:FindFirstChild("Depurar") or Instance.new("BindableFunction")
	funcion.Name = "Depurar"
	funcion.OnInvoke = function(nombre, ...)
		local comando = comandos[nombre]
		if not comando then
			return "comando desconocido: " .. tostring(nombre)
		end
		local ok, resultado = pcall(comando, ...)
		return ok and resultado or ("error: " .. tostring(resultado))
	end
	funcion.Parent = ServerStorage
end

return Depurar
