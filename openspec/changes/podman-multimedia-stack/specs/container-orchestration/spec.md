## Purpose

Permite levantar, parar y mantener el stack multimedia completo en un host con Podman, de forma reproducible, mediante un único archivo compatible con `podman-compose` y un conjunto de scripts de provisioning.

## ADDED Requirements

### Requirement: Despliegue con un solo comando
El sistema SHALL permitir levantar todo el stack con `podman-compose up -d` desde la raíz del repositorio, sin requerir pasos manuales adicionales más allá de editar el `.env`.

#### Scenario: Despliegue desde cero
- **WHEN** el operador copia `.env.example` a `.env`, edita las variables y ejecuta `podman-compose up -d`
- **THEN** los 10 servicios SHALL arrancar en la red interna `multimedia-net` con el volumen `/data` montado

#### Scenario: Servicio dependiente no disponible
- **WHEN** Sonarr arranca antes de que Jackett responda
- **THEN** el sistema SHALL permitir que Sonarr reintente la conexión sin abortar el despliegue

### Requirement: Volumen único `/data`
El sistema SHALL mapear un único volumen `/data` del host en todos los servicios que lo requieran, SHALL crear los subdirectorios `torrents/`, `media/{movies,tv,music,books}/`, `config/<servicio>/` mediante un script de provisioning, y SHALL permitir hard links entre ellos.

#### Scenario: Creación del árbol de directorios
- **WHEN** se ejecuta el script de provisioning
- **THEN** el sistema SHALL crear `/data/{torrents,media/movies,media/tv,media/music,media/books,config}` y todos los subdirectorios `config/<servicio>` con permisos compatibles con el PUID/PGID configurado

#### Scenario: Hard link entre `torrents` y `media`
- **WHEN** Radarr importa una película terminada
- **THEN** el archivo en `media/movies/` SHALL ser un hard link al archivo en `torrents/`, verificable por inode idéntico

### Requirement: Red interna única
El sistema SHALL crear una red bridge `multimedia-net` y SHALL conectar todos los servicios a ella, SHALL resolver nombres entre contenedores por nombre de servicio.

#### Scenario: Sonarr consulta Jackett por hostname
- **WHEN** Sonarr hace una petición a `http://jackett:9117` desde la red interna
- **THEN** el sistema SHALL resolver el nombre y SHALL completar la conexión

### Requirement: Aislamiento de FlareSolverr
FlareSolverr SHALL estar unido a la red interna y SHALL no publicar ningún puerto en el host.

#### Scenario: No hay puerto de FlareSolverr en el host
- **WHEN** el operador inspecciona los puertos publicados
- **THEN** SHALL no existir ninguna línea que mapee un puerto del host a FlareSolverr

### Requirement: Configuración basada en `.env`
El sistema SHALL leer todas las rutas, PUID/PGID, TZ, claim tokens y API keys desde un único archivo `.env`, y SHALL proporcionar un `.env.example` documentado.

#### Scenario: `.env` ausente
- **WHEN** el operador ejecuta `podman-compose up -d` sin `.env`
- **THEN** el sistema SHALL fallar con un mensaje que indique la necesidad de crear `.env` desde `.env.example`

### Requirement: Documentación de despliegue
El sistema SHALL incluir un `README.md` con prerrequisitos, pasos de instalación, configuración inicial por servicio y troubleshooting básico.

#### Scenario: Operador nuevo lee el README
- **WHEN** un operador nuevo sigue los pasos del README desde cero
- **THEN** SHALL poder levantar el stack y SHALL tener todos los servicios accesibles en la LAN
