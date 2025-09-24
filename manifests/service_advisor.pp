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
# $database_host:: Host for the advisor database
#
# $database_port:: Port for the advisor database
#
class iop::service_advisor (
  String[1] $image = 'quay.io/iop/advisor-backend:latest',
  Enum['present', 'absent'] $ensure = 'present',
  String[1] $database_name = 'advisor_db',
  String[1] $database_user = 'advisor_user',
  String[1] $database_password = $iop::params::advisor_database_password,
  String[1] $database_host = '/var/run/postgresql',
  Stdlib::Port $database_port = 5432,
) inherits iop::params {
  include podman
  include iop::database
  include iop::core_kafka
  require iop::core_network
  include iop::core_host_inventory

  $service_name = 'iop-service-advisor-backend'
  $database_username_secret_name = "${service_name}-database-username"
  $database_password_secret_name = "${service_name}-database-password"
  $database_name_secret_name = "${service_name}-database-name"
  $database_host_secret_name = "${service_name}-database-host"
  $database_port_secret_name = "${service_name}-database-port"

  $socket_volume = $database_host ? {
    /^\/var\/run\/postgresql/ => ['/var/run/postgresql:/var/run/postgresql:rw'],
    default                   => [],
  }

  podman::secret { $database_username_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_user),
  }

  podman::secret { $database_password_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_password),
  }

  podman::secret { $database_name_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_name),
  }

  podman::secret { $database_host_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_host),
  }

  podman::secret { $database_port_secret_name:
    ensure => $ensure,
    secret => Sensitive(String($database_port)),
  }

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
    subscribe    => [
      Podman::Secret[$database_username_secret_name],
      Podman::Secret[$database_password_secret_name],
      Podman::Secret[$database_name_secret_name],
      Podman::Secret[$database_host_secret_name],
      Podman::Secret[$database_port_secret_name],
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
        'Volume'        => $socket_volume,
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
          'ALLOWED_HOSTS=*',
          'INVENTORY_SERVER_URL=http://iop-core-host-inventory-api:8081/api/inventory/v1',
        ],
        'Secret'        => [
          "${database_username_secret_name},type=env,target=ADVISOR_DB_USER",
          "${database_password_secret_name},type=env,target=ADVISOR_DB_PASSWORD",
          "${database_name_secret_name},type=env,target=ADVISOR_DB_NAME",
          "${database_host_secret_name},type=env,target=ADVISOR_DB_HOST",
          "${database_port_secret_name},type=env,target=ADVISOR_DB_PORT",
        ],
      },
      'Service'   => {
        'Environment' => 'REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json',
        'Restart'     => 'on-failure',
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
    subscribe    => [
      Podman::Secret[$database_username_secret_name],
      Podman::Secret[$database_password_secret_name],
      Podman::Secret[$database_name_secret_name],
      Podman::Secret[$database_host_secret_name],
      Podman::Secret[$database_port_secret_name],
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
        'Volume'        => $socket_volume,
        'Environment'   => [
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092',
        ],
        'Secret'        => [
          "${database_username_secret_name},type=env,target=ADVISOR_DB_USER",
          "${database_password_secret_name},type=env,target=ADVISOR_DB_PASSWORD",
          "${database_name_secret_name},type=env,target=ADVISOR_DB_NAME",
          "${database_host_secret_name},type=env,target=ADVISOR_DB_HOST",
          "${database_port_secret_name},type=env,target=ADVISOR_DB_PORT",
        ],
      },
      'Service'   => {
        'Environment' => 'REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json',
        'Restart'     => 'on-failure',
      },
      'Install'   => { 'WantedBy' => 'default.target' },
    },
  }
}
