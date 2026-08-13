## Purpose

Actúa como puente entre los gestores automatizados (*Arr) y múltiples indexadores de torrents, agregando las consultas en un único endpoint Torznab y resolviendo las protecciones Cloudflare que muchos sitios imponen.

## ADDED Requirements

### Requirement: Agregación de indexadores
El sistema SHALL permitir configurar múltiples indexadores (públicos y privados) y SHALL exponer cada uno como un feed Torznab individual y como un feed agregado.

#### Scenario: Sonarr consulta un índice añadido
- **WHEN** Sonarr consulta el feed Torznab para un índice configurado
- **THEN** el sistema SHALL devolver los resultados del índice transformado al formato Torznab

### Requirement: Evasión de Cloudflare mediante FlareSolverr
El sistema SHALL enrutar las peticiones a sitios protegidos por Cloudflare a través de FlareSolverr, SHALL reintentar automáticamente y SHALL devolver el contenido solicitado al cliente.

#### Scenario: Indexador protegido por challenge
- **WHEN** Sonarr consulta un indexador que responde con un challenge de Cloudflare
- **THEN** el sistema SHALL delegar la resolución en FlareSolverr y SHALL devolver los resultados a Sonarr

#### Scenario: FlareSolverr no disponible
- **WHEN** FlareSolverr no responde
- **THEN** el sistema SHALL registrar el error y SHALL devolver un fallo a Sonarr (no se simulan resultados vacíos)

### Requirement: Aislamiento de FlareSolverr
El servicio FlareSolverr SHALL estar unido exclusivamente a la red interna del stack y SHALL no exponer ningún puerto al host.

#### Scenario: Intento de conexión desde fuera del host
- **WHEN** un cliente en internet intenta conectar al puerto de FlareSolverr
- **THEN** la conexión SHALL ser rechazada a nivel de red (no hay puerto mapeado)

### Requirement: Seguridad de API keys
El sistema SHALL gestionar las claves de los indexadores mediante variables de entorno y SHALL no escribirlas en logs.

#### Scenario: Log de error en indexador
- **WHEN** un indexador devuelve un error de autenticación
- **THEN** el mensaje SHALL identificar el indexador por nombre, no SHALL incluir la clave
