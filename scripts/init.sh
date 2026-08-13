#!/usr/bin/env bash
# =============================================================================
# scripts/init.sh — prepara el árbol de directorios bajo ${DATA_ROOT} para
# el stack multimedia en Podman. Idempotente: se puede re-ejecutar.
#
# Crea:
#   ${DATA_ROOT}/torrents/
#   ${DATA_ROOT}/media/{movies,tv,music,books}/
#   ${DATA_ROOT}/config/<servicio>/  para los 10 servicios
#
# Aplica chown -R ${PUID}:${PGID} sobre todo ${DATA_ROOT} para que los
# contenedores LinuxServer puedan escribir como el UID del host y los
# hard links funcionen entre bind mounts.
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

# --- Crear el árbol -----------------------------------------------------------
SERVICES=(
    "torrents"
    "media/movies"
    "media/tv"
    "media/music"
    "media/books"
    "config/jellyfin"
    "config/seerr"
    "config/sonarr"
    "config/radarr"
    "config/lidarr"
    "config/readarr"
    "config/bazarr"
    "config/jackett"
    "config/flaresolverr"
    "config/tracearr"
)

echo "📁 Creando estructura bajo ${DATA_ROOT} ..."
for sub in "${SERVICES[@]}"; do
    mkdir -p "${DATA_ROOT}/${sub}"
done

# --- Permisos -----------------------------------------------------------------
# En rootless Podman, los UID/GID numéricos del host deben coincidir con
# PUID/PGID para que los hard links entre bind mounts funcionen.
echo "🔐 Aplicando chown -R ${PUID}:${PGID} sobre ${DATA_ROOT} ..."
# Usamos --no-dereference para no seguir symlinks accidentales.
chown -R --no-dereference "${PUID}:${PGID}" "${DATA_ROOT}" 2>/dev/null || \
    echo "   (Aviso: chown parcial — algunos archivos pueden no haber cambiado de owner.)"

# --- Resumen ------------------------------------------------------------------
echo ""
echo "✅ Estructura lista:"
if command -v tree >/dev/null 2>&1; then
    tree -L 3 -d "${DATA_ROOT}" | head -40
else
    find "${DATA_ROOT}" -maxdepth 3 -type d | sort
fi

echo ""
echo "➡️  Siguiente paso: editar .env si hace falta y arrancar el stack con:"
echo "    podman-compose up -d      # o: podman compose up -d"
echo ""
echo "   Tras arrancar, ejecuta scripts/healthcheck.sh para ver el estado."
