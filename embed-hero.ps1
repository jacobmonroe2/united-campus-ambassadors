# Embeds the hero background photo (United 787 in flight) into index.html as a
# data URI on the .hero rule, between the HERO-BG-START/END CSS markers.
# Re-run if you swap the photo. Source:
$src = 'C:\Users\jacob\Downloads\Boeing_and_United_Airlines_787s.jpg'

Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($src)

# Crop to a wide banner: keep the full width, take the band from near the top
# down through the clouds. 1900x1036 source -> ~2.45:1 band.
$cw = $img.Width
$ch = [int]($cw / 2.45)
$y  = [int](($img.Height - $ch) * 0.45)   # favor the upper-middle: plane + sky
$srcRect = New-Object System.Drawing.Rectangle 0, $y, $cw, $ch

$outW = 1600; $outH = [int]($outW / 2.45)
$bmp = New-Object System.Drawing.Bitmap $outW, $outH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $outW, $outH), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $img.Dispose()

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]78)
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, $codec, $ep)
$bmp.Dispose()
$b64 = [Convert]::ToBase64String($ms.ToArray())
$ms.Dispose()

$path = Join-Path $PSScriptRoot 'index.html'
$html = [System.IO.File]::ReadAllText($path)
$pattern = '(?s)/\* HERO-BG-START \*/.*?/\* HERO-BG-END \*/'
if ($html -notmatch $pattern) { throw 'HERO-BG markers not found in index.html' }
$block = "/* HERO-BG-START */ --hero-photo:url('data:image/jpeg;base64,$b64'); /* HERO-BG-END */"
$html = [regex]::Replace($html, $pattern, $block.Replace('$', '$$'))
[System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding $false))
Write-Host ("hero photo embedded: {0}x{1}, {2:n0} KB" -f $outW, $outH, ($b64.Length * 3 / 4 / 1KB))
