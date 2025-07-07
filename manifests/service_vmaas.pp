# == Class: iop::service_vmaas
#
# Install and configure the VMAAS reposcan service
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
# $database_user:: Username for the vmaas database
#
# $database_name:: Name of the vmaas database
#
# $database_password:: Password for the vmaas database
#
class iop::service_vmaas (
  String[1] $image = 'quay.io/iop/vmaas:latest',
  Enum['present', 'absent'] $ensure = 'present',
  String[1] $database_user = 'vmaas_admin',
  String[1] $database_name = 'vmaas_db',
  String[1] $database_password = 'changeme',
) {
  include podman
  include iop::core_network
  include iop::core_kafka
  include iop::database
  include certs::iop_advisor_engine

  $service_name = 'iop-service-vmaas-reposcan'
  $server_ca_cert_secret_name = "${service_name}-server-ca-cert"

  podman::secret { $server_ca_cert_secret_name:
    ensure => $ensure,
    path   => $certs::iop_advisor_engine::server_ca_cert,
  }

  # Prevents errors if run from /root etc.
  Postgresql_psql {
    cwd => '/',
  }

  include postgresql::client, postgresql::server

  postgresql::server::db { $database_name:
    user     => $database_user,
    password => postgresql::postgresql_password($database_user, $database_password),
    owner    => $database_user,
    encoding => 'utf8',
    locale   => 'en_US.utf8',
  }

  file { '/var/lib/vmaas':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  podman::quadlet { 'iop-service-vmaas-reposcan':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      File['/var/lib/vmaas'],
      Postgresql::Server::Db[$database_name],
      Podman::Secret[$server_ca_cert_secret_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'VMAAS Reposcan Service',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-service-vmaas-reposcan',
        'Network'       => 'iop-core-network',
        'Exec'          => '/vmaas/entrypoint.sh database-upgrade reposcan',
        'Environment'   => [
          'POSTGRESQL_HOST=/var/run/postgresql',
          'POSTGRESQL_PORT=5432',
          "POSTGRESQL_DATABASE=${database_name}",
          "POSTGRESQL_USER=${database_user}",
          "POSTGRESQL_PASSWORD=${database_password}",
          'PROMETHEUS_PORT=8085',
          'PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus_multiproc_dir',
          'SYNC_REPO_LIST_SOURCE=katello',
          'SYNC_REPOS=yes',
          'SYNC_CVE_MAP=yes',
          'SYNC_CPE=no',
          'SYNC_CSAF=no',
          'SYNC_RELEASES=no',
          'SYNC_RELEASE_GRAPH=no',
          'KATELLO_URL=http://iop-core-gateway:9090',
          'REDHAT_CVEMAP_URL=http://iop-core-gateway:9090/pub/iop/data/meta/v1/cvemap.xml',
        ],
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
          '/var/lib/vmaas:/data:z',
        ],
        'Secret'        => [
          "${server_ca_cert_secret_name},target=/katello-server-ca.crt,mode=0440,type=mount",
        ],
      },
      'Install'   => {
        'WantedBy' => ['multi-user.target', 'default.target'],
      },
    },
  }

  podman::quadlet { 'iop-service-vmaas-webapp-go':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'VMAAS Webapp-Go Service',
        'Wants'       => ['iop-service-vmaas-reposcan.service'],
        'After'       => ['iop-service-vmaas-reposcan.service'],
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-service-vmaas-webapp-go',
        'Network'       => 'iop-core-network',
        'Exec'          => '/vmaas/entrypoint.sh webapp-go',
        'Environment'   => [
          'POSTGRESQL_HOST=/var/run/postgresql',
          'POSTGRESQL_PORT=5432',
          "POSTGRESQL_DATABASE=${database_name}",
          "POSTGRESQL_USER=${database_user}",
          "POSTGRESQL_PASSWORD=${database_password}",
          'REPOSCAN_PUBLIC_URL=http://iop-service-vmaas-reposcan:8000',
          'REPOSCAN_PRIVATE_URL=http://iop-service-vmaas-reposcan:10000',
          'CSAF_UNFIXED_EVAL_ENABLED=FALSE',
          'GIN_MODE=release',
        ],
        'Volume'        => [
          '/var/run/postgresql:/var/run/postgresql:rw',
        ],
      },
      'Install'   => {
        'WantedBy' => ['multi-user.target', 'default.target'],
      },
    },
  }
}
