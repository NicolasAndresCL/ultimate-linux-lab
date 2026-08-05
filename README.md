# Laboratorio Ultimate Linux — Ubuntu 24.04 con Docker

Entorno Linux **desechable y reproducible** para seguir el curso *Ultimate Linux* de
Hola Mundo. Sustituye a una máquina virtual: se rompe, se destruye y se recrea en segundos
sin perder el trabajo guardado.

## Qué incluye

- **Ubuntu 24.04 LTS** (Noble Numbat)
- **systemd real** — `systemctl`, `journalctl`, `cron` y `rsyslog` funcionan como en una VM
- Usuario no-root **`nico`** con `sudo`, para practicar permisos correctamente
- Páginas de manual operativas (`man`, `apropos`, `whatis`), en español
- Toolkit del curso: `vim`, `nano`, `htop`, `tree`, `git`, `curl`, `iproute2`, `jq`, `rsync`…
- Locale `es_CL.UTF-8` y zona horaria `America/Santiago`

## Requisitos

- Docker Desktop (probado con Docker 29.3.1 y Compose v5.1.1)
- Unidad `C:` compartida en *Settings → Resources → File sharing*

## Arranque rápido

```bash
git clone https://github.com/NicolasAndresCL/ultimate-linux-lab.git
cd ultimate-linux-lab
docker compose up -d --build
docker exec -it -u nico ubuntu-lab bash
```

**Credenciales** — usuario `nico`, contraseña `linux`. `root` usa la misma contraseña.

Para salir del contenedor: `exit`. Para apagarlo: `docker compose stop`.

## Estructura

```
ultimate-linux/
├── Dockerfile        # imagen: Ubuntu 24.04 + systemd + toolkit + usuario nico
├── compose.yaml      # servicio ubuntu-lab: privileged, cgroups, volúmenes
├── workspace/        # ← tus scripts y ejercicios, editables desde VS Code
├── pasos.md          # chuleta completa de comandos Docker
└── memory.md         # bitácora de hitos (no versionada)
```

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
