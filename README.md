# Proyecto-Blockbuster

Stack multimedia automatizado para desplegar con Podman, basado en el ecosistema
*Arr (Sonarr, Radarr, Lidarr, Readarr, Bazarr, Jackett + FlareSolverr, Seerr,
Jellyfin, Tracearr). Inspirado en el vídeo *"Jellyfin + Radarr + Sonarr 100%
AUTOMATIZADO"* del canal Pelado Nerd, ampliado para cubrir todas las facetas de
una biblioteca digital (películas, series, música, libros, subtítulos,
peticiones, indexación y monitoreo).

La motivación completa y las fuentes que respaldan cada decisión están en
[`Sources.txt`](Sources.txt).

---

## 1. Requisitos previos

| Componente | Versión recomendada | Notas |
|---|---|---|
| Podman | >= 4.x (probado en 5.6.0) | Motor rootless preferido. |
| podman-compose | última estable | Si tu Podman no lo trae, `pip install podman-compose` o usa `podman compose` (wrapper nativo). |
| subuid / subgid | configurados | Necesario para rootless con hard links. |
| uid / gid numéricos | `id -u` y `id -g` | Se vuelcan en `PUID` y `PGID` del `.env`. |
| Disco | >= 200 GB libres | Recomendable almacenar `${DATA_ROOT}` en un volumen/pool aparte. |

> **Windows (WSL2)**: este stack se ha diseñado para Linux. En Windows el
> comportamiento de bind mounts y rootless puede requerir adaptaciones; se
> recomienda ejecutarlo en una VM Linux o WSL2 con systemd. Si estás en
> Windows 10/11, salta directamente a §10 "Despliegue en Windows 10/11"
> antes de continuar.

---

## 2. Despliegue paso a paso

```bash
# 1. Clonar el repo (o copiar la carpeta)
git clone <url> proyecto-blockbuster && cd proyecto-blockbuster

# 2. Crear el .env a partir del example
cp .env.example .env
$EDITOR .env       # ajustar PUID, PGID, TZ, DATA_ROOT y puertos si hace falta

# ⚠️ Obligatorio: rellena TRACEARR_JWT_SECRET y TRACEARR_DB_PASSWORD.
# En `.env.example` vienen VACÍOS a propósito (fail-fast seguro): si los
# dejas así, Postgres y Tracearr NO arrancarán al hacer `up -d`. Genera
# valores aleatorios con:
#   openssl rand -hex 32   # para TRACEARR_JWT_SECRET (>=32 chars)
#   openssl rand -hex 16   # para TRACEARR_DB_PASSWORD
# y pégalos en el `.env` antes de continuar.

# 3. Crear el árbol de directorios bajo ${DATA_ROOT} con permisos correctos
./scripts/init.sh

# 4. Levantar el stack
podman-compose up -d        # o: podman compose up -d

# 5. Comprobar estado
./scripts/healthcheck.sh
```

Tras el primer `up -d`, las imágenes (~3 GB en total) se descargan. El primer
arranque de Jellyfin puede tardar 30–60 s.

---

## 3. Configuración inicial por servicio

Accede a cada UI desde la red local. Los puertos vienen del `.env` (los
listados abajo son los valores por defecto).

| Servicio | URL local | Notas |
|---|---|---|
| Jellyfin | http://localhost:8096 | Crear usuario admin y añadir bibliotecas `media/movies`, `media/tv`, `media/music`, `media/books`. |
| Seerr | http://localhost:5055 | Login con cuenta Jellyfin. Conectar Radarr y Sonarr. |
| Sonarr | http://localhost:8989 | Añadir indexador → Jackett (URL interna `http://jackett:9117`, API key desde la UI de Jackett). |
| Radarr | http://localhost:7878 | Idem con Jackett. |
| Lidarr | http://localhost:8686 | Idem con Jackett. |
| Readarr | http://localhost:8787 | Idem con Jackett + mirror `rreading-glasses` (ver §5). |
| Whisparr | http://localhost:6969 | Fork de Sonarr para series/películas adultas. Misma config (Jackett + qBittorrent como download client). **Opcional**: solo si la necesitas. |
| Bazarr | http://localhost:6767 | Conectar con Sonarr y Radarr por API. |
| Jackett | http://localhost:9117 | Añadir indexadores. |
| qBittorrent | http://localhost:9080 | Cliente torrent. User/pass por defecto `admin` / `adminadmin` (cambia al primer login). **Importante**: revisa la sección §"Activación de descubrimiento de peers en qBittorrent" abajo. |
| Tracearr | http://localhost:3000 | Ver §4 para los claim tokens. |
| autobrr | http://localhost:7474 | Gestor automático de torrents (IRC, trackers privados). User/pass se pide en el primer arranque. Ver §"Configurar autobrr" abajo. |
| FlareSolverr | **no acceso web** | Se configura automáticamente en Jackett. |

### Activación de descubrimiento de peers en qBittorrent

La imagen `linuxserver/qBittorrent` **no acepta variables de entorno**
para DHT, PeX, LSD ni UPnP. Estos ajustes solo se pueden configurar de
dos formas:

**A. Variables en `.env` (recomendado para el primer arranque)**

Este repo incluye un init script (`scripts/qbittorrent-init.sh`) que se
monta automáticamente en el container y, **solo la primera vez** (cuando
`/config/qBittorrent/qBittorrent.conf` no existe), siembra esas
preferencias a partir de:

```ini
QBITTORRENT_DHT_ENABLED=true
QBITTORRENT_PEX_ENABLED=true
QBITTORRENT_LSD_ENABLED=true
QBITTORRENT_UPNP_ENABLED=true
```

Para activarlas de verdad, **borra el config y recrea el container**:

```bash
# OJO: esto borra la configuracion de qBittorrent (incluidos torrents
# añadidos y categorias). Haz backup antes si te importa.
rm -rf ${DATA_ROOT}/config/qbittorrent/*
podman-compose up -d qbittorrent
```

Tras el primer arranque, el init script se desactiva (no pisa cambios
posteriores). Si después quieres tocar DHT/PeX/LSD/UPnP, hazlo desde
la WebUI.

**B. Manual desde la WebUI (para cambios posteriores)**

`Tools → Options → Connection`. Marca las casillas que quieras y dale a
**Save** (abajo del todo):

- ✅ **Enable DHT (decentralized network) to find more peers**
- ✅ **Enable Peer Exchange (PeX) to find more peers**
- ✅ **Enable Local Peer Discovery (LSD) to find more peers**
- ✅ **Enable UPnP / NAT-PMP port forwarding from my router**

**¿Cuándo activar cada uno?**

| Ajuste | Recomendado si... | No recomendado si... |
|---|---|---|
| DHT | trackers caídos o torrents sin trackers | solo usas trackers privados fiables |
| PeX | casi siempre (descubre pares via otros pares) | nunca realmente |
| LSD | compartes LAN con otros usuarios | no compartes LAN |
| UPnP | host Linux nativo y quieres abrir puertos sin tocar el router a mano | CGNAT (no funciona), WSL2/rootless Podman (no funciona por multicast) |

### Conectar Sonarr → Jackett

1. Entra en Jackett, abre un indexador (`+ Add indexer`) y copia la API key
   desde la esquina superior derecha.
2. En Sonarr: `Settings → Indexers → Add → Torznab → Custom`. Pon
   `http://jackett:9117` como URL y pega la API key. Si el indexador está
   protegido por Cloudflare, Jackett delegará en FlareSolverr.

---

## 4. Claim tokens de Tracearr

Tracearr necesita un "claim token" para autenticarse con Jellyfin y Sonarr como
"cliente oficial" durante el primer arranque. Pasos:

1. Arranca el stack con `podman-compose up -d`.
2. Abre Jellyfin (`http://localhost:8096`) y crea un usuario admin.
3. El **JELLYFIN_CLAIM_TOKEN** se muestra en `Administration → Dashboard →
   "Claim" / "Connect to Tracearr"` o se imprime en la consola de Jellyfin la
   primera vez. Cópialo.
4. Lo mismo con Sonarr: en la sección de notificaciones o claim de Sonarr
   aparecerá el **SONARR_CLAIM_TOKEN**. Cópialo.
5. Pega ambos en tu `.env`:
   ```
   JELLYFIN_CLAIM_TOKEN=xxxxxxxxxxxx
   SONARR_CLAIM_TOKEN=yyyyyyyyyyyy
   ```
6. Reinicia Tracearr: `podman-compose restart tracearr`.

> Si dejas los tokens vacíos, Tracearr seguirá funcionando pero las
> notificaciones/alertas iniciales no se configurarán.

---

## 5. Mirror de metadatos para Readarr

Readarr fue archivado por sus desarrolladores por problemas con sus proveedores
de metadatos. Este stack usa el mirror comunitario **`rreading-glasses`**.

1. Arranca el stack y entra en la UI de Readarr (`http://localhost:8787`).
2. Ve a `Settings → Indexers` y añade un indexador Torznab que apunte a
   `http://jackett:9117`.
3. Para los metadatos, Readarr puede seguir usando los providers originales
   mientras estén disponibles; si fallan, la búsqueda funcionará pero los
   metadatos pueden estar incompletos. El proyecto `rreading-glasses` se
   mantiene como respaldo externo (no se integra automáticamente en Readarr:
   úsalo desde tu navegador si lo necesitas).

---

## 6. Estructura del host

```
${DATA_ROOT}/
├── torrents/                  # Zona de staging para descargas
├── media/
│   ├── movies/                # Radarr → aquí
│   ├── tv/                    # Sonarr → aquí
│   ├── music/                 # Lidarr → aquí
│   └── books/                 # Readarr → aquí
└── config/
    ├── jellyfin/
    ├── seerr/
    ├── sonarr/
    ├── radarr/
    ├── lidarr/
    ├── readarr/
    ├── bazarr/
    ├── jackett/
    ├── flaresolverr/
    └── tracearr/
```

> **Backups**: respalda `media/` y `config/`. `torrents/` puede regenerarse
> desde el cliente de descargas, pero conservarlo acelera re-seed.

Los **hard links** entre `torrents/` y `media/` (lo que evita duplicar el
espacio en disco) solo funcionan si ambos viven dentro del mismo filesystem
del host — por eso se monta un volumen único y no se separan en dos bind
mounts.

### Puertos publicados

| Servicio | Host → Contenedor |
|---|---|
| Jellyfin | `${JELLYFIN_PORT}:8096` |
| Seerr | `${SEERR_PORT}:5055` |
| Sonarr | `${SONARR_PORT}:8989` |
| Radarr | `${RADARR_PORT}:7878` |
| Lidarr | `${LIDARR_PORT}:8686` |
| Readarr | `${READARR_PORT}:8787` |
| Bazarr | `${BAZARR_PORT}:6767` |
| Jackett | `${JACKETT_PORT}:9117` |
| qBittorrent | `${QBITTORRENT_PORT}:${QBITTORRENT_PORT}` + `6881/tcp` + `6881/udp` |
| Tracearr | `${TRACEARR_PORT}:3000` |

> **Gotcha de qBittorrent v5**: valida estrictamente que el puerto del `Host`
> header coincida con su puerto interno. Si mapeas `9080:8080`, el navegador
> envía `Host: localhost:9080` pero qBittorrent escucha en `8080` → **rechaza
> TODAS las peticiones con 401** sin mostrar el formulario de login. El
> compose usa `${QBITTORRENT_PORT}:${QBITTORRENT_PORT}` para que ambos lados
> coincidan. Si necesitas un puerto distinto al 8080, **no cambies solo el
> host**; asegúrate de que `WEBUI_PORT` y el mapping usen el mismo número.
| **FlareSolverr** | **no publicado** (solo red interna) |

Ajusta los valores en el `.env` si tu host tiene algún conflicto.

---

## 7. Conectar qBittorrent a Radarr y Sonarr

Una vez qBittorrent está corriendo, hay que declararlo como **Download Client**
(no como Indexer) en cada *Arr.

**1. Configura qBittorrent** (una sola vez, en `http://localhost:8080`):
- Login: `admin` / `adminadmin` (te obligará a cambiarlos al primer acceso).
- (Opcional) `Tools → Options → Downloads`: cambia la "Default Save Path" a
  `/downloads` si no lo está ya (es donde apunta el volumen `${DATA_ROOT}/torrents`).
- (Opcional) Activa "Append torrent's label" si quieres organizar por etiqueta.

**2. En Radarr** (`http://localhost:7878`):
- `Settings → Download Clients → + Add → qBittorrent`
- **Name**: `qBittorrent`
- **Host**: `qbittorrent` (hostname interno, NO `localhost`)
- **Port**: `8080`
- **Username**: el que pusiste
- **Password**: el que pusiste
- **Category** (importante): `movies` — así Radarr etiqueta los torrents y
  qBittorrent los pone en una subcarpeta por categoría
- **Use SSL**: ☐
- **Test** → **Save**

**3. En Sonarr** (`http://localhost:8989`):
- Igual pero la **Category** es `tv` (o `anime` si quieres separar)

### Cómo funciona el ciclo completo

```
Seerr (petición) → Radarr (busca en Jackett) → qBittorrent (descarga)
   → al terminar, Radarr importa el archivo a /arr-data/Peliculas/
   → Jellyfin refresca la biblioteca y muestra la nueva película
```

Hard links entre `/downloads/` y `/arr-data/` solo funcionarán en FS POSIX
ext4/btrfs/xfs. En NTFS/v9fs (caso W10), Radarr **copia** el archivo y luego
lo borra de `/downloads/`. Cada download duplica el espacio temporalmente.

---

## 8. Troubleshooting

### "Permission denied" al escribir en `${DATA_ROOT}`
- Verifica que `PUID`/`PGID` en el `.env` coinciden con tu UID/GID del host
  (`id -u`, `id -g`).
- Vuelve a ejecutar `./scripts/init.sh` para reaplicar `chown`.

### Hard links no funcionan (los archivos se duplican)
- En rootless Podman necesitas que el UID del host (`PUID`) tenga permitidos
  rangos `subuid`/`subgid` (típicamente `100000:65536`). Edite
  `/etc/subuid` y `/etc/subgid`.

### FlareSolverr no resuelve Cloudflare
- Comprueba que la red `multimedia-net` existe: `podman network ls | grep
  multimedia-net`.
- Jackett debe tener la URL `http://flaresolverr:8191` (NO `localhost`).
- Revisa los logs: `podman compose logs flaresolverr`.

### Un servicio no arranca
- `podman compose logs <servicio>` para ver el motivo.
- `podman compose ps` para ver el estado de los 10.
- `./scripts/healthcheck.sh` para un resumen rápido.

### Jellyfin no ve los archivos
- Verifica que el directorio `${DATA_ROOT}/media/movies` está mapeado al
  contenedor en `/media` (visible desde la UI: `Administration → Dashboard →
  Paths`).
- Asegúrate de que `chown` se aplicó al directorio, sino Jellyfin no puede
  escanearlo.

### Quiero resetear un servicio
- `podman compose stop <servicio>` y `podman compose rm <servicio>`.
- Borrar `${DATA_ROOT}/config/<servicio>` para empezar de cero.

### qBittorrent aparece como "Firewalled" en la WebUI
Síntomas: la WebUI muestra el triángulo amarillo "Connection status:
Firewalled", el log repite `UPnP/NAT-PMP port mapping failed: no router
found`, y la velocidad de **subida** es muy inferior a la de descarga
(p. ej. 5 MiB/s ↓ vs 50 KiB/s ↑).

Causa: en este stack (rootless Podman sobre WSL2), UPnP/SSDP multicast
NO atraviesa slirp4netns. Por tanto qBittorrent dentro del contenedor
no puede pedirle al router que abra el 6881. La consecuencia es que los
peers externos no pueden iniciar conexiones entrantes y qBittorrent se
autocalifica como "Firewalled".

Probamos `network_mode: host` (commit revertido) y no es la solución:
sí arregla UPnP pero rompe la resolución DNS de `qbittorrent` para los
Arr (Radarr/Sonarr/etc. dejan de encontrar el download client).

Solución: **port forwarding manual en el router**. Una sola vez.

1. Entra al panel del router (`http://192.168.1.1`, `192.168.0.1` o la
   que uses). Suele estar en "Port Forwarding", "NAT" o "Virtual
   Server" (varía por marca: ASUS, Movistar HGU, Mikrotik, etc.).
2. Crea regla(s):
   - Externo `6881` TCP → interno `<IP-LAN-Windows>` (la de `ipconfig`,
     p. ej. `<TU-IP-LAN>`) puerto `6881`
   - Externo `6881` UDP → mismo destino
3. Guarda y aplica.

Tras esto, los peers externos llegan a `Windows:6881` y la cadena
inbound funciona:
```
Internet → Router → Windows:6881
  → portproxy (regla de setup-lan-access.ps1)
  → WSL2 VM:6881
  → rootlessport (docker-compose ports:)
  → contenedor:6881 → qBittorrent
```

Espera 1-2 minutos y la WebUI pasará de "Firewalled" a "OK" en cuanto
algún peer externo complete una conexión inbound. La velocidad de
subida debería igualarse a la de descarga (o subir bastante).

Si tu ISP filtra puertos BitTorrent conocidos (algunos ISPs en España
bloquean o limitan el 6881), cambia el Listening Port en la WebUI a
algo no estándar como 51413. Si lo haces, recuerda actualizar también
el `6881:6881` en `docker-compose.yml` y la regla de port forwarding
del router para que apunte al nuevo puerto.

### Podman-machine queda corrupto tras un upgrade (WSL2)
Síntomas: `podman machine list` se cuelga, `wsl -d podman-machine-default
-- echo "alive"` no responde, o `podman machine init` falla con
`WSL_E_DISTRO_NOT_FOUND` / `ERROR_FILE_EXISTS`. Causa típica: la distro
Fedora interna del podman-machine quedó en mal estado tras un upgrade
mayor de Podman (5.x → 6.x) o de WSL2.

Recovery paso a paso (Windows 10/11, **PowerShell como Administrador**):

1. **Matar zombis y reiniciar el servicio WSL**:
   ```powershell
   Get-Process wslservice, wsl, wslhost -ErrorAction SilentlyContinue | Stop-Process -Force
   Stop-Service LxssManager -Force
   Start-Service LxssManager
   wsl --list --verbose
   ```
2. **Borrar la distro y la metadata de Podman**:
   ```powershell
   wsl --unregister podman-machine-default
   podman machine rm podman-machine-default -f
   ```
3. **Limpiar la basura que deja `wsl --unregister`** (instalación previa
   en `%USERPROFILE%\.local\share\containers\podman\machine\wsl\`):
   ```powershell
   Remove-Item -Recurse -Force "$env:USERPROFILE\.local\share\containers\podman\machine\wsl\wsldist\podman-machine-default"
   Remove-Item -Recurse -Force "$env:USERPROFILE\.local\share\containers\podman\machine\wsl\podman-machine-default"
   Remove-Item -Recurse -Force "$env:USERPROFILE\.local\share\containers\podman\machine\wsl\podman-machine-default-amd64" -ErrorAction SilentlyContinue
   ```
   Si los pasos 2-3 siguen dando `ERROR_FILE_EXISTS`, queda una entrada
   zombie en el registro de WSL:
   ```powershell
   $lxssKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
   Get-ChildItem $lxssKey | ForEach-Object {
       $props = Get-ItemProperty $_.PSPath
       if ($props.DistributionName -eq "podman-machine-default") {
           Remove-Item $_.PSPath -Recurse -Force
       }
   }
   ```
4. **Recrear la VM Fedora**:
   ```powershell
   podman machine init --now
   podman machine list   # confirmar "Currently running"
   ```
5. **Relevantar el stack** (los bind mounts a `${DATA_ROOT}` siguen vivos):
   ```powershell
   cd F:\GITHUB_REPOS\Proyecto-Blockbuster
   podman-compose up -d
   ```

Notas importantes:
- Tu biblioteca en `${DATA_ROOT}` **no se pierde** (está fuera de la VM).
- Los configs de los *Arr en `${DATA_ROOT}/config/<servicio>` **se conservan**.
- El volumen named `tracearr-postgres` **se recrea vacío**; Tracearr
  pedirá un `JELLYFIN_CLAIM_TOKEN` nuevo, pero el actual del `.env`
  debería seguir siendo válido.
- **No actualices Podman y WSL a la vez.** Haz uno, prueba, y luego el
  otro.

### `podman compose` delega a `docker-compose.exe` de Docker Desktop
Síntoma: `podman compose up -d` muestra
`Executing external compose provider "...\Docker\resources\bin\docker-compose.exe"`
y falla con `EOF` al conectar al socket. Causa: Docker Desktop está
instalado y su `docker-compose.exe` aparece en `PATH` antes que el compose
nativo de Podman.

Solución rápida (PowerShell como Admin):
```powershell
Move-Item "C:\Program Files\Docker\Docker\resources\bin\docker-compose.exe" "C:\Program Files\Docker\Docker\resources\bin\docker-compose.exe.bak"
```
Tras esto, `podman compose` usa su compose provider nativo. Para
restaurar, renombra el `.bak` de vuelta.

Solución definitiva: instalar `podman-compose` (Python):
```powershell
python -m pip install podman-compose
```
Y usar `podman-compose up -d` en lugar de `podman compose up -d`.

### Jellyfin devuelve 503 "Service Unavailable" al arrancar
Síntoma: `curl -I http://localhost:8096` devuelve `HTTP/1.1 503` con
`Retry-After: 005` durante más de 5 minutos. Los logs muestran
repetidamente `Health check StartupCheck with status Degraded` con mensaje
`'Server is still starting up.'`.

Causa típica: Jellyfin está ejecutando migraciones de base de datos
bloqueadas (la `jellyfin.db` quedó en estado inconsistente tras un
apagado forzoso o un upgrade). El puerto responde (Kestrel escucha) pero
la app no termina de arrancar.

Diagnóstico:
```powershell
podman logs jellyfin 2>&1 | Select-String -Pattern "Migration|error|Error|WARN" | Select-Object -Last 30
```

Fix A — esperar a la migración (si no hay errores):
A veces tarda 10-15 min en escanear una biblioteca grande. Si los logs
muestran progreso de escaneo, déjalo correr.

Fix B — borrar la DB y empezar de cero (puedes perder configuración de
bibliotecas):
```powershell
podman compose stop jellyfin
# Desde Windows, ${DATA_ROOT}/config/jellyfin/data/jellyfin.db
Remove-Item "${DATA_ROOT}\config\jellyfin\data\jellyfin.db"  # ajusta la ruta
podman compose up -d jellyfin
```
Las bibliotecas configuradas se pierden y hay que volver a crearlas en la
UI, pero las películas/series en `${DATA_ROOT}` siguen ahí.

Fix C — recuperar desde un backup (si lo tenías):
```powershell
podman compose stop jellyfin
Copy-Item ruta\backup\jellyfin.db "${DATA_ROOT}\config\jellyfin\data\jellyfin.db"
podman compose up -d jellyfin
```

---

## 9. Arquitectura decisional

Las decisiones técnicas (por qué `podman-compose`, por qué un volumen único,
por qué imágenes `linuxserver/*`, por qué FlareSolverr aislado) están
documentadas en
[`openspec/changes/podman-multimedia-stack/design.md`](openspec/changes/podman-multimedia-stack/design.md).
Las capacidades del sistema (qué debe hacer cada servicio) están en
`openspec/changes/podman-multimedia-stack/specs/`.

---

## 10. Licencia y aviso

Este repositorio es un orquestador. Las imágenes y servicios desplegados
mantienen sus propias licencias (mayoritariamente GPL/Apache). El usuario es
responsable del uso del contenido que descargue.

Las fuentes consultadas para construir este stack están en [`Sources.txt`](Sources.txt).

---

## 12. Acceso remoto (LAN, Tailscale, VPN)

Por defecto, los servicios solo son accesibles desde `localhost` del host donde
corre podman. Para acceder desde otros dispositivos (TV, móvil, otro PC en la
red local o vía Tailscale) hay que exponer los puertos. El procedimiento
depende de si el host es **Linux nativo** o **Windows 10/11 con WSL2**.

### Caso A — Host Linux nativo (recomendado para servidores)

En Linux, podman-compose expone los puertos directamente en `0.0.0.0` del host
(la IP de la LAN). **No hace falta port forwarding**, solo abrir el firewall:

```bash
sudo ./scripts/setup-lan-access.sh
```

El script detecta automáticamente si usas `firewalld` (RHEL/Fedora) o `ufw`
(Ubuntu/Debian) y abre los puertos TCP del stack más UDP 6881 (BitTorrent).
Idempotente — se puede correr varias veces sin problema.

Verifica que los puertos están escuchando en todas las interfaces:

```bash
ss -tlnp | grep -E ':(8096|8989|7878|9117|9080)\b'
# Debe mostrar 0.0.0.0:PUERTO (no solo 127.0.0.1)
```

### Caso B — Windows 10/11 con podman-machine (WSL2)

En W10, `podman` corre en una VM WSL2 (`podman-machine-default`) con IP
interna `172.19.x.x`. Los containers exponen puertos a esa VM, pero **Windows
no los reenvía automáticamente** a las IPs externas (LAN, Tailscale). Sin
configuración adicional, solo se puede acceder desde el propio W10 vía
`localhost`.

Solución: configurar **port forwarding** desde Windows hacia la WSL2 VM y
abrir los puertos en el firewall de Windows.

#### Procedimiento

1. **Ejecutar como Administrador** (PowerShell):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\setup-lan-access.ps1
   ```
   El script se auto-eleva con UAC si no estás en admin. Detecta la IP de
   la WSL2 VM y crea las reglas de `netsh interface portproxy` y de
   `Windows Firewall` para todos los puertos del stack.

2. **Verificar acceso** desde el propio W10:
   ```powershell
   curl http://<TU-IP-LAN>:8096   # sustituye por tu IP LAN
   # Debe devolver HTTP 302 (redirect al login de Jellyfin)
   ```

3. **Probar desde otro dispositivo**:
   - TV / móvil en la misma Wi-Fi → abre `http://<IP-LAN>:8096`
   - Dispositivo en Tailscale → abre `http://<IP-Tailscale>:8096`

#### ⚠️ El problema de la IP dinámica de WSL2

La IP `172.19.x.x` del WSL2 VM **puede cambiar tras cada restart** de WSL2.
Cuando cambia, las reglas de portproxy quedan apuntando a la IP vieja y dejan
de funcionar.

Tres opciones para mantenerlo estable:

| Solución | Dificultad | Recomendación |
|---|---|---|
| **Re-ejecutar el script** tras cada restart | Trivial | Para setups pequeños / experimentales |
| **Task Scheduler** que detecte WSL2 boot y corra el script | Media | Para setups semi-estables |
| **Instalar Tailscale dentro del WSL2 VM** y usar la IP de Tailscale (estable) como destino del portproxy | Media-alta | **Recomendada** para setups 24/7 |

La opción recomendada (Tailscale en WSL2) da además una IP de Tailscale
dentro de la VM que es estable entre reinicios, ideal para acceso remoto
desde cualquier parte del mundo sin abrir puertos en el router.

#### Instalación rápida de Tailscale en WSL2

```bash
podman machine ssh
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Una vez dentro de la red Tailscale, los containers son accesibles vía
`http://<tailscale-ip-wsl2>:<puerto>` desde cualquier dispositivo Tailscale
(sea de la LAN o no), **incluso desde fuera de casa**.

#### Limitación: BitTorrent UDP 6881

`netsh interface portproxy` solo soporta TCP. El tráfico BitTorrent UDP en
puerto 6881 **no se puede reenviar** desde Windows a WSL2 vía portproxy.

Alternativas para W10:
- Configurar qBittorrent para usar **solo TCP** (Tools → Options →
  Connection → "Use UDP trackers": desmarca "Enable UDP tracker support")
- O instalar Tailscale en la VM y exponer 6881/UDP vía una regla de
  firewall en WSL2 directamente

### Tabla resumen

| Host | Acceso LAN | Acceso Tailscale | Acceso desde Internet |
|---|---|---|---|
| Linux nativo | ✅ directo tras `setup-lan-access.sh` | ✅ si Tailscale en host | Requiere port-forward en router |
| W10 + WSL2 | ⚠️ requiere `setup-lan-access.ps1` + re-ejecutar tras restart | ✅ tras setup o vía Tailscale en WSL2 | Igual + Tailscale funciona fuera |

---

---

## 11. Despliegue en Windows 10/11 (probado en este repo)

Esta sección documenta el caso real probado en W10 + `podman-machine-default`
(WSL2, Fedora 41).

### 10.1. Lo importante: ¿dónde corre el stack?

`podman` en W10 delega en una **VM WSL2 Fedora** (`podman-machine-default`).
Los contenedores NO corren en Windows directamente: corren en la VM. Esto
implica:

- Los paths de `DATA_ROOT` en el `.env` son **paths de la VM** (Linux), no
  de Windows.
- Los volúmenes NTFS de Windows están disponibles dentro de la VM en
  `/mnt/<letra>/...` (ej. `F:\Videos` → `/mnt/f/Videos`).
- El `chown` no funciona en NTFS ni en `9p/DrvFS`; `init.sh` lo detecta y
  aplica `chmod 777` automáticamente.
- Los **hard links** entre `torrents/` y `media/` no funcionarán en NTFS;
  cada download **duplicará el espacio** hasta que el torrent se limpie.

### 10.2. Caso típico: tu colección ya existe

Si tu biblioteca ya está en `F:\Videos` con subcarpetas (`Peliculas/`,
`Series/`, etc.) **NO la reorganices** para encajar en `media/movies/`,
`media/tv/`. En su lugar:

1. Apunta `DATA_ROOT` a la raíz: `DATA_ROOT=/mnt/f/Videos`.
2. Cada `*Arr` se monta `${DATA_ROOT}` en `/arr-data` y configura en la UI
   sus **Root Folders** apuntando a los subdirectorios reales:

   | Servicio | Root folders sugeridos |
   |---|---|
   | Radarr  | `/arr-data/Peliculas`, `/arr-data/Documentales` |
   | Sonarr  | `/arr-data/Series`, `/arr-data/Anime` |
   | Lidarr  | (vacío si no tienes música) |
   | Readarr | (vacío si no tienes libros) |
   | Jellyfin | bibliotecas por cada subcarpeta: Peliculas, Series, Anime, Hanime, Otros, Documentales |

3. `Hanime` y `Otros` quedan como bibliotecas Jellyfin estáticas (los *Arr
   no las gestionan).

### 10.3. Procedimiento paso a paso (W10 + WSL2)

```powershell
# 0. Verificar que podman-machine está corriendo (en PowerShell o Git Bash)
podman machine list
# NAME                     VM TYPE     ...   LAST UP
# podman-machine-default*  wsl         ...   Currently running

# 1. Editar .env para apuntar a tu colección
cp .env.example .env
# Abrir .env y poner:
#   DATA_ROOT=/mnt/f/Videos         # (o donde esté tu colección)
#   PUID=1000
#   PGID=1000
#   TZ=Europe/Madrid

# 2. Ejecutar init.sh DENTRO de la VM (no desde Git Bash, porque Git Bash
#    no ve /mnt/f/).
podman machine ssh -- 'bash /mnt/f/GITHUB_REPOS/Proyecto-Blockbuster/scripts/init.sh'
# Detecta el FS (v9fs/ntfs) y hace chmod 777. No aplica chown porque
# no funcionaría.

# 3. Levantar el stack
podman compose up -d

# 4. Comprobar estado
bash scripts/healthcheck.sh     # sí, desde Git Bash funciona

# 5. Acceder desde el navegador
# http://localhost:8096  → Jellyfin
# http://localhost:8989  → Sonarr
# http://localhost:7878  → Radarr
# ... (los puertos vienen de .env)
```

### 10.4. Verificación E2E (resultados reales)

Con `DATA_ROOT=/mnt/f/Videos` y la estructura `Peliculas/Series/Anime/...`:

| Comprobación | Resultado |
|---|---|
| 10/10 servicios `running` | ✅ en <60s |
| Jellyfin ve las 6 categorías en `/media` (read-only) | ✅ |
| Sonarr puede escribir en `/arr-data/Peliculas` | ✅ |
| FlareSolverr sin puertos en host (`podman port flaresolverr` vacío) | ✅ |
| Sonarr → Jackett (interno) | HTTP 301 |
| Radarr → FlareSolverr (interno) | HTTP 200 |
| Jellyfin accesible desde W10 en `localhost:8096` | HTTP 302 (wizard inicial) |
| Hard link NTFS entre `torrents/` y `media/` | ❌ no soportado por v9fs/DrvFS |

### 10.5. Limitaciones específicas de W10/W11

- **Sin hard links reales**: cada download duplica el espacio hasta que
  limpias el torrent. Con 200 GB libres en `F:` y descargas típicas de
  1-10 GB, es manejable. Si te quedas sin espacio, programa limpieza
  automática de torrents completados en tu cliente.
- **Rendimiento**: WSL2 usa 9P/DrvFS para exponer `F:` a la VM, lo que
  añade algo de latencia. Se nota especialmente en escaneos de bibliotecas
  grandes. Si molesta, mueve la biblioteca a un volumen nativo de la VM
  (`/home/user/multimedia`) y sincroniza con `rsync` desde `F:\Videos`.
- **Permisos**: como `chown` no funciona en NTFS, los contenedores ven
  los archivos con `root:root` aunque el host diga `user:user`. Los
  contenedores con `PUID=1000` no podrán borrar/renombrar archivos de tu
  colección existente. Si necesitas hacerlo, entra al contenedor:
  `podman exec -u root <servicio> rm /arr-data/Peliculas/...`.
- **Claim tokens de Tracearr**: Tracearr usa `JELLYFIN_URL=http://jellyfin:8096`
  internamente. Funciona aunque la URL externa sea `http://localhost:8096`.
- **Jellyfin URL en Seerr/Jellyseerr**: usa SIEMPRE `http://jellyfin:8096` (hostname
  interno de la red `multimedia-net`), **NO** `http://localhost:8096`. Desde
  dentro del contenedor Seerr, `localhost` apunta al propio Seerr, no a
  Jellyfin. Igual aplica para Sonarr/Radarr/Lidarr/Readarr: usa siempre los
  nombres internos (`http://sonarr:8989`, `http://radarr:7878`, etc.).
