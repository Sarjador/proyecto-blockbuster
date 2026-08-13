## Purpose

Proporciona un panel centralizado para monitorear en tiempo real la reproducción y el uso del servidor de medios, agregando estadísticas de los distintos servicios del stack.

## ADDED Requirements

### Requirement: Monitoreo de sesiones activas
El sistema SHALL agregar la información de sesiones activas desde Jellyfin y SHALL mostrarla en una vista única.

#### Scenario: Usuario reproduce una película
- **WHEN** Jellyfin inicia una sesión de reproducción
- **THEN** el sistema SHALL mostrar al administrador la sesión con usuario, contenido, dispositivo y bitrate

### Requirement: Métricas históricas de uso
El sistema SHALL persistir el historial de reproducciones y SHALL permitir consultar métricas de uso por usuario, contenido y rango de fechas.

#### Scenario: Consulta de uso por usuario
- **WHEN** un administrador filtra el historial por usuario y rango de fechas
- **THEN** el sistema SHALL devolver la lista de reproducciones con duración y bytes servidos

### Requirement: Detección de cuentas compartidas
El sistema SHALL aplicar heurísticas (múltiples IPs simultáneas, ubicaciones geográficas incompatibles) y SHALL marcar comportamientos sospechosos.

#### Scenario: Dos IPs geográficamente distantes en la misma cuenta
- **WHEN** una misma cuenta inicia sesión desde dos IPs en países distintos en una ventana corta
- **THEN** el sistema SHALL marcar la cuenta con una alerta visible en el panel

### Requirement: Integración con Sonarr
El sistema SHALL conectarse a Sonarr para complementar las estadísticas con el historial de descargas y eventos del gestor.

#### Scenario: Consulta de eventos de Sonarr
- **WHEN** el panel consulta la actividad reciente
- **THEN** el sistema SHALL incluir los últimos eventos de Sonarr

### Requirement: Acceso solo desde la red interna
El sistema SHALL ser accesible en la red local a través del puerto publicado en el host.

#### Scenario: Administrador abre el panel
- **WHEN** un administrador abre `http://<host-puerto-tracearr>` desde la LAN
- **THEN** el sistema SHALL mostrar el dashboard de Tracearr
