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
> recomienda ejecutarlo en una VM Linux o WSL2 con systemd.

---

## 2. Despliegue paso a paso

```bash
# 1. Clonar el repo (o copiar la carpeta)
git clone <url> proyecto-blockbuster && cd proyecto-blockbuster

# 2. Crear el .env a partir del example
cp .env.example .env
$EDITOR .env       # ajustar PUID, PGID, TZ, DATA_ROOT y puertos si hace falta

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
| Bazarr | http://localhost:6767 | Conectar con Sonarr y Radarr por API. |
| Jackett | http://localhost:9117 | Añadir indexadores. |
| Tracearr | http://localhost:3000 | Ver §4 para los claim tokens. |
| FlareSolverr | **no acceso web** | Se configura automáticamente en Jackett. |

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
| Tracearr | `${TRACEARR_PORT}:3000` |
| **FlareSolverr** | **no publicado** (solo red interna) |

Ajusta los valores en el `.env` si tu host tiene algún conflicto.

---

## 7. Troubleshooting

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

---

## 8. Arquitectura decisional

Las decisiones técnicas (por qué `podman-compose`, por qué un volumen único,
por qué imágenes `linuxserver/*`, por qué FlareSolverr aislado) están
documentadas en
[`openspec/changes/podman-multimedia-stack/design.md`](openspec/changes/podman-multimedia-stack/design.md).
Las capacidades del sistema (qué debe hacer cada servicio) están en
`openspec/changes/podman-multimedia-stack/specs/`.

---

## 9. Licencia y aviso

Este repositorio es un orquestador. Las imágenes y servicios desplegados
mantienen sus propias licencias (mayoritariamente GPL/Apache). El usuario es
responsable del uso del contenido que descargue.

Las fuentes consultadas para construir este stack están en [`Sources.txt`](Sources.txt).
