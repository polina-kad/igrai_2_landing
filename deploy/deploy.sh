#!/usr/bin/env bash
#
# Выкладка лендинга IGRAI на сервер.
#
#   ./deploy/deploy.sh
#
# На Windows запускать в Git Bash — либо двойным кликом по 3-deploy.bat
# в корне проекта, он сам найдёт Git Bash.
#
# Настройки берутся из deploy/target.env.
#
# Что делает:
#   1. проверяет, что локально все файлы на месте
#   2. спрашивает у nginx, где корень сайта, и кладёт папку внутрь него
#   3. заливает файлы во временную папку, потом атомарно подменяет боевую
#   4. проверяет, что отдаётся именно наш сайт, а не чужой
#
# Сайт статический: nginx отдаёт его сам, ничего запускать на сервере не нужно.

set -euo pipefail

cd "$(dirname "$0")/.."

# ── оформление вывода ────────────────────────────────────────────────────────
if [ -t 1 ]; then
    C_H=$'\033[1;36m'; C_OK=$'\033[1;32m'; C_ERR=$'\033[1;31m'
    C_WARN=$'\033[1;33m'; C_OFF=$'\033[0m'
else
    C_H=''; C_OK=''; C_ERR=''; C_WARN=''; C_OFF=''
fi
say()  { printf '\n%s==>%s %s\n' "$C_H"  "$C_OFF" "$1"; }
ok()   { printf '    %sok%s  %s\n'  "$C_OK"  "$C_OFF" "$1"; }
warn() { printf '    %s!%s   %s\n'  "$C_WARN" "$C_OFF" "$1"; }
die()  { printf '\n%sОшибка:%s %s\n\n' "$C_ERR" "$C_OFF" "$1" >&2; exit 1; }

# маркер, по которому узнаём собственную страницу среди чужих:
# при неверном пути nginx отдаёт чужой index.html с кодом 200
MARKER='screenBox'

# ── 1. настройки ─────────────────────────────────────────────────────────────
CONF="deploy/target.env"
[ -f "$CONF" ] || die "нет $CONF — скопируйте deploy/target.env.example и заполните."
# shellcheck source=/dev/null
. "$CONF"

: "${SSH_HOST:?не задан SSH_HOST в $CONF}"
: "${SSH_USER:?не задан SSH_USER в $CONF}"
SSH_PORT="${SSH_PORT:-22}"
SITE_PATH="${SITE_PATH:-/igrai2}"
REMOTE_DIR="${REMOTE_DIR:-}"          # пусто = определить автоматически

TARGET="$SSH_USER@$SSH_HOST"
SSH="ssh -p $SSH_PORT -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new"

# root'у sudo не нужен
if [ "$SSH_USER" = "root" ]; then SUDO=""; else SUDO="sudo "; fi

printf '\n%s┌────────────────────────────────────────────┐%s\n' "$C_H" "$C_OFF"
printf '%s│  IGRAI — выкладка на сервер                │%s\n'   "$C_H" "$C_OFF"
printf '%s└────────────────────────────────────────────┘%s\n'   "$C_H" "$C_OFF"
printf '    сервер:  %s:%s\n' "$TARGET" "$SSH_PORT"
printf '    адрес:   http://%s%s/\n' "$SSH_HOST" "$SITE_PATH"

# ── 2. локальные файлы ───────────────────────────────────────────────────────
say "Проверяю файлы проекта"
for f in index.html assets/style.css assets/app.js assets/fonts.css asus_rog_animated.glb; do
    [ -f "$f" ] || die "нет файла $f — запускаете не из папки проекта?"
done
[ -d assets/vendor/three ] || die "нет папки assets/vendor/three (библиотека three.js)"
[ -d assets/fonts ]        || die "нет папки assets/fonts (шрифты)"
grep -q "$MARKER" index.html || die "в index.html нет блока $MARKER — файл повреждён?"
grep -q 'asus_rog_animated' assets/app.js || die "assets/app.js не ссылается на модель"
ok "всё на месте"

# ── 3. связь с сервером ──────────────────────────────────────────────────────
say "Подключаюсь к серверу"
$SSH "$TARGET" 'echo "    сервер: $(hostname), $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"' \
    || die "не удалось подключиться. Проверьте SSH_HOST, SSH_USER и что ключ добавлен на сервер."

# ── 4. подготовка сервера ────────────────────────────────────────────────────
say "Готовлю сервер"
$SSH "$TARGET" "bash -s" <<REMOTE_PREP
set -e
if ! command -v nginx >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    ${SUDO}apt-get update -qq
    ${SUDO}apt-get install -y -qq nginx
fi
${SUDO}systemctl enable --now nginx >/dev/null 2>&1 || true
${SUDO}mkdir -p "$REMOTE_DIR"
echo "    nginx: \$(nginx -v 2>&1)"
REMOTE_PREP
printf '    папка:   %s\n' "$REMOTE_DIR"

# ── 5. заливка ───────────────────────────────────────────────────────────────
say "Заливаю файлы"

STAGE="${REMOTE_DIR}.new"
BACKUP="${REMOTE_DIR}.old"

# Команда для сервера собирается в строку: stdin занят потоком tar,
# поэтому heredoc здесь использовать нельзя.
REMOTE_CMD="set -e
${SUDO}mkdir -p \"\$(dirname '$REMOTE_DIR')\"
${SUDO}rm -rf '$STAGE' '$BACKUP'
${SUDO}mkdir -p '$STAGE'
${SUDO}tar xzf - -C '$STAGE'
# атомарная подмена: сайт не бывает обновлённым наполовину
if [ -d '$REMOTE_DIR' ]; then ${SUDO}mv '$REMOTE_DIR' '$BACKUP'; fi
${SUDO}mv '$STAGE' '$REMOTE_DIR'
${SUDO}rm -rf '$BACKUP'
${SUDO}chown -R www-data:www-data '$REMOTE_DIR' 2>/dev/null || true
${SUDO}find '$REMOTE_DIR' -type d -exec chmod 755 {} +
${SUDO}find '$REMOTE_DIR' -type f -exec chmod 644 {} +
echo \"    файлов: \$(find '$REMOTE_DIR' -type f | wc -l), размер: \$(du -sh '$REMOTE_DIR' | cut -f1)\""

# tar через ssh — работает и в Git Bash на Windows, где нет rsync
tar czf - \
    --exclude='Thumbs.db' \
    --exclude='.DS_Store' \
    --exclude='desktop.ini' \
    index.html README.md assets asus_rog_animated.glb \
| $SSH "$TARGET" "$REMOTE_CMD"
ok "файлы на месте"

# ── 6. проверка ──────────────────────────────────────────────────────────────
# Коду ответа верить нельзя: при неверном пути nginx отдаёт чужой index.html
# с кодом 200. Поэтому ищем в ответе маркер нашей страницы и следим, чтобы
# CSS приходил как CSS, а не как HTML.
BASE="http://127.0.0.1${SITE_PATH}/"

check_site() {
    local out
    out=$($SSH "$TARGET" "
page=\$(curl -sL '$BASE' | head -c 4000)
echo \"MARKER=\$(echo \"\$page\" | grep -c '$MARKER')\"
echo \"CSSTYPE=\$(curl -sLo /dev/null -w '%{content_type}' '${BASE}assets/style.css')\"
echo \"CSSCODE=\$(curl -sLo /dev/null -w '%{http_code}' '${BASE}assets/style.css')\"
echo \"GLBCODE=\$(curl -sLo /dev/null -w '%{http_code}' '${BASE}asus_rog_animated.glb')\"
echo \"GLBSIZE=\$(curl -sLo /dev/null -w '%{size_download}' '${BASE}asus_rog_animated.glb')\"" | tr -d '\r')
    eval "$out"

    FAIL=0
    if [ "${MARKER:-0}" -ge 1 ]; then ok "отдаётся наш index.html"
    else warn "по адресу отдаётся чужая страница"; FAIL=1; fi

    case "${CSSTYPE:-}" in
        text/css*) ok "стили отдаются как CSS" ;;
        *) warn "style.css приходит как '${CSSTYPE:-нет ответа}' (код ${CSSCODE:-?})"; FAIL=1 ;;
    esac

    if [ "${GLBCODE:-0}" = "200" ] && [ "${GLBSIZE:-0}" -gt 1000000 ]; then
        ok "3D-модель отдаётся ($(( ${GLBSIZE:-0} / 1048576 )) МБ)"
    else
        warn "модель: код ${GLBCODE:-?}, размер ${GLBSIZE:-0} байт"; FAIL=1
    fi
    return $FAIL
}

say "Проверяю, что отдаётся именно наш сайт"
if check_site; then
    NEEDS_NGINX=0
else
    NEEDS_NGINX=1
fi

# ── 7. если nginx не знает про наш подпуть — предлагаем добавить блок ────────
if [ "$NEEDS_NGINX" = "1" ]; then
    printf '
%snginx не отдаёт %s/ из папки %s.%s

Причина обычно одна: корень server-блока указывает на другой сайт,
и наш подпуть туда не попадает. Лечится отдельным блоком location —
ровно так же, как на этом сервере уже сделано для /1comp/.

Вот что будет добавлено в конфиг:
' "$C_WARN" "$SITE_PATH" "$REMOTE_DIR" "$C_OFF"
    sed 's/^/    /' deploy/nginx-igrai2.conf | grep -v '^\s*#' | grep -v '^\s*$'
    printf '
Перед изменением делается резервная копия конфига, потом nginx -t.
Если проверка не пройдёт — конфиг откатывается обратно.

'
    printf 'Добавить блок в конфиг nginx? [y/N] '
    if [ -r /dev/tty ]; then read -r ANS </dev/tty || ANS=""; else read -r ANS || ANS=""; fi
    case "$ANS" in
        y|Y|д|Д) ;;
        *) printf '\n    Отменено. Файлы залиты, но сайт по адресу не открывается.\n\n'; exit 1 ;;
    esac

    say "Правлю конфиг nginx"

    # блок отправляем отдельным файлом — так надёжнее, чем вкладывать в команду
    $SSH "$TARGET" "cat > /tmp/igrai2-block.conf" < deploy/nginx-igrai2.conf

    $SSH "$TARGET" "bash -s" <<REMOTE_NGINX
set -e
F=\$(grep -rl 'default_server' /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null | head -n1)
[ -n "\$F" ] || F=\$(ls /etc/nginx/sites-enabled/* 2>/dev/null | head -n1)
[ -n "\$F" ] || { echo "не нашла включённый конфиг nginx"; exit 1; }
F=\$(readlink -f "\$F")
echo "    конфиг: \$F"

if grep -q 'location ^~ ${SITE_PATH}/' "\$F"; then
    echo "    блок уже есть — ничего не меняю"
    exit 0
fi

BAK="\$F.bak-igrai2-\$(date +%Y%m%d-%H%M%S)"
${SUDO}cp -a "\$F" "\$BAK"
echo "    резервная копия: \$BAK"

awk '
    FNR==NR { block = block \$0 "\\n"; next }
    !ins && /^[[:space:]]*location \\/ \\{/ { printf "%s\\n", block; ins=1 }
    { print }
' /tmp/igrai2-block.conf "\$BAK" > /tmp/igrai2-nginx.new

if ! grep -q 'location ^~ ${SITE_PATH}/' /tmp/igrai2-nginx.new; then
    echo "    не нашла, куда вставить блок (нет строки 'location / {')"
    exit 1
fi

${SUDO}cp /tmp/igrai2-nginx.new "\$F"
if ${SUDO}nginx -t 2>&1 | tail -2; then
    ${SUDO}systemctl reload nginx
    echo "    конфиг применён"
else
    ${SUDO}cp -a "\$BAK" "\$F"
    echo "    ОШИБКА в конфиге — откатила обратно"
    exit 1
fi
${SUDO}rm -f /tmp/igrai2-block.conf /tmp/igrai2-nginx.new
REMOTE_NGINX

    say "Проверяю ещё раз"
    if check_site; then NEEDS_NGINX=0; fi
fi

if [ "$NEEDS_NGINX" = "0" ]; then
    printf '\n%s┌────────────────────────────────────────────┐%s\n' "$C_OK" "$C_OFF"
    printf '%s│  ГОТОВО                                    │%s\n'   "$C_OK" "$C_OFF"
    printf '%s└────────────────────────────────────────────┘%s\n'   "$C_OK" "$C_OFF"
    printf '\n    Откройте:  http://%s%s/\n\n' "$SSH_HOST" "$SITE_PATH"
else
    printf '\n%sСайт всё ещё отдаётся неверно.%s
    Пришлите отчёт: запустите 4-diagnostika-servera.bat\n\n' "$C_ERR" "$C_OFF"
    exit 1
fi
