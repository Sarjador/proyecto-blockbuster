## Purpose

Gestiona de forma automatizada la colección de música: monitoriza artistas y álbumes, descarga releases autorizados, los clasifica y los deja listos para `media/music/` sin duplicar espacio en disco.

## ADDED Requirements

### Requirement: Monitorización de artistas y álbumes
El sistema SHALL monitorizar una lista de artistas y/o álbumes y buscar nuevos lanzamientos en los indexadores configurados.

#### Scenario: Nuevo álbum disponible
- **WHEN** un artista monitorizado publica un álbum y este cumple los criterios configurados
- **THEN** el sistema SHALL enviar el torrent al cliente de descargas y planificar la importación

### Requirement: Importación a la biblioteca musical
El sistema SHALL mover (atómicamente, vía hard link) el álbum terminado a `media/music/<Artista>/<Álbum>/` y respetar la estructura de carpetas esperada por Jellyfin.

#### Scenario: Álbum importado
- **WHEN** el cliente de descargas notifica un torrent completo
- **THEN** el sistema SHALL crear el árbol de directorios y mover los archivos por hard link

### Requirement: Hard links desde `/data/torrents`
El sistema SHALL crear enlaces duros desde `torrents/` a `media/music/` para evitar duplicar espacio.

#### Scenario: Verificación de hard link
- **WHEN** un álbum termina de descargarse
- **THEN** los archivos en `media/music/` SHALL ser hard links a los archivos en `torrents/`, verificables por inode idéntico

### Requirement: Perfiles de calidad
El sistema SHALL permitir restringir las descargas a formatos específicos (por ejemplo, FLAC, MP3 320).

#### Scenario: Formato no deseado
- **WHEN** un release aparece en un formato no habilitado por el perfil
- **THEN** el sistema SHALL rechazarlo automáticamente

### Requirement: Acceso solo desde la red interna
El sistema SHALL ser accesible en la red local a través del puerto publicado en el host.

#### Scenario: Usuario accede a la UI
- **WHEN** un usuario abre `http://<host-puerto-lidarr>` desde la LAN
- **THEN** el sistema SHALL servir la interfaz de Lidarr tras autenticación
