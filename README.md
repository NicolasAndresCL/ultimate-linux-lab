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

## Arranque rápido

```bash
git clone https://github.com/NicolasAndresCL/ultimate-linux-lab.git
cd ultimate-linux-lab
docker compose up -d --build
```

> La primera construcción tarda **10-15 minutos**: descarga el escritorio GNOME completo.
> Las siguientes son casi instantáneas gracias a la caché de capas de Docker.
> Si prefieres no esperar, usa la imagen ya construida (abajo).

### Usar la imagen ya construida

El CI publica la imagen en GitHub Container Registry en cada cambio de `main`, así que puedes
saltarte el build y bajarla directamente (~2 minutos):

```bash
docker pull ghcr.io/nicolasandrescl/ultimate-linux-lab:latest
```

Para que `docker compose` la use en vez de construirla, comenta el bloque `build:` de
[compose.yaml](compose.yaml) y apunta `image:` a esa ruta.

### Escritorio gráfico

Abre **http://localhost:6080/vnc.html** en el navegador y pulsa *Connect*.
Tarda unos 40 segundos en cargar GNOME la primera vez.

### Terminal

```bash
docker exec -it -u nico ubuntu-lab bash
```

**Credenciales** — usuario `nico`, contraseña `linux`, tanto en el escritorio como en la
terminal y en VNC. `root` usa la misma.

Para salir de la terminal: `exit`. Para apagar el lab: `docker compose stop`.

## Estructura

```
ultimate-linux/
├── .github/workflows/ci.yml   # CI: lint, build, smoke test y publicación en GHCR
├── Dockerfile        # imagen: Ubuntu 24.04 + systemd + GNOME + toolkit
├── compose.yaml      # servicio ubuntu-lab: privileged, cgroups, puertos, volúmenes
├── desktop/          # configuración del escritorio (VNC, noVNC, sesión GNOME)
├── workspace/        # ← tus scripts y ejercicios, editables desde VS Code
├── pasos.md          # chuleta completa de comandos Docker
└── memory.md         # bitácora de hitos (no versionada)
```

## Integración continua

Cada push verifica que el laboratorio **construye y arranca de verdad**, no solo que el
`Dockerfile` esté bien escrito: levanta el contenedor y comprueba systemd, `man`, el usuario
`nico` y que el escritorio responde en el puerto 6080. Detalles en [pasos.md](pasos.md).

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
