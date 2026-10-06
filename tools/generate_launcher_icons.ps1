# Resample the approved artwork into Android resources; no external dependencies.
param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sourcePath = Join-Path $ProjectRoot 'assets/branding/auto_electrician_app_icon.png'
$sourceImage = [Drawing.Image]::FromFile($sourcePath)
function Write-LauncherImage([string]$OutputPath, [int]$Size, [double]$ArtworkFraction) {
    $bitmap = [Drawing.Bitmap]::new($Size, $Size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $artworkSize = [int][Math]::Round($Size * $ArtworkFraction)
        $offset = [int][Math]::Round(($Size - $artworkSize) / 2)
        $graphics.DrawImage($sourceImage, $offset, $offset, $artworkSize, $artworkSize)
        [IO.Directory]::CreateDirectory((Split-Path $OutputPath -Parent)) | Out-Null
        $bitmap.Save($OutputPath, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
try {
    foreach ($density in @(
        @{Name='mdpi'; Size=48}, @{Name='hdpi'; Size=72},
        @{Name='xhdpi'; Size=96}, @{Name='xxhdpi'; Size=144},
        @{Name='xxxhdpi'; Size=192}
    )) {
        Write-LauncherImage (Join-Path $ProjectRoot "android/app/src/main/res/mipmap-$($density.Name)/ic_launcher.png") $density.Size 1
    }
    # 108 dp layer at xxxhdpi. Artwork fits in the central 60 dp with white padding.
    Write-LauncherImage (Join-Path $ProjectRoot 'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png') 432 (60.0 / 108.0)
} finally {
    $sourceImage.Dispose()
}
