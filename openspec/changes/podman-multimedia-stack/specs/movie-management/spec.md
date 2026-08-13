## Purpose

Gestiona de forma automatizada la biblioteca de películas: monitoriza lanzamientos, descarga los releases que cumplen los criterios, los clasifica y los mueve a `media/movies/` mediante hard links sin duplicar espacio en disco.

## ADDED Requirements

### Requirement: Monitorización de películas
El sistema SHALL monitorizar una lista de películas configuradas y buscar releases en los indexadores disponibles.

#### Scenario: Release disponible para película añadida
- **WHEN** aparece un release que cumple el perfil de calidad configurado para una película en la lista
- **THEN** el sistema SHALL enviar el torrent al cliente de descargas y planificar la importación

### Requirement: Importación a la biblioteca
El sistema SHALL mover (atómicamente, vía hard link) la película terminada a `media/movies/<Título (Año)/<archivo>` y refrescar la biblioteca de Jellyfin.

#### Scenario: Película importada
- **WHEN** el cliente de descargas notifica un torrent completo
- **THEN** el sistema SHALL crear el directorio destino, mover el archivo por hard link y refrescar Jellyfin

### Requirement: Hard links desde `/data/torrents`
El sistema SHALL crear enlaces duros desde `torrents/` a `media/movies/` para no duplicar el espacio en disco.

#### Scenario: Verificación de hard link
- **WHEN** una película termina de descargarse
- **THEN** el archivo en `media/movies/` SHALL ser un hard link al archivo en `torrents/`, verificable por inode idéntico

### Requirement: Perfiles de calidad configurables
El sistema SHALL restringir las descargas a los perfiles de calidad definidos por el administrador.

#### Scenario: Release por debajo del corte
- **WHEN** un release aparece pero su calidad está por debajo del mínimo configurado
- **THEN** el sistema SHALL rechazarlo automáticamente

### Requirement: Acceso solo desde la red interna
El sistema SHALL ser accesible en la red local a través del puerto publicado en el host.

#### Scenario: Administrador accede a la UI
- **WHEN** un administrador abre `http://<host-puerto-radarr>` desde la LAN
- **THEN** el sistema SHALL servir la interfaz tras autenticación
