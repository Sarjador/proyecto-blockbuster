#!/usr/bin/env bash
# =============================================================================
# scripts/healthcheck.sh — comprueba el estado de los 10 servicios del stack.
# Imprime ✅ / ❌ por servicio y resume el total.
# =============================================================================
set -euo pipefail

SERVICES=(
    "jellyfin"
    "seerr"
    "sonarr"
    "radarr"
    "lidarr"
    "readarr"
    "bazarr"
    "jackett"
    "flaresolverr"
    "tracearr"
)

# Detectar si el motor de contenedores es podman o docker
if command -v podman >/dev/null 2>&1; then
    PS_CMD=(podman ps --format '{{.Names}} {{.State}}')
elif command -v docker >/dev/null 2>&1; then
    PS_CMD=(docker ps --format '{{.Names}} {{.State}}')
else
    echo "❌ Ni podman ni docker disponibles en PATH." >&2
    exit 1
fi

declare -A STATUS
while read -r name state; do
    [[ -z "${name}" ]] && continue
    STATUS["${name}"]="${state}"
done < <("${PS_CMD[@]}")

up=0
down=0
echo "📊 Estado del stack multimedia"
echo "------------------------------"
for svc in "${SERVICES[@]}"; do
    state="${STATUS[${svc}]:-missing}"
    case "${state}" in
        running|up)
            printf "  ✅  %-12s  %s\n" "${svc}" "${state}"
            up=$((up + 1))
            ;;
        *)
            printf "  ❌  %-12s  %s\n" "${svc}" "${state}"
            down=$((down + 1))
            ;;
    esac
done

echo "------------------------------"
echo "Total: ${up}/10 en estado 'running'."
if [[ "${down}" -gt 0 ]]; then
    echo ""
    echo "💡 Diagnóstico: 'podman compose logs <servicio>' para ver detalles."
    exit 1
fi
exit 0
