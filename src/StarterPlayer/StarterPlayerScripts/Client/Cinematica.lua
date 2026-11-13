--!nonstrict
--[[
	Cinematica (cliente): reproduce los clips de Shared/Cinematicas para grabarlos con OBS (TikTok / Reels / Shorts).
	Solo se carga con Config.Debug.ModoGrabacion = true (Main.client.lua); con false no existe.

	Qué hace:
	  * Oculta lo que no va en el video (ficha, barra de energía, menú, diálogos, carteles flotantes, prompts, contornos y la
	    interfaz de Roblox) pero deja el filtro VHS y el OSD de videocasetera.
	  * Toma la cámara (Scriptable), la mueve por los puntos del clip con curva suave + easing de TweenService y le suma un
	    temblor de cámara en mano. Usa el FOV de Config.Jugador.CamaraFOV salvo que el clip diga otro.
	  * Ejecuta los eventos del clip sincronizados: OSD, parpadeo de luces, Socio (con sus gestos reales), sonidos, estática, negro.
	  * Formato vertical (Config.Cinematicas.Vertical): se graba en 16:9 y se recorta el centro a 9:16; acá se abre el FOV, se echa
	    atrás la cámara y el OSD queda dentro de la franja central, sin texto en el 10% de arriba ni en el 15% de abajo.

	Se lanza desde el servidor:  node dbg.js cine NOMBRE [desde] [foto]
	  desde = segundo del clip por el que empezar (para revisar un plano), foto = congela el clip en ese segundo.
	Atributos de ReplicatedStorage: CineClip (nombre o ""), CineId (cambia con cada pedido), CineDesde, CineFoto.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cinematicas = require(ReplicatedStorage.Shared.Cinematicas)
local Personajes = require(ReplicatedStorage.Shared.Personajes)
local SocioHuesos = require(ReplicatedStorage.Shared.SocioHuesos)
local Trepador = require(script.Parent.Trepador)
local AudioManager = require(script.Parent.AudioManager)
local LuzFluorescente = require(script.Parent.LuzFluorescente)
local OSD = require(script.Parent.OSD)
local VHSEffects = require(script.Parent.VHSEffects)

local Cinematica = {}

local cfg = Config.Cinematicas
local enc = cfg.Encuadre
local sesion -- clip en marcha: { clip, nombre, t0, desde, foto, objetos, conexiones, indice, socio, ... }
local gui, capaNegra, guia
local ocultoListo = false
local personaje -- { raiz, cframe, anclada } para devolver al jugador
local ID_PASO = "Cinematica"

-- ===== Interfaz propia =====

local function crearGui()
	if gui then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "CinematicaUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 500 -- encima del OSD (110) y del filtro (100): el negro tapa todo
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	capaNegra = Instance.new("Frame")
	capaNegra.Name = "Negro"
	capaNegra.Size = UDim2.fromScale(1, 1)
	capaNegra.BackgroundColor3 = Color3.new(0, 0, 0)
	capaNegra.BackgroundTransparency = 1
	capaNegra.BorderSizePixel = 0
	capaNegra.ZIndex = 10
	capaNegra.Parent = gui
end

--- Cuánta pantalla ocupa el recorte vertical, centrado: { x0, x1, y0, y1 } en fracciones.
local function franjaVertical()
	local camara = workspace.CurrentCamera
	local vp = camara.ViewportSize
	local ancho = math.min(1, enc.Relacion * vp.Y / math.max(vp.X, 1))
	return { x0 = 0.5 - ancho / 2, x1 = 0.5 + ancho / 2, y0 = enc.MargenSuperior, y1 = 1 - enc.MargenInferior, margenX = enc.MargenLateral }
end

--- Guía para encuadrar: oscurece lo que se pierde en el recorte y marca las zonas libres de texto. Solo con Config.Cinematicas.GuiaVertical.
local function dibujarGuia()
	if guia then
		guia:Destroy()
		guia = nil
	end
	if not (cfg.GuiaVertical and cfg.Vertical) then
		return
	end
	local r = franjaVertical()
	guia = Instance.new("Folder")
	guia.Name = "Guia"
	guia.Parent = gui
	local function barra(x, y, w, h, transparencia, color)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color or Color3.new(0, 0, 0)
		f.BackgroundTransparency = transparencia
		f.BorderSizePixel = 0
		f.ZIndex = 5
		f.Parent = guia
	end
	barra(0, 0, r.x0, 1, 0.35)
	barra(r.x1, 0, 1 - r.x1, 1, 0.35)
	barra(r.x0, 0, r.x1 - r.x0, r.y0, 0.8, Color3.fromRGB(255, 60, 60))
	barra(r.x0, r.y1, r.x1 - r.x0, 1 - r.y1, 0.8, Color3.fromRGB(255, 60, 60))
end

local function ajustarEncuadre()
	if cfg.Vertical then
		OSD.encuadre(franjaVertical())
	else
		OSD.encuadre(nil)
	end
	dibujarGuia()
end

local function negro(alfa: number, duracion: number?)
	crearGui()
	if duracion and duracion > 0 then
		TweenService:Create(capaNegra, TweenInfo.new(duracion, Enum.EasingStyle.Linear), { BackgroundTransparency = 1 - alfa }):Play()
	else
		capaNegra.BackgroundTransparency = 1 - alfa
	end
end

-- ===== Ocultar lo que no va en el video =====

local function ocultarJuego()
	if ocultoListo then
		return
	end
	ocultoListo = true
	local jugador = Players.LocalPlayer
	local playerGui = jugador:WaitForChild("PlayerGui")

	local nombres = {}
	for _, n in cfg.OcultarGui do
		nombres[n] = true
	end
	local function revisarGui(g)
		if g:IsA("ScreenGui") and nombres[g.Name] then
			g.Enabled = false
			g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if g.Enabled then
					g.Enabled = false
				end
			end)
		end
	end
	for _, g in playerGui:GetChildren() do
		revisarGui(g)
	end
	playerGui.ChildAdded:Connect(revisarGui)

	-- Carteles flotantes (teléfono sonando, etc.), "E ..." de los prompts y contornos de las tareas.
	local function revisarMundo(d)
		if d:IsA("BillboardGui") then
			d.Enabled = false
		elseif d:IsA("ProximityPrompt") then
			d.Style = Enum.ProximityPromptStyle.Custom
		elseif d:IsA("Highlight") then
			d.Enabled = false
		end
	end
	for _, d in workspace:GetDescendants() do
		revisarMundo(d)
	end
	workspace.DescendantAdded:Connect(revisarMundo)

	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false) then
				break
			end
			task.wait(0.5)
		end
	end)
end

--- El personaje del jugador sale del plano: queda anclado bajo el mapa mientras dura el clip.
local function esconderJugador()
	local personajeJ = Players.LocalPlayer.Character
	local raiz = personajeJ and personajeJ:FindFirstChild("HumanoidRootPart")
	if not raiz or personaje then
		return
	end
	personaje = { raiz = raiz, cframe = raiz.CFrame, anclada = raiz.Anchored }
	raiz.Anchored = true
	raiz.CFrame = CFrame.new(0, -40, 0)
end

local function devolverJugador()
	if personaje and personaje.raiz.Parent then
		personaje.raiz.CFrame = personaje.cframe
		personaje.raiz.Anchored = personaje.anclada
	end
	personaje = nil
end

-- ===== Cámara =====

local function facilidad(nombre: string?, a: number): number
	if not nombre or nombre == "Linear" then
		return a
	end
	local ok, estilo = pcall(function()
		return Enum.EasingStyle[nombre]
	end)
	if not ok then
		return a
	end
	return TweenService:GetValue(a, estilo, Enum.EasingDirection.InOut)
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: number): Vector3
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (3 * p1 - p0 - 3 * p2 + p3) * u3)
end

--- Pose de la cámara guiada en el instante t: posición, punto al que mira, fov y giro.
local function muestrear(camara: { any }, t: number)
	local n = #camara
	if t <= camara[1].t then
		local k = camara[1]
		return k.pos, k.mira, k.fov, k.giro or 0, k.sinAjuste
	end
	if t >= camara[n].t then
		local k = camara[n]
		return k.pos, k.mira, k.fov, k.giro or 0, k.sinAjuste
	end
	local i = 1
	while i < n - 1 and t >= camara[i + 1].t do
		i += 1
	end
	local a, b = camara[i], camara[i + 1]
	if b.corte then
		-- Corte de plano: hasta llegar a b.t se queda en a; en b.t salta (sin curva entre uno y otro).
		return a.pos, a.mira, a.fov, a.giro or 0, a.sinAjuste
	end
	local alfa = (t - a.t) / math.max(b.t - a.t, 1e-4)
	local u = facilidad(b.ease or (n == 2 and "Sine" or nil), alfa)
	-- Vecinos para la curva: no se mezclan planos distintos (si a o b están pegados a un corte, se repite el punto).
	local k0, k3 = camara[math.max(i - 1, 1)], camara[math.min(i + 2, n)]
	if a.corte then
		k0 = a
	end
	if camara[i + 2] and camara[i + 2].corte then
		k3 = b
	end
	local pos = catmull(k0.pos, a.pos, b.pos, k3.pos, u)
	local mira = catmull(k0.mira, a.mira, b.mira, k3.mira, u)
	local fa, fb = a.fov, b.fov
	local fov = if fa and fb then fa + (fb - fa) * u else (fb or fa)
	local giro = (a.giro or 0) + ((b.giro or 0) - (a.giro or 0)) * u
	return pos, mira, fov, giro, a.sinAjuste or b.sinAjuste
end

--- Temblor de cámara en mano: ruido suave (no aleatorio de cuadro a cuadro) en posición y giro.
local function mano(t: number, escala: number): CFrame
	local m = cfg.Mano
	local f = m.Frecuencia
	local n = function(semilla: number, vel: number)
		return math.noise(t * f * vel, semilla, 0.37) * 2
	end
	local pos = Vector3.new(n(1, 1), n(2, 1.3), n(3, 0.8)) * m.Posicion * escala
	local rot = CFrame.Angles(math.rad(n(4, 1.1) * m.Giro * escala), math.rad(n(5, 0.9) * m.Giro * escala), math.rad(n(6, 0.7) * m.Giro * 0.6 * escala))
	return CFrame.new(pos) * rot
end

local function poseCamara(s, t: number)
	local clip = s.clip
	local pos, mira, fovPunto, giro, sinAjuste = muestrear(clip.camara, t)
	local fov = fovPunto or clip.fov or Config.Jugador.CamaraFOV
	if cfg.Vertical and not sinAjuste then
		fov = math.min(fov * enc.FovFactor, enc.FovMax)
		local dir = mira - pos
		if dir.Magnitude > 1e-3 then
			pos -= dir.Unit * enc.Retroceso
		end
	end
	local cf = CFrame.lookAt(pos, mira) * CFrame.Angles(0, 0, math.rad(giro))
	return cf * mano(t, clip.mano or 1), fov
end

-- ===== Socio =====

local function socioAparecer(s, e)
	if s.socio then
		s.socio.modelo:Destroy()
		s.socio = nil
	end
	local modelo = Personajes.crearSocioMalla(Config.Socio)
	if not modelo then
		warn("[Cinematica] No se pudo armar el Socio (falta ReplicatedStorage.SocioModelo)")
		return
	end
	modelo.Name = "SocioCine" -- (no "Socio0000": ese nombre lo toman SocioAnimacion y LuzFluorescente)
	local pos = e.pos or Vector3.zero
	local cf
	if e.mira then
		cf = CFrame.lookAt(pos, Vector3.new(e.mira.X, pos.Y, e.mira.Z))
	else
		cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(e.rot or 0), 0)
	end
	modelo:PivotTo(cf)
	modelo.Parent = workspace
	local huesos
	if modelo:GetAttribute("ConHuesos") then
		huesos = SocioHuesos.nuevo(modelo, { distanciaBoca = Config.Socio.BocaDistancia, anguloBoca = Config.Socio.BocaAngulo, suave = true })
		huesos.suavizar(0, 0)
		if e.azar == false then
			huesos.gestosAlAzar(false)
		end
	end
	s.socio = {
		modelo = modelo,
		huesos = huesos,
		quieto = e.quieto == true, -- "observado": la cabeza queda clavada de frente, ladeada, y no hace más que mover los dedos
		acumulado = 0,
		pos = pos,
		rot = select(2, cf:ToEulerAnglesYXZ()),
		encara = e.encara == true, -- true: siempre de frente a la cámara
		vel = 0,
		mov = nil,
	}
	table.insert(s.objetos, modelo)
end

local function socioQuitar(s)
	if s.socio then
		s.socio.modelo:Destroy()
		s.socio = nil
	end
end

--- Mueve al Socio hasta `pos` en `dur` segundos. tirones = { mueve, pausa }: avanza a sacudidas (mueve segundos andando, pausa
--- segundos clavado, y así), como se arrastra en el juego. dur = 0: aparece ahí de golpe.
local function socioMover(s, e)
	local so = s.socio
	if not so then
		return
	end
	local destino = Vector3.new(e.pos.X, e.pos.Y or so.pos.Y, e.pos.Z)
	if s.saltando or not e.dur or e.dur <= 0 then
		so.pos, so.mov = destino, nil
	else
		so.mov = { desde = so.pos, hasta = destino, t0 = os.clock(), dur = e.dur, tirones = e.tirones }
	end
end

--- Cuánto del trayecto (0 a 1) lleva recorrido a los te segundos, con o sin sacudidas.
local function avance(m, te: number): number
	if te >= m.dur then
		return 1
	end
	local k = m.tirones
	if not k then
		return te / m.dur
	end
	local ciclo = k[1] + k[2]
	local andando = math.floor(te / ciclo) * k[1] + math.min(te % ciclo, k[1])
	local total = m.dur / ciclo * k[1]
	return math.min(andando / total, 1)
end

local function socioPaso(s, dt: number, camaraPos: Vector3)
	local so = s.socio
	if not (so and so.modelo.Parent) then
		return
	end
	local velocidad = 0
	if so.mov then
		local p = avance(so.mov, os.clock() - so.mov.t0)
		local nueva = so.mov.desde:Lerp(so.mov.hasta, p)
		velocidad = (nueva - so.pos).Magnitude / math.max(dt, 1e-3)
		so.pos = nueva
		if p >= 1 then
			so.mov = nil
		end
	end
	so.vel += (velocidad - so.vel) * (1 - math.exp(-dt * 8))
	if so.encara then
		local d = Vector3.new(camaraPos.X - so.pos.X, 0, camaraPos.Z - so.pos.Z)
		if d.Magnitude > 1e-3 then
			so.rot = select(2, CFrame.lookAt(Vector3.zero, d):ToEulerAnglesYXZ())
		end
	end
	so.modelo:PivotTo(CFrame.new(so.pos) * CFrame.Angles(0, so.rot, 0))
	if not so.huesos then
		return
	end
	so.huesos.suavizar(dt, so.vel)
	so.acumulado += dt
	if so.acumulado >= Config.Socio.TickSeg then
		so.acumulado = 0
		local distancia = Vector3.new(camaraPos.X - so.pos.X, 0, camaraPos.Z - so.pos.Z).Magnitude
		so.huesos.actualizar(Config.Socio.TickSeg, true, so.quieto, false, distancia, camaraPos)
	end
end

-- ===== Linterna del jugador (la misma luz que la del juego, Client/Linterna) =====

local function linterna(s, e)
	if not s.linterna then
		local parte = Instance.new("Part")
		parte.Name = "LinternaCine"
		parte.Size = Vector3.new(0.2, 0.2, 0.2)
		parte.Transparency = 1
		parte.Anchored = true
		parte.CanCollide = false
		parte.CanQuery = false
		parte.CanTouch = false
		local luz = Instance.new("SpotLight")
		luz.Angle = 58
		luz.Range = 55
		luz.Brightness = 5
		luz.Color = Color3.fromRGB(255, 244, 214)
		luz.Shadows = true
		luz.Enabled = false
		luz.Parent = parte
		parte.Parent = workspace
		s.linterna = { parte = parte, luz = luz }
		table.insert(s.objetos, parte)
	end
	s.linterna.luz.Enabled = e.on == true
end

local function linternaPaso(s, camaraCF: CFrame)
	if s.linterna then
		s.linterna.parte.CFrame = camaraCF * CFrame.new(0.4, -0.3, -0.5)
	end
end

-- ===== Trepador (la criatura de las anomalías, con sus gestos reales) =====

--- Pose de los pies sobre una superficie: arriba = normal de la superficie (el techo: hacia abajo), adelante = hacia dónde mira.
local function orientacionSuperficie(pos: Vector3, arriba: Vector3, adelante: Vector3): CFrame
	local f = adelante - arriba * adelante:Dot(arriba)
	if f.Magnitude < 1e-3 then
		f = if math.abs(arriba.Y) > 0.9 then Vector3.new(0, 0, -1) else Vector3.new(0, 1, 0)
	end
	f = f.Unit
	return CFrame.fromMatrix(pos, f:Cross(arriba), arriba, -f)
end

local function trepadorQuitar(s)
	if s.trepador then
		s.trepador.obj.destruir()
		s.trepador = nil
	end
end

local function trepadorAparecer(s, e)
	trepadorQuitar(s)
	local obj = Trepador.crear()
	if not obj then
		warn("[Cinematica] No se pudo armar el Trepador (falta ReplicatedStorage.TrepadorModelo)")
		return
	end
	obj.modelo.Parent = workspace
	local pos = e.pos or Vector3.new(0, Config.Anomalias.Reptar.Techo, 0)
	local arriba = (e.arriba or Vector3.new(0, -1, 0)).Unit -- normal de la superficie: por defecto el techo (cabeza abajo)
	local cf = orientacionSuperficie(pos, arriba, e.adelante or Vector3.new(0, 0, 1))
	if e.azar == false then
		obj.gestosAlAzar(false)
	end
	s.trepador = { obj = obj, cf = cf }
	obj.actualizar(cf, 1 / 60, nil)
	table.insert(s.objetos, obj.modelo)
end

local function trepadorPaso(s, dt: number, camaraPos: Vector3)
	local t = s.trepador
	if t and t.obj.modelo.Parent then
		t.obj.actualizar(t.cf, dt, camaraPos) -- la cabeza lo sigue a la cámara (a tirones)
	end
end

-- ===== Portadas de las góndolas (la anomalía "título que no existe") =====

--- Cambia (solo en esta pantalla) el título de una portada: id = su atributo PortadaId, por ejemplo "P_TERROR_1_3_7"
--- (P_GÉNERO_lado_fila_columna). Se restaura al terminar el clip.
local function portada(s, e)
	for _, p in CollectionService:GetTagged("Portada") do
		if p:GetAttribute("PortadaId") == e.id then
			local etiqueta = p:FindFirstChild("Etiqueta")
			local titulo = etiqueta and etiqueta:FindFirstChild("Papel") and etiqueta.Papel:FindFirstChild("Titulo")
			if titulo then
				s.portadas = s.portadas or {}
				if s.portadas[titulo] == nil then
					s.portadas[titulo] = titulo.Text
				end
				titulo.Text = e.titulo or ""
			end
			return
		end
	end
	warn("[Cinematica] No encontré la portada " .. tostring(e.id))
end

-- ===== Casete (el de la cinta sin etiqueta, igual que el de TapeItem) =====

local function casete(s, e)
	local acc = e.accion
	if acc == "quitar" then
		if s.casete then
			s.casete:Destroy()
			s.casete = nil
		end
		return
	end
	local function cframeDe(pos: Vector3, rot: Vector3?)
		local r = rot or Vector3.zero
		return CFrame.new(pos) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end
	if acc == "aparecer" then
		if s.casete then
			s.casete:Destroy()
		end
		local p = Instance.new("Part")
		p.Name = "CaseteCine"
		p.Size = Config.Casetes.Tamano
		p.Color = Config.Casetes.ColorSinEtiqueta
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CFrame = cframeDe(e.pos, e.rot)
		p.Parent = workspace
		s.casete = p
		table.insert(s.objetos, p)
	elseif acc == "mover" and s.casete then
		local meta = cframeDe(e.pos, e.rot)
		if s.saltando or not e.dur or e.dur <= 0 then
			s.casete.CFrame = meta
		else
			local ok, estilo = pcall(function()
				return Enum.EasingStyle[e.estilo or "Quad"]
			end)
			TweenService:Create(s.casete, TweenInfo.new(e.dur, ok and estilo or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = meta }):Play()
		end
	end
end

-- ===== Eventos =====

local function aplicarOSD(e)
	if e.estado then
		OSD.setEstado(e.estado)
	end
	if e.hora then
		OSD.sobrescribirFecha(nil)
		OSD.setHora(e.hora.noche or 1, e.hora.minuto or 0, "turno", e.hora.escala or (1 / 60))
	end
	if e.fecha ~= nil then
		OSD.sobrescribirFecha(e.fecha or nil)
	end
	if e.contador then
		OSD.setContador(e.contador)
	end
end

local ejecutar = {
	osd = function(_s, e)
		aplicarOSD(e)
	end,
	luz = function(s, e)
		s.usoLuz = true
		if e.patron then
			LuzFluorescente.patron(e.patron)
		elseif e.corte ~= nil then
			LuzFluorescente.cortarTodo(e.corte == true)
			s.corteLuz = e.corte == true
		end
	end,
	socio = function(s, e)
		if e.accion == "aparecer" then
			socioAparecer(s, e)
		elseif e.accion == "quitar" then
			socioQuitar(s)
		elseif e.accion == "gesto" and s.socio and s.socio.huesos then
			s.socio.quieto = false
			s.socio.huesos.gesto(e.gesto, e.lado, e.dur)
		elseif e.accion == "mover" then
			socioMover(s, e)
		elseif e.accion == "parar" and s.socio then
			s.socio.mov = nil
		elseif e.accion == "quieto" and s.socio then
			s.socio.quieto = e.valor == true -- true: lo están mirando (cabeza clavada de frente, ladeada)
		end
	end,
	portada = portada,
	linterna = linterna,
	trepador = function(s, e)
		if e.accion == "aparecer" then
			trepadorAparecer(s, e)
		elseif e.accion == "quitar" then
			trepadorQuitar(s)
		elseif e.accion == "gesto" and s.trepador then
			s.trepador.obj.gesto(e.gesto, e.lado, e.dur)
		end
	end,
	casete = casete,
	sonido = function(_s, e)
		AudioManager.efecto(e.id, { volumen = e.volumen, velocidad = e.velocidad, duracion = e.duracion, apagado = e.apagado, posicion = e.posicion })
	end,
	estatica = function(s, e)
		VHSEffects.forzar(e.peligro or 1)
		local token = (s.tokenEstatica or 0) + 1
		s.tokenEstatica = token
		task.delay(e.dur or 0.5, function()
			if sesion == s and s.tokenEstatica == token then
				VHSEffects.forzar(s.clip.vhs and s.clip.vhs.peligro or nil)
			end
		end)
	end,
	negro = function(_s, e)
		negro(e.alfa or 1, e.dur)
	end,
}

--- Estado que deja un evento ya pasado cuando se empieza a mitad del clip (los efectos de un instante no se repiten).
local ESTADO_PERSISTENTE = { linterna = true, osd = true, socio = true, negro = true, casete = true, trepador = true, portada = true }

-- ===== Reproducción =====

local function limpiar(s)
	RunService:UnbindFromRenderStep(ID_PASO)
	for _, c in s.conexiones do
		c:Disconnect()
	end
	for _, o in s.objetos do
		if typeof(o) == "Instance" then
			o:Destroy()
		end
	end
end

local function terminar(s, motivo: string?)
	if sesion ~= s then
		return
	end
	sesion = nil
	limpiar(s)
	if s.corteLuz then
		LuzFluorescente.cortarTodo(false)
	end
	for titulo, original in s.portadas or {} do
		titulo.Text = original
	end
	if s.ambientePrevio then
		game:GetService("Lighting").Ambient = s.ambientePrevio[1]
		game:GetService("Lighting").OutdoorAmbient = s.ambientePrevio[2]
	end
	if s.usoLuz then
		LuzFluorescente.patron({}) -- devuelve la luz si quedó en pleno parpadeo
	end
	VHSEffects.forzar(nil)
	VHSEffects.setIntensidad(1)
	OSD.sobrescribirFecha(nil)
	OSD.setEstado("PLAY")
	OSD.encuadre(nil)
	if guia then
		guia:Destroy()
		guia = nil
	end
	local camara = workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Custom
	camara.FieldOfView = Config.Jugador.CamaraFOV
	devolverJugador()
	if motivo == "fin" then
		print(string.format("[Cinematica] '%s' terminado", s.nombre))
	end
	negro(0, 0)
end

local function arrancar(nombre: string, desde: number, foto: boolean)
	local clip = Cinematicas.Clips[nombre]
	if not clip then
		warn("[Cinematica] No existe el clip " .. tostring(nombre))
		return
	end
	if sesion then
		terminar(sesion, "reemplazado")
	end
	crearGui()
	ocultarJuego()
	local s = { clip = clip, nombre = nombre, desde = desde, foto = foto, objetos = {}, conexiones = {}, indice = 1, t0 = nil }
	sesion = s

	-- Eventos en orden de tiempo.
	local eventos = table.clone(clip.eventos or {})
	table.sort(eventos, function(a, b)
		return a.t < b.t
	end)
	s.eventos = eventos

	-- Negro desde ya: los 3 s de espera no se ven (el primer cuadro del clip es limpio).
	negro(1, 0)
	esconderJugador()
	local camara = workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Scriptable
	ajustarEncuadre()
	table.insert(s.conexiones, camara:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEncuadre))

	-- Estado inicial del clip.
	if clip.ambiente then
		local L = game:GetService("Lighting")
		s.ambientePrevio = { L.Ambient, L.OutdoorAmbient }
		local k = clip.ambiente
		L.Ambient = Color3.new(L.Ambient.R * k, L.Ambient.G * k, L.Ambient.B * k)
		L.OutdoorAmbient = Color3.new(L.OutdoorAmbient.R * k, L.OutdoorAmbient.G * k, L.OutdoorAmbient.B * k)
	end
	VHSEffects.setIntensidad(clip.vhs and clip.vhs.intensidad or 1)
	VHSEffects.forzar(clip.vhs and clip.vhs.peligro or nil)
	OSD.setContador(0)
	aplicarOSD(clip.osd or {})
	-- Primer cuadro de la cámara ya puesto, para que no salte al empezar.
	local cf0, fov0 = poseCamara(s, desde)
	camara.CFrame = cf0
	camara.FieldOfView = fov0

	local espera = if foto then 0.5 else cfg.InicioSeg
	print(string.format("[Cinematica] '%s' (%s) arranca en %.1f s", nombre, clip.titulo, espera))
	task.delay(espera, function()
		if sesion ~= s then
			return
		end
		-- Los eventos anteriores al punto de partida dejan su estado (Socio en su lugar, OSD, negro); los efectos sueltos no.
		-- El reloj de la cinta arranca con el primer cuadro, no con la cuenta atrás (y antes de los eventos ya pasados, que lo pisan).
		OSD.setContador(0)
		aplicarOSD(clip.osd or {})
		s.saltando = true -- (los movimientos de los eventos que ya pasaron se aplican de golpe)
		while s.indice <= #eventos and eventos[s.indice].t < desde do
			local e = eventos[s.indice]
			if ESTADO_PERSISTENTE[e.tipo] then
				ejecutar[e.tipo](s, e)
			elseif e.tipo == "luz" and e.patron then
				-- Un parpadeo que todavía no terminó: sigue desde donde estaría (para revisar un plano a oscuras).
				local restante, acumulado = {}, e.t
				for i, dur in e.patron do
					if acumulado + dur > desde then
						if #restante == 0 and i % 2 == 0 then
							table.insert(restante, 0) -- (arrancó en un tramo de luz: se mantiene la alternancia oscuro/luz)
						end
						table.insert(restante, acumulado + dur - math.max(desde, acumulado))
					end
					acumulado += dur
				end
				if #restante > 0 then
					ejecutar.luz(s, { patron = restante })
				end
			end
			s.indice += 1
		end
		s.saltando = false
		negro(0, 0) -- (a menos que un evento ya dejara el negro puesto)
		for i = 1, s.indice - 1 do
			if eventos[i].tipo == "negro" then
				negro(eventos[i].alfa or 1, 0)
			end
		end
		s.t0 = os.clock()
		RunService:BindToRenderStep(ID_PASO, Enum.RenderPriority.Camera.Value + 1, function(dt)
			if sesion ~= s then
				return
			end
			local t = if foto then desde else desde + (os.clock() - s.t0)
			while s.indice <= #eventos and eventos[s.indice].t <= t do
				local e = eventos[s.indice]
				s.indice += 1
				local f = ejecutar[e.tipo]
				if f then
					local ok, err = pcall(f, s, e)
					if not ok then
						warn(string.format("[Cinematica] Evento %s en t=%.2f falló: %s", tostring(e.tipo), e.t, tostring(err)))
					end
				else
					warn("[Cinematica] Evento desconocido: " .. tostring(e.tipo))
				end
			end
			local cf, fov = poseCamara(s, t)
			camara.CFrame = cf
			camara.FieldOfView = fov
			socioPaso(s, dt, cf.Position)
			trepadorPaso(s, dt, cf.Position)
			linternaPaso(s, cf)
			if not foto and t >= clip.duracion then
				negro(1, 0)
				RunService:UnbindFromRenderStep(ID_PASO)
				task.delay(cfg.FinSeg, terminar, s, "fin")
			end
		end)
	end)
end

function Cinematica.reproducir(nombre: string, desde: number?, foto: boolean?)
	arrancar(nombre, desde or 0, foto == true)
end

function Cinematica.parar()
	if sesion then
		terminar(sesion, "parado")
	end
end

function Cinematica.init()
	crearGui() -- (el juego no se oculta hasta que arranca un clip: así el menú sigue andando mientras no se grabe)
	local function pedido()
		local nombre = ReplicatedStorage:GetAttribute("CineClip")
		if typeof(nombre) ~= "string" or nombre == "" then
			Cinematica.parar()
			return
		end
		arrancar(nombre, tonumber(ReplicatedStorage:GetAttribute("CineDesde")) or 0, ReplicatedStorage:GetAttribute("CineFoto") == true)
	end
	ReplicatedStorage:GetAttributeChangedSignal("CineId"):Connect(pedido)
	if ReplicatedStorage:GetAttribute("CineId") then
		pedido()
	end
	print("[Cinematica] Modo grabación listo. Lanzá un clip con: node dbg.js cine NOMBRE")
end

return Cinematica
