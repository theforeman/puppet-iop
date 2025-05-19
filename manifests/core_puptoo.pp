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
          'BOOTSTRAP_SERVERS=iop-core-kafka:9092', # Assumes 'iop-core-kafka' is resolvable.
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
