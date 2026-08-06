#!/usr/bin/env bash
# Reproduce en local el job `lint` del CI.
#
# Existe porque la regla escrita "acuérdate de correr hadolint" falló dos veces:
# un paso obligatorio que se puede omitir sin consecuencias no es obligatorio.
# Lo invoca el hook de pre-commit (.githooks/pre-commit), así que corre solo.
#
# Uso manual:  ./verificar.sh          → verifica todo
#              ./verificar.sh --rapido → omite lo que necesita descargar imágenes
set -uo pipefail

fallos=0
rapido=false
[ "${1:-}" = "--rapido" ] && rapido=true

# Colores solo si hay terminal.
if [ -t 1 ]; then
    ROJO=$'\e[31m'; VERDE=$'\e[32m'; GRIS=$'\e[90m'; FIN=$'\e[0m'
else
    ROJO=''; VERDE=''; GRIS=''; FIN=''
fi

ok()    { echo "  ${VERDE}OK${FIN}    $1"; }
error() { echo "  ${ROJO}FALLO${FIN} $1"; fallos=$((fallos + 1)); }
salto() { echo "  ${GRIS}omitido${FIN} $1"; }
titulo() { echo; echo "── $1"; }

# Docker es opcional: sin él se verifica lo que no lo necesita.
hay_docker=false
docker info >/dev/null 2>&1 && hay_docker=true

# En Windows, montar el repo requiere la ruta nativa; en Linux/macOS vale $PWD.
ruta_repo="$PWD"
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        ruta_repo="$(pwd -W 2>/dev/null || echo "$PWD")"
        # Git Bash reescribe cualquier argumento que parezca ruta absoluta: sin
        # esto, `-w /mnt` llega al demonio como 'C:/Program Files/Git/mnt'.
        export MSYS_NO_PATHCONV=1
        ;;
esac

titulo "Dockerfile (hadolint)"
if $hay_docker && ! $rapido; then
    # Los mismos ignores que el CI. Si cambian allí, cambiarlos aquí.
    if docker run --rm -i hadolint/hadolint hadolint \
        --ignore DL3008 --ignore DL3064 --ignore DL3059 - < Dockerfile; then
        ok "sin hallazgos"
    else
        error "hadolint encontró problemas"
    fi
else
    salto "necesita Docker"
fi

titulo "Scripts del escritorio (shellcheck)"
if $hay_docker && ! $rapido; then
    if docker run --rm -v "${ruta_repo}:/mnt" -w /mnt koalaman/shellcheck:stable \
        desktop/prepare-vnc-home desktop/xstartup verificar.sh; then
        ok "sin hallazgos"
    else
        error "shellcheck encontró problemas"
    fi
else
    salto "necesita Docker"
fi

titulo "Workflow (actionlint)"
if $hay_docker && ! $rapido; then
    if docker run --rm -v "${ruta_repo}:/repo" -w /repo rhysd/actionlint:latest; then
        ok "sin errores"
    else
        error "actionlint encontró problemas"
    fi
else
    salto "necesita Docker"
fi

titulo "Sintaxis del compose"
if $hay_docker; then
    if docker compose config -q; then ok "válido"; else error "compose inválido"; fi
else
    salto "necesita Docker"
fi

titulo "Units de systemd"
faltantes=0
for unit in desktop/vncserver.service desktop/novnc.service; do
    for seccion in '\[Unit\]' '\[Service\]' '\[Install\]'; do
        grep -q "^$seccion" "$unit" || { error "falta $seccion en $unit"; faltantes=1; }
    done
done
[ $faltantes -eq 0 ] && ok "ambas units completas"

titulo "Finales de línea"
if git ls-files --eol | grep -qE 'w/crlf'; then
    git ls-files --eol | grep -E 'w/crlf'
    error "hay archivos con CRLF; revisa .gitattributes"
else
    ok "todo LF"
fi

titulo "Hardening"
# Un puerto con IP tiene tres partes ("127.0.0.1:6080:6080"); uno expuesto solo
# dos ("6080:6080"). Ojo: filtrar por '"[0-9]' marcaría también las IP, que
# empiezan por dígito — ese falso positivo ya dejó el CI en rojo una vez.
expuestos=$(grep -nE '^[[:space:]]*-[[:space:]]*"([0-9]+:[0-9]+|0\.0\.0\.0:)' compose.yaml || true)
if [ -n "$expuestos" ]; then
    echo "$expuestos"
    error "hay puertos publicados fuera de 127.0.0.1"
else
    ok "$(grep -cE '^[[:space:]]*-[[:space:]]*"127\.0\.0\.1:' compose.yaml) puerto(s) atados a loopback"
fi

n_hc=$(grep -c '^HEALTHCHECK' Dockerfile || true)
if [ "$n_hc" -ge 2 ]; then ok "HEALTHCHECK en ambas etapas"; else error "faltan HEALTHCHECK ($n_hc de 2)"; fi

if grep -q '^ARG LAB_PASSWORD' Dockerfile; then
    ok "la contraseña es parametrizable"
else
    error "LAB_PASSWORD dejó de ser un ARG"
fi

echo
if [ $fallos -eq 0 ]; then
    echo "${VERDE}Todo en orden.${FIN} El CI debería pasar."
else
    echo "${ROJO}$fallos verificación(es) fallaron.${FIN} Corrige antes de pushear."
fi
exit $fallos
