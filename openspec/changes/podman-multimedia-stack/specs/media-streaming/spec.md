## Purpose

Expone la biblioteca multimedia unificada a los clientes del hogar a través de un servidor de medios centralizado, con descubrimiento automático de metadatos y soporte multi-dispositivo.

## ADDED Requirements

### Requirement: Reproducción local y remota
El sistema SHALL reproducir películas, series, música, audiolibros y libros electrónicos desde la biblioteca persistida, con acceso simultáneo para múltiples clientes.

#### Scenario: Cliente accede a una película
- **WHEN** un cliente autorizado solicita el stream de un archivo en `media/movies/`
- **THEN** el sistema SHALL servir el contenido por HTTP con transcodificación adaptativa cuando el dispositivo lo requiera

#### Scenario: Múltiples clientes simultáneos
- **WHEN** dos o más clientes están reproduciendo contenido a la vez
- **THEN** el sistema SHALL servir streams independientes sin interferencia

### Requirement: Descubrimiento automático de biblioteca
El sistema SHALL escanear los directorios `media/movies`, `media/tv`, `media/music` y `media/books` y construir la biblioteca con metadatos, carátulas y descripciones.

#### Scenario: Nueva película añadida al volumen
- **WHEN** aparece un nuevo archivo en `media/movies/`
- **THEN** el sistema SHALL detectarlo en una biblioteca como máximo en el siguiente escaneo y añadirlo con metadatos y póster

#### Scenario: Carpeta de series vacía
- **WHEN** la carpeta `media/tv/` no contiene archivos
- **THEN** el sistema SHALL mostrar la biblioteca de series como vacía sin generar errores

### Requirement: Integración con monitoreo
El sistema SHALL exponer su API de actividad y notificaciones para que el servicio de monitoreo registre qué usuario reproduce qué contenido.

#### Scenario: Servicio de monitoreo suscrito
- **WHEN** el servicio de monitoreo consulta la API de sesiones activas
- **THEN** el sistema SHALL devolver la lista de usuarios activos, contenido en reproducción y tipo de cliente

### Requirement: Acceso solo desde la red interna
El sistema SHALL estar disponible para clientes en la red local a través del puerto publicado en el host, sin autenticación por defecto hasta que el administrador la configure.

#### Scenario: Cliente en LAN solicita la interfaz web
- **WHEN** un usuario abre `http://<host-puerto-jellyfin>` desde un dispositivo en la red local
- **THEN** el sistema SHALL responder la interfaz de Jellyfin
