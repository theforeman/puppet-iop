# == Class: iop::pgbouncer
#
# Configure pgbouncer
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::pgbouncer (
  String[1] $image = 'quay.io/ehelms/pgbouncer:latest',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include iop::core_network
  include postgresql::server
  include iop::core_host_inventory

  postgresql::server::pg_hba_rule { 'allow iop network to access postgres':
    description => "Open up PostgreSQL for access from ${iop::core_network::subnet}",
    type        => 'local',
    database    => 'all',
    user        => 'all',
    auth_method => 'md5',
    order       => 2,
  }

  podman::secret { 'iop-pgbouncer-userlist':
    ensure => $ensure,
    secret => Sensitive(epp(
        'iop/userlist.txt.epp',
        {
          'inventory_database_user'     => $iop::core_host_inventory::database_user,
          'inventory_database_password' => postgresql::postgresql_password($iop::core_host_inventory::database_user, $iop::core_host_inventory::database_password),
        }
    )),
  }

  podman::secret { 'iop-pgbouncer-pgbouncer-ini':
    ensure => $ensure,
    secret => Sensitive(file('iop/pgbouncer.ini')),
  }

  podman::quadlet { 'iop-pgbouncer':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'Pgbouncer container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-pgbouncer',
        'Network'       => [
          'iop-core-network',
        ],
        'Secret'        => [
          'iop-pgbouncer-userlist,target=/etc/pgbouncer/userlist.txt',
          'iop-pgbouncer-pgbouncer-ini,target=/etc/pgbouncer/pgbouncer.ini',
        ],
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
        'User'          => 'pgbouncer',
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
