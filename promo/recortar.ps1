# Recorta el centro 9:16 de una captura (para revisar cómo queda el clip vertical) y la achica a 360x640.
# Uso:  powershell -File promo\recortar.ps1 entrada.jpg salida.png [ancho alto]
param([string]$Entrada, [string]$Salida, [int]$Ancho = 360, [int]$Alto = 640)
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile((Resolve-Path $Entrada))
$h = $img.Height
$w = [int][math]::Round($h * 9 / 16)
if ($w -gt $img.Width) { $w = $img.Width; $h = [int][math]::Round($w * 16 / 9) }
$x = [int][math]::Round(($img.Width - $w) / 2)
$y = [int][math]::Round(($img.Height - $h) / 2)
$dst = New-Object System.Drawing.Bitmap $Ancho, $Alto
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $Ancho, $Alto), (New-Object System.Drawing.Rectangle $x, $y, $w, $h), [System.Drawing.GraphicsUnit]::Pixel)
$dst.Save((Join-Path (Get-Location) $Salida), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $dst.Dispose(); $img.Dispose()
Write-Output "ok $Salida"
