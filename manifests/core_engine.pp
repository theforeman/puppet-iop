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
  String[1] $image = 'quay.io/iop/insights-engine:latest',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  require iop::core_network
  require iop::core_ingress
  require iop::core_puptoo

  $service_name = 'iop-core-engine'
  $config_secret_name = "${service_name}-config-yml"

  # Create the engine config as a secret
  podman::secret { $config_secret_name:
    ensure => $ensure,
    secret => Sensitive(file('iop/engine-config/config.yml')),
    flags  => {
      label => [
        'filename=config.yml',
        'app=iop-core-engine',
      ],
    },
  }

  podman::quadlet { $service_name:
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      Podman::Secret[$config_secret_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Engine Container',
        'After'       => ['iop-core-ingress.service', 'iop-core-puptoo.service'],
        'Wants'       => ['iop-core-ingress.service', 'iop-core-puptoo.service'],
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-engine',
        'Network'       => 'iop-core-network',
        'Exec'          => 'insights-core-engine /var/config.yml',
        'Secret'        => [
          "${config_secret_name},target=/var/config.yml,mode=0440,uid=1000,type=mount",
        ],
        'AddHost'       => [
          'console.redhat.com:127.0.0.1',
        ],
      },
      'Service'   => {
        'Restart' => 'on-failure',
      },
      'Install'   => {
        'WantedBy' => 'default.target',
      },
    },
  }
}
