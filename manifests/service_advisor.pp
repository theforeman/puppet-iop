# == Class: iop::service_advisor
#
# Install and configure the Advisor service
#
# === Parameters:
#
# $image:: The container image
#
# $ensure:: Ensure service is present or absent
#
# $database_user:: Username for the advisor database
#
# $database_name:: Name of the advisor database
#
# $database_password:: Password for the advisor database
#
class iop::service_advisor (
  String[1] $image = 'quay.io/iop/advisor-backend:latest',
  Enum['present', 'absent'] $ensure = 'present',
  String[1] $database_name = 'advisor_db',
  String[1] $database_user = 'advisor_user',
  String[1] $database_password = extlib::cache_data('iop_cache_data', 'advisor_db_password', extlib::random_password(32)),
) {
  include podman
  include iop::database
  include iop::core_kafka
  include iop::core_network
  include iop::core_host_inventory

  # Prevents errors if run from /root etc.
  Postgresql_psql {
    cwd => '/',
  }

  include postgresql::client, postgresql::server

  postgresql::server::db { $database_name:
    user     => $database_user,
    password => postgresql::postgresql_password($database_user, $database_password),
    owner    => $database_user,
    encoding => 'utf8',
    locale   => 'en_US.utf8',
  }

  iop::postgresql_fdw { 'advisor':
    database_name        => $database_name,
    database_user        => $database_user,
    database_password    => $database_password,
    remote_database_name => $iop::core_host_inventory::database_name,
    remote_user          => $iop::core_host_inventory::database_user,
    remote_password      => $iop::core_host_inventory::database_password,
    require              => [
      Postgresql::Server::Db[$database_name],
      Postgresql::Server::Schema['inventory'],
      Postgresql_psql['create_or_replace_remote_view_inventory_hosts'],
    ],
  }

  podman::quadlet { 'iop-service-advisor-backend-api':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'Advisor Backend API',
        'Wants'       => ['iop-core-host-inventory-api.service'],
        'After'       => ['iop-core-host-inventory-api.service'],
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-service-advisor-backend-api',
        'Network'       => 'iop-core-network',
        'Exec'          => 'sh -c "./container_init.sh && api/app.sh"',
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
        'Environment'   => [
          'DJANGO_SESSION_KEY=UNUSED',
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092',
          'ADVISOR_ENV=prod',
          'LOG_LEVEL=INFO',
          'USE_DJANGO_WEBSERVER=false',
          'CLOWDER_ENABLED=false',
          'WEB_CONCURRENCY=2',
          'ENABLE_AUTOSUB=true',
          'TASKS_REWRITE_INTERNAL_URLS=true',
          'TASKS_REWRITE_INTERNAL_URLS_FOR=internal.localhost',
          'ENABLE_INIT_CONTAINER_MIGRATIONS=true',
          'ENABLE_INIT_CONTAINER_IMPORT_CONTENT=true',
          'IMAGE=latest',
          'ADVISOR_DB_HOST=/var/run/postgresql',
          'ADVISOR_DB_PORT=5432',
          "ADVISOR_DB_NAME=${database_name}",
          "ADVISOR_DB_USER=${database_user}",
          "ADVISOR_DB_PASSWORD=${database_password}",
          'ALLOWED_HOSTS=*',
          'INVENTORY_SERVER_URL=http://iop-core-host-inventory-api:8081/api/inventory/v1',
        ],
      },
      'Install'   => { 'WantedBy' => 'default.target' },
    },
  }

  podman::quadlet { 'iop-service-advisor-backend-service':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'Advisor Backend Service',
        'Wants'       => ['iop-core-host-inventory-api.service'],
        'After'       => ['iop-core-host-inventory-api.service'],
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-service-advisor-backend-service',
        'Network'       => 'iop-core-network',
        'Exec'          => 'pipenv run python service/service.py',
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
        'Environment'   => [
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092',
          'ADVISOR_DB_HOST=/var/run/postgresql',
          'ADVISOR_DB_PORT=5432',
          "ADVISOR_DB_NAME=${database_name}",
          "ADVISOR_DB_USER=${database_user}",
          "ADVISOR_DB_PASSWORD=${database_password}",
        ],
      },
      'Install'   => { 'WantedBy' => 'default.target' },
    },
  }
}
