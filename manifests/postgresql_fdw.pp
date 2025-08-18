# @summary Manages PostgreSQL Foreign Data Wrapper (FDW) setup, including foreign server,
#   user mapping, schema creation, foreign table import, and local view definition.
#
# This define orchestrates the necessary PostgreSQL operations to enable
# access to a remote 'inventory.hosts' table via FDW within a local database.
# It ensures idempotency for all configured resources.
#
# @param database_name The name of the local PostgreSQL database where FDW will be configured.
#
# @param database_user The PostgreSQL user in the local database who will own schemas,
#   access the FDW, and perform related operations. This user must have sufficient
#   privileges (e.g., superuser or explicit grants for CREATE EXTENSION, CREATE SERVER, etc.).
#
# @param database_password The password for the local PostgreSQL database_user.
#   WARNING: Direct passwords in Puppet manifests are generally discouraged for production.
#   Consider using Hiera-Eyaml for secrets management or configuring .pgpass files on agents.
#
# @param remote_database_name The name of the foreign database to access on the same PostgreSQL server.
#
# @param remote_user The user for connecting to the remote database within the same server.
#
# @param remote_password The password for the remote_user.
#
# @param database_host The host for the remote database connection.
#
# @param database_port The port for the remote database connection.
#
define iop::postgresql_fdw (
  String $database_name,
  String $database_user,
  String $database_password,
  String $remote_database_name,
  String $remote_user,
  String $remote_password,
  String $database_host = 'localhost',
  Stdlib::Port $database_port = 5432,
) {
  $remote_table_schema = 'inventory'
  $remote_table_name = 'hosts'
  $local_source_schema = 'inventory_source'
  $foreign_server_name = 'hbi_server'

  include postgresql::client

  $psql_env = [
    "PGPASSWORD=${database_password}",
    "PGUSER=${database_user}",
  ]

  postgresql::server::extension { "${database_name}-fdw":
    ensure    => 'present',
    database  => $database_name,
    extension => 'postgres_fdw',
    require   => Postgresql::Server::Db[$database_name],
  }

  postgresql_psql { "${name}-create_foreign_server":
    db      => $database_name,
    command => "CREATE SERVER ${foreign_server_name} FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '${database_host}', port '${database_port}', dbname '${remote_database_name}');",
    unless  => "SELECT 1 FROM pg_foreign_server WHERE srvname = '${foreign_server_name}'",
    require => Postgresql::Server::Extension["${database_name}-fdw"],
  }

  postgresql_psql { "${name}-create_user_mapping":
    db      => $database_name,
    command => "CREATE USER MAPPING FOR \"${database_user}\" SERVER ${foreign_server_name} OPTIONS (user '${remote_user}', password '${remote_password}');",
    unless  => "SELECT 1 FROM information_schema.user_mappings WHERE authorization_identifier = '${database_user}' AND foreign_server_name = '${foreign_server_name}'",
    require => Postgresql_psql["${name}-create_foreign_server"],
  }

  postgresql_psql { "${name}-create_postgres_user_mapping":
    db      => $database_name,
    command => "CREATE USER MAPPING FOR \"postgres\" SERVER ${foreign_server_name} OPTIONS (user '${remote_user}', password '${remote_password}');",
    unless  => "SELECT 1 FROM information_schema.user_mappings WHERE authorization_identifier = 'postgres' AND foreign_server_name = '${foreign_server_name}'",
    require => Postgresql_psql["${name}-create_foreign_server"],
  }

  postgresql_psql { "${name}-grant_usage_on_foreign_server":
    db      => $database_name,
    command => "GRANT USAGE ON FOREIGN SERVER ${foreign_server_name} TO \"${database_user}\";",
    unless  => "SELECT 1 FROM pg_foreign_server WHERE srvname = '${foreign_server_name}' AND has_server_privilege('${database_user}', '${foreign_server_name}', 'USAGE')",
    require => Postgresql_psql["${name}-create_user_mapping"],
  }

  postgresql::server::schema { "${name}-inventory":
    db      => $database_name,
    owner   => $database_user,
    schema  => $remote_table_schema,
    require => Postgresql_psql["${name}-grant_usage_on_foreign_server"],
  }

  postgresql::server::schema { "${name}-inventory_source":
    db      => $database_name,
    owner   => $database_user,
    schema  => $local_source_schema,
    require => Postgresql::Server::Schema["${name}-inventory"],
  }

  postgresql_psql { "${name}-import_foreign_table":
    db      => $database_name,
    command => "IMPORT FOREIGN SCHEMA \"${remote_table_schema}\" LIMIT TO (\"${remote_table_name}\") FROM SERVER ${foreign_server_name} INTO \"${local_source_schema}\";",
    unless  => "SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = '${local_source_schema}' AND foreign_table_name = '${remote_table_name}'",
    require => [
      Postgresql::Server::Schema["${name}-inventory_source"],
      Postgresql_psql["${name}-create_user_mapping"],
      Postgresql_psql["${name}-create_postgres_user_mapping"],
    ],
  }

  $create_view_sql = "CREATE OR REPLACE VIEW \"${remote_table_schema}\".\"${remote_table_name}\" AS SELECT * FROM \"${local_source_schema}\".\"${remote_table_name}\";"

  postgresql_psql { "${name}-create_local_view":
    db          => $database_name,
    command     => $create_view_sql,
    unless      => "SELECT 1 FROM pg_views WHERE schemaname = '${remote_table_schema}' AND viewname = '${remote_table_name}'",
    environment => $psql_env,
    require     => Postgresql_psql["${name}-import_foreign_table"],
  }

  # Grant SELECT permission on the foreign table to the database user
  # Foreign tables require explicit permissions even for schema owners
  # Must run as postgres since foreign table is owned by postgres
  postgresql_psql { "${name}-grant_foreign_table_access":
    db      => $database_name,
    command => "GRANT SELECT ON \"${local_source_schema}\".\"${remote_table_name}\" TO \"${database_user}\";",
    unless  => "SELECT 1 FROM information_schema.role_table_grants WHERE grantee = '${database_user}' AND table_schema = '${local_source_schema}' AND table_name = '${remote_table_name}' AND privilege_type = 'SELECT'",
    require => Postgresql_psql["${name}-import_foreign_table"],
  }

  postgresql_psql { "${name}-grant_remote_view_access":
    db      => $remote_database_name,
    command => "GRANT SELECT ON \"${remote_table_schema}\".\"${remote_table_name}\" TO \"${remote_user}\";",
    unless  => "SELECT 1 FROM information_schema.role_table_grants WHERE grantee = '${remote_user}' AND table_schema = '${remote_table_schema}' AND table_name = '${remote_table_name}' AND privilege_type = 'SELECT'",
    require => Postgresql_psql["${name}-import_foreign_table"],
  }
}
