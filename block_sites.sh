#!/bin/bash

SITES=("www.youtube.com" "reddit.com" "www.instagram.com" "g1.globo.com" "ge.globo.com" "www.uol.com.br")

REDIRECT=${REDIRECT_IP:-"127.0.0.1"}

BACKUP_FILE="/etc/hosts.bak"

create_backup() {
    if [ ! -f $BACKUP_FILE ] || [ "$(date +%F -r $BACKUP_FILE)" != "$(date +%F)" ]; then
        sudo cp /etc/hosts $BACKUP_FILE
    fi
}

is_holiday() {
    CACHE_FILE="/tmp/is_holiday_check.cache"
    TODAY=$(date +%Y-%m-%d)
    YEAR=$(date +%Y)
    if [ ! -f $CACHE_FILE ] || [ "$(date +%F -r $CACHE_FILE)" != "$TODAY" ]; then
        HOLIDAYS=$(curl -s "https://brasilapi.com.br/api/feriados/$YEAR")
        echo $HOLIDAYS | grep -q "$TODAY" && touch $CACHE_FILE
    fi
    [ -f $CACHE_FILE ]
}

block_sites() {
    for site in "${SITES[@]}"; do
        if ! grep -q "$site" /etc/hosts; then
            echo "$REDIRECT $site" | sudo tee -a /etc/hosts > /dev/null
        fi
    done
    echo "$(date): Sites blocked." | sudo tee -a /var/log/siteblocker.log
}

unblock_sites() {
    if [ -f $BACKUP_FILE ]; then
        sudo cp $BACKUP_FILE /etc/hosts
        echo "$(date): Sites unblocked." | sudo tee -a /var/log/siteblocker.log
    fi
}

if is_holiday; then
    echo "Today is a holiday. No blocking will be applied."
    exit 0
fi

create_backup

HOUR=$(date +%-H)

START_HOUR=${START_HOUR:-9}
END_HOUR=${END_HOUR:-18}

if [[ $HOUR -ge $START_HOUR && $HOUR -lt $END_HOUR ]]; then
    block_sites
else
    unblock_sites
fi

