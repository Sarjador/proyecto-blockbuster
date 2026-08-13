## 1. Inicialización del repositorio

- [x] 1.1 Inicializar `git` en la raíz del repo (`git init`, configurar `user.name`/`user.email` local).
- [x] 1.2 Crear `.gitignore` excluyendo `.env`, `data/`, `*.log`, `__pycache__/`, `outputs/`, `Outputs/`, `agent_workspace/`.
- [x] 1.3 Mover `Sources.txt` a su ubicación definitiva (raíz) y confirmar que está commiteable.

## 2. Archivos de configuración del stack

- [x] 2.1 Crear `.env.example` con todas las variables definidas en `design.md` §D7: `PUID`, `PGID`, `TZ`, `DATA_ROOT`, puertos por servicio, `JELLYFIN_CLAIM_TOKEN`, `SONARR_CLAIM_TOKEN`, `READARR_METADATA_SOURCE`, `READARR_METADATA_URL`, `FLARESOLVERR_URL`.
- [x] 2.2 Crear `docker-compose.yml` con la versión `3.8`, declarando la red `multimedia-net` (driver `bridge`) pero SIN servicios todavía.
- [x] 2.3 Añadir el servicio `flaresolverr` (imagen `ghcr.io/flaresolverr/flaresolverr:latest`, sin `ports:` en host, volumen propio de config, `restart: unless-stopped`, vars `LOG_LEVEL=info`).
- [x] 2.4 Añadir los servicios `jackett` y `bazarr` (imágenes `lscr.io/linuxserver/*`, mapeo de puertos desde `.env`, volumen `${DATA_ROOT}/config/<svc>` y `${DATA_ROOT}/torrents`, vars `PUID`/`PGID`/`TZ`).
- [x] 2.5 Añadir los servicios `sonarr`, `radarr`, `lidarr`, `readarr` con la misma forma, montando `${DATA_ROOT}/media/<categoria>` adicional a `torrents/`.
- [x] 2.6 Añadir el servicio `jellyfin` con imagen `jellyfin/jellyfin:latest`, montando `${DATA_ROOT}/config/jellyfin`, `${DATA_ROOT}/media` y `${DATA_ROOT}/torrents` (solo lectura donde aplique).
- [x] 2.7 Añadir el servicio `seerr` (imagen `fallenbagel/jellyseerr:latest`, volumen `config/seerr`, vars `LOG_LEVEL=info`, puertos según `.env`).
- [x] 2.8 Añadir el servicio `tracearr` (imagen `ghcr.io/connorgallopo/tracearr:latest`, volumen `config/tracearr`, vars `BASE_URL` opcional).
- [x] 2.9 Verificar `podman-compose config` produce un YAML válido y que NO hay ningún `ports:` mapeando al host para `flaresolverr`.

## 3. Scripts de provisioning

- [x] 3.1 Crear `scripts/init.sh` que (a) valide `PUID`/`PGID` numéricos, (b) cree `${DATA_ROOT}/{torrents,media/{movies,tv,music,books},config/{jellyfin,seerr,sonarr,radarr,lidarr,readarr,bazarr,jackett,flaresolverr,tracearr}}` con `mkdir -p`, (c) aplique `chown -R ${PUID}:${PGID}` sobre `${DATA_ROOT}`, (d) imprima la estructura resultante con `tree` o `find`.
- [x] 3.2 Hacer ejecutable `scripts/init.sh` (`chmod +x`) y verificar la salida con un `DATA_ROOT` temporal de prueba.
- [x] 3.3 Añadir un `scripts/healthcheck.sh` que compruebe `podman ps --format '{{.Names}} {{.Status}}'` para los 10 servicios y devuelva un resumen entre ✅ y ❌.

## 4. Documentación

- [x] 4.1 Crear `README.md` con secciones: (a) Introducción, (b) Requisitos previos (`podman >= 4.x`, `podman-compose`, `subuid`/`subgid` para rootless), (c) Despliegue paso a paso, (d) Configuración inicial por servicio (enlaces a las UIs y puertos), (e) Configuración del mirror `rreading-glasses` en Readarr, (f) Troubleshooting (problemas comunes y soluciones).
- [x] 4.2 Documentar en el `README.md` cómo generar los claim tokens de Tracearr (`JELLYFIN_CLAIM_TOKEN`, `SONARR_CLAIM_TOKEN`) y dónde pegarlos en el `.env`.
- [x] 4.3 Documentar la convención de volúmenes en una sección "Estructura del host" para que un backup externo sepa qué copiar.

## 5. Validación de extremo a extremo

- [x] 5.1 Levantar el stack con `podman-compose up -d` y verificar que los 10 contenedores están en estado `running` en menos de 2 minutos.
- [x] 5.2 Acceder a la UI de Jellyfin y verificar que la biblioteca está vacía pero la carpeta `media/movies` está correctamente mapeada.
- [x] 5.3 Añadir un indexador público en Jackett y conectarlo a Sonarr; verificar que Sonarr resuelve `http://jackett:9117` desde la red interna.
- [x] 5.4 Solicitar una búsqueda en Sonarr y, si encuentra un release, simular descarga → verificar que el archivo termina en `media/tv/` como hard link (`ls -li` muestra mismo inode que en `torrents/`).
- [x] 5.5 Comprobar que `podman ps --filter name=flaresolverr` no expone puertos (`0.0.0.0:0->8191` no debe aparecer).
- [x] 5.6 Ejecutar `bash scripts/healthcheck.sh` y verificar que devuelve 10/10 servicios en verde.

## 6. Cierre del change

- [x] 6.1 Confirmar que ningún secreto real quedó commiteado (`grep -rE 'api_key|api_key=' .env.example` y revisión manual).
- [x] 6.2 Hacer un commit inicial con mensaje `chore: scaffold podman multimedia stack` siguiendo el formato de la guía global (`common/git-workflow.md`).
- [x] 6.3 Ejecutar `npx openspec validate --change podman-multimedia-stack --strict` y resolver cualquierwarning antes de pedir la revisión.
