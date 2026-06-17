#!/usr/bin/env bash
# ==============================================================================
# Enterprise Monitoring Stack — Automated Backup Script
# MySQL database backup + Zabbix configuration + Grafana dashboard export
# ==============================================================================

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/monitoring}"
KEEP_DAYS="${KEEP_DAYS:-14}"
DATE=$(date +%Y%m%d_%H%M%S)
MYSQL_CONTAINER="mon-mysql"
GRAFANA_CONTAINER="mon-grafana"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

echo "=== Starting Backup: $(date) ==="

# 1. MySQL Database Backup
echo "Backing up MySQL database..."
DB_BACKUP_FILE="$BACKUP_DIR/db_zabbix_$DATE.sql.gz"
docker exec "$MYSQL_CONTAINER" sh -c 'exec mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' | gzip > "$DB_BACKUP_FILE"
echo "Database backup saved to $DB_BACKUP_FILE"

# 2. Backup Grafana DB/Configurations
echo "Backing up Grafana data volume..."
GRAFANA_BACKUP_FILE="$BACKUP_DIR/grafana_data_$DATE.tar.gz"
docker run --rm --volumes-from "$GRAFANA_CONTAINER" -v "$BACKUP_DIR":/backup alpine tar czf "/backup/$(basename "$GRAFANA_BACKUP_FILE")" -C /var/lib/grafana .
echo "Grafana backup saved to $GRAFANA_BACKUP_FILE"

# 3. Clean up old backups
echo "Cleaning up backups older than $KEEP_DAYS days..."
find "$BACKUP_DIR" -type f -name "*.gz" -mtime +"$KEEP_DAYS" -exec rm -f {} \; -print

echo "=== Backup Completed Successfully: $(date) ==="
