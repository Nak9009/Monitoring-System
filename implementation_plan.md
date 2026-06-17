# Implementation Plan — Migration to MySQL Database Stack

This plan outlines the architecture changes required to migrate the monitoring stack's database layer from PostgreSQL + TimescaleDB to MySQL 8.0.

---

## Proposed Changes

We will modify the Docker Compose configurations, Ansible roles, and utility scripts to support MySQL.

### 1. Docker Compose Stack Migrations
- **Database Engine**: Replace PostgreSQL/TimescaleDB container with `mysql:8.0`.
- **Configuration**: Create `configs/mysql/my.cnf` tuned for a 4 GB system.
- **Images**: Switch Zabbix components to their MySQL-supported equivalents:
  - `zabbix/zabbix-server-pgsql` ➔ `zabbix/zabbix-server-mysql:ubuntu-7.0-latest`
  - `zabbix/zabbix-web-nginx-pgsql` ➔ `zabbix/zabbix-web-nginx-mysql:ubuntu-7.0-latest`
- **Tuning**: Adjust database memory limits for MySQL (InnoDB buffer pool).
- **Scripts**: 
  - Delete `scripts/init-timescaledb.sh` (obsolete).
  - Update `scripts/backup.sh` to use `mysqldump` instead of `pg_dump`.

### 2. Ansible Configurations
- **Database Role**: Replace `roles/postgresql` with a new `roles/mysql` role.
- **MySQL Role Details**:
  - Install MySQL Server package and Python `pymysql` module.
  - Create Zabbix database, grant permissions, and configure `/etc/mysql/conf.d/zabbix.cnf` using a template.
- **Zabbix Roles**:
  - Update `roles/zabbix-server` to install `zabbix-server-mysql` and import the MySQL database schema (`/usr/share/zabbix-sql-scripts/mysql/schema.sql`).
  - Update `roles/zabbix-frontend` template `zabbix.conf.php.j2` to use `MYSQL` as the database type.
- **Backup Role**: Update `roles/backup/templates/backup.sh.j2` to use `mysqldump`.

---

## Verification Plan

### Automated Checks
- Run `docker compose config` to validate compose health checks and environment setups.
- Validate Ansible playbook syntax.
