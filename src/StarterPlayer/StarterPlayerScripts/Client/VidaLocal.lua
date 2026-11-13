--!nonstrict
--[[
	VidaLocal (cliente): pequeños movimientos de la decoración del salón (build/decoracion.lua) para que el local no se sienta quieto.
	  * Tag "TVEstatica": las rayas de la estática de los televisores se reacomodan varias veces por segundo.
	  * Tag "ArcadeParpadeo": los carteles "INSERT COIN" / "PRESS START" de los arcades titilan.
	Todo es local a cada pantalla (son GuiObjects de SurfaceGui), no cuesta nada de red.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local VidaLocal = {}

local rng = Random.new()

function VidaLocal.init()
	local estaticas, parpadeos = {}, {}
	local function registrar(lista)
		return function(obj)
			lista[obj] = true
			obj.Destroying:Once(function()
				lista[obj] = nil
			end)
		end
	end
	for _, o in CollectionService:GetTagged("TVEstatica") do
		registrar(estaticas)(o)
	end
	for _, o in CollectionService:GetTagged("ArcadeParpadeo") do
		registrar(parpadeos)(o)
	end
	CollectionService:GetInstanceAddedSignal("TVEstatica"):Connect(registrar(estaticas))
	CollectionService:GetInstanceAddedSignal("ArcadeParpadeo"):Connect(registrar(parpadeos))

	local tEstatica, tParpadeo, encendido = 0, 0, true
	RunService.Heartbeat:Connect(function(dt)
		tEstatica += dt
		if tEstatica >= 0.1 then
			tEstatica = 0
			for fondo in estaticas do
				for _, f in fondo:GetChildren() do
					if f:IsA("Frame") then
						local g = rng:NextInteger(30, 235)
						f.BackgroundColor3 = Color3.fromRGB(g, g, g)
						f.Position = UDim2.fromScale(rng:NextNumber(0, 0.8), rng:NextNumber(0, 1))
					end
				end
			end
		end
		tParpadeo += dt
		if tParpadeo >= 0.6 then
			tParpadeo = 0
			encendido = not encendido
			for texto in parpadeos do
				texto.Visible = encendido
			end
		end
	end)
end

return VidaLocal
