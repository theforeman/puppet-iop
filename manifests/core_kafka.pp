# == Class: iop::core_kafka
#
# Install and configure kafka
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::core_kafka (
  String[1] $image = 'quay.io/strimzi/kafka:latest-kafka-3.7.1',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  require iop::core_network

  podman::secret { 'iop-core-kafka-init-start':
    ensure => $ensure,
    secret => Sensitive(file('iop/kafka/init-start.sh')),
  }

  podman::secret { 'iop-core-kafka-server-properties':
    ensure => $ensure,
    secret => Sensitive(file('iop/kafka/kraft')),
  }

  podman::secret { 'iop-core-kafka-init':
    ensure => $ensure,
    secret => Sensitive(file('iop/kafka/init')),
  }

  podman::volume { 'iop-core-kafka-data':
    ensure => $ensure,
  }

  podman::quadlet { 'iop-core-kafka':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Volume['iop-core-kafka-data'],
      Podman::Network['iop-core-network']
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Kafka Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-kafka',
        'Network'       => 'iop-core-network',
        'Exec'          => 'sh bin/init-start.sh',
        'Environment'   => [
          'LOG_DIR=/tmp/kafka-logs',
          'KAFKA_NODE_ID=1',
        ],
        'Volume'        => [
          'iop-core-kafka-data:/var/lib/kafka/data',
        ],
        'Secret'        => [
          'iop-core-kafka-init-start,target=/opt/kafka/bin/init-start.sh',
          'iop-core-kafka-server-properties,target=/opt/kafka/config/kraft/server.properties',
          'iop-core-kafka-init,target=/opt/kafka/init.sh',
        ],
      },
      'Service'   => {
        'Restart' => 'on-failure',
      },
      'Install'   => {
        'WantedBy' => ['multi-user.target', 'default.target'],
      },
    },
  }

  Exec { 'kafka-init':
    command => "podman run --network=iop-core-network --secret iop-core-kafka-init,target=/opt/kafka/init.sh,mode=0755 ${image} /opt/kafka/init.sh --create",
    unless  => "podman run --network=iop-core-network --secret iop-core-kafka-init,target=/opt/kafka/init.sh,mode=0755 ${image} /opt/kafka/init.sh --check",
    require => [
      Podman::Quadlet['iop-core-kafka'],
      Podman::Network['iop-core-network'],
      Podman::Secret['iop-core-kafka-init']
    ],
    path    => ['/usr/bin', '/usr/sbin'],
  }
}
