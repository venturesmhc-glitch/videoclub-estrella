# Junta varias capturas en una tira horizontal (revisión rápida).
# Uso: powershell -ExecutionPolicy Bypass -File promo\montaje.ps1 salida.png a.png b.png c.png ...
$Salida = $args[0]
$Entradas = $args[1..($args.Count - 1)]
Add-Type -AssemblyName System.Drawing
$imgs = @()
foreach ($e in $Entradas) { $imgs += [System.Drawing.Image]::FromFile((Resolve-Path $e).Path) }
$w = 0; $h = 0
foreach ($i in $imgs) { $w += $i.Width + 8; if ($i.Height -gt $h) { $h = $i.Height } }
$bmp = New-Object System.Drawing.Bitmap ([int]$w), ([int]$h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(40, 40, 40))
$x = 0
foreach ($i in $imgs) { $g.DrawImage($i, $x, 0, $i.Width, $i.Height); $x += $i.Width + 8; $i.Dispose() }
$bmp.Save((Join-Path (Get-Location) $Salida), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "ok $Salida"
