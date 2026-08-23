# Nota: NO usamos `#Requires -RunAsAdministrator` porque queremos auto-elevarnos
# con UAC si no estamos en admin (el bloque mas abajo lo gestiona).
<#
.SYNOPSIS
    Configura port forwarding desde las interfaces de red de Windows 10 hacia
    el WSL2 VM donde corren los containers de Podman, para que dispositivos
    en la LAN (TV, Pixel6) y en Tailscale puedan acceder al stack multimedia.

.DESCRIPTION
    El stack corre dentro de podman-machine (WSL2 Fedora) que tiene una IP
    interna (172.19.x.x). Los containers exponen puertos a esa VM, pero
    Windows NO los reenvia automaticamente a las IPs externas (192.168.x.x,
    100.x.x.x). Este script:
      1. Detecta la IP actual del WSL2 VM
      2. Configura netsh interface portproxy para cada puerto del stack
         (escuchando en 0.0.0.0:PUERTO, reenviando a WSL2_IP:PUERTO)
      3. Abre los puertos en Windows Firewall

    IMPORTANTE: si el WSL2 VM reinicia y su IP cambia, los portproxy rules
    quedan apuntando a la IP vieja y dejan de funcionar. Soluciones:
      - Volver a correr este script tras cada restart del VM
      - Programarlo con Task Scheduler al detectar evento WSL2 boot
      - (Mejor) Instalar Tailscale en el WSL2 VM para tener una IP estable

.NOTES
    Se auto-eleva a Administrador si no lo esta. Se puede correr multiples
    veces sin problema (cada ejecucion limpia reglas previas antes de crear
    las nuevas).

    Puertos configurados (deben coincidir con .env):
      Jellyfin 8096, Seerr 5055, Sonarr 8989, Radarr 7878, Lidarr 8686,
      Readarr 8787, Bazarr 6767, Jackett 9117, Tracearr 3000,
      qBittorrent WebUI 9080 (NO 8080: qBittorrent v5 valida que el puerto
      del Host header coincida con el interno),
      qBittorrent BitTorrent 6881 TCP (portproxy a WSL2 VM).
    qBittorrent corre con network_mode: host, lo que en WSL2 + podman-machine
    significa que esta en el namespace de red de la VM de Fedora (no en el
    de Windows directamente). Por eso el 6881 SI necesita portproxy hacia
    la IP actual de la VM; sin el, los paquetes que llegan a Windows:6881
    no encuentran nada que escuche (qBittorrent esta en la VM, no en
    Windows). NO se puede portproxy-ar UDP con netsh (limitación de
    Windows); para UDP 6881 hay que abrir solo la regla de Firewall.
#>

# --- Auto-elevacion: si no corre como admin, re-lanzar con UAC --------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }
    Write-Host '[setup-lan-access] Solicitando elevacion a Administrador...'
    $proc = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
        -Verb RunAs -Wait -PassThru
    exit $proc.ExitCode
}

# --- Configuracion (debe coincidir con docker-compose.yml) -------------------
$PORTS = @{
    'Jellyfin'    = 8096
    'Seerr'       = 5055
    'Sonarr'      = 8989
    'Radarr'      = 7878
    'Lidarr'      = 8686
    'Readarr'     = 8787
    'Bazarr'      = 6767
    'Jackett'     = 9117
    'Tracearr'    = 3000
    'qBittorrent' = 9080
}

# --- 1. Detectar la IP del WSL2 VM ------------------------------------------
Write-Host '[1/3] Detectando IP del WSL2 VM (podman-machine)...' -ForegroundColor Cyan

# IMPORTANTE: usar 'wsl -d podman-machine-default -- ip ...' (no 'wsl --exec ip ...').
# 'wsl --exec' corre en la distro por defecto de WSL, que puede ser otra
# (p. ej. Ubuntu, docker-desktop) y no es podman-machine. '-d' fuerza la distro
# correcta independientemente de cual sea la default.
$wslIp = wsl -d podman-machine-default -- ip -4 addr show eth0 2>&1 |
    Select-String -Pattern 'inet (\d+\.\d+\.\d+\.\d+)' |
    ForEach-Object { ($_.Matches[0].Groups[1].Value) } |
    Select-Object -First 1

if (-not $wslIp) {
    Write-Host 'ERROR: no se pudo detectar la IP del WSL2 VM.' -ForegroundColor Red
    Write-Host 'Asegurate de que podman-machine esta corriendo: podman machine list' -ForegroundColor Red
    Write-Host "Tampoco funciono 'wsl -d podman-machine-default -- ip ...'. Si tu distro" -ForegroundColor Red
    Write-Host "de WSL no tiene el comando 'ip', prueba 'podman machine ssh -- ip -4 addr show eth0'." -ForegroundColor Red
    exit 1
}
Write-Host "  -> WSL2 IP: $wslIp" -ForegroundColor Green

# --- 2. Configurar netsh portproxy ------------------------------------------
Write-Host '[2/3] Configurando netsh interface portproxy...' -ForegroundColor Cyan

# Limpiar reglas previas (idempotente)
$existing = netsh interface portproxy show v4tov4 2>&1
foreach ($line in $existing) {
    if ($line -match '(\d+\.\d+\.\d+\.\d+):(\d+)\s+(\d+\.\d+\.\d+\.\d+):(\d+)') {
        $oldPort = $Matches[2]
        try {
            netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$oldPort 2>&1 | Out-Null
        } catch { }
    }
}

# Crear reglas nuevas
foreach ($entry in $PORTS.GetEnumerator()) {
    $name  = $entry.Key
    $port  = $entry.Value
    Write-Host "  + $name :$port -> ${wslIp}:${port}"
    netsh interface portproxy add v4tov4 `
        listenaddress=0.0.0.0 `
        listenport=$port `
        connectaddress=$wslIp `
        connectport=$port | Out-Null
}

# qBittorrent BitTorrent (puerto configurable via .env): portproxy hacia la VM.
# Si tu ISP filtra 6881, define QBITTORRENT_BT_PORT en .env (ej. 46881),
# actualiza tambien la regla de port forwarding del router y la WebUI del
# propio qBittorrent.
$qbtBtPort = if ($env:QBITTORRENT_BT_PORT) { $env:QBITTORRENT_BT_PORT } else { '6881' }
Write-Host "  + qBittorrent BT ${qbtBtPort}/tcp (portproxy a VM)"
netsh interface portproxy add v4tov4 `
    listenaddress=0.0.0.0 `
    listenport=$qbtBtPort `
    connectaddress=$wslIp `
    connectport=$qbtBtPort | Out-Null
# ${qbtBtPort}/UDP no se puede portproxy-ar con netsh (limitación de Windows);
# lo cubre solo la regla de Firewall de la sección 3.

# --- 3. Abrir puertos en Windows Firewall ----------------------------------
Write-Host '[3/3] Abriendo puertos en Windows Firewall...' -ForegroundColor Cyan

foreach ($entry in $PORTS.GetEnumerator()) {
    $name = $entry.Key
    $port = $entry.Value
    $ruleName = "Proyecto-Blockbuster $name :$port"

    # Eliminar regla previa si existe (idempotente)
    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

    # Crear regla nueva: TCP, allow, any source
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $port `
        -Action Allow `
        -Profile Any `
        -ErrorAction SilentlyContinue | Out-Null

    Write-Host "  + Firewall: $name :$port (TCP)"
}

# qBittorrent BitTorrent traffic: TCP y UDP en el puerto configurado
# en .env (QBITTORRENT_BT_PORT, default 6881). Cubre el BT del container.
foreach ($proto in @('TCP', 'UDP')) {
    $ruleName = "Proyecto-Blockbuster qBittorrent BT ${qbtBtPort} $proto"
    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol $proto `
        -LocalPort $qbtBtPort `
        -Action Allow `
        -Profile Any `
        -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  + Firewall: qBittorrent BT ${qbtBtPort} ($proto)"
}

Write-Host ''
Write-Host '=== Resultado ===' -ForegroundColor Green
Write-Host 'Reglas de portproxy activas:' -ForegroundColor Cyan
netsh interface portproxy show v4tov4 | Select-String -Pattern '0\.0\.0\.0' | ForEach-Object { Write-Host "  $_" }

Write-Host ''
Write-Host 'IPs accesibles desde la LAN / Tailscale:' -ForegroundColor Cyan
$lanIps = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' } |
    Select-Object -ExpandProperty IPAddress
foreach ($ip in $lanIps) {
    Write-Host "  http://${ip}:8096  (Jellyfin)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Si el WSL2 VM reinicia y cambia su IP, vuelve a correr este script.' -ForegroundColor Yellow
Write-Host 'Para automatizar: ver README.md seccion 12 (Acceso remoto).' -ForegroundColor Yellow
