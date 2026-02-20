# == Class: iop::core_engine
#
# Install and configure the core engine
#
# === Parameters:
#
# $image::    The container image
#
# $ensure::   Ensure service is present or absent
#
# $packages:: Array of packages to configure in the engine config
#
# $log_level_insights_core_dr::     Log level for insights.core.dr logger
#
# $log_level_insights_messaging::   Log level for insights_messaging logger
#
# $log_level_insights_kafka_service:: Log level for insights_kafka_service logger
#
# $log_level_root::                 Log level for root logger
#
class iop::core_engine (
  String[1] $image = 'quay.io/iop/insights-engine:foreman-3.18',
  Enum['present', 'absent'] $ensure = 'present',
  Array[String] $packages = [
    'insights.specs.default',
    'insights.specs.insights_archive',
    'insights_kafka_service.rules',
  ],
  Enum['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'] $log_level_insights_core_dr = 'ERROR',
  Enum['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'] $log_level_insights_messaging = 'INFO',
  Enum['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'] $log_level_insights_kafka_service = 'INFO',
  Enum['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'] $log_level_root = 'INFO',
) {
  include podman
  include iop::core_network
  require iop::core_ingress
  require iop::core_puptoo

  $service_name = 'iop-core-engine'
  $config_secret_name = "${service_name}-config-yml"

  # Create the engine config as a secret
  podman::secret { $config_secret_name:
    ensure => $ensure,
    secret => Sensitive(epp('iop/engine-config/config.yml.epp', {
          'packages'                         => $packages,
          'log_level_insights_core_dr'       => $log_level_insights_core_dr,
          'log_level_insights_messaging'     => $log_level_insights_messaging,
          'log_level_insights_kafka_service' => $log_level_insights_kafka_service,
          'log_level_root'                   => $log_level_root,
    })),
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
    subscribe    => [
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
        'Tmpfs'         => '/tmp:rw,size=2G,mode=1777',
        'Secret'        => [
          "${config_secret_name},target=/var/config.yml,mode=0440,uid=1000,type=mount",
        ],
        'AddHost'       => [
          'console.redhat.com:127.0.0.1',
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
