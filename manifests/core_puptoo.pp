# == Class: iop::core_puptoo
#
# Install and configure the core puptoo
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::core_puptoo (
  String[1] $image = '',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman

  podman::quadlet { 'iop-core-puptoo':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Puptoo Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-puptoo',
        'Environment'   => [
          'LOG_LEVEL=INFO',
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092', # Assumes 'iop-core-kafka' is resolvable.
          'INVENTORY_TOPIC=platform.inventory.host-ingress',
          'HABERDASHER_EMITTER=stderr',
          'HABERDASHER_KAFKA_BOOTSTRAP=iop-core-kafka:9092', # Assumes 'iop-core-kafka' is resolvable.
          'HABERDASHER_KAFKA_TOPIC=platform.logging.logs',
          'KAFKA_LOGGER=ERROR',
          'DISABLE_REDIS=True',
          'DISABLE_S3_UPLOAD=True',
        ],
      },
      'Service'   => {
        'Restart' => 'always',
      },
      'Install'   => {
        'WantedBy' => 'default.target',
      },
    },
  }
}
