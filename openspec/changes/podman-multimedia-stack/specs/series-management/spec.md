## Purpose

Gestiona de forma automatizada la biblioteca de series de TV: monitoriza releases, descarga nuevos episodios, los clasifica correctamente y los mueve a `media/tv/` mediante hard links para evitar duplicación.

## ADDED Requirements

### Requirement: Monitorización continua de series
El sistema SHALL monitorizar una lista de series configuradas y buscar nuevos episodios en los indexadores configurados.

#### Scenario: Nuevo episodio disponible
- **WHEN** una serie monitorizada publica un episodio que cumple los criterios de calidad configurados
- **THEN** el sistema SHALL enviar el torrent al cliente de descargas y planificar la importación

### Requirement: Importación a la biblioteca
El sistema SHALL mover (atómicamente, vía hard link) los episodios terminados a `media/tv/<Serie>/<Temporada>/<Episodio>` y refrescar la biblioteca de Jellyfin.

#### Scenario: Descarga completada
- **WHEN** el cliente de descargas notifica que un torrent está completo
- **THEN** el sistema SHALL importarlo bajo la ruta correcta y notificar a Jellyfin

### Requirement: Hard links desde `/data/torrents`
El sistema SHALL crear enlaces duros desde `torrents/` a `media/tv/` para que un mismo archivo no ocupe espacio duplicado.

#### Scenario: Verificación de hard link
- **WHEN** un episodio termina de descargarse
- **THEN** el archivo en `media/tv/` SHALL ser un hard link al archivo en `torrents/`, verificable por inode idéntico

### Requirement: Configuración de perfiles de calidad
El sistema SHALL permitir definir perfiles de calidad (por ejemplo, 1080p WEB-DL) y restringirse a ellos.

#### Scenario: Release fuera de perfil
- **WHEN** aparece un release que no cumple el perfil de calidad
- **THEN** el sistema SHALL rechazarlo automáticamente y registrarlo como "rejected"

### Requirement: Acceso solo desde la red interna
El sistema SHALL estar disponible en la red local a través del puerto publicado en el host y SHALL no exponer API públicamente.

#### Scenario: Administrador accede a la UI
- **WHEN** un administrador abre `http://<host-puerto-sonarr>` desde la LAN
- **THEN** el sistema SHALL requerir autenticación y mostrar la interfaz
