local RS = game:GetService("RunService")
local t0 = os.clock()
pcall(function() RS:UnbindFromRenderStep("Foto") end)
RS:BindToRenderStep("Foto", Enum.RenderPriority.Last.Value + 1, function()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-27, 7, -4), Vector3.new(-40, 3, -14))
	if os.clock() - t0 > 60 then RS:UnbindFromRenderStep("Foto") end
end)
return "ok"
