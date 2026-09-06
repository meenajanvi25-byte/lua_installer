$ErrorActionPreference = "Stop"

# Your Google Drive file
$id = "1vfJZfHAHiLBMzTvCo1G_-8quHLaFW5_d"
$url = "https://drive.usercontent.google.com/download?id=$id&export=download"

Write-Host ""
Write-Host "=== FILE INSTALLER ===" -ForegroundColor Cyan
Write-Host ""

$base = Read-Host "Enter base location (example: \Program Files (x86)\Steam )"

if ([string]::IsNullOrWhiteSpace($base)) {
    Write-Host "ERROR: No location entered." -ForegroundColor Red
    exit
}

$dest = Join-Path $base "config\stplug-in"
$tmp = Join-Path $env:TEMP "game_download.tmp"

try {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null

    Write-Host ""
    Write-Host "Destination:" -ForegroundColor Yellow
    Write-Host $dest
    Write-Host ""
    Write-Host "Downloading..." -ForegroundColor Cyan

    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing

    if (!(Test-Path $tmp)) {
        throw "Download failed."
    }

    $file = Get-Item $tmp

    if ($file.Length -lt 10000) {
        $text = [System.IO.File]::ReadAllText($tmp)

        if ($text -match "<html|<!doctype|Google Drive|drive.google.com") {
            throw "Google Drive returned a webpage instead of the file. Make sure the file is shared as Anyone with the link."
        }
    }

    $bytes = [System.IO.File]::ReadAllBytes($tmp)
    $isZip = $bytes.Length -ge 4 -and
             $bytes[0] -eq 80 -and
             $bytes[1] -eq 75 -and
             $bytes[2] -eq 3 -and
             $bytes[3] -eq 4

    if ($isZip) {
        Write-Host "ZIP detected. Extracting..." -ForegroundColor Cyan
        Expand-Archive -LiteralPath $tmp -DestinationPath $dest -Force
    }
    else {
        Write-Host "File detected. Copying..." -ForegroundColor Cyan
        Copy-Item $tmp (Join-Path $dest "downloaded_file") -Force
    }

    Remove-Item $tmp -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "================================" -ForegroundColor Green
    Write-Host " SUCCESS!" -ForegroundColor Green
    Write-Host " Files installed to:" -ForegroundColor Green
    Write-Host $dest -ForegroundColor White
    Write-Host "================================" -ForegroundColor Green
}
catch {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "================================" -ForegroundColor Red
    Write-Host " ERROR!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "================================" -ForegroundColor Red
}
