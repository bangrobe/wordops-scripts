#!/bin/bash

# === Check for input ===
if [ -z "$1" ]; then
  echo "Usage: $0 <your_site_domain>"
  exit 1
fi

SITE="$1"
SITE_PATH="/var/www/${SITE}/htdocs/wp-content"
BACKUP_DIR="/var/backups/wordops"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
SITE_BACKUP_NAME="${SITE}_wp-content-db_${TIMESTAMP}.tar.gz"

# === Check if wp-content exists ===
if [ ! -d "$SITE_PATH" ]; then
  echo "❌ Error: wp-content folder not found at ${SITE_PATH}"
  exit 2
fi

# === Extract DB credentials using wo site info (strip ANSI color) ===
echo "🔍 Extracting DB credentials..."
WO_INFO=$(wo site info $SITE | sed 's/\x1b\[[0-9;]*m//g')

DB_NAME=$(echo "$WO_INFO" | grep "DB_NAME" | awk '{print $2}')
DB_USER=$(echo "$WO_INFO" | grep "DB_USER" | awk '{print $2}')
DB_PASS=$(echo "$WO_INFO" | grep "DB_PASS" | awk '{print $2}')

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
  echo "❌ Error: Could not extract DB credentials"
  exit 3
fi

# === Create backup directory ===
mkdir -p "$BACKUP_DIR"

# === Backup wp-content ===
echo "📁 Backing up wp-content..."
tar -czf "/tmp/${SITE}_wp-content.tar.gz" -C "/var/www/${SITE}/htdocs" wp-content

# === Backup database ===
echo "🗃️ Backing up database..."
mariadb-dump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "/tmp/${SITE}_db.sql"
if [ $? -ne 0 ]; then
  echo "❌ Error: Database dump failed."
  rm -f "/tmp/${SITE}_wp-content.tar.gz"
  exit 4
fi

# === Combine both into final archive ===
echo "📦 Creating final archive..."
tar -czf "${BACKUP_DIR}/${SITE_BACKUP_NAME}" "/tmp/${SITE}_wp-content.tar.gz" "/tmp/${SITE}_db.sql"

# === Cleanup ===
rm -f "/tmp/${SITE}_wp-content.tar.gz" "/tmp/${SITE}_db.sql"

echo "✅ Backup complete: ${BACKUP_DIR}/${SITE_BACKUP_NAME}"
