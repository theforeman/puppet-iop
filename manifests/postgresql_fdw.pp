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
define iop::postgresql_fdw (
  String $database_name,
  String $database_user,
  String $database_password,
  String $remote_database_name, # Renamed from remote_dbname
  String $remote_user,
  String $remote_password,
) {
  $remote_table_schema = 'inventory'
  $remote_table_name = 'hosts'
  $local_source_schema = 'inventory_source'

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

  postgresql_psql { "${name}-create_hbi_foreign_server":
    db      => $database_name,
    command => "CREATE SERVER hbi_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '5432', dbname '${remote_database_name}');",
    unless  => "SELECT 1 FROM pg_foreign_server WHERE srvname = 'hbi_server'",
    require => Postgresql::Server::Extension["${database_name}-fdw"],
  }

  postgresql_psql { "${name}-create_user_mapping_for_hbi_server":
    db      => $database_name,
    command => "CREATE USER MAPPING FOR \"${database_user}\" SERVER hbi_server OPTIONS (user '${remote_user}', password '${remote_password}');",
    unless  => "SELECT 1 FROM information_schema.user_mappings WHERE authorization_identifier = '${database_user}' AND foreign_server_name = 'hbi_server'",
    require => Postgresql_psql["${name}-create_hbi_foreign_server"],
  }

  postgresql_psql { "${name}-postgres-create_user_mapping_for_hbi_server":
    db      => $database_name,
    command => "CREATE USER MAPPING FOR \"postgres\" SERVER hbi_server OPTIONS (user '${remote_user}', password '${remote_password}');",
    unless  => "SELECT 1 FROM information_schema.user_mappings WHERE authorization_identifier = 'postgres' AND foreign_server_name = 'hbi_server'",
    require => Postgresql_psql["${name}-create_hbi_foreign_server"],
  }

  postgresql_psql { "${name}-grant_usage_on_hbi_server_to_database_user":
    db      => $database_name,
    command => "GRANT USAGE ON FOREIGN SERVER hbi_server TO \"${database_user}\";",
    unless  => "SELECT 1 FROM pg_foreign_server fs JOIN pg_roles r ON r.oid = fs.srvowner WHERE fs.srvname = 'hbi_server' AND has_server_privilege(r.rolname, 'hbi_server', 'USAGE')",
    require => Postgresql_psql["${name}-create_user_mapping_for_hbi_server"],
  }

  postgresql::server::schema { "${name}-inventory":
    db      => $database_name,
    owner   => $database_user,
    schema  => $remote_table_schema,
    require => Postgresql_psql["${name}-grant_usage_on_hbi_server_to_database_user"],
  }

  postgresql::server::schema { "${name}-inventory_source":
    db      => $database_name,
    owner   => $database_user,
    schema  => $local_source_schema,
    require => Postgresql::Server::Schema["${name}-inventory"],
  }

  postgresql_psql { "${name}-import_foreign_table_hosts":
    db      => $database_name,
    command => "IMPORT FOREIGN SCHEMA \"${remote_table_schema}\" LIMIT TO (\"${remote_table_name}\") FROM SERVER hbi_server INTO \"${local_source_schema}\";",
    unless  => "SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = '${local_source_schema}' AND foreign_table_name = '${remote_table_name}'",
    require => [
      Postgresql::Server::Schema["${name}-inventory_source"],
      Postgresql_psql["${name}-create_user_mapping_for_hbi_server"],
    ],
  }

  $create_view_sql = "CREATE OR REPLACE VIEW \"${remote_table_schema}\".\"${remote_table_name}\" AS SELECT * FROM \"${local_source_schema}\".\"${remote_table_name}\";"

  postgresql_psql { "${name}-create_or_replace_local_view_inventory_hosts":
    db          => $database_name,
    command     => $create_view_sql,
    unless      => "SELECT 1 FROM pg_views WHERE schemaname = '${remote_table_schema}' AND viewname = '${remote_table_name}'",
    environment => $psql_env,
    require     => Postgresql_psql["${name}-import_foreign_table_hosts"],
  }

  postgresql_psql { "${name}-grant_select_on_inventory_hosts_to_public":
    db          => $database_name,
    command     => "GRANT SELECT ON \"${remote_table_schema}\".\"${remote_table_name}\" TO PUBLIC;",
    unless      => "SELECT 1 FROM information_schema.role_table_grants WHERE grantee = 'PUBLIC' AND table_schema = '${remote_table_schema}' AND table_name = '${remote_table_name}' AND privilege_type = 'SELECT'",
    environment => $psql_env,
    require     => Postgresql_psql["${name}-create_or_replace_local_view_inventory_hosts"],
  }
}
