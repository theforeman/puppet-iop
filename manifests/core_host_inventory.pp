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
class iop::core_host_inventory (
  String[1] $image = 'quay.io/iop/host-inventory',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  include iop::core_kafka

  podman::quadlet { 'iop-core-host-inventory':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => Class['iop::core_kafka'],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Host-Based Inventory Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-host-inventory',
        'Command'       => 'make upgrade_db && exec make run_inv_mq_service',
        'Environment'   => [
          'INVENTORY_DB_HOST=iop-core-db',
          'INVENTORY_DB_NAME=inventory_db',
          'INVENTORY_DB_USER=inventory_user',
          'INVENTORY_DB_PASS=inventory_password',
          'KAFKA_BOOTSTRAP_SERVERS=PLAINTEXT://iop-core-kafka:9092',
          'FF_LAST_CHECKIN=true',
          'USE_SUBMAN_ID=true',
        ],
        'After'         => 'iop-core-kafka.service',
        'Requires'      => 'iop-core-kafka.service',
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
