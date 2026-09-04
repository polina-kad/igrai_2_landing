#!/usr/bin/env bash
# Собирает всё о том, как настроен веб-сервер, и кладёт отчёт
# в deploy/server-report.txt. Ничего на сервере не меняет.
cd "$(dirname "$0")/.."
. deploy/target.env
SSH_PORT="${SSH_PORT:-22}"
SITE_PATH="${SITE_PATH:-/igrai2}"
OUT="deploy/server-report.txt"

echo "Собираю отчёт с $SSH_USER@$SSH_HOST ..."

ssh -p "$SSH_PORT" -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
    "$SSH_USER@$SSH_HOST" "SITE_PATH='$SITE_PATH' bash -s" > "$OUT" 2>&1 <<'REMOTE'
echo "===== 1. КТО СЛУШАЕТ ПОРТ 80 ====="
ss -ltnp 2>/dev/null | grep -E ':80\b|:443\b' || netstat -ltnp 2>/dev/null | grep -E ':80|:443'

echo; echo "===== 2. КОНТЕЙНЕРЫ ====="
if command -v docker >/dev/null 2>&1; then docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}' 2>&1 | head -20
else echo "docker не установлен"; fi

echo; echo "===== 3. СЛУЖБЫ ====="
systemctl is-active nginx apache2 caddy 2>/dev/null | paste -d' ' <(echo "nginx apache2 caddy" | tr ' ' '\n') -

echo; echo "===== 4. ВКЛЮЧЁННЫЕ КОНФИГИ NGINX ====="
ls -la /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>&1 | head -40

echo; echo "===== 5. ТЕКСТ ВКЛЮЧЁННЫХ КОНФИГОВ ====="
for f in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
    [ -e "$f" ] || continue
    echo "--- $f ---"
    grep -vE '^\s*#|^\s*$' "$(readlink -f "$f")" 2>/dev/null | head -70
done

echo; echo "===== 6. ROOT / ALIAS / LISTEN ИЗ ДЕЙСТВУЮЩЕГО КОНФИГА ====="
nginx -T 2>&1 | grep -nE 'server_name|listen|root |alias |try_files|location ' | head -60

echo; echo "===== 7. ЧТО ОТДАЁТСЯ ====="
echo "-- / --";              curl -sI --max-time 8 http://127.0.0.1/ | head -6
echo "-- $SITE_PATH/ --";    curl -sI --max-time 8 "http://127.0.0.1$SITE_PATH/" | head -6
echo "-- заголовок страницы $SITE_PATH/ --"
curl -s --max-time 8 "http://127.0.0.1$SITE_PATH/" | grep -o '<title>[^<]*' | head -2

echo; echo "===== 8. ЧТО ЛЕЖИТ НА ДИСКЕ ====="
for d in /var/www /var/www/html /var/www/igrai /var/www/igrai2 /var/www/html/igrai2 /usr/share/nginx/html; do
    echo "-- $d --"; ls -la "$d" 2>&1 | head -12
done

echo; echo "===== 9. ПРОБА ЗАПИСИ ====="
for d in /var/www /var/www/html /var/www/igrai; do
    [ -d "$d" ] || continue
    if mkdir -p "$d/__t" 2>/dev/null; then echo "$d — записываемо"; rmdir "$d/__t"; else echo "$d — НЕТ прав на запись"; fi
done

echo; echo "===== КОНЕЦ ====="
REMOTE

echo
echo "Готово. Отчёт: $OUT"
echo "Ничего на сервере не менялось."
