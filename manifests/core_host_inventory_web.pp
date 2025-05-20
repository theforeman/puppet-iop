# == Class: iop::core_host_inventory_web
#
# Install and configure the core host-inventory-web
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::core_host_inventory_web (
  String[1] $image = 'quay.io/iop/host-inventory',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman

  podman::quadlet { 'iop-core-host-inventory-web':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Host-Based Inventory Web Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-host-inventory-web',
        'Command'       => 'python run_gunicorn.py',
        'Environment'   => [
          'INVENTORY_DB_HOST=iop-core-db',
          'INVENTORY_DB_NAME=inventory_db',
          'INVENTORY_DB_USER=inventory_user',
          'INVENTORY_DB_PASS=inventory_password',
          'KAFKA_BOOTSTRAP_SERVERS=PLAINTEXT://iop-core-kafka:9092',
          'LISTEN_PORT=8081',
          'BYPASS_RBAC=true',
          'USE_SUBMAN_ID=true',
          'FF_LAST_CHECKIN=true',
        ],
        'After'         => 'iop-core-db.service iop-core-host-inventory.service iop-core-kafka.service',
        'Requires'      => 'iop-core-db.service iop-core-host-inventory.service iop-core-kafka.service',
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
