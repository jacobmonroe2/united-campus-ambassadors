# Embeds the official United logos into index.html as data URIs:
#  - white UNITED lockup -> header brand (#brandWord)
#  - globe square (blue) -> favicon
#  - blue UNITED lockup  -> About section (#lockupLogo)
# Re-run if the source files change.
$globeSrc  = 'C:\Users\jacob\Downloads\UAL-44813086.png'
$lockupSrc = 'C:\Users\jacob\Downloads\United-Airlines-Logo.png'
$whiteSrc  = 'C:\Users\jacob\Downloads\6616a25bd7e14940f4b0a007_white_logo-2 (2).png'

Add-Type -AssemblyName System.Drawing

function Resize-ToB64([System.Drawing.Image]$img, [System.Drawing.Rectangle]$srcRect, [int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $b64 = [Convert]::ToBase64String($ms.ToArray())
  $ms.Dispose()
  return $b64
}

# Globe: full frame, down to 76px (2x the 38px display size)
$globe = [System.Drawing.Image]::FromFile($globeSrc)
$globeB64 = Resize-ToB64 $globe (New-Object System.Drawing.Rectangle 0, 0, $globe.Width, $globe.Height) 76 76
$globe.Dispose()

# Lockup: find the bounding box of non-white pixels (sampled), then crop + shrink
$lock = New-Object System.Drawing.Bitmap $lockupSrc
$minX = $lock.Width; $minY = $lock.Height; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $lock.Height; $y += 6) {
  for ($x = 0; $x -lt $lock.Width; $x += 6) {
    $p = $lock.GetPixel($x, $y)
    if ($p.A -gt 40 -and ($p.R -lt 230 -or $p.G -lt 230 -or $p.B -lt 230)) {
      if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$pad = 10
$minX = [Math]::Max(0, $minX - $pad); $minY = [Math]::Max(0, $minY - $pad)
$maxX = [Math]::Min($lock.Width - 1, $maxX + $pad); $maxY = [Math]::Min($lock.Height - 1, $maxY + $pad)
$cw = $maxX - $minX; $ch = $maxY - $minY
$w = 320; $h = [int]($ch * $w / $cw)
$lockB64 = Resize-ToB64 $lock (New-Object System.Drawing.Rectangle $minX, $minY, $cw, $ch) $w $h
$lock.Dispose()
Write-Host ("lockup bbox: {0},{1} {2}x{3} -> {4}x{5}" -f $minX, $minY, $cw, $ch, $w, $h)

# White lockup: trim by alpha (white-on-transparent), keep transparency
$white = New-Object System.Drawing.Bitmap $whiteSrc
$minX = $white.Width; $minY = $white.Height; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $white.Height; $y += 6) {
  for ($x = 0; $x -lt $white.Width; $x += 6) {
    if ($white.GetPixel($x, $y).A -gt 40) {
      if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$pad = 8
$minX = [Math]::Max(0, $minX - $pad); $minY = [Math]::Max(0, $minY - $pad)
$maxX = [Math]::Min($white.Width - 1, $maxX + $pad); $maxY = [Math]::Min($white.Height - 1, $maxY + $pad)
$cw = $maxX - $minX; $ch = $maxY - $minY
$wh = 60; $ww = [int]($cw * $wh / $ch)   # 2x the 30px display height
$whiteB64 = Resize-ToB64 $white (New-Object System.Drawing.Rectangle $minX, $minY, $cw, $ch) $ww $wh
$white.Dispose()

# Inject into index.html
$path = Join-Path $PSScriptRoot 'index.html'
$html = [System.IO.File]::ReadAllText($path)

# Header: white lockup (matches either the old brand-mark tag or a previous
# brand-word tag, so the script stays re-runnable)
$brandTag = '<img class="brand-word" id="brandWord" alt="United" src="data:image/png;base64,' + $whiteB64 + '">'
$html = [regex]::Replace($html,
  '<img class="brand-(?:word" id="brandWord|mark" id="brandLogo)"[^>]*>',
  $brandTag.Replace('$', '$$'), 1)
# About section: blue globe tile (was the full wordmark lockup)
$html = [regex]::Replace($html, '(<img class="lockup" id="lockupLogo" alt="United Airlines" src=")[^"]*(">)',
  ('${1}data:image/png;base64,' + $globeB64 + '${2}'))

# Favicon: favicon-source.png (bold-line white globe on blue). Stepwise
# downscale + contrast lift keeps the white lattice legible at tab size; 16px
# and 32px renditions so browsers never re-shrink it themselves. Outside the
# ART markers; the published artifact keeps its emoji favicon.
function Shrink-Crisp([string]$src, [int]$to) {
  $img = [System.Drawing.Image]::FromFile($src)
  $side = [Math]::Min($img.Width, $img.Height)
  $cur = New-Object System.Drawing.Bitmap $side, $side
  $g = [System.Drawing.Graphics]::FromImage($cur)
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $side, $side),
    (New-Object System.Drawing.Rectangle 0, 0, $side, $side), [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $img.Dispose()
  while ($cur.Width / 2 -gt $to) {
    $half = [int]($cur.Width / 2)
    $next = New-Object System.Drawing.Bitmap $half, $half
    $g = [System.Drawing.Graphics]::FromImage($next)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($cur, 0, 0, $half, $half)
    $g.Dispose(); $cur.Dispose(); $cur = $next
  }
  $final = New-Object System.Drawing.Bitmap $to, $to
  $g = [System.Drawing.Graphics]::FromImage($final)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  # contrast lift so the white lattice stays white after averaging
  $cm = New-Object System.Drawing.Imaging.ColorMatrix
  $cm.Matrix00 = 1.35; $cm.Matrix11 = 1.35; $cm.Matrix22 = 1.35; $cm.Matrix33 = 1.0
  $cm.Matrix40 = -0.12; $cm.Matrix41 = -0.12; $cm.Matrix42 = -0.12; $cm.Matrix44 = 1.0
  $ia = New-Object System.Drawing.Imaging.ImageAttributes
  $ia.SetColorMatrix($cm)
  $g.DrawImage($cur, (New-Object System.Drawing.Rectangle 0, 0, $to, $to),
    0, 0, $cur.Width, $cur.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
  $g.Dispose(); $cur.Dispose()
  $ms = New-Object System.IO.MemoryStream
  $final.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $final.Dispose()
  $b64 = [Convert]::ToBase64String($ms.ToArray())
  $ms.Dispose()
  return $b64
}
$favSrc = Join-Path $PSScriptRoot 'favicon-source.png'
$fav = '<link rel="icon" type="image/png" sizes="32x32" href="data:image/png;base64,' + (Shrink-Crisp $favSrc 32) + '">' + "`n" +
       '<link rel="icon" type="image/png" sizes="16x16" href="data:image/png;base64,' + (Shrink-Crisp $favSrc 16) + '">'
if ($html -match '<link rel="icon"') {
  # consecutive icon links collapse into one match, so re-runs stay idempotent
  $html = [regex]::Replace($html, '(?:<link rel="icon"[^>]*>\s*)+', ($fav.Replace('$', '$$') + "`n"))
} else {
  $html = $html.Replace('<meta name="viewport" content="width=device-width, initial-scale=1">',
    "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">`n" + $fav)
}

[System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding $false))
Write-Host ("index.html updated: globe {0:n0} KB, blue lockup {1:n0} KB, white lockup {2:n0} KB" -f ($globeB64.Length * 3 / 4 / 1KB), ($lockB64.Length * 3 / 4 / 1KB), ($whiteB64.Length * 3 / 4 / 1KB))
