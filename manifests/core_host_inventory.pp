# == Class: iop::core_host_inventory
#
# Install and configure the core host-inventory
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
# $database_user:: Username for the inventory database
#
# $database_name:: Name of the inventory database
#
# $database_password:: Password for the inventory database
#
class iop::core_host_inventory (
  String[1] $image = 'quay.io/iop/host-inventory:latest',
  Enum['present', 'absent'] $ensure = 'present',
  String[1] $database_password = 'changeme',
  String[1] $database_user = 'inventory_user',
  String[1] $database_name = 'inventory_db',
) {
  include podman
  include iop::core_network
  include iop::core_kafka
  include iop::database

  # Prevents errors if run from /root etc.
  Postgresql_psql {
    cwd => '/',
  }

  include postgresql::client, postgresql::server, postgresql::server::contrib

  postgresql::server::db { $database_name:
    user     => $database_user,
    password => postgresql::postgresql_password($database_user, $database_password),
    owner    => $database_user,
    encoding => 'utf8',
    locale   => 'en_US.utf8',
  }

  postgresql::server::extension { "${database_name}-fdw":
    ensure    => 'present',
    database  => $database_name,
    extension => 'postgres_fdw',
    require   => Postgresql::Server::Db[$database_name],
  }

  $psql_env = [
    "PGPASSWORD=${postgresql::postgresql_password($database_user, $database_password)}",
  ]

  postgresql::server::schema { 'inventory':
    db    => $database_name,
    owner => $database_user,
  }

  $remote_view_command = @("EOM")
    CREATE OR REPLACE VIEW "inventory"."hosts" AS SELECT
      id,
      account,
      display_name,
      created_on as created,
      modified_on as updated,
      stale_timestamp,
      stale_timestamp + INTERVAL '1' DAY * '7' AS stale_warning_timestamp,
      stale_timestamp + INTERVAL '1' DAY * '14' AS culled_timestamp,
      tags_alt as tags,
      system_profile_facts as system_profile,
      (canonical_facts ->> 'inventory_id')::uuid as inventory_id,
      reporter,
      per_reporter_staleness,
      org_id,
      groups
    FROM hbi.hosts WHERE (canonical_facts->'inventory_id' IS NOT NULL);
    | EOM

  postgresql_psql { 'create_or_replace_remote_view_inventory_hosts':
    db          => $database_name,
    command     => $remote_view_command,
    unless      => "SELECT 1 FROM pg_views WHERE schemaname = 'inventory' AND viewname = 'hosts'",
    environment => $psql_env,
    require     => [
      Postgresql::Server::Schema['inventory'],
      Podman::Quadlet['iop-core-host-inventory-migrate'],
    ],
  }

  podman::quadlet { 'iop-core-host-inventory-migrate':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'Database Readiness and Migration Init Container',
      },
      'Service'   => {
        'Type'            => 'oneshot',
        'RemainAfterExit' => 'true',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-host-inventory-migrate',
        'Network'       => 'iop-core-network',
        'Exec'          => 'make upgrade_db',
        'Environment'   => [
          'INVENTORY_DB_HOST=/var/run/postgresql/',
          'INVENTORY_DB_PORT=5432',
          "INVENTORY_DB_NAME=${database_name}",
          "INVENTORY_DB_USER=${database_user}",
          "INVENTORY_DB_PASS=${database_password}",
          'KAFKA_BOOTSTRAP_SERVERS=PLAINTEXT://iop-core-kafka:9092',
          'FF_LAST_CHECKIN=true',
          'USE_SUBMAN_ID=true',
        ],
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
      },
    },
  }

  podman::quadlet { 'iop-core-host-inventory':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Host-Based Inventory Container',
        'After'       => ['network-online.target', 'iop-core-host-inventory-migrate.service'],
        'Requires'    => 'iop-core-host-inventory-migrate.service',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-host-inventory',
        'Network'       => 'iop-core-network',
        'Exec'          => 'make run_inv_mq_service',
        'Environment'   => [
          'INVENTORY_DB_HOST=/var/run/postgresql/',
          'INVENTORY_DB_PORT=5432',
          "INVENTORY_DB_NAME=${database_name}",
          "INVENTORY_DB_USER=${database_user}",
          "INVENTORY_DB_PASS=${database_password}",
          'KAFKA_BOOTSTRAP_SERVERS=PLAINTEXT://iop-core-kafka:9092',
          'FF_LAST_CHECKIN=true',
          'USE_SUBMAN_ID=true',
        ],
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
      },
      'Install'   => {
        'WantedBy' => ['multi-user.target', 'default.target'],
      },
    },
  }

  podman::quadlet { 'iop-core-host-inventory-api':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Host-Based Inventory Web Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-host-inventory-api',
        'Network'       => 'iop-core-network',
        'Exec'          => 'python run_gunicorn.py',
        'Environment'   => [
          'INVENTORY_DB_HOST=/var/run/postgresql/',
          'INVENTORY_DB_PORT=5432',
          "INVENTORY_DB_NAME=${database_name}",
          "INVENTORY_DB_USER=${database_user}",
          "INVENTORY_DB_PASS=${database_password}",
          'KAFKA_BOOTSTRAP_SERVERS=PLAINTEXT://iop-core-kafka:9092',
          'LISTEN_PORT=8081',
          'BYPASS_RBAC=true',
          'FF_LAST_CHECKIN=true',
          'USE_SUBMAN_ID=true',
        ],
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
      },
      'Service'   => {
        'Restart' => 'always',
      },
      'Install'   => {
        'WantedBy' => ['multi-user.target', 'default.target'],
      },
    },
  }
}
