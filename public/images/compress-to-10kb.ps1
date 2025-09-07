# ============================
# compress-to-10kb.ps1
# Ziel: Alle Bilder nach /images_tiny als .webp <= 10 KB
# ============================

$ErrorActionPreference = "Stop"

# Pfade anpassen
$InputDir  = "H:\github\ginas-landhaus\public\images"
$OutputDir = "H:\github\ginas-landhaus\public\images_tiny"

# Maximalgröße in Bytes (10 KB)
$TargetBytes = 10240

# Start-Dimension (größer -> bessere Qualität, aber evtl. >10KB)
$MaxDim = 640

# Unterstützte Eingaben
$exts = @("*.jpg","*.jpeg","*.png","*.webp")

# Check: magick vorhanden?
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
  Write-Host "❌ magick.exe nicht gefunden. Bitte ImageMagick installieren & PATH prüfen." -ForegroundColor Red
  exit 1
}

# Output-Ordner
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Hilfsfunktion: Ein Bild auf Zielgröße zwingen
function Compress-One {
  param(
    [string]$inPath,
    [string]$outPath,
    [int]$targetBytes,
    [int]$startDim
  )

  # 1) Erster Schuss mit target-size (schnell)
  & magick "$inPath" `
    -resize "${startDim}x${startDim}>" `
    -strip `
    -define "webp:method=6" `
    -define "webp:thread-level=1" `
    -define "webp:target-size=$targetBytes" `
    "$outPath" 2>$null

  if (Test-Path "$outPath") {
    if ( (Get-Item "$outPath").Length -le $targetBytes ) { return $true }
  }

  # 2) Iteratives Downsizing
  $tryDims      = @($startDim, 560, 480, 360, 320, 240, 160)
  $tryQualities = @(60,50,40,30,20,10,5,1)

  foreach ($d in $tryDims) {
    foreach ($q in $tryQualities) {
      & magick "$inPath" `
        -resize "${d}x${d}>" `
        -strip `
        -define "webp:method=6" `
        -quality $q `
        "$outPath" 2>$null

      if (Test-Path "$outPath") {
        $size = (Get-Item "$outPath").Length
        if ($size -le $targetBytes) { return $true }
      }
    }
  }

  # 3) Brechstange (sehr klein, sehr hässlich – aber sicher unter 10 KB)
  & magick "$inPath" `
    -resize "160x160>" `
    -strip `
    -define "webp:method=6" `
    -quality 1 `
    "$outPath" 2>$null

  if (Test-Path "$outPath") {
    return ((Get-Item "$outPath").Length -le $targetBytes)
  }

  return $false
}

# Lauf
Get-ChildItem -Path $InputDir -Recurse -Include $exts | ForEach-Object {
  $in = $_.FullName
  $rel = $in.Substring($InputDir.Length).TrimStart('\','/')

  # 0-Byte-Dateien überspringen
  if ($_.Length -eq 0) {
    Write-Host "⏭  Skip (0 B): $rel"
    return
  }

  # Zielpfad (gleiche Struktur, aber .webp)
  $outRel = [System.IO.Path]::ChangeExtension($rel, ".webp")
  $out = Join-Path $OutputDir $outRel
  New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($out)) | Out-Null

  $ok = Compress-One -inPath $in -outPath $out -targetBytes $TargetBytes -startDim $MaxDim

  if ($ok) {
    $size = (Get-Item $out).Length
    Write-Host ("✅ OK  ({0,6} B)  " -f $size) $rel "->" (Resolve-Path $out).Path
  } else {
    if (Test-Path $out) { $size = (Get-Item $out).Length } else { $size = 0 }
    Write-Host ("⚠️  FAIL({0,6} B)  " -f $size) $rel "  (nicht <= 10 KB trotz Max-Reduktion)" -ForegroundColor Yellow
  }
}
