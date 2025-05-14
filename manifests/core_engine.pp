# == Class: iop::core_engine
#
# Install and configure the core engine
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::core_engine (
  String[1] $image = 'fill-this-in',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman

  podman::quadlet { 'iop-core-engine':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Engine Container',
        'Wants'       => [
          'iop-core-ingress.service',
          'iop-core-puptoo.service',
        ],
        'After'       => [
          'iop-core-ingress.service',
          'iop-core-puptoo.service',
        ],
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-engine',
        'Environment'   => [
          'EVENTS_TOPIC=platform.inventory.events',
          'DEFAULT_LOG_LEVEL=INFO',
          'ENGINE_LOG_LEVEL=INFO',
          'KAFKA_LOG_LEVEL=ERROR',
          'INSIGHTS_CORE_LOG_LEVEL=ERROR',
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092',
        ],
        'Exec'          => 'insights-core-engine /var/config.yml',
        'Volume'        => [
          './engine-config/config.yml:/var/config.yml:Z',
        ],
        'Service'       => {
          'Restart' => 'always',
        },
        'Install'       => {
          'WantedBy' => 'default.target',
        },
      },
    },
  }
}
