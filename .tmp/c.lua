local t = {}
for _, s in game.SoundService:GetChildren() do
	if s:IsA("Sound") then
		table.insert(t, s.Name .. " loaded=" .. tostring(s.IsLoaded) .. " dur=" .. string.format("%.1f", s.TimeLength) .. " vol=" .. string.format("%.2f", s.Volume) .. " playing=" .. tostring(s.Playing))
	end
end
return table.concat(t, "\n")
