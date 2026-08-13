## Context

El repositorio `Proyecto-Blockbuster` solo contiene `Sources.txt`, que documenta el stack multimedia objetivo. No hay código desplegable. El host será un sistema donde Podman esté disponible; los servicios necesitan coordinarse entre sí (Sonarr llama a Jackett, Tracearr lee Jellyfin y Sonarr, etc.) y compartir un único árbol de archivos para que los hard links entre `torrents/` y `media/` sean posibles. Las restricciones críticas provienen directamente de `Sources.txt`:

- Volumen único `/data` mapeado en host (hard links atómicos, sin duplicar espacio).
- `FlareSolverr` no debe exponer puertos al host.
- Configuración sensible en `.env`.
- Compatible con `podman-compose`.

## Goals / Non-Goals

**Goals:**
- Diseñar un `docker-compose.yml` declarativo, idempotente y compatible con `podman-compose` v1.x.
- Definir imágenes, etiquetas y políticas de reinicio por servicio.
- Definir mapeo de puertos, red interna y volumen único.
- Definir la estructura exacta de `/data` en el host y los subdirectorios que cada servicio monta.
- Definir las variables de `.env` mínimas y su semántica.
- Definir los scripts de provisioning y su contrato.

**Non-Goals:**
- Configuración fina de cada servicio (calidad, perfiles, indexadores concretos). Eso se hará por UI tras el primer arranque y queda fuera del compose.
- Auth SSO / usuarios centralizados. Se deja la autenticación por defecto de cada servicio.
- Backups automatizados. Solo se documenta el punto de montaje para que un backup externo pueda operar sobre `/data`.
- HTTPS / reverse proxy. Queda como evolución posterior; este change entrega HTTP plano en LAN.

## Decisions

### D1. Orquestación: `podman-compose` con `docker-compose.yml`
- **Decisión**: usar `podman-compose` (CLI Python) leyendo un único `docker-compose.yml` con la spec `compose-spec` (compatible con Compose v3+ reducido a campos soportados por podman-compose).
- **Por qué**: ya está documentado en `Sources.txt`; reproducible y familiar; no requiere K8s ni quadlets.
- **Alternativas consideradas**:
  - *Pods de Podman (`podman pod`)*: no escala bien para 10 servicios con dependencias cruzadas; añade otra capa de configuración.
  - *Quadlets* (`/etc/containers/systemd/`): muy acoplado a systemd y menos portátil; queda como evolución.

### D2. Imágenes por servicio
| Servicio  | Imagen | Justificación |
|---|---|---|
| Jellyfin | `jellyfin/jellyfin:latest` | Imagen oficial; mejor rendimiento de transcodificación que variantes LSIO. |
| Seerr   | `fallenbagel/jellyseerr:latest` (o `ghcr.io/seerr-team/seerr:latest` si está publicado) | Mantenedor activo que coincide con la URL de `Sources.txt` (`seerr.dev`). |
| Sonarr  | `lscr.io/linuxserver/sonarr:latest` | Imagen canónica de la comunidad *Arr. |
| Radarr  | `lscr.io/linuxserver/radarr:latest` | Idem. |
| Lidarr  | `lscr.io/linuxserver/lidarr:latest` | Idem. |
| Readarr | `lscr.io/linuxserver/readarr:latest` | Idem; mirror de metadatos se configura en la UI. |
| Bazarr  | `lscr.io/linuxserver/bazarr:latest` | Idem. |
| Jackett | `lscr.io/linuxserver/jackett:latest` | Idem. |
| FlareSolverr | `ghcr.io/flaresolverr/flaresolverr:latest` | Imagen oficial del proyecto. |
| Tracearr | `ghcr.io/connorgallopo/tracearr:latest` | Imagen oficial del proyecto. |

- **Por qué `linuxserver/*` para los *Arr**: PUID/PGID consistente, documentación uniforme, rootless amigable.
- **Alternativas**: Hotio (`hotio/*`) tiene builds más recientes; LSIO es la referencia en guías.

### D3. Red: bridge interna `multimedia-net`
- **Decisión**: una sola red bridge definida por el usuario, `multimedia-net`, con todos los servicios conectados.
- **Por qué**: simplifica resolución DNS entre servicios (Sonarr llama a `http://jackett:9117`), aísla el stack del resto de redes del host.
- **Alternativas**: red por defecto de Podman — no permite nombres consistentes entre arranques si los contenedores se recrean.

### D4. Volumen único `/data`
- **Decisión**: todos los servicios que necesiten persistencia montan subdirectorios de un mismo bind mount del host (por defecto `~/.local/share/podman/multimedia` o ruta configurable `DATA_ROOT`).
- **Estructura**:
  ```
  ${DATA_ROOT}/
  ├── torrents/
  ├── media/
  │   ├── movies/
  │   ├── tv/
  │   ├── music/
  │   └── books/
  └── config/
      ├── jellyfin/
      ├── seerr/
      ├── sonarr/
      ├── radarr/
      ├── lidarr/
      ├── readarr/
      ├── bazarr/
      ├── jackett/
      └── tracearr/
  ```
- **Por qué**: cualquier servicio puede hacer hard links entre `torrents/` y `media/` porque comparten filesystem. Esto evita el error más común en stacks *Arr mal desplegados.

### D5. Mapeo de puertos al host
- **Decisión**: solo se publican los puertos de UI/API de los servicios visibles. `FlareSolverr` queda sin puerto publicado.
- **Tabla** (valores por defecto, editables en `.env`):

  | Servicio | Puerto host | Puerto contenedor |
  |---|---|---|
  | Jellyfin | 8096 | 8096 |
  | Seerr | 5055 | 5055 |
  | Sonarr | 8989 | 8989 |
  | Radarr | 7878 | 7878 |
  | Lidarr | 8686 | 8686 |
  | Readarr | 8787 | 8787 |
  | Bazarr | 6767 | 6767 |
  | Jackett | 9117 | 9117 |
  | Tracearr | 3000 | 3000 |
  | FlareSolverr | **no publicado** | 8191 |

### D6. Política de reinicio y salud
- **Decisión**: `restart: unless-stopped` para todos los servicios. Healthchecks solo donde la imagen los expone (`HEALTHCHECK` en Dockerfile); no se definen healthchecks inline para no acoplar la versión.

### D7. Variables de entorno desde `.env`
- **Decisión**: todas las rutas, PUID/PGID, TZ, puertos y claves se leen de `.env`. Se distribuye `.env.example` documentado.
- **Variables mínimas**:
  - `PUID=1000`, `PGID=1000`, `TZ=Europe/Madrid`
  - `DATA_ROOT=/var/lib/podman/multimedia`
  - `JELLYFIN_PORT=8096`, `SEERR_PORT=5055`, `SONARR_PORT=8989`, `RADARR_PORT=7878`, `LIDARR_PORT=8686`, `READARR_PORT=8787`, `BAZARR_PORT=6767`, `JACKETT_PORT=9117`, `TRACEARR_PORT=3000`
  - `JELLYFIN_CLAIM_TOKEN` (opcional, para Tracearr)
  - `SONARR_CLAIM_TOKEN` (opcional, para Tracearr)
  - `READARR_METADATA_SOURCE=rreading-glasses` (default) y, si requiere URL, `READARR_METADATA_URL`
  - `FLARESOLVERR_URL=http://flaresolverr:8191` (para Jackett)

### D8. UID/GID en rootless
- **Decisión**: usar las imágenes `linuxserver/*` con `PUID`/`PGID` garantiza que el usuario dentro del contenedor escribirá como el UID del host, lo que habilita hard links entre bind mounts en rootless Podman.
- **Por qué**: requisito de Sources.txt ("vale más un volumen único que tener `/downloads` y `/media` separados").
- **Alternativa**: `--userns=keep-id` + permisos 0777 en `/data`. Más frágil, no se adopta.

### D9. Scripts de provisioning
- **Decisión**: `scripts/init.sh` crea el árbol de directorios bajo `${DATA_ROOT}` con permisos `0755` y propiedad `${PUID}:${PGID}` usando `chown`. Se ejecuta una vez antes del primer `podman-compose up`.
- **Por qué**: automatiza la creación de la estructura documentada en D4 sin requerir que el operador la haga a mano.
- **Validación**: el script imprime la estructura creada y los pasos siguientes.

### D10. Documentación inicial
- **Decisión**: `README.md` en la raíz con (1) requisitos, (2) primer despliegue, (3) configuración inicial por servicio (enlaces a las UIs locales), (4) troubleshooting.
- **Por qué**: el operador nuevo debe poder levantar el stack siguiendo exclusivamente el README.

## Risks / Trade-offs

- **R1. Hard links fallan con subuid/subgid mal configurados** → Mitigación: el script de provisioning valida que `PUID`/`PGID` son numéricos y existen; el README documenta que rootless Podman requiere `subuid`/`subgid` correctos.
- **R2. Readarr está archivado upstream** → Mitigación: dependemos del mirror `rreading-glasses`; si el mirror cae, la búsqueda de metadatos falla pero el resto del stack sigue funcionando. El `tracearr` y `bazarr` no dependen de Readarr.
- **R3. Imágenes `latest` pueden romper compatibilidad** → Mitigación: fijar versiones en `.env` (`SONARR_VERSION=4.0.0.929`, etc.) en una iteración posterior; este change empieza con `latest` para reducir fricción inicial.
- **R4. Compose v3 completo no soportado por podman-compose** → Mitigación: revisar changelog de podman-compose antes de usar `secrets`, `configs` o `develop.watch`; no se usarán en este change.
- **R5. Claim tokens de Tracearr caducan** → Mitigación: documentar en el README cómo regenerarlos; no es bloqueante porque Tracearr funciona sin ellos, solo pierde notificaciones iniciales.
- **R6. Conflictos de puertos con otros servicios del host** → Mitigación: todos los puertos son variables; el `init.sh` puede opcionalmente validar disponibilidad con `ss`.

## Migration Plan

No hay estado previo a migrar — el repositorio está vacío. Pasos de despliegue:

1. Operador instala `podman` y `podman-compose` (documentado en README).
2. `cp .env.example .env` y ajusta `PUID`, `PGID`, `TZ`, `DATA_ROOT`, puertos.
3. `./scripts/init.sh` crea el árbol bajo `${DATA_ROOT}`.
4. `podman-compose up -d` levanta los 10 servicios.
5. Operador entra a cada UI y completa la configuración inicial (indexadores en Jackett, perfiles de calidad, claim tokens de Tracearr, mirror `rreading-glasses` en Readarr).
6. Operador descarga un primer torrent de prueba y verifica que el archivo aparece en `media/` como hard link (`ls -li` muestra el mismo inode).

**Rollback**: `podman-compose down -v` para parar y limpiar contenedores. Los datos en `${DATA_ROOT}` no se tocan; para un rollback completo basta con `rm -rf ${DATA_ROOT}/config/<servicio>`.

## Open Questions

- ¿La imagen de Seerr debe ser `fallenbagel/jellyseerr` o `ghcr.io/seerr-team/seerr`? A día de hoy `seerr.dev` apunta al repo `seerr-team/seerr`; se elige `fallenbagel/jellyseerr` como estable conocida y se deja nota en `README.md` para migrar a la oficial cuando esté pulida.
- ¿Se quiere un cliente de torrents dentro del compose (qBittorrent/Transmission) o se asume uno externo? Se asume externo — está fuera del scope documentado en `Sources.txt`. Se documenta en el README cómo cablear Sonarr/Radarr/Lidarr/Readarr a un cliente externo.
- ¿Tracearr debe poder escanear todos los *Arr o solo Sonarr + Jellyfin? Se deja la lista ampliada a Jellyfin + Sonarr + Radarr + Lidarr + Readarr; se documenta en el README cómo acotar.
