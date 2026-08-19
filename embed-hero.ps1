# Embeds the hero aircraft (transparent PNG cutout of a United 787) into
# index.html as a data URI, between the HERO-BG-START/END CSS markers.
# Trims transparent margins and downsizes; re-run if you swap the image.
$src = 'C:\Users\jacob\OneDrive\Documents\Boeing_and_United_Airlines_787s.png'

Add-Type -AssemblyName System.Drawing
$img = New-Object System.Drawing.Bitmap $src

# bounding box of non-transparent pixels (sampled every 4px for speed)
$minX = $img.Width; $minY = $img.Height; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $img.Height; $y += 4) {
  for ($x = 0; $x -lt $img.Width; $x += 4) {
    if ($img.GetPixel($x, $y).A -gt 20) {
      if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$pad = 12
$minX = [Math]::Max(0, $minX - $pad); $minY = [Math]::Max(0, $minY - $pad)
$maxX = [Math]::Min($img.Width - 1, $maxX + $pad); $maxY = [Math]::Min($img.Height - 1, $maxY + $pad)
$cw = $maxX - $minX; $ch = $maxY - $minY

$outW = 1000; $outH = [int]($ch * $outW / $cw)
$bmp = New-Object System.Drawing.Bitmap $outW, $outH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $outW, $outH),
  (New-Object System.Drawing.Rectangle $minX, $minY, $cw, $ch), [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $img.Dispose()

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$b64 = [Convert]::ToBase64String($ms.ToArray())
$ms.Dispose()

$path = Join-Path $PSScriptRoot 'index.html'
$html = [System.IO.File]::ReadAllText($path)
$pattern = '(?s)/\* HERO-BG-START \*/.*?/\* HERO-BG-END \*/'
if ($html -notmatch $pattern) { throw 'HERO-BG markers not found in index.html' }
$block = "/* HERO-BG-START */ --hero-photo:url('data:image/png;base64,$b64'); /* HERO-BG-END */"
$html = [regex]::Replace($html, $pattern, $block.Replace('$', '$$'))
[System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding $false))
Write-Host ("aircraft embedded: trimmed {0}x{1} -> {2}x{3}, {4:n0} KB" -f $cw, $ch, $outW, $outH, ($b64.Length * 3 / 4 / 1KB))
