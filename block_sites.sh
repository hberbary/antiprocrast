#!/bin/bash

# Define the websites and common subdomains to block or redirect
SITES=("youtube.com" "reddit.com" "instagram.com" "globo.com" "uol.com.br")
SUBDOMAINS=("www" "m" "mobile")

# Define the hosts entry
REDIRECT=${REDIRECT_IP:-"127.0.0.1"}

# Define backup file
BACKUP_FILE="/etc/hosts.bak"

# Function to create a backup if it doesn't exist or if it's a new day
create_backup() {
    if [ ! -f $BACKUP_FILE ] || [ "$(date +%F -r $BACKUP_FILE)" != "$(date +%F)" ]; then
        sudo cp /etc/hosts $BACKUP_FILE
    fi
}

# Function to check if today is a holiday
is_holiday() {
    CACHE_FILE="/tmp/holiday_check.cache"
    TODAY=$(date +%Y-%m-%d)
    YEAR=$(date +%Y)
    if [ ! -f $CACHE_FILE ] || [ "$(date +%F -r $CACHE_FILE)" != "$TODAY" ]; then
        HOLIDAYS=$(curl -s "https://brasilapi.com.br/api/feriados/v1/$YEAR")
        echo $HOLIDAYS | grep -q "$TODAY" && touch $CACHE_FILE
    fi
    [ -f $CACHE_FILE ]
}

# Function to block sites and common subdomains
block_sites() {
    for site in "${SITES[@]}"; do
        if ! grep -q "$site" /etc/hosts; then
            echo "$REDIRECT $site" | sudo tee -a /etc/hosts > /dev/null
        fi
        for subdomain in "${SUBDOMAINS[@]}"; do
            full_domain="$subdomain.$site"
            if ! grep -q "$full_domain" /etc/hosts; then
                echo "$REDIRECT $full_domain" | sudo tee -a /etc/hosts > /dev/null
            fi
        done
    done
    echo "$(date): Sites blocked." | sudo tee -a /var/log/siteblocker.log
}

# Function to unblock sites
unblock_sites() {
    if [ -f $BACKUP_FILE ]; then
        sudo cp $BACKUP_FILE /etc/hosts
        echo "$(date): Sites unblocked." | sudo tee -a /var/log/siteblocker.log
    fi
}

# Exit if today is a holiday
if is_holiday; then
    echo "Today is a holiday. No blocking will be applied."
    exit 0
fi

# Create backup if it doesn't exist or if it's a new day
create_backup

# Get current hour
HOUR=$(date +%-H)

# Define work hours (e.g., 9 AM to 6 PM)
START_HOUR=${START_HOUR:-9}
END_HOUR=${END_HOUR:-18}

# Block or unblock sites based on current hour
if [[ $HOUR -ge $START_HOUR && $HOUR -lt $END_HOUR ]]; then
    block_sites
else
    unblock_sites
fi
