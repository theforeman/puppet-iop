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
  String[1] $image = 'quay.io/strimzi/kafka:latest-kafka-3.9.0',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman

  podman::secret { 'iop-core-kafka-init-start':
    ensure => $ensure,
    secret => Sensitive(file('iop/kafka/init-start.sh')),
  }

  podman::secret { 'iop-core-kafka-server-properties':
    ensure => $ensure,
    secret => Sensitive(file('iop/kafka/kraft')),
  }

  podman::quadlet { 'iop-core-kafka':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Kafka Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-kafka',
        'Environment'   => [
          'LOG_DIR=/tmp/kafka-logs',
          'KAFKA_NODE_ID=1',
        ],
        'Exec'          => 'sh bin/init-start.sh',
        'Secret'        => [
          'iop-core-kafka-init-start,target=/opt/kafka/bin/init-start.sh',
          'iop-core-kafka-server-properties,target=/opt/kafka/config/kraft/server.properties',
        ],
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
