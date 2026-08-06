# =============================================================================
#  Laboratorio Ubuntu 24.04 LTS con systemd — curso "Ultimate Linux" (Hola Mundo)
#  Reemplaza a la máquina virtual: desechable, reproducible y arranca en segundos.
# =============================================================================
FROM ubuntu:26.04

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
ARG USERNAME=nico
ARG PASSWORD=linux

RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -m -u 1000 -s /bin/bash "$USERNAME" \
 && echo "$USERNAME:$PASSWORD" | chpasswd \
 && usermod -aG sudo "$USERNAME" \
 && echo "root:$PASSWORD" | chpasswd \
 && mkdir -p /home/$USERNAME/workspace \
 && chown -R $USERNAME:$USERNAME /home/$USERNAME

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
RUN echo "linux" | vncpasswd -f > /opt/lab-skel/.vnc/passwd \
 && chmod 600 /opt/lab-skel/.vnc/passwd \
 && chmod 755 /opt/lab-skel/.vnc/xstartup /usr/local/bin/prepare-vnc-home \
 && chown -R nico:nico /opt/lab-skel

# Servicios systemd del escritorio: así se gestionan con systemctl, igual que
# cualquier otro servicio del curso.
COPY desktop/vncserver.service /etc/systemd/system/vncserver.service
COPY desktop/novnc.service     /etc/systemd/system/novnc.service

# Habilitar servicios útiles para las clases de systemd/cron, más el escritorio
RUN systemctl enable cron rsyslog vncserver novnc

# Mensaje de bienvenida del lab
RUN printf '%s\n' \
    '' \
    '  ┌──────────────────────────────────────────────┐' \
    '  │  Laboratorio Ultimate Linux — Ubuntu 24.04   │' \
    '  │  systemd activo · rompe lo que quieras       │' \
    '  │  Trabajo persistente en ~/workspace          │' \
    '  └──────────────────────────────────────────────┘' \
    '' > /etc/motd

VOLUME [ "/sys/fs/cgroup" ]

# systemd apaga limpiamente al recibir SIGRTMIN+3 (equivale a un `shutdown`).
STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
