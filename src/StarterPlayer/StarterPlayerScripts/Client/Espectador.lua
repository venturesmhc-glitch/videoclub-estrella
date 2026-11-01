--!nonstrict
--[[
	Espectador (cliente): lo que ve el jugador que quedó fuera de la noche (el servidor le pone el atributo "Espectador").
	  - La cámara sigue a un compañero que sigue en pie (se cambia con ◀ ▶, las flechas o A/D).
	  - El mundo se ve distorsionado: sin color, azulado, desenfocado, con el filtro VHS al medio y un leve bamboleo.
	  - El monstruo no aparece (se esconde su modelo solo para este jugador) ni los sustos suaves.
	  - Botón "REVIVIR": abre la compra con Robux (Tienda); si se paga, vuelve a jugar al instante.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local VHSEffects = require(script.Parent.VHSEffects)

local Espectador = {}

local cfg = Config.Espectador
local jugador = Players.LocalPlayer
local activo = false
local gui, titulo, nombreObjetivo
local correccion, desenfoque
local indice = 1
local conexiones = {}

local FUENTE = Enum.Font.Code
local COLOR = Color3.fromRGB(190, 205, 255)

local function vivos(): { Player }
	local lista = {}
	for _, otro in Players:GetPlayers() do
		if otro ~= jugador and not otro:GetAttribute("Espectador") then
			local personaje = otro.Character
			if personaje and personaje:FindFirstChild("HumanoidRootPart") then
				table.insert(lista, otro)
			end
		end
	end
	return lista
end

local function objetivoActual(): Player?
	local lista = vivos()
	if #lista == 0 then
		return nil
	end
	indice = ((indice - 1) % #lista) + 1
	return lista[indice]
end

local function cambiar(delta: number)
	indice += delta
	local o = objetivoActual()
	nombreObjetivo.Text = o and ("Mirando a " .. o.DisplayName) or "No queda nadie en pie"
end

local function boton(texto: string, posicion: UDim2, tamano: UDim2, alActivar)
	local b = Instance.new("TextButton")
	b.Size = tamano
	b.Position = posicion
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = Color3.new(0, 0, 0)
	b.BackgroundTransparency = 0.45
	b.AutoButtonColor = true
	b.Font = FUENTE
	b.TextScaled = true
	b.TextColor3 = COLOR
	b.Text = texto
	b.Parent = gui
	local borde = Instance.new("UIStroke")
	borde.Color = COLOR
	borde.Transparency = 0.4
	borde.Thickness = 2
	borde.Parent = b
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	relleno.Parent = b
	b.Activated:Connect(alActivar)
	return b
end

local function texto(contenido: string, posicion: UDim2, tamano: UDim2)
	local t = Instance.new("TextLabel")
	t.Size = tamano
	t.Position = posicion
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.BackgroundTransparency = 1
	t.Font = FUENTE
	t.TextScaled = true
	t.TextColor3 = COLOR
	t.Text = contenido
	t.Parent = gui
	return t
end

local function crearInterfaz()
	gui = Instance.new("ScreenGui")
	gui.Name = "Espectador"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80 -- debajo del filtro VHS (100) y del menú (90)
	gui.Enabled = false
	gui.Parent = jugador:WaitForChild("PlayerGui")
	titulo = texto("ESTÁS FUERA DE LA NOCHE", UDim2.fromScale(0.5, 0.07), UDim2.fromScale(0.5, 0.05))
	nombreObjetivo = texto("", UDim2.fromScale(0.5, 0.13), UDim2.fromScale(0.4, 0.04))
	boton("◀", UDim2.fromScale(0.3, 0.13), UDim2.fromScale(0.05, 0.05), function()
		cambiar(-1)
	end)
	boton("▶", UDim2.fromScale(0.7, 0.13), UDim2.fromScale(0.05, 0.05), function()
		cambiar(1)
	end)
	boton(string.format("REVIVIR · R$ %d", Config.Tienda.Precios.Revivir), UDim2.fromScale(0.5, 0.9), UDim2.fromScale(0.3, 0.07), function()
		Net.obtener("Comprar"):FireServer({ producto = "revivir" })
	end)
	texto("Tus compañeros siguen jugando. Ellos ven tu estatua en el motel.", UDim2.fromScale(0.5, 0.82), UDim2.fromScale(0.6, 0.035)).TextTransparency = 0.3
end

local function crearEfectos()
	correccion = Instance.new("ColorCorrectionEffect")
	correccion.Name = "EspectadorColor"
	correccion.Saturation = cfg.Saturacion
	correccion.Contrast = cfg.Contraste
	correccion.TintColor = cfg.Tinte
	correccion.Parent = Lighting
	desenfoque = Instance.new("BlurEffect")
	desenfoque.Name = "EspectadorDesenfoque"
	desenfoque.Size = cfg.Desenfoque
	desenfoque.Parent = Lighting
end

-- El monstruo no existe para el espectador: su modelo se vuelve invisible solo en esta pantalla.
local function esconderMonstruo()
	local socio = workspace:FindFirstChild("Socio0000")
	if not socio then
		return
	end
	for _, d in socio:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
end

local function encender()
	if activo then
		return
	end
	activo = true
	indice = 1
	gui.Enabled = true
	crearEfectos()
	VHSEffects.forzar(cfg.Peligro)
	cambiar(0)

	local camara = workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Scriptable
	local base = camara.FieldOfView
	local t0 = os.clock()
	RunService:BindToRenderStep("EspectadorCamara", Enum.RenderPriority.Camera.Value + 1, function()
		local o = objetivoActual()
		local raiz = o and o.Character and o.Character:FindFirstChild("HumanoidRootPart")
		local t = os.clock() - t0
		if raiz then
			local mira = raiz.CFrame.LookVector * Vector3.new(1, 0, 1)
			if mira.Magnitude < 0.1 then
				mira = Vector3.new(0, 0, -1)
			end
			local punto = raiz.Position + Vector3.new(0, cfg.Altura * 0.5, 0)
			local posicion = raiz.Position - mira.Unit * cfg.Distancia + Vector3.new(0, cfg.Altura, 0)
			camara.CFrame = CFrame.lookAt(posicion, punto)
		end
		-- Bamboleo lento: el mundo "respira" y se tuerce apenas.
		camara.CFrame *= CFrame.Angles(0, 0, math.rad(math.sin(t * 0.9) * cfg.OndaGrados))
		camara.FieldOfView = base + math.sin(t * 0.7) * 3
	end)
	table.insert(conexiones, task.spawn(function()
		while activo do
			esconderMonstruo()
			task.wait(0.25)
		end
	end))
	table.insert(conexiones, UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.Left or entrada.KeyCode == Enum.KeyCode.A then
			cambiar(-1)
		elseif entrada.KeyCode == Enum.KeyCode.Right or entrada.KeyCode == Enum.KeyCode.D then
			cambiar(1)
		end
	end))
end

local function apagar()
	if not activo then
		return
	end
	activo = false
	gui.Enabled = false
	for _, c in conexiones do
		if typeof(c) == "RBXScriptConnection" then
			c:Disconnect()
		elseif typeof(c) == "thread" then
			pcall(task.cancel, c)
		end
	end
	table.clear(conexiones)
	pcall(function()
		RunService:UnbindFromRenderStep("EspectadorCamara")
	end)
	if correccion then
		correccion:Destroy()
	end
	if desenfoque then
		desenfoque:Destroy()
	end
	VHSEffects.forzar(nil)
	local camara = workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Custom
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if humanoide then
		camara.CameraSubject = humanoide
	end
	-- El monstruo vuelve a verse.
	local socio = workspace:FindFirstChild("Socio0000")
	if socio then
		for _, d in socio:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			elseif d:IsA("Light") then
				d.Enabled = true
			end
		end
	end
end

function Espectador.estaActivo(): boolean
	return activo
end

function Espectador.init()
	crearInterfaz()
	local function revisar()
		if jugador:GetAttribute("Espectador") then
			encender()
		else
			apagar()
		end
	end
	jugador:GetAttributeChangedSignal("Espectador"):Connect(revisar)
	revisar()
end

return Espectador
