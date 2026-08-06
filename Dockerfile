# =============================================================================
#  Laboratorio Ubuntu 24.04 LTS con systemd — curso "Ultimate Linux" (Hola Mundo)
#  Reemplaza a la máquina virtual: desechable, reproducible y arranca en segundos.
#
#  Dos etapas:
#    base     → sistema con systemd y el toolkit del curso (~600 MB, 2-3 min)
#    desktop  → base + escritorio GNOME accesible por navegador (~2,7 GB, ~15 min)
#
#  Construir solo la terminal:  docker build --target base .
# =============================================================================
FROM ubuntu:24.04 AS base

# `container=docker` le indica a systemd que corre dentro de un contenedor
# y debe saltarse las tareas propias de hardware real.
ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Santiago

# Con el `sh` por defecto, un fallo a la izquierda de un pipe pasa desapercibido
# y la capa se da por buena. `pipefail` hace que el RUN falle de verdad.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# -----------------------------------------------------------------------------
# Restaurar las páginas de manual.
# La imagen oficial de Ubuntu viene "minimizada": /etc/dpkg/dpkg.cfg.d/excludes
# borra TODAS las manpages, así que `man ls` no funciona. En un curso de Linux
# eso es inaceptable, de modo que se elimina la exclusión ANTES de instalar nada
# (así los paquetes siguientes ya traen su documentación).
# -----------------------------------------------------------------------------
RUN rm -f /etc/dpkg/dpkg.cfg.d/excludes

# -----------------------------------------------------------------------------
# Paquetes: systemd + todo el toolkit que se usa a lo largo del curso.
# Una sola capa para no inflar la imagen.
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # --- systemd y su bus de mensajes ---
    systemd systemd-sysv dbus dbus-user-session \
    # --- básicos del curso ---
    sudo nano vim less man-db manpages tree htop procps psmisc \
    # --- red ---
    iproute2 iputils-ping net-tools curl wget dnsutils traceroute \
    # --- utilidades ---
    git cron rsyslog bash-completion unzip zip tzdata locales \
    file lsof rsync ca-certificates jq \
    # --- páginas de manual ---
    manpages-es \
 # Los paquetes base (ls, cd, chmod, grep...) YA estaban instalados cuando las
 # manpages seguían excluidas, así que hay que reinstalarlos para recuperarlas.
 && apt-get install -y --reinstall --no-install-recommends \
    coreutils bash dash findutils grep sed gawk diffutils tar gzip \
    util-linux procps passwd login adduser mount hostname debianutils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# La imagen minimizada sustituye /usr/bin/man por un stub que solo imprime un
# aviso, y esconde el binario real en /usr/bin/man.REAL. Se restaura el original
# y se reconstruye el índice para que `man`, `whatis` y `apropos` funcionen.
RUN [ -f /usr/bin/man.REAL ] && mv -f /usr/bin/man.REAL /usr/bin/man || true \
 && mandb -q

# -----------------------------------------------------------------------------
# Locale y zona horaria.
# NOTA: no se ejecuta `unminimize` (tarda muchísimo). Instalar man-db + manpages
# es suficiente para que `man` funcione, que es lo que importa en este curso.
# -----------------------------------------------------------------------------
RUN sed -i 's/^# *\(es_CL.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen \
 && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo $TZ > /etc/timezone

ENV LANG=es_CL.UTF-8
ENV LANGUAGE=es_CL:es
ENV LC_ALL=es_CL.UTF-8

# -----------------------------------------------------------------------------
# Usuario de trabajo.
# ⚠ Ubuntu 24.04 YA trae un usuario `ubuntu` ocupando el UID 1000, así que hay
#   que eliminarlo antes o `useradd` falla con "UID 1000 is not unique".
# -----------------------------------------------------------------------------
ARG LAB_USERNAME=nico

# Contraseña de `nico` y de `root`.
#
# El valor por defecto es cómodo para un lab local, pero la imagen que el CI
# publica en GHCR es PÚBLICA: cualquiera puede descargarla y sus credenciales
# son de conocimiento público. Lo que evita que eso importe es que los puertos
# se publican solo en 127.0.0.1 (ver compose.yaml) y que el lab es desechable.
#
# Para construir con otra:
#     docker compose build --build-arg LAB_PASSWORD='la-que-quieras'
#
# ⚠ LIMITACIÓN VERIFICADA: el valor pasado por --build-arg queda registrado en
#   `docker history` de la imagen resultante. Sirve para no dejar la contraseña
#   por defecto, pero NO es un mecanismo de secretos: no uses ahí una clave que
#   reutilices en otro sitio, ni publiques esa imagen en un registro.
#   Para cambiarla sin dejar rastro, hazlo dentro del contenedor con `passwd`
#   (persiste mientras no hagas `docker compose down`).
ARG LAB_PASSWORD=linux

RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -m -u 1000 -s /bin/bash "$LAB_USERNAME" \
 && echo "$LAB_USERNAME:$LAB_PASSWORD" | chpasswd \
 && usermod -aG sudo "$LAB_USERNAME" \
 && echo "root:$LAB_PASSWORD" | chpasswd \
 && mkdir -p "/home/$LAB_USERNAME/workspace" \
 && chown -R "$LAB_USERNAME:$LAB_USERNAME" "/home/$LAB_USERNAME"

# -----------------------------------------------------------------------------
# Limpieza de units que no tienen sentido en un contenedor (consolas tty, udev,
# espera de red). Sin esto el arranque es lento y `systemctl` muestra servicios
# en estado `failed` que confunden al estudiar.
# -----------------------------------------------------------------------------
RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    sys-kernel-config.mount \
    systemd-udevd.service \
    systemd-udev-trigger.service \
    getty.target \
    console-getty.service \
    systemd-networkd-wait-online.service \
 && rm -f /lib/systemd/system/multi-user.target.wants/getty.target

# Servicios del curso en la etapa de terminal.
RUN systemctl enable cron rsyslog

RUN printf '%s\n' \
    '' \
    '  ┌──────────────────────────────────────────────┐' \
    '  │  Laboratorio Ultimate Linux — Ubuntu 24.04   │' \
    '  │  systemd activo · rompe lo que quieras       │' \
    '  │  Trabajo persistente en ~/workspace          │' \
    '  └──────────────────────────────────────────────┘' \
    '' > /etc/motd

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]


# =============================================================================
#  ETAPA `desktop` — añade el escritorio GNOME sobre el sistema anterior
# =============================================================================
FROM base AS desktop

# -----------------------------------------------------------------------------
# ESCRITORIO GRÁFICO — GNOME de Ubuntu, accesible desde el navegador
#
# El curso se imparte sobre Ubuntu Desktop, así que el lab replica el mismo
# entorno gráfico. La cadena es:
#     GNOME  →  servidor TigerVNC (:1 / puerto 5901)  →  websockify/noVNC (6080)
# y desde Windows se abre en http://localhost:6080
#
# Se instala `ubuntu-desktop-minimal` SIN recomendados para evitar arrastrar
# gdm3, snapd e impresoras, que en un contenedor sobran y rompen el arranque.
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ubuntu-desktop-minimal \
    gnome-session gnome-shell gnome-terminal gnome-control-center \
    nautilus gnome-text-editor gnome-system-monitor gnome-disk-utility \
    yaru-theme-gtk yaru-theme-icon yaru-theme-sound \
    fonts-ubuntu xfonts-base \
    tigervnc-standalone-server tigervnc-common tigervnc-tools \
    novnc websockify \
    dbus-x11 x11-xserver-utils xdg-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# GDM (el gestor de login gráfico) sobra: la sesión la arranca el servidor VNC.
# Si quedara activo, competiría por el display y el escritorio no cargaría.
RUN systemctl disable gdm3.service 2>/dev/null || true; \
    systemctl mask gdm3.service 2>/dev/null || true; \
    systemctl set-default multi-user.target

# Plantilla de configuración VNC.
# Va en /opt/lab-skel y NO en /home/nico: /home es un volumen de Docker, y todo
# lo que la imagen escriba ahí queda oculto al montarlo. El script
# prepare-vnc-home la copia al home real en cada arranque.
COPY desktop/xstartup          /opt/lab-skel/.vnc/xstartup
COPY desktop/prepare-vnc-home  /usr/local/bin/prepare-vnc-home

# Los ARG no cruzan de una etapa a otra: hay que volver a declararlos.
ARG LAB_USERNAME=nico
ARG LAB_PASSWORD=linux

RUN echo "$LAB_PASSWORD" | vncpasswd -f > /opt/lab-skel/.vnc/passwd \
 && chmod 600 /opt/lab-skel/.vnc/passwd \
 && chmod 755 /opt/lab-skel/.vnc/xstartup /usr/local/bin/prepare-vnc-home \
 && chown -R "$LAB_USERNAME:$LAB_USERNAME" /opt/lab-skel

# Servicios systemd del escritorio: así se gestionan con systemctl, igual que
# cualquier otro servicio del curso.
COPY desktop/vncserver.service /etc/systemd/system/vncserver.service
COPY desktop/novnc.service     /etc/systemd/system/novnc.service

RUN systemctl enable vncserver novnc

RUN printf '%s\n' \
    '' \
    '  ┌──────────────────────────────────────────────┐' \
    '  │  Laboratorio Ultimate Linux — Ubuntu 24.04   │' \
    '  │  Escritorio: http://localhost:6080/vnc.html  │' \
    '  │  Trabajo persistente en ~/workspace          │' \
    '  └──────────────────────────────────────────────┘' \
    '' > /etc/motd

VOLUME [ "/sys/fs/cgroup" ]

# systemd apaga limpiamente al recibir SIGRTMIN+3 (equivale a un `shutdown`).
STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
