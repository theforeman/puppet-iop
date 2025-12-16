# == Class: iop::core_ingress
#
# Install and configure the core ingress
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::core_ingress (
  String[1] $image = 'quay.io/iop/ingress:foreman-3.16',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  include iop::core_kafka
  include iop::core_network

  file { '/var/tmp/insights-archives':
    ensure => directory,
    owner  => '1001',
    group  => '1001',
    mode   => '0755',
  }

  file { '/etc/tmpfiles.d/insights-archives-cleanup.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "e /var/tmp/insights-archives - - - 24h\n",
  }

  podman::quadlet { 'iop-core-ingress':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => File['/var/tmp/insights-archives'],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Ingress Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-ingress',
        'Network'       => 'iop-core-network',
        'Volume'        => '/var/tmp/insights-archives:/var/tmp/insights-archives:rw,Z',
        'Environment'   => [
          'INGRESS_VALID_UPLOAD_TYPES=advisor,compliance,qpc,rhv,tower,leapp-reporting,xavier,playbook,playbook-sat,malware-detection,tasks',
          'INGRESS_KAFKA_BROKERS=iop-core-kafka:9092',
          'INGRESS_STAGERIMPLEMENTATION=filebased',
          'INGRESS_STORAGEFILESYSTEMPATH=/var/tmp/insights-archives',
          'INGRESS_SERVICEBASEURL=http://iop-core-ingress:8080',
          'INGRESS_WEBPORT=8080',
          'INGRESS_METRICSPORT=3001',
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
