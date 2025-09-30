# == Class: iop::core_yuptoo
#
# Install and configure the core yuptoo
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::core_yuptoo (
  String[1] $image = 'quay.io/iop/yuptoo:latest',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  include iop::core_network

  podman::quadlet { 'iop-core-yuptoo':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Yuptoo Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-yuptoo',
        'Network'       => 'iop-core-network',
        'Exec'          => 'python -m main',
        'Environment'   => [
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092',
          'BYPASS_PAYLOAD_EXPIRATION=true',
        ],
      },
      'Service'   => {
        'Environment' => 'REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json',
        'Restart'     => 'on-failure',
      },
      'Install'   => {
        'WantedBy' => 'default.target',
      },
    },
  }
}
