# =============================================================================
# scripts/add-milnueve-tracker.ps1
#
# Anade el tracker privado de MilNueve a TODOS los torrents actuales del
# qBittorrent nativo. NO toca archivos en disco, solo modifica la metadata
# del torrent (trackers). Tras anadir el tracker, los torrents privados
# empezaran a anunciarse a MilNueve y daran pares.
#
# Uso:
#   1. Abrir PowerShell COMO ADMIN (necesario para que el WebUI acepte
#      cambios via API).
#   2. Ejecutar: powershell -ExecutionPolicy Bypass -File add-milnueve-tracker.ps1
#
# El script:
#   1. Hace login al WebUI con tu API key.
#   2. Lista todos los torrents.
#   3. Para cada torrent, anade el tracker de MilNueve si no lo tiene ya.
#   4. Al final hace "Force Reannounce" de todos para que empiecen a hablar
#      con MilNueve inmediatamente.
# =============================================================================

# --- Configuracion ----------------------------------------------------------
$qbittorrentHost = "127.0.0.1"
$qbittorrentPort = 9090
$qbittorrentUsername = "salvavr"
$qbittorrentPassword = ""   # dejar vacio si no tiene password
$milnueveTracker = "https://tracker.milnueve.cc/announce/0d64abfb0ebd289a567dbfa802ecb896"

# --- 1. Login ---------------------------------------------------------------
Write-Host "[1/4] Login al WebUI de qBittorrent..." -ForegroundColor Cyan
$loginUrl = "http://${qbittorrentHost}:${qbittorrentPort}/api/v2/auth/login"
$loginBody = "username=${qbittorrentUsername}&password=${qbittorrentPassword}"

try {
    $loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginBody -ContentType "application/x-www-form-urlencoded" -SessionVariable session
    if ($loginResponse -ne "Ok.") {
        Write-Host "  ERROR: login fallo: $loginResponse" -ForegroundColor Red
        Write-Host "  Si tienes password, ponlo en la variable qbittorrentPassword del script" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  Login OK" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: no se pudo conectar al WebUI: $_" -ForegroundColor Red
    exit 1
}

# --- 2. Listar torrents ------------------------------------------------------
Write-Host "[2/4] Listando torrents..." -ForegroundColor Cyan
$torrentsUrl = "http://${qbittorrentHost}:${qbittorrentPort}/api/v2/torrents/info"
try {
    $torrents = Invoke-RestMethod -Uri $torrentsUrl -Method Get -WebSession $session
    Write-Host "  $($torrents.Count) torrents encontrados" -ForegroundColor Green
} catch {
    Write-Host "  ERROR listando torrents: $_" -ForegroundColor Red
    exit 1
}

# --- 3. Anadir tracker a cada torrent ---------------------------------------
Write-Host "[3/4] Anadiendo tracker de MilNueve a cada torrent..." -ForegroundColor Cyan
$addTrackerUrl = "http://${qbittorrentHost}:${qbittorrentPort}/api/v2/torrents/addTrackers"

$anadidos = 0
$yaTenia = 0
$errores = 0

foreach ($torrent in $torrents) {
    $hash = $torrent.hash
    $name = if ($torrent.name.Length -gt 60) { $torrent.name.Substring(0, 60) + "..." } else { $torrent.name }
    
    # Comprobar si ya tiene el tracker de MilNueve
    $trackersUrl = "http://${qbittorrentHost}:${qbittorrentPort}/api/v2/torrents/trackers?hashes=$hash"
    try {
        $trackersInfo = Invoke-RestMethod -Uri $trackersUrl -Method Get -WebSession $session
        $yaLoTiene = $false
        foreach ($entry in $trackersInfo) {
            if ($entry.tid -eq $hash) {
                foreach ($tr in $entry.trackers) {
                    if ($tr.url -like "*milnueve*") {
                        $yaLoTiene = $true
                        break
                    }
                }
            }
            if ($yaLoTiene) { break }
        }
    } catch {
        # Si falla la consulta de trackers, intentar anadir de todas formas
        $yaLoTiene = $false
    }
    
    if ($yaLoTiene) {
        Write-Host "  [YA TIENE] $name" -ForegroundColor DarkGray
        $yaTenia++
        continue
    }
    
    # Anadir tracker via API
    $addBody = "hash=$hash&urls=$milnueveTracker"
    try {
        Invoke-RestMethod -Uri $addTrackerUrl -Method Post -Body $addBody -ContentType "application/x-www-form-urlencoded" -WebSession $session
        Write-Host "  [OK] $name" -ForegroundColor Green
        $anadidos++
    } catch {
        Write-Host "  [ERROR] $name : $_" -ForegroundColor Red
        $errores++
    }
    
    Start-Sleep -Milliseconds 200   # no spammear al WebUI
}

Write-Host ""
Write-Host "Resumen: $anadidos anadidos, $yaTenia ya lo tenian, $errores errores" -ForegroundColor Yellow

# --- 4. Force Reannounce de todos ------------------------------------------
Write-Host "[4/4] Force Reannounce de todos los torrents..." -ForegroundColor Cyan
$reannounceUrl = "http://${qbittorrentHost}:${qbittorrentPort}/api/v2/torrents/reannounce"
$hashes = ($torrents | ForEach-Object { $_.hash }) -join "|"
$reannounceBody = "hashes=$hashes"
try {
    Invoke-RestMethod -Uri $reannounceUrl -Method Post -Body $reannounceBody -ContentType "application/x-www-form-urlencoded" -WebSession $session
    Write-Host "  Reannounce enviado a $($torrents.Count) torrents" -ForegroundColor Green
} catch {
    Write-Host "  ERROR en reannounce: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Listo ===" -ForegroundColor Green
Write-Host "Espera 2-3 minutos y revisa la WebUI:" -ForegroundColor Yellow
Write-Host "  - Torrents deberian empezar a tener seeds/leechs" -ForegroundColor Yellow
Write-Host "  - Tu ratio en MilNueva empezara a subir" -ForegroundColor Yellow
Write-Host ""
Write-Host "Si tu cuenta MilNueve tiene free-leech temporal, descarga algo" -ForegroundColor Yellow
Write-Host "de MilNueve ahora para generar upload credit rapido." -ForegroundColor Yellow