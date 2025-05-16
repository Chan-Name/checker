#!/bin/bash

PROCESS_NAME="test"
SCRIPT_NAME="$(basename "$0")"
FILE_NAME="${SCRIPT_NAME%.*}"
SCRIPT_PATH="$(realpath "$0")"
LOG_PATH="/var/log/monitoring.log"
UNIT_PATH="/etc/systemd/system"
USER_NAME=$(whoami)
URL="https://test.com/monitoring/test/api"
SLEEP_TIME=60

create_unit() {
    if [[ -f "$UNIT_PATH/$FILE_NAME.service" ]]; then
        return 0
    fi

    sudo tee "$UNIT_PATH/$FILE_NAME.service" >/dev/null <<EOF
[Unit]
Description=Service for $SCRIPT_NAME

[Service]
Type=simple
User=$USER_NAME
ExecStart=$SCRIPT_PATH
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$FILE_NAME"
    sudo systemctl start "$FILE_NAME"
}

log() {
    if [[ ! -f "$LOG_PATH" ]]; then
        sudo touch "$LOG_PATH"
        sudo chown "$USER_NAME:$USER_NAME" "$LOG_PATH"
    fi
    echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$LOG_PATH"
}

# Чисто технически это можно было реализовать через поиск имеющегося пакетного менеджера
# И вызов установки с его помощью
# Но это выглядило по итогу крайне страшно и занимало сравнительно слишком много места
curl_checker() {
    if ! command -v "curl"; then
        read -p "Curl не найден. Произведите команду установки (Пример: sudo apt install curl) " answer
        $answer
    fi
}

knock() {
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    if [[ "$http_status" -ne "200" ]]; then
        log "Сервис мониторинга недоступен. HTTP response: "$http_status""
    fi
}

process_checker() {
    prev_pid=$(pgrep -f "$PROCESS_NAME")

    while true; do
        cur_pid=$(pgrep -f "$PROCESS_NAME")
        if [[ -n $cur_pid ]]; then
            knock
            if [[ $cur_pid != $prev_pid ]]; then
                log "Процесс "$PROCESS_NAME" был перезапущен\n Старый PID=$prev_pid, Новый=$cur_pid"
                prev_pid=$cur_pid
            fi
        fi
        sleep "$SLEEP_TIME"
    done
}

main() {
    create_unit
    curl_checker
    process_checker
}

main
