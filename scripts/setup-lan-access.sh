#!/usr/bin/env bash
# =============================================================================
# scripts/setup-lan-access.sh — Abre los puertos del stack en el firewall de
# un host Linux nativo donde podman corre directamente (sin WSL2/VM).
#
# En Linux NO se necesita port forwarding: podman-compose expone los puertos
# directamente en 0.0.0.0 del host. Lo único que bloquea el acceso externo
# es el firewall del sistema.
#
# Detecta automáticamente el gestor de firewall (firewalld o ufw), abre los
# puertos y verifica que quedan activos.
#
# Ejecutar como root:  sudo ./scripts/setup-lan-access.sh
# =============================================================================
set -euo pipefail

# --- Puertos del stack (deben coincidir con docker-compose.yml) -------------
PORTS_TCP=(8096 5055 8989 7878 8686 8787 6767 9117 3000 9080 6881)

# --- Detectar el gestor de firewall disponible -------------------------------
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
    FW="firewalld"
elif command -v ufw >/dev/null 2>&1 && ufw status >/dev/null 2>&1; then
    FW="ufw"
else
    echo "❌ No se detectó firewalld ni ufw activo." >&2
    echo "   Instala uno de los dos o abre los puertos manualmente." >&2
    exit 1
fi

echo "🔍 Firewall detectado: $FW"
echo ""

# --- Abrir puertos -----------------------------------------------------------
case "$FW" in
    firewalld)
        for port in "${PORTS_TCP[@]}"; do
            firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null
            echo "  + firewalld: TCP ${port}"
        done
        # qBittorrent BitTorrent usa UDP 6881
        firewall-cmd --permanent --add-port=6881/udp >/dev/null
        echo "  + firewalld: UDP 6881 (BitTorrent)"
        firewall-cmd --reload >/dev/null
        echo ""
        echo "✅ Reglas recargadas. Estado actual:"
        firewall-cmd --list-ports
        ;;

    ufw)
        for port in "${PORTS_TCP[@]}"; do
            ufw allow "${port}/tcp" >/dev/null
            echo "  + ufw: TCP ${port}"
        done
        ufw allow 6881/udp >/dev/null
        echo "  + ufw: UDP 6881 (BitTorrent)"
        echo ""
        echo "✅ Reglas aplicadas. Estado actual:"
        ufw status
        ;;
esac

echo ""
echo "🌐 IPs accesibles desde la LAN / Tailscale:"
ip -4 -o addr show 2>/dev/null | awk '{print $2, $4}' | grep -v "127.0.0.1" | while read -r iface cidr; do
    ip=${cidr%/*}
    echo "  http://${ip}:8096  (Jellyfin) [${iface}]"
done

echo ""
echo "ℹ️  En Linux NO hace falta port-forwarding: los containers exponen"
echo "   puertos directamente en 0.0.0.0 del host."
echo ""
echo "⚠️  Si el host tiene IP dinámica, los clientes deben usar el hostname"
echo "   o actualizar el bookmark del navegador cuando la IP cambie."
