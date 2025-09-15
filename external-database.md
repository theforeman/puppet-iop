# External Database Configuration for IOP Services

This document provides instructions for configuring IOP (Insights on Premise) services to use external PostgreSQL databases instead of the default local database.

## Overview

The IOP module provides these database-dependent services:
- **Host Inventory** (inventory_db)
- **Vulnerability Service** (vulnerability_db) 
- **VMaaS** (vmaas_db)
- **Advisor** (advisor_db)
- **Remediations** (remediations_db)

## Prerequisites

- External PostgreSQL server configured and accessible
- Foreman server with network access to PostgreSQL server
- PostgreSQL client tools installed on Foreman server

## Configuration Steps

### 1. Create IOP Databases and Users

Connect to your external PostgreSQL server and create the required databases:

```sql
-- Connect as postgres superuser
-- Create users
CREATE USER inventory_user WITH ENCRYPTED PASSWORD 'your_inventory_password';
CREATE USER vulnerability_admin WITH ENCRYPTED PASSWORD 'your_vulnerability_password';
CREATE USER vmaas_admin WITH ENCRYPTED PASSWORD 'your_vmaas_password';
CREATE USER advisor_user WITH ENCRYPTED PASSWORD 'your_advisor_password';
CREATE USER remediations_user WITH ENCRYPTED PASSWORD 'your_remediations_password';

-- Create databases with owners (automatically grants all privileges)
CREATE DATABASE inventory_db OWNER inventory_user;
CREATE DATABASE vulnerability_db OWNER vulnerability_admin;
CREATE DATABASE vmaas_db OWNER vmaas_admin;
CREATE DATABASE advisor_db OWNER advisor_user;
CREATE DATABASE remediations_db OWNER remediations_user;
```

### 2. Configure PostgreSQL for SSL (Optional)

If using SSL connections, enable SSL in postgresql.conf:

```
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'ca.crt'
```

### 3. Configure pg_hba.conf

Add entries for IOP service connections in pg_hba.conf:

```
# IOP service connections (without SSL)
host inventory_db inventory_user <foreman-server-ip>/32 md5
host vulnerability_db vulnerability_admin <foreman-server-ip>/32 md5
host vmaas_db vmaas_admin <foreman-server-ip>/32 md5
host advisor_db advisor_user <foreman-server-ip>/32 md5
host remediations_db remediations_user <foreman-server-ip>/32 md5

# IOP service connections (with SSL)
hostssl inventory_db inventory_user <foreman-server-ip>/32 md5
hostssl vulnerability_db vulnerability_admin <foreman-server-ip>/32 md5
hostssl vmaas_db vmaas_admin <foreman-server-ip>/32 md5
hostssl advisor_db advisor_user <foreman-server-ip>/32 md5
hostssl remediations_db remediations_user <foreman-server-ip>/32 md5
```

### 4. Install with External Database Configuration

Run foreman-installer with IOP external database parameters:

```bash
foreman-installer --scenario katello \
  --external-postgresql-host=postgresql.example.com \
  --external-postgresql-port=5432 \
  --external-postgresql-database=foreman \
  --external-postgresql-username=foreman \
  --external-postgresql-password=foreman_password \
  --iop-database-host=postgresql.example.com \
  --iop-database-port=5432 \
  --iop-inventory-database-name=inventory_db \
  --iop-inventory-database-user=inventory_user \
  --iop-inventory-database-password=your_inventory_password \
  --iop-vulnerability-database-name=vulnerability_db \
  --iop-vulnerability-database-user=vulnerability_admin \
  --iop-vulnerability-database-password=your_vulnerability_password \
  --iop-vmaas-database-name=vmaas_db \
  --iop-vmaas-database-user=vmaas_admin \
  --iop-vmaas-database-password=your_vmaas_password \
  --iop-advisor-database-name=advisor_db \
  --iop-advisor-database-user=advisor_user \
  --iop-advisor-database-password=your_advisor_password \
  --iop-remediations-database-name=remediations_db \
  --iop-remediations-database-user=remediations_user \
  --iop-remediations-database-password=your_remediations_password
```

### 5. SSL Configuration

For SSL database connections, add these SSL options to the foreman-installer command:

```bash
# Add SSL options to the foreman-installer command:
  --iop-database-sslmode=verify-ca \
  --iop-database-ssl-ca=/path/to/ca.crt
```

Common SSL modes:
- `disable` - No SSL connection
- `require` - SSL required, but no certificate verification
- `verify-ca` - SSL required with CA certificate verification
- `verify-full` - SSL required with full certificate verification

### 6. Optional Service Control

Control which IOP services are enabled:

```bash
# Disable vulnerability services
--iop-enable-vulnerability=false

# Disable advisor services  
--iop-enable-advisor=false

# Disable smart proxy registration
--iop-register-as-smartproxy=false
```

## Important Configuration Notes

### Database Host Configuration
- **Default**: `database_host = '/var/run/postgresql/'` (Unix socket)
- **External**: Must specify hostname/IP address for external database
- **Port**: Default port 5432, override with `--iop-database-port`

### Cross-Database Access
The IOP module uses PostgreSQL Foreign Data Wrapper (FDW) to enable cross-service database access. This requires:
- All databases on the same PostgreSQL server
- Proper user permissions for FDW operations
- Network connectivity between services and databases

### SSL Environment Variables

Each service uses different SSL-related environment variables:

**Vulnerability Service:**
- `POSTGRES_SSL_MODE` - PostgreSQL SSL mode (disable, allow, prefer, require, verify-ca, verify-full)
- `POSTGRES_SSL_ROOT_CERT_PATH` - Path to SSL root certificate file

**Remediations Service:**
- `DB_SSL_ENABLED` - SSL enabled flag (true/false, true when sslmode is not 'disable')
- `DB_SSL_CERT` - Path to SSL certificate file

These are automatically configured based on the `--iop-database-sslmode` and `--iop-database-ssl-ca` parameters.

### Security Considerations
1. **Strong Passwords**: Use unique, strong passwords for each database user
2. **Network Security**: Ensure firewall rules allow only necessary connections
3. **SSL/TLS**: Consider enabling SSL for database connections in production
4. **Certificate Management**: Integrates with existing `certs::iop` module

### Available Parameters

All parameters defined in the `iop` class are automatically recognized by foreman-installer using the `--iop-` prefix:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `database_host` | Database server hostname/IP | `/var/run/postgresql/` |
| `database_port` | Database server port | `5432` |
| `database_sslmode` | PostgreSQL SSL mode | `disable` |
| `database_ssl_ca` | Path to SSL CA certificate | `undef` |
| `inventory_database_name` | Host inventory database name | `inventory_db` |
| `inventory_database_user` | Host inventory database user | `inventory_user` |
| `inventory_database_password` | Host inventory database password | Auto-generated |
| `vulnerability_database_name` | Vulnerability service database name | `vulnerability_db` |
| `vulnerability_database_user` | Vulnerability service database user | `vulnerability_admin` |
| `vulnerability_database_password` | Vulnerability service database password | Auto-generated |
| `vmaas_database_name` | VMaaS service database name | `vmaas_db` |
| `vmaas_database_user` | VMaaS service database user | `vmaas_admin` |
| `vmaas_database_password` | VMaaS service database password | Auto-generated |
| `advisor_database_name` | Advisor service database name | `advisor_db` |
| `advisor_database_user` | Advisor service database user | `advisor_user` |
| `advisor_database_password` | Advisor service database password | Auto-generated |
| `remediations_database_name` | Remediations service database name | `remediations_db` |
| `remediations_database_user` | Remediations service database user | `remediations_user` |
| `remediations_database_password` | Remediations service database password | Auto-generated |
| `enable_vulnerability` | Enable vulnerability services | `true` |
| `enable_advisor` | Enable advisor services | `true` |
| `register_as_smartproxy` | Register as Foreman smart proxy | `true` |

## Troubleshooting

### Connection Issues
- Verify network connectivity: `telnet postgresql.example.com 5432`
- Check PostgreSQL logs for authentication failures
- Ensure pg_hba.conf entries are correctly configured

### Permission Issues
- Verify user has proper database privileges
- Check FDW setup for cross-database access
- Ensure database users can connect from Foreman server IP

### SSL Issues
- Verify SSL certificates are properly configured
- Check PostgreSQL SSL configuration
- Ensure certificate paths are accessible to services

## Migration Considerations

**Note:** Migration from local to external databases for existing IOP installations is not currently documented. This process would require:
- Database dumps and restoration
- Service reconfiguration
- Data validation
- Minimal downtime planning

For migration assistance, consult Foreman documentation or support resources.