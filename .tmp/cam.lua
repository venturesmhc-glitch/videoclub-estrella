local RS = game:GetService("RunService")
local t0 = os.clock()
pcall(function() RS:UnbindFromRenderStep("Foto") end)
RS:BindToRenderStep("Foto", Enum.RenderPriority.Last.Value + 1, function()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(CAMX, CAMY, CAMZ), Vector3.new(MIRX, MIRY, MIRZ))
	if os.clock() - t0 > 60 then RS:UnbindFromRenderStep("Foto") end
end)
return "ok"
