# == Class: iop
#
# Install and configure IOP services
#
# === Parameters:
#
# $register_as_smartproxy:: Whether to register as a smart proxy
#
# $enable_vulnerability:: Enable vulnerability services
#
# $enable_advisor:: Enable advisor services
#
class iop (
  Boolean $register_as_smartproxy = false,
  Boolean $enable_vulnerability = true,
  Boolean $enable_advisor = true,
) {
  include iop::core_ingress
  include iop::core_puptoo
  include iop::core_yuptoo
  include iop::core_engine
  include iop::core_gateway
  include iop::core_host_inventory

  if $enable_vulnerability {
    include iop::service_vmaas
    include iop::service_vulnerability_frontend
    include iop::service_vulnerability
  }

  if $enable_advisor {
    include iop::service_advisor_frontend
    include iop::service_advisor
    include iop::service_remediations
  }

  if $register_as_smartproxy {
    include katello

    foreman_smartproxy { 'iop-gateway':
      ensure          => present,
      base_url        => "https://${facts['networking']['fqdn']}",
      consumer_key    => $foreman::oauth_consumer_key,
      consumer_secret => $foreman::oauth_consumer_secret,
      effective_user  => $foreman::oauth_effective_user,
      ssl_ca          => $certs::iop::client_ca_cert,
      url             => 'https://localhost:24443',
      require         => [
        Class['katello'],
        Class['iop::core_gateway'],
      ],
    }
  }
}
