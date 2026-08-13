## Purpose

Descarga y sincroniza subtítulos para la biblioteca de películas y series de forma automática, alineada con los releases ya importados por Sonarr y Radarr, sin requerir intervención manual.

## ADDED Requirements

### Requirement: Detección de episodios y películas sin subtítulos
El sistema SHALL consultar periódicamente la biblioteca de Sonarr y Radarr para localizar contenido al que le falten subtítulos en los idiomas configurados.

#### Scenario: Episodio nuevo sin subtítulo en idioma configurado
- **WHEN** Sonarr importa un episodio y este no tiene subtítulo en alguno de los idiomas habilitados
- **THEN** el sistema SHALL buscar un subtítulo adecuado y descargarlo

### Requirement: Búsqueda en múltiples proveedores
El sistema SHALL consultar varios proveedores de subtítulos (OpenSubtitles y otros configurados) y SHALL priorizar los releases que coincidan con el grupo de release del archivo.

#### Scenario: Proveedor no disponible
- **WHEN** un proveedor de subtítulos no responde
- **THEN** el sistema SHALL continuar la consulta con los proveedores restantes y SHALL registrar el fallo

### Requirement: Idioma por defecto y overrides
El sistema SHALL tener un idioma por defecto configurable y SHALL permitir overrides por serie o película.

#### Scenario: Override por serie
- **WHEN** una serie tiene un override de idioma distinto del global
- **THEN** el sistema SHALL buscar subtítulos en el idioma del override

### Requirement: Integración con la biblioteca
El sistema SHALL colocar los subtítulos en la misma carpeta que el archivo de vídeo, con un nombre coincidente para que Jellyfin los detecte.

#### Scenario: Subtítulo colocado correctamente
- **WHEN** se descarga un subtítulo para un episodio
- **THEN** el archivo `.srt` SHALL quedar junto al `.mkv`/` .mp4` con el mismo nombre base

### Requirement: Acceso solo desde la red interna
El sistema SHALL ser accesible en la red local a través del puerto publicado en el host.

#### Scenario: Administrador accede a la UI
- **WHEN** un administrador abre `http://<host-puerto-bazarr>` desde la LAN
- **THEN** el sistema SHALL servir la interfaz de Bazarr tras autenticación
