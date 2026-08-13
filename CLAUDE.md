# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado del proyecto

El proyecto está en fase inicial. El único archivo presente es `Sources.txt`, que documenta el ecosistema de aplicaciones que se pretende desplegar. **No hay código, scripts, `docker-compose.yml`, ni `.git` todavía.** Cualquier futura implementación (compose file, scripts de provisionamiento, configuración de rutas, etc.) debe partir del plan descrito en `Sources.txt`.

## Objetivo

Montar un stack completo de gestión automatizada de bibliotecas multimedia con Podman, basado en el ecosistema *Arr. La motivación es superar la propuesta del vídeo "Jellyfin + Radarr + Sonarr 100% AUTOMATIZADO [PARTE 1]" del canal Pelado Nerd, cubriendo películas, series, música, libros, subtítulos, peticiones, indexación y monitoreo.

## Arquitectura planificada (según `Sources.txt`)

| Categoría | Servicio |
|---|---|
| Streaming | Jellyfin |
| Peticiones / descubrimiento | Seerr |
| Series | Sonarr |
| Películas | Radarr |
| Música | Lidarr |
| Libros | Readarr (con mirror de metadatos `rreading-glasses`) |
| Subtítulos | Bazarr |
| Indexación | Jackett + FlareSolverr |
| Monitoreo | Tracearr |

## Decisiones técnicas obligatorias (leídas de `Sources.txt`)

Al implementar el stack, respetar estas reglas que las propias fuentes documentales marcan como críticas:

- **Hard links / volumen único**: nunca separar `/downloads` de `/media` en contenedores. Mapear un único volumen raíz (`/data`) para que las apps compartan sistema de archivos y los archivos terminados se muevan atómicamente sin复制 datos.
  - Estructura recomendada: `/data/torrents`, `/data/media/movies`, `/data/media/tv`, etc.
- **Podman compose**: usar un `docker-compose.yml` (Podman es compatible con la spec de Docker) para levantar todo el conjunto.
- **FlareSolverr no debe exponerse a internet**: accesible solo dentro de la red interna de contenedores.
- **Variables de entorno centralizadas** en un `.env` para rutas y API keys, facilitando la replicación en otros servidores.

## Fuentes

Toda la documentación de referencia (URLs oficiales, repos GitHub, vídeo de YouTube motivador) está listada en `Sources.txt`. Cualquier duda sobre un servicio concreto debe resolverse contrastando contra esas fuentes antes de tomar decisiones de configuración.

## Espacio de trabajo del usuario

Este repositorio convive con otros muchos en `F:\GITHUB_REPOS` (incluido `PyRoBot`, `everything-claude-code`, `customGrok`, etc.). Las convenciones globales del usuario están en `F:\GITHUB_REPOS\CLAUDE.md` (gestión de tareas, filosofía de colaboración, protocolos de sesión) y en `~/.claude/rules/` (coding style, testing, git workflow, etc.). Las instrucciones allí descritas aplican también a este proyecto, pero las decisiones de arquitectura del stack multimedia se rigen por `Sources.txt`.
