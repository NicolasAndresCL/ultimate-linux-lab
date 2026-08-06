# Pasos — Comandos Docker del laboratorio

Chuleta de comandos para operar el lab de **Ultimate Linux**.
Todos se ejecutan desde `c:\dev\learning\hola_mundo\ultimate-linux` (PowerShell o Git Bash).

---

## 0. Arranque rápido (lo único que necesitas el día 1)

Hay **dos laboratorios** sobre la misma base. Empieza por el de terminal: construye en 2-3
minutos en vez de 15 y cubre casi todo el temario.

```bash
docker compose --profile cli up -d --build     # solo terminal (539 MB)
docker exec -it -u nico ubuntu-lab-cli bash
```

Cuando la clase sea de entorno gráfico:

```bash
docker compose up -d --build                   # con escritorio GNOME (2,67 GB)
```

**Escritorio gráfico** → abre <http://localhost:6080/vnc.html> y pulsa *Connect*.
GNOME tarda ~40 segundos en cargar tras el arranque.

**Terminal del lab con escritorio** → `docker exec -it -u nico ubuntu-lab bash`

Contraseña de `nico` y de `root`: **`linux`** (la misma para el escritorio, VNC y `sudo`).
Para usar otra: `docker compose build --build-arg LAB_PASSWORD='la-que-quieras'`.

> Los dos labs **comparten el volumen `/home`**, así que tu trabajo está en ambos.
> No hace falta levantarlos a la vez; de hecho, es mejor no hacerlo.

---

## 1. Ciclo de vida del contenedor

| Comando | Qué hace |
|---|---|
| `docker compose up -d` | Levanta el lab en segundo plano |
| `docker compose up -d --build` | Reconstruye la imagen y levanta |
| `docker compose ps` | Estado del lab (`Up` = corriendo) |
| `docker compose stop` | **Apaga** el lab conservando *todo* (usuarios, paquetes, `/etc`) |
| `docker compose start` | Vuelve a encenderlo tal como quedó |
| `docker compose restart` | Reinicia el contenedor |
| `docker compose down` | **Destruye** el contenedor (conserva `/home` y `./workspace`) |
| `docker compose down -v` | ⚠️ Destruye *también* el volumen `/home`. Borra tu trabajo del home |

> **Regla de oro del día a día**: usa `stop` / `start`.
> `down` solo cuando quieras un sistema limpio de fábrica.

Para el lab de terminal, antepón siempre `--profile cli`:

```bash
docker compose --profile cli up -d      # levantar
docker compose --profile cli stop       # apagar
docker compose --profile cli ps         # ver ambos servicios
```

Sin `--profile cli`, `docker compose` ignora por completo el servicio `lab-cli` — no falla,
simplemente actúa como si no existiera.

---

## 2. Entrar al laboratorio

> Los ejemplos usan `ubuntu-lab` (el lab con escritorio). Para el de terminal, sustituye ese
> nombre por **`ubuntu-lab-cli`** en todos los comandos de esta chuleta.

```bash
# Como usuario normal — así es como debes trabajar el 95% del tiempo
docker exec -it -u nico ubuntu-lab bash

# Como root — solo cuando el ejercicio lo pida
docker exec -it ubuntu-lab bash

# Sesión de login completa (carga /etc/profile, motd y variables de entorno)
docker exec -it -u nico ubuntu-lab bash -l

# Ejecutar un comando suelto sin entrar
docker exec -u nico ubuntu-lab ls -la /etc
```

Para salir: `exit` o `Ctrl+D` (el contenedor **sigue corriendo**).

---

## 2 bis. El escritorio GNOME

El curso se imparte sobre Ubuntu Desktop, así que el lab levanta el mismo escritorio. La
cadena es: **GNOME → servidor VNC (`:1`, puerto 5901) → websockify/noVNC (puerto 6080)**.

| Acceso | Cómo |
|---|---|
| Navegador (recomendado) | <http://localhost:6080/vnc.html> → *Connect* → contraseña `linux` |
| Cliente VNC nativo | Conecta a `localhost:5901`, contraseña `linux` |

### Controlarlo con systemctl

Son servicios de systemd normales, así que se manejan como cualquier otro del curso:

```bash
sudo systemctl status vncserver     # estado del escritorio
sudo systemctl restart vncserver    # reiniciar la sesión gráfica (si se cuelga)
sudo systemctl stop vncserver       # apagar el escritorio y liberar RAM
sudo systemctl status novnc         # el puente hacia el navegador
journalctl -u vncserver -f          # ver los logs en vivo
```

### Cambiar la resolución

Edita `desktop/vncserver.service`, la línea `-geometry 1440x900`, y reconstruye con
`docker compose up -d --build`.

### Si el escritorio no carga

```bash
docker exec ubuntu-lab systemctl is-active vncserver   # debe decir `active`
docker exec ubuntu-lab journalctl -u vncserver -n 40 --no-pager
```

- **`activating` y nunca llega a `active`**: GNOME está arrancando, dale ~40 segundos.
- **Pantalla gris o negra**: `sudo systemctl restart vncserver` desde la terminal.
- **`Connection refused` en el navegador**: el contenedor no está levantado
  (`docker compose ps`).

---

## 3. Qué persiste y qué no — el modelo de capas

Esto es lo más importante que hay que entender, y está **verificado**:

| Qué | `stop` / `start` | `down` + `up` | `down -v` + `up` |
|---|:---:|:---:|:---:|
| `./workspace` (bind mount) | ✅ | ✅ | ✅ |
| `/home` (volumen `ultimate-linux-home`) | ✅ | ✅ | ❌ |
| Ajustes de GNOME y `~/.vnc` (viven en `/home`) | ✅ | ✅ | ❌ |
| `/etc/passwd`, usuarios creados con `useradd` | ✅ | ❌ | ❌ |
| Paquetes instalados con `apt install` | ✅ | ❌ | ❌ |
| Cambios en `/etc`, `/var`, `/opt` | ✅ | ❌ | ❌ |

**Por qué**: `/home` y `./workspace` están montados como volúmenes, así que viven fuera
del contenedor. Todo lo demás vive en la *capa de escritura* del contenedor, que
`docker compose down` elimina. `stop` no la elimina.

**Consecuencia práctica**: si creas el usuario `alumno` y haces `down`, su carpeta
`/home/alumno` sigue ahí pero el usuario ya no existe en `/etc/passwd`. Para conservar
un estado completo de sistema, usa un snapshot (sección 5).

---

## 4. Trabajar con los archivos

```bash
# Ver dónde está el volumen del home
docker volume ls
docker volume inspect ultimate-linux-home

# Copiar un archivo del contenedor a Windows
docker cp ubuntu-lab:/etc/passwd ./passwd-copia.txt

# Copiar de Windows al contenedor
docker cp ./mi-script.sh ubuntu-lab:/home/nico/
```

> ⚠️ **Permisos en `./workspace`**: al ser una carpeta de Windows, `chmod` y `chown`
> **no tienen efecto real** ahí dentro. Para practicar permisos, usa
> `~/ejercicios` o cualquier carpeta fuera de `workspace` — esas sí son ext4 de verdad.

### Respaldar el home

```bash
mkdir -p backups
docker run --rm -v ultimate-linux-home:/data -v "${PWD}/backups:/backup" ubuntu:24.04 \
  tar czf /backup/home-$(date +%Y%m%d).tar.gz -C /data .
```

### Restaurar el home

```bash
docker run --rm -v ultimate-linux-home:/data -v "${PWD}/backups:/backup" ubuntu:24.04 \
  tar xzf /backup/home-20260804.tar.gz -C /data
```

---

## 5. Snapshots — el reemplazo de las *snapshots* de VirtualBox

Esto es exactamente lo que faltó con la máquina virtual. **Antes de una clase
arriesgada**, congela el estado completo del sistema:

```bash
# Crear el snapshot (usa ubuntu-lab-cli si trabajas en el lab de terminal)
docker commit ubuntu-lab ultimate-linux-lab:antes-de-permisos

# Ver los snapshots que tienes
docker images ultimate-linux-lab
```

**Volver a un snapshot**: edita `image:` del servicio en `compose.yaml` apuntando al tag del
snapshot y comenta su sección `build:`, o lánzalo suelto:

```bash
docker run -d --name lab-restaurado --privileged --cgroup host \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
  --shm-size 1gb \
  -p 127.0.0.1:6081:6080 -p 127.0.0.1:5902:5901 \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  ultimate-linux-lab:antes-de-permisos
```

> Los puertos van desplazados (`6081`, `5902`) para no chocar con el lab principal si
> ambos están levantados. El escritorio del snapshot estaría en
> <http://localhost:6081/vnc.html>. Si el snapshot es del lab de terminal, quita las dos
> líneas `-p` y `--shm-size`: no le hacen falta.
> **`--shm-size 1gb` no es opcional**: sin él, GNOME arranca con la pantalla en negro.

Cada snapshot ocupa solo la diferencia respecto de la imagen base — cuestan casi nada,
al contrario que los discos de una VM.

---

## 6. Diagnóstico

```bash
docker compose logs -f              # log de arranque de systemd
docker stats ubuntu-lab             # CPU / RAM en tiempo real
docker top ubuntu-lab               # procesos vistos desde el host
docker inspect ubuntu-lab           # configuración completa en JSON
docker exec ubuntu-lab systemctl is-system-running   # salud de systemd
docker exec ubuntu-lab systemctl --failed            # servicios caídos
docker exec ubuntu-lab systemctl is-active vncserver # ¿el escritorio está arriba?
docker port ubuntu-lab                               # puertos publicados
```

---

## 7. Botón de pánico 🔴

Rompiste el sistema y quieres empezar de cero. **`./workspace` no se toca**:

```bash
docker compose down          # destruye el contenedor
docker compose up -d --build # lo reconstruye limpio
```

Si además quieres borrar el `/home` persistente (reset absoluto):

```bash
docker compose down -v
docker compose up -d --build
```

Recrear el contenedor tarda **segundos** si la imagen ya está construida. Si además
cambiaste el `Dockerfile`, la reconstrucción con GNOME lleva unos **10 minutos** (Docker
reutiliza las capas que no cambiaron). Aun así, frente a reinstalar una VM corrupta, no hay
comparación: ese es el motivo de haber cambiado la máquina virtual por Docker.

---

## 8. Comandos de Linux que ya funcionan dentro del lab

Verificados tras la construcción:

```bash
man ls                    # páginas de manual (¡en español!)
apropos permisos          # buscar comandos por descripción
sudo whoami               # → root (contraseña: linux)
systemctl status cron     # systemd operativo
systemctl list-units      # todas las units
journalctl -xe            # logs del sistema
crontab -e                # tareas programadas
htop / ps aux / top       # procesos
ip a / ping / ss -tuln    # red
useradd / groupadd / chmod / chown   # usuarios y permisos
systemctl status vncserver           # el escritorio GNOME, como servicio
```

Y en el **escritorio** (<http://localhost:6080/vnc.html>): Terminal de GNOME, Archivos
(Nautilus), Configuración, Monitor del sistema y Discos — las mismas aplicaciones que usa
el instructor en su máquina virtual.

---

## 8 bis. Integración continua

Cada push a `main` y cada Pull Request ejecutan
[`.github/workflows/ci.yml`](.github/workflows/ci.yml). El pipeline no se limita a revisar
sintaxis: **construye la imagen y levanta el lab** para comprobar que funciona de verdad.

| Job | Qué hace | Duración |
|---|---|---|
| `lint` | hadolint, shellcheck, compose, units, CRLF y **hardening** (puertos en loopback, healthchecks, contraseña parametrizable) | ~1 min |
| `build` (×2) | Construye **cada target** y levanta el lab: systemd, `man`, usuario `nico`, `cron` y —solo en `desktop`— el escritorio y noVNC en el 6080 | 3 y 15 min |
| `scan` (×2) | **Trivy** sobre ambas imágenes; el informe va a la pestaña *Security* | ~5 min |
| `publish` (×2) | Sube ambas variantes a GHCR (solo en `main`) | ~3 min |

Los jobs corren en **matriz** sobre los dos targets (`base` y `desktop`), con cachés
separadas por `scope` para que no se pisen.

### El escaneo de vulnerabilidades

Publicar en un registro público sin saber qué CVEs llevas dentro es el hueco obvio, así que
el CI escanea las dos imágenes antes de subirlas:

- **El informe completo** (CRITICAL, HIGH y MEDIUM) se sube como SARIF y aparece en
  *Security → Code scanning* del repositorio.
- **El build solo se rompe** si hay un CVE `CRITICAL` **que ya tiene parche disponible**
  (`ignore-unfixed`). Una base Ubuntu siempre arrastra CVEs sin arreglo aguas arriba; fallar
  por ellos convertiría el CI en ruido que se acaba ignorando.

Para escanear en local, igual que el CI:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image --severity CRITICAL,HIGH ultimate-linux-lab:24.04-cli
```

Es material directo para los módulos de seguridad del curso: mira qué paquetes arrastran los
CVEs y compara la superficie del lab de terminal con la del escritorio.

### Seguirlo desde la terminal

```bash
gh run list --limit 5        # últimas ejecuciones
gh run watch                 # seguir la actual en vivo
gh run view --log-failed     # solo los logs de lo que falló
gh workflow run ci.yml       # lanzarlo a mano
```

### Usar la imagen que publica el CI

Evita los 15 minutos de build en cualquier equipo:

```bash
docker pull ghcr.io/nicolasandrescl/ultimate-linux-lab:cli       # terminal, 539 MB
docker pull ghcr.io/nicolasandrescl/ultimate-linux-lab:latest    # escritorio, 2,67 GB
```

| Tag | Contenido |
|---|---|
| `latest`, `24.04` | Lab completo con escritorio GNOME |
| `cli`, `24.04-cli` | Lab de terminal |
| `sha-<commit>`, `sha-<commit>-cli` | Versión concreta, para volver atrás |

### Verificar en local: ya es automático

```bash
./verificar.sh
```

Reproduce el job `lint` entero: hadolint, shellcheck, actionlint, compose, units, CRLF y
hardening. Tarda unos segundos y evita esperar 15 minutos a que el CI te diga lo mismo.

**No hace falta que te acuerdes**: el hook `.githooks/pre-commit` lo ejecuta solo, y únicamente
cuando el commit toca `Dockerfile`, `compose.yaml`, `desktop/` o el workflow — los commits de
documentación no esperan a que arranquen contenedores.

```bash
git config core.hooksPath .githooks   # activarlo tras clonar (una sola vez)
./verificar.sh --rapido               # omite lo que necesita descargar imágenes
git commit --no-verify                # saltárselo, solo con un motivo concreto
```

> El script existe porque el CI se rompió **dos veces** por no ejecutar hadolint en el momento
> correcto, y las dos veces la "solución" fue una nota para acordarse. Un paso obligatorio que
> se puede omitir sin que pase nada no es obligatorio.

Los dos fallos más habituales que caza:

- **CRLF** — si Windows convirtió los finales de línea, el build funciona en tu equipo y
  revienta en el runner de Linux.
- **`SHELL` y `ARG` no se heredan entre etapas** — al dividir el Dockerfile en dos, la etapa
  `desktop` volvió al `sh` por defecto y el CI se puso rojo con DL4006.

### Comprobar la salud del laboratorio

Ambas imágenes traen `HEALTHCHECK`, así que Docker sabe si el lab está realmente sano:

```bash
docker ps                                    # la columna STATUS muestra (healthy)
docker inspect ubuntu-lab --format '{{.State.Health.Status}}'
```

El de terminal comprueba que systemd responde; el del escritorio, además, que noVNC sirve el
cliente web — así un GNOME que no arranca no queda marcado como sano con la pantalla en
negro. Se acepta el estado `degraded` a propósito: en un lab para romper cosas, un servicio
caído adrede no debe marcar el contenedor como enfermo.

---

## 9. Troubleshooting

### `systemctl` responde "Failed to connect to bus"

systemd no arrancó. En este equipo funciona con la configuración actual, pero si tras
una actualización de Docker Desktop deja de hacerlo, prueba **en este orden** en
`compose.yaml`:

1. Quitar el montaje explícito de cgroups (con `privileged: true` ya viene escribible):
   ```yaml
   # - /sys/fs/cgroup:/sys/fs/cgroup:rw
   ```
2. Cambiar `cgroup: host` por:
   ```yaml
   cgroup_parent: docker.slice
   ```
3. Como último recurso, prescindir de systemd: cambiar el `CMD` del Dockerfile a
   `CMD ["/bin/bash"]` y usar `service cron start` en vez de `systemctl`.
   ⚠️ Esto **te deja sin escritorio gráfico**: `vncserver` y `novnc` son units de systemd.
   Habría que arrancarlos a mano con `vncserver :1` y `websockify --web=/usr/share/novnc/
   6080 localhost:5901`.

Después de cualquier cambio: `docker compose up -d --build`.

### El contenedor se reinicia en bucle

```bash
docker compose logs --tail 50
```

### `man` muestra "This system has been minimized"

No debería pasar (el Dockerfile ya lo corrige restaurando `/usr/bin/man.REAL`).
Si ocurre, reconstruye: `docker compose up -d --build`.

### Cambios en `./workspace` no se ven desde Windows

Docker Desktop debe tener compartida la unidad `C:`.
*Settings → Resources → File sharing*.
