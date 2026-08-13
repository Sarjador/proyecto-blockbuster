## Purpose

Gestiona de forma automatizada la biblioteca de libros electrónicos y audiolibros, apoyándose en un mirror de metadatos de la comunidad (`rreading-glasses`) ante el retiro oficial de Readarr, y dejando los archivos en `media/books/` sin duplicar espacio en disco.

## ADDED Requirements

### Requirement: Mirror de metadatos
El sistema SHALL configurarse para usar `rreading-glasses` como fuente de metadatos en lugar de los proveedores originales.

#### Scenario: Búsqueda de un libro
- **WHEN** un usuario busca un libro por título o autor
- **THEN** el sistema SHALL devolver resultados del mirror `rreading-glasses`

### Requirement: Monitorización de autores
El sistema SHALL monitorizar autores y libros configurados y descargar nuevos lanzamientos en los formatos autorizados.

#### Scenario: Nuevo libro publicado
- **WHEN** un autor monitorizado publica un libro en un formato habilitado
- **THEN** el sistema SHALL enviar el torrent al cliente de descargas y planificar la importación

### Requirement: Importación a la biblioteca
El sistema SHALL mover (atómicamente, vía hard link) el libro terminado a `media/books/<Autor>/<Título>/` y mantener la estructura esperada por Jellyfin.

#### Scenario: Libro importado
- **WHEN** el cliente de descargas notifica un torrent completo
- **THEN** el sistema SHALL crear el directorio destino y mover los archivos por hard link

### Requirement: Hard links desde `/data/torrents`
El sistema SHALL crear enlaces duros desde `torrents/` a `media/books/`.

#### Scenario: Verificación de hard link
- **WHEN** un libro termina de descargarse
- **THEN** los archivos en `media/books/` SHALL ser hard links a los archivos en `torrents/`, verificables por inode idéntico

### Requirement: Acceso solo desde la red interna
El sistema SHALL ser accesible en la red local a través del puerto publicado en el host.

#### Scenario: Usuario accede a la UI
- **WHEN** un usuario abre `http://<host-puerto-readarr>` desde la LAN
- **THEN** el sistema SHALL servir la interfaz de Readarr tras autenticación
