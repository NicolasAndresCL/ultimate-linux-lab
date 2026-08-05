# Pasos — Comandos Docker del laboratorio

Chuleta de comandos para operar el lab de **Ultimate Linux**.
Todos se ejecutan desde `c:\dev\learning\hola_mundo\ultimate-linux` (PowerShell o Git Bash).

---

## 0. Arranque rápido (lo único que necesitas el día 1)

```bash
docker compose up -d --build          # construye la imagen y levanta el lab
```

**Escritorio gráfico** → abre <http://localhost:6080/vnc.html> y pulsa *Connect*.
GNOME tarda ~40 segundos en cargar tras el arranque.

**Terminal** → `docker exec -it -u nico ubuntu-lab bash`

Contraseña de `nico` y de `root`: **`linux`** (la misma para el escritorio, VNC y `sudo`).

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

---

## 2. Entrar al laboratorio

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
# Crear el snapshot
docker commit ubuntu-lab ultimate-linux-lab:antes-de-permisos

# Ver los snapshots que tienes
docker images ultimate-linux-lab
```

**Volver a un snapshot**: edita `image:` en `compose.yaml` apuntando al tag del snapshot
y comenta la sección `build:`, o lánzalo suelto:

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
> <http://localhost:6081/vnc.html>.
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
