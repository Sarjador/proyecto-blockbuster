## Purpose

Permite a los usuarios descubrir, solicitar y seguir el ciclo de vida de contenido multimedia nuevo (películas y series), integrándose con los gestores automatizados para que las peticiones aprobadas acaben descargadas y disponibles.

## ADDED Requirements

### Requirement: Descubrimiento de contenido
El sistema SHALL presentar a los usuarios un catálogo de películas y series con tendencias, populares, próximos estrenos y recomendaciones.

#### Scenario: Usuario navega tendencias
- **WHEN** un usuario abre la sección de tendencias
- **THEN** el sistema SHALL mostrar al menos 20 títulos con póster y resumen

### Requirement: Solicitudes de usuarios
El sistema SHALL permitir a los usuarios solicitar películas y series que no estén ya en la biblioteca o en cola de descarga.

#### Scenario: Solicitud aprobada
- **WHEN** un usuario autenticado solicita una película y existe un gestor correspondiente (Radarr) configurado
- **THEN** el sistema SHALL enviar la solicitud a Radarr y reflejar el estado "solicitado" en la interfaz

#### Scenario: Solicitud duplicada
- **WHEN** un usuario pide un título que ya está en la biblioteca o pendiente
- **THEN** el sistema SHALL informar del estado actual en lugar de crear una nueva solicitud

### Requirement: Integración con gestores automatizados
El sistema SHALL conectarse vía API con Radarr y Sonarr para crear solicitudes remotas y leer el estado de las mismas.

#### Scenario: Servicio de gestión no disponible
- **WHEN** Radarr o Sonarr no responden a la API
- **THEN** el sistema SHALL mantener su servicio activo y registrar el fallo en su registro

### Requirement: Acceso solo desde la red interna
El sistema SHALL ser accesible solo en la red local del host, sin exposición a internet.

#### Scenario: Cliente en LAN accede a la interfaz
- **WHEN** un usuario abre `http://<host-puerto-seerr>` desde la red local
- **THEN** el sistema SHALL responder la interfaz de Seerr

#### Scenario: Intento de acceso desde exterior
- **WHEN** una petición llega al servicio desde fuera de la red local
- **THEN** el sistema SHALL no tener un puerto expuesto y por tanto SHALL rechazar la conexión a nivel de red
