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
  String[1] $image = 'quay.io/iop/puptoo:latest',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  require iop::core_network

  podman::quadlet { 'iop-core-puptoo':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Puptoo Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-puptoo',
        'Network'       => 'iop-core-network',
        'Environment'   => [
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092', # Assumes 'iop-core-kafka' is resolvable.
          'DISABLE_REDIS=True',
          'DISABLE_S3_UPLOAD=True',
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
