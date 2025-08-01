# == Class: iop::service_remediations
#
# Install and configure the Remediations service
#
# === Parameters:
#
# $image:: The container image
#
# $ensure:: Ensure service is present or absent
#
# $database_user:: Username for the remediations database
#
# $database_name:: Name of the remediations database
#
# $database_password:: Password for the remediations database
#
class iop::service_remediations (
  String[1] $image = 'quay.io/iop/remediations:latest',
  Enum['present', 'absent'] $ensure = 'present',
  String[1] $database_name = 'remediations_db',
  String[1] $database_user = 'remediations_user',
  String[1] $database_password = extlib::cache_data('iop_cache_data', 'remediations_db_password', extlib::random_password(32)),
) {
  include podman
  include iop::database
  include iop::core_kafka
  include iop::core_network
  include iop::core_host_inventory
  include iop::service_advisor

  $service_name = 'iop-service-remediations-api'
  $database_username_secret_name = "${service_name}-database-username"
  $database_password_secret_name = "${service_name}-database-password"
  $database_name_secret_name = "${service_name}-database-name"
  $database_host_secret_name = "${service_name}-database-host"
  $database_port_secret_name = "${service_name}-database-port"

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
    secret => Sensitive('/var/run/postgresql'),
  }

  podman::secret { $database_port_secret_name:
    ensure => $ensure,
    secret => Sensitive('5432'),
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

  podman::quadlet { $service_name:
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
      Podman::Secret[$database_username_secret_name],
      Podman::Secret[$database_password_secret_name],
      Podman::Secret[$database_name_secret_name],
      Podman::Secret[$database_host_secret_name],
      Podman::Secret[$database_port_secret_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'Remediations API',
        'Wants'       => ['iop-core-host-inventory-api.service', 'iop-service-advisor-backend-api.service'],
        'After'       => ['iop-core-host-inventory-api.service', 'iop-service-advisor-backend-api.service'],
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-service-remediations-api',
        'Network'       => 'iop-core-network',
        'Exec'          => 'sh -c "npm run db:migrate && exec node --max-http-header-size=16384 src/app.js"',
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
        'Environment'   => [
          'REDIS_ENABLED=false',
          'RBAC_ENFORCE=false',
          'CONTENT_SERVER_HOST=http://iop-service-advisor-backend-api:8000',
          'ADVISOR_HOST=http://iop-service-advisor-backend-api:8000',
          'INVENTORY_HOST=http://iop-core-host-inventory-api:8081',
        ],
        'Secret'        => [
          "${database_username_secret_name},type=env,target=DB_USERNAME",
          "${database_password_secret_name},type=env,target=DB_PASSWORD",
          "${database_name_secret_name},type=env,target=DB_DATABASE",
          "${database_host_secret_name},type=env,target=DB_HOST",
          "${database_port_secret_name},type=env,target=DB_PORT",
        ],
      },
      'Install'   => { 'WantedBy' => 'default.target' },
    },
  }
}
