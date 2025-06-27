# == Class: iop::core_gateway
#
# Install and configure the core gateway
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
class iop::core_gateway (
  String[1] $image = 'quay.io/iop/gateway',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  require iop::core_network
  include certs::iop_advisor_engine

  $service_name = 'iop-core-gateway'

  $server_cert_secret_name = "${service_name}-server-cert"
  $server_key_secret_name = "${service_name}-server-key"
  $server_ca_cert_secret_name = "${service_name}-server-ca-cert"

  # Client certificates for Smart Proxy Relay
  $client_cert_secret_name = "${service_name}-client-cert"
  $client_key_secret_name = "${service_name}-client-key"
  $client_ca_cert_secret_name = "${service_name}-client-ca-cert"

  podman::secret { $server_cert_secret_name:
    ensure => $ensure,
    path   => $certs::iop_advisor_engine::server_cert,
  }

  podman::secret { $server_key_secret_name:
    ensure => $ensure,
    path   => $certs::iop_advisor_engine::server_key,
  }

  podman::secret { $server_ca_cert_secret_name:
    ensure => $ensure,
    path   => $certs::iop_advisor_engine::server_ca_cert,
  }

  podman::secret { $client_cert_secret_name:
    ensure => $ensure,
    path   => $certs::foreman_proxy::foreman_ssl_cert,
  }

  podman::secret { $client_key_secret_name:
    ensure => $ensure,
    path   => $certs::foreman_proxy::foreman_ssl_key,
  }

  podman::secret { $client_ca_cert_secret_name:
    ensure => $ensure,
    path   => $certs::foreman_proxy::foreman_ssl_ca_cert,
  }

  podman::quadlet { 'iop-core-gateway':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      Podman::Secret[
        $server_cert_secret_name,
        $server_key_secret_name,
        $server_ca_cert_secret_name,
      ],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'IOP Core Gateway Container',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-core-gateway',
        'Network'       => 'iop-core-network',
        'PublishPort'   => [
          '127.0.0.1:24443:8443',
        ],
        'Secret'        => [
          "${server_cert_secret_name},target=/etc/nginx/certs/nginx.crt,mode=0440,type=mount,uid=998,gid=998",
          "${server_key_secret_name},target=/etc/nginx/certs/nginx.key,mode=0440,type=mount,uid=998,gid=998",
          "${server_ca_cert_secret_name},target=/etc/nginx/certs/ca.crt,mode=0440,type=mount,uid=998,gid=998",
          "${client_cert_secret_name},target=/etc/nginx/smart-proxy-relay/certs/proxy.crt,mode=0440,type=mount,uid=998,gid=998",
          "${client_key_secret_name},target=/etc/nginx/smart-proxy-relay/certs/proxy.key,mode=0440,type=mount,uid=998,gid=998",
          "${client_ca_cert_secret_name},target=/etc/nginx/smart-proxy-relay/certs/ca.crt,mode=0440,type=mount,uid=998,gid=998",
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
