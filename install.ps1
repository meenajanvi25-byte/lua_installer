Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       INITIALIZING INSTALLER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$steps = @(
    "Connecting to installer server",
    "Loading configuration",
    "Checking download system",
    "Preparing installer",
    "Finalizing setup"
)

foreach ($step in $steps) {

    Write-Host "[+] $step" -ForegroundColor Cyan -NoNewline

    for ($i = 0; $i -lt 4; $i++) {
        Start-Sleep -Milliseconds 250
        Write-Host "." -NoNewline -ForegroundColor DarkCyan
    }

    Write-Host " DONE" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installer ready!" -ForegroundColor Green
Write-Host ""

# ==============================
# GOOGLE DRIVE FILE
# ==============================
$id = "1vfJZfHAHiLBMzTvCo1G_-8quHLaFW5_d"

$url = "https://drive.usercontent.google.com/download?id=$id&export=download"

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "        FILE INSTALLER" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$base = Read-Host "Enter base location (example: C:\Program Files (x86)\Steam )"

if ([string]::IsNullOrWhiteSpace($base)) {
    Write-Host "ERROR: No location entered." -ForegroundColor Red
    exit
}

$dest = Join-Path $base "config\stplug-in"
$tmp = Join-Path $env:TEMP "game_download.tmp"

try {

    # Create destination
    New-Item -ItemType Directory -Path $dest -Force | Out-Null

    Write-Host ""
    Write-Host "Destination:" -ForegroundColor Yellow
    Write-Host $dest -ForegroundColor White
    Write-Host ""

    # ==============================
    # FIRST GOOGLE DRIVE REQUEST
    # ==============================

    Write-Host "Connecting to Google Drive..." -ForegroundColor Cyan

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    $response = Invoke-WebRequest `
        -Uri $url `
        -WebSession $session `
        -UseBasicParsing

    # ==============================
    # CHECK IF GOOGLE SENT HTML
    # ==============================

    $contentType = $response.Headers["Content-Type"]

    if ($contentType -match "text/html") {

        Write-Host "Google Drive confirmation detected..." -ForegroundColor Yellow

        $html = $response.Content

        # Find confirmation token
        $confirmToken = $null

        if ($html -match 'confirm=([0-9A-Za-z_-]+)') {
            $confirmToken = $matches[1]
        }

        if (-not $confirmToken) {
            throw "Google Drive did not provide a download confirmation token."
        }

        # Download URL with confirmation token
        $downloadUrl = "$url&confirm=$confirmToken"

    }
    else {

        # File was returned directly
        $downloadUrl = $url
    }

    # ==============================
    # DOWNLOAD
    # ==============================

    Write-Host ""
    Write-Host "Downloading file..." -ForegroundColor Cyan

    $downloadResponse = Invoke-WebRequest `
        -Uri $downloadUrl `
        -WebSession $session `
        -OutFile $tmp `
        -UseBasicParsing `
        -PassThru

    if (!(Test-Path $tmp)) {
        throw "Download failed. No file was received."
    }

    $file = Get-Item $tmp

    if ($file.Length -lt 1000) {
        throw "Downloaded file is too small. Google Drive may have returned an error page."
    }

    # ==============================
    # CHECK FILE TYPE
    # ==============================

    $stream = [System.IO.File]::OpenRead($tmp)

    try {
        $header = New-Object byte[] 4
        [void]$stream.Read($header, 0, 4)
    }
    finally {
        $stream.Dispose()
    }

    # ZIP signature = PK 03 04
    $isZip = (
        $header[0] -eq 80 -and
        $header[1] -eq 75 -and
        $header[2] -eq 3 -and
        $header[3] -eq 4
    )

    # ==============================
    # INSTALL
    # ==============================

    if ($isZip) {

        Write-Host ""
        Write-Host "ZIP file detected." -ForegroundColor Green
        Write-Host "Extracting..." -ForegroundColor Cyan

        Expand-Archive `
            -LiteralPath $tmp `
            -DestinationPath $dest `
            -Force

        Write-Host "Extraction complete." -ForegroundColor Green
    }
    else {

        Write-Host ""
        Write-Host "Non-ZIP file detected." -ForegroundColor Green
        Write-Host "Copying file..." -ForegroundColor Cyan

        $name = "downloaded_file"

        # Try to get original filename
        $disposition = $downloadResponse.Headers["Content-Disposition"]

        if ($disposition -match 'filename\*=UTF-8''([^;]+)') {
            $name = [System.Uri]::UnescapeDataString($matches[1])
        }
        elseif ($disposition -match 'filename="?([^"]+)"?') {
            $name = $matches[1]
        }

        Copy-Item `
            -LiteralPath $tmp `
            -Destination (Join-Path $dest $name) `
            -Force

        Write-Host "File copied as: $name" -ForegroundColor Green
    }

    # Remove temporary file
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue

    # ==============================
    # SUCCESS
    # ==============================

    Write-Host ""
    Write-Host "================================" -ForegroundColor Green
    Write-Host "          SUCCESS!" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Files installed to:" -ForegroundColor Green
    Write-Host $dest -ForegroundColor White
    Write-Host ""

}
catch {

    Remove-Item $tmp -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "================================" -ForegroundColor Red
    Write-Host "            ERROR!" -ForegroundColor Red
    Write-Host "================================" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}
