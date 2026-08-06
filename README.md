# Laboratorio Ultimate Linux — Ubuntu 24.04 con Docker

[![CI](https://github.com/NicolasAndresCL/ultimate-linux-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/NicolasAndresCL/ultimate-linux-lab/actions/workflows/ci.yml)

Entorno Linux **desechable y reproducible** para seguir el curso *Ultimate Linux* de
Hola Mundo, con **escritorio GNOME en el navegador**. Sustituye a una máquina virtual: se
rompe, se destruye y se recrea en segundos sin perder el trabajo guardado.

## Qué incluye

- **Ubuntu 24.04 LTS** (Noble Numbat)
- **Escritorio GNOME** accesible desde el navegador en `http://localhost:6080/vnc.html`
- **systemd real** — `systemctl`, `journalctl`, `cron` y `rsyslog` funcionan como en una VM
- Usuario no-root **`nico`** con `sudo`, para practicar permisos correctamente
- Páginas de manual operativas (`man`, `apropos`, `whatis`), en español
- Toolkit del curso: `vim`, `nano`, `htop`, `tree`, `git`, `curl`, `iproute2`, `jq`, `rsync`…
- Locale `es_CL.UTF-8` y zona horaria `America/Santiago`

## Requisitos

- Docker Desktop (probado con Docker 29.3.1 y Compose v5.1.1)
- Unidad `C:` compartida en *Settings → Resources → File sharing*
- **4 GB de RAM** asignados a Docker como mínimo (GNOME es exigente) y **~3 GB de disco**

## Dos laboratorios, un Dockerfile

| | `lab-cli` | `lab` (por defecto) |
|---|---|---|
| Contenido | Sistema + systemd + toolkit | Lo anterior **+ escritorio GNOME** |
| Tamaño | **539 MB** | 2,67 GB |
| Construcción | **2-3 min** | 10-15 min |
| Cubre | Ficheros, permisos, usuarios, procesos, systemd, cron, redes, scripting | Todo lo anterior + seguir los clics del instructor |

Empieza por el de terminal: cubre casi todo el temario y se recrea en un suspiro. Levanta el
escritorio solo cuando la clase sea de entorno gráfico.

## Arranque rápido

```bash
git clone https://github.com/NicolasAndresCL/ultimate-linux-lab.git
cd ultimate-linux-lab

docker compose --profile cli up -d --build    # solo terminal, 2-3 min
docker compose up -d --build                  # con escritorio, 10-15 min
```

### Usar la imagen ya construida

El CI publica ambas variantes en GitHub Container Registry en cada cambio de `main`, así que
puedes saltarte el build:

```bash
docker pull ghcr.io/nicolasandrescl/ultimate-linux-lab:cli       # terminal
docker pull ghcr.io/nicolasandrescl/ultimate-linux-lab:latest    # con escritorio
```

Para que `docker compose` las use en vez de construirlas, comenta el bloque `build:` del
servicio en [compose.yaml](compose.yaml).

### Escritorio gráfico

Abre **http://localhost:6080/vnc.html** en el navegador y pulsa *Connect*.
Tarda unos 40 segundos en cargar GNOME la primera vez.

### Terminal

```bash
docker exec -it -u nico ubuntu-lab bash        # lab con escritorio
docker exec -it -u nico ubuntu-lab-cli bash    # lab de terminal
```

Para salir: `exit`. Para apagar el lab: `docker compose stop`.

## Credenciales y seguridad

Usuario **`nico`**, contraseña **`linux`** — la misma en el escritorio, la terminal, VNC y
`sudo`. `root` usa esa contraseña también.

> ⚠️ **Las imágenes publicadas en GHCR son públicas, así que esa contraseña es de
> conocimiento público.** Lo que hace que no importe es que los puertos se publican **solo en
> `127.0.0.1`**: el laboratorio no es accesible desde tu red ni desde Internet.

Para construir con otra contraseña:

```bash
docker compose build --build-arg LAB_PASSWORD='la-que-quieras'
```

> El valor pasado por `--build-arg` queda registrado en `docker history` de la imagen
> resultante. Sirve para no dejar el valor por defecto, pero **no es un mecanismo de
> secretos**: no uses ahí una contraseña que reutilices en otro sitio. Para cambiarla sin
> dejar rastro, hazlo dentro del contenedor con `passwd`.

**El contenedor corre en modo `privileged`**, que systemd necesita para gestionar cgroups y
montajes del kernel. Equivale en la práctica a root en el host, y es un trade-off asumido a
conciencia: el lab es desechable, sus puertos van solo a loopback y corre en tu propia
máquina. No reutilices esa configuración en servicios expuestos a Internet. El razonamiento
completo está en el propio [compose.yaml](compose.yaml).

## Estructura

```
ultimate-linux/
├── .github/workflows/ci.yml   # CI: lint, build+smoke test, escaneo de CVEs y publicación
├── Dockerfile        # dos etapas: `base` (terminal) y `desktop` (+ GNOME)
├── compose.yaml      # servicios lab y lab-cli: privileged, cgroups, puertos, volúmenes
├── desktop/          # configuración del escritorio (VNC, noVNC, sesión GNOME)
├── workspace/        # ← tus scripts y ejercicios, editables desde VS Code
├── pasos.md          # chuleta completa de comandos Docker
└── memory.md         # bitácora de hitos (no versionada)
```

## Integración continua

Cada push verifica que **ambos laboratorios construyen y arrancan de verdad**, no solo que el
`Dockerfile` esté bien escrito: levanta los contenedores y comprueba systemd, `man`, el
usuario `nico` y que el escritorio responde en el 6080. Además:

- **Escanea las imágenes con Trivy** antes de publicarlas; el informe queda en la pestaña
  *Security* del repositorio.
- **Verifica el hardening**: que ningún puerto se publique fuera de `127.0.0.1`, que ambas
  etapas definan `HEALTHCHECK` y que la contraseña siga siendo parametrizable. Si alguien
  quitara el bind a loopback, el pipeline falla en vez de callar.

Ambas imágenes traen `HEALTHCHECK`, así que `docker ps` muestra `(healthy)` cuando el
laboratorio está realmente operativo. Detalles en [pasos.md](pasos.md).

## Puertos

| Puerto | Servicio |
|---|---|
| `6080` | noVNC — escritorio en el navegador |
| `5901` | VNC nativo — para clientes como TigerVNC Viewer o RealVNC |

Ambos se publican **solo en `127.0.0.1`**: el escritorio no queda expuesto a tu red local.

## Persistencia

| Ubicación | Dónde vive | Sobrevive a `down` |
|---|---|---|
| `./workspace` → `/home/nico/workspace` | Carpeta de Windows (bind mount) | ✅ |
| `/home` | Volumen `ultimate-linux-home` | ✅ |
| `/etc`, paquetes `apt`, usuarios | Capa del contenedor | ❌ (usa `stop`/`start`) |

> Para el día a día usa `docker compose stop` / `start`, que conserva **todo**.
> `down` solo cuando quieras un sistema limpio de fábrica.

> ⚠️ `chmod` y `chown` no tienen efecto real dentro de `./workspace` (es una carpeta de
> Windows). Para practicar permisos, trabaja en `~/ejercicios` o cualquier ruta fuera de
> `workspace`.

## Documentación

- **[pasos.md](pasos.md)** — todos los comandos: ciclo de vida, backups, snapshots con
  `docker commit`, diagnóstico y troubleshooting.

## Licencia

[MIT](LICENSE) © Nicolás Andrés Cano Leal
