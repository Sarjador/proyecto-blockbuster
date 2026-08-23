#!/usr/bin/with-contenv bash
# =============================================================================
# scripts/qbittorrent-init.sh — sembrado inicial de preferencias para qBittorrent
#
# Las imagenes linuxserver/qBittorrent no aceptan variables de entorno para
# DHT/PeX/LSD/UPnP. Hay que escribirlas directamente en el fichero de
# configuracion. Este init script:
#
#   - Si el config NO existe (primer arranque), crea uno vacio con las
#     preferencias indicadas en .env (QBITTORRENT_DHT_ENABLED, etc.).
#   - Si el config YA existe (arranques posteriores), NO lo modifica para
#     respetar la configuracion que el usuario haya tuneado via WebUI.
#
# Valores validos para cada variable: 'true' / 'false'.
# =============================================================================

set -e

CONFIG_FILE="/config/qBittorrent/qBittorrent.conf"

# Solo actuar si el config no existe (primer arranque)
if [[ -f "$CONFIG_FILE" ]]; then
    echo "[qbittorrent-init] Config ya existe en $CONFIG_FILE, no se modifica"
    echo "[qbittorrent-init] Para cambiar DHT/PeX/LSD/UPnP usa la WebUI (Tools -> Options -> Connection)"
    exit 0
fi

mkdir -p /config/qBittorrent

DHT="${QBITTORRENT_DHT_ENABLED:-false}"
PEX="${QBITTORRENT_PEX_ENABLED:-false}"
LSD="${QBITTORRENT_LSD_ENABLED:-false}"
UPNP="${QBITTORRENT_UPNP_ENABLED:-false}"

echo "[qbittorrent-init] Sembrando config inicial con:"
echo "                  DHT=$DHT  PeX=$PEX  LSD=$LSD  UPnP=$UPNP"

cat > "$CONFIG_FILE" << EOF
[BitTorrent]
Session\DefaultSavePath=/downloads/
Session\TempPath=/downloads/incomplete/
Session\PortForwardingEnabled=$UPNP
Session\DHTEnabled=$DHT
Session\PeXEnabled=$PEX
Session\LSDEnabled=$LSD

[Preferences]
General\Locale=en
Downloads\SavePath=/downloads/
Downloads\TempPath=/downloads/incomplete/
EOF

echo "[qbittorrent-init] OK - Config sembrado. El usuario debera configurar la WebUI en el primer arranque (admin/adminadmin)."
