## Why

El proyecto `Proyecto-Blockbuster` cuenta únicamente con `Sources.txt`, que describe el plan para desplegar un stack multimedia automatizado con Podman (ecosistema *Arr) que supere la propuesta del vídeo "Jellyfin + Radarr + Sonarr 100% AUTOMATIZADO [PARTE 1]" del canal Pelado Nerd. Hoy no existe ningún artefacto ejecutable (compose, scripts, configuración), por lo que la idea documentada no se puede levantar. Este change materializa ese plan: 10 servicios coordinados, desplegables con `podman-compose`, sobre un volumen único `/data` con hard links, sin exponer `FlareSolverr` a internet.

## What Changes

- Nuevo `docker-compose.yml` en la raíz del repo, compatible con `podman-compose` (Docker Compose spec), declarando los 10 servicios del stack: Jellyfin, Seerr, Sonarr, Radarr, Lidarr, Readarr (con mirror `rreading-glasses`), Bazarr, Jackett, FlareSolverr y Tracearr.
- Nuevo `.env.example` documentando todas las variables necesarias: rutas del host, PUID/PGID, TZ, API keys, timezones, claim tokens de Tracearr (Jellyfin + Sonarr), URL interna de Jackett, etc.
- Scripts de provisioning (`scripts/`) que Automaticen la creación del árbol de directorios bajo `/data/{torrents,media/{movies,tv,music,books}}` con permisos compatibles con PUID/PGID, y la generación local de `config/` por servicio.
- Nuevo `README.md` en la raíz con instrucciones de despliegue: prerrequisitos (podman, podman-compose), pasos de instalación, configuración inicial por servicio, networking interno, y troubleshooting básico.
- Red interna Podman `multimedia-net` (bridge) compartida por todos los servicios; `FlareSolverr` queda sin映射 de puertos al host.
- **BREAKING**: ninguno (no hay estado previo).

## Capabilities

### New Capabilities

- `media-streaming`: Servidor de medios principal (Jellyfin) que expone la biblioteca a los clientes.
- `content-discovery`: Descubrimiento y gestión de peticiones de contenido nuevo (Seerr), integrado con Radarr y Sonarr.
- `series-management`: Gestión automatizada de series de TV (Sonarr).
- `movie-management`: Gestión automatizada de películas (Radarr).
- `music-management`: Gestión automatizada de colecciones de música (Lidarr).
- `book-management`: Gestión automatizada de libros electrónicos y audiolibros (Readarr, con mirror de metadatos `rreading-glasses`).
- `subtitle-management`: Descarga automática de subtítulos (Bazarr) integrada con Sonarr y Radarr.
- `indexer-bypass`: Indexación de torrents y evasión de protecciones Cloudflare (Jackett + FlareSolverr).
- `usage-monitoring`: Panel unificado de monitoreo de reproducción y uso (Tracearr).
- `container-orchestration`: Orquestación del stack completo con Podman: compose file, red interna, volumen único `/data`, scripts de provisioning y documentación.

### Modified Capabilities

- *(ninguna — no hay specs existentes en `openspec/specs/`)*

## Impact

- **Archivos nuevos en la raíz del repo**: `docker-compose.yml`, `.env.example`, `README.md`, `.gitignore` (ajustes a `Sources.txt`/`outputs/` etc.).
- **Nuevos subdirectorios**: `scripts/` (scripts bash de provisioning), `openspec/specs/` (una carpeta por capability nueva).
- **Servicios externos requeridos**: ninguno nuevo. Las imágenes son las oficiales por servicio (`linuxserver/*`, `fallenbagel/jellyfin`, `ghcr.io/seerr-team/seerr`, `ghcr.io/connorgallopo/tracearr`, etc.).
- **Hosts**: el host necesita `podman >= 4.x` y `podman-compose` (versiones se confirmarán en `design.md`); permisos rootless con subuid/subgid si el usuario lo desea.
- **Persistencia**: volumen único `/data` en el host, mapeado en cada servicio, con subdirectorios `torrents/`, `media/movies/`, `media/tv/`, `media/music/`, `media/books/`, `config/<servicio>/`.
- **Networking**: una red bridge interna `multimedia-net`; puertos hacia el host solo para Jellyfin, Seerr, Sonarr, Radarr, Lidarr, Readarr, Bazarr, Jackett y Tracearr; **FlareSolverr no expone puertos al host**.
- **Seguridad**: PUID/PGID unificados vía `.env`; claves API centralizadas en `.env`; `FlareSolverr` accesible solo en la red interna.
