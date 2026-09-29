#!/usr/bin/env bash
# =============================================================================
# scripts/init.sh — prepara el árbol de directorios bajo ${DATA_ROOT} para
# el stack multimedia en Podman. Idempotente: se puede re-ejecutar.
#
# Crea:
#   ${DATA_ROOT}/torrents/                       (zona de staging)
#   ${DATA_ROOT}/config/<servicio>/              (los 10 servicios)
#
# Si la raíz es ext4/btrfs/xfs (POSIX completo), aplica chown -R
#   ${PUID}:${PGID} para que los contenedores LinuxServer puedan escribir
#   con el UID del host y los hard links funcionen entre bind mounts.
#
# Si la raíz está sobre un FS no-POSIX (NTFS, FAT, 9P/DrvFS en WSL2, CIFS),
#   no aplica chown (no funciona) y en su lugar hace chmod 777 para que
#   los contenedores con PUID/PGID puedan leer y escribir.
# =============================================================================
set -euo pipefail

# --- Cargar .env si existe ----------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
    # shellcheck disable=SC1091
    set -a; source "${ROOT_DIR}/.env"; set +a
elif [[ -f "${ROOT_DIR}/.env.example" ]]; then
    echo "⚠️  No se encontró .env; usando valores de .env.example."
    echo "   Crea tu .env con 'cp .env.example .env' y ajusta PUID/PGID/DATA_ROOT."
    # shellcheck disable=SC1091
    set -a; source "${ROOT_DIR}/.env.example"; set +a
else
    echo "❌ Ni .env ni .env.example encontrados en ${ROOT_DIR}."
    exit 1
fi

: "${DATA_ROOT:?DATA_ROOT no definido en .env}"
: "${PUID:?PUID no definido en .env}"
: "${PGID:?PGID no definido en .env}"

# --- Validaciones -------------------------------------------------------------
if ! [[ "${PUID}" =~ ^[0-9]+$ ]]; then
    echo "❌ PUID='${PUID}' no es numérico." >&2
    exit 1
fi
if ! [[ "${PGID}" =~ ^[0-9]+$ ]]; then
    echo "❌ PGID='${PGID}' no es numérico." >&2
    exit 1
fi

# --- Crear el árbol mínimo que el compose necesita ----------------------------
# Solo lo que el compose *crea*: config/ por servicio y torrents/.
# Las carpetas de la biblioteca (Peliculas/, Series/, etc.) NO se crean:
# las gestiona el usuario.
SERVICES=(
    "torrents"
    "config/jellyfin"
    "config/seerr"
    "config/sonarr"
    "config/radarr"
    "config/lidarr"
    "config/readarr"
    "config/bazarr"
    "config/jackett"
    "config/flaresolverr"
    "config/qbittorrent"
    "config/tracearr"
    "config/redis"
    "config/postgres"
    "config/threadfin"   # Proxy IPTV opcional (Threadfin). Ver README §"Configurar Threadfin".
)

echo "📁 Creando estructura bajo ${DATA_ROOT} ..."
for sub in "${SERVICES[@]}"; do
    mkdir -p "${DATA_ROOT}/${sub}"
done

# --- Detectar tipo de filesystem y aplicar permisos ----------------------------
FS_TYPE="$(stat -f -c '%T' "${DATA_ROOT}" 2>/dev/null || echo unknown)"
case "${FS_TYPE}" in
    ext4|btrfs|xfs|zfs|f2fs|overlayfs|rootfs|tmpfs)
        echo "🔐 FS POSIX detectado (${FS_TYPE}) → chown -R ${PUID}:${PGID} ..."
        chown -R --no-dereference "${PUID}:${PGID}" "${DATA_ROOT}" 2>/dev/null || \
            echo "   (Aviso: chown parcial — algunos archivos pueden no haber cambiado de owner.)"
        ;;
    fuseblk|drvfs|ntfs|cifs|smb3|9p|v9fs|vfat|exfat|msdos|unknown)
        echo "ℹ️  FS no-POSIX detectado (${FS_TYPE}) → chmod -R 777 (chown no soportado)."
        chmod -R u+rwX,g+rwX,o+rwX "${DATA_ROOT}" 2>/dev/null || \
            echo "   (Aviso: chmod parcial.)"
        echo "   Hard links entre torrents/ y media/ no funcionarán en este FS;"
        echo "   cada download duplicará el espacio hasta que se limpie el torrent."
        ;;
    *)
        echo "⚠️  FS desconocido ('${FS_TYPE}'); aplicando chmod 777 por seguridad."
        chmod -R u+rwX,g+rwX,o+rwX "${DATA_ROOT}" 2>/dev/null || true
        ;;
esac

# --- Resumen ------------------------------------------------------------------
echo ""
echo "✅ Estructura lista (solo lo creado por este script):"
echo "   ${DATA_ROOT}/torrents/"
echo "   ${DATA_ROOT}/config/<10 servicios>/"
echo ""
echo "ℹ️  Tu biblioteca existente en ${DATA_ROOT} (Peliculas, Series, etc.) NO se ha listado para no escanear miles de archivos."

echo ""
echo "➡️  Siguiente paso: editar .env si hace falta y arrancar el stack con:"
echo "    podman-compose up -d      # o: podman compose up -d"
echo ""
echo "   Tras arrancar, ejecuta scripts/healthcheck.sh para ver el estado."
