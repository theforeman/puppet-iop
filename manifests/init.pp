# == Class: iop
#
# Install and configure IOP services
#
# === Advanced parameters:
#
# $register_as_smartproxy:: Whether to register as a smart proxy
#
# $enable_vulnerability:: Enable vulnerability services
#
# $enable_advisor:: Enable advisor services
#
# $foreman_base_url:: Base URL for Foreman connection
#
class iop (
  Boolean $register_as_smartproxy = true,
  Boolean $enable_vulnerability = true,
  Boolean $enable_advisor = true,
  Optional[Stdlib::HTTPUrl] $foreman_base_url = undef,
) {
  include iop::core_ingress
  include iop::core_puptoo
  include iop::core_yuptoo
  include iop::core_engine
  include iop::core_gateway
  include iop::core_host_inventory
  include iop::core_host_inventory_frontend

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
    $oauth_consumer_key = extlib::cache_data('foreman_cache_data', 'oauth_consumer_key', extlib::random_password(32))
    $oauth_consumer_secret = extlib::cache_data('foreman_cache_data', 'oauth_consumer_secret', extlib::random_password(32))

    $_foreman_base_url_real = pick($foreman_base_url, "https://${facts['networking']['fqdn']}")

    foreman_smartproxy { 'iop-gateway':
      ensure          => present,
      base_url        => $_foreman_base_url_real,
      consumer_key    => $oauth_consumer_key,
      consumer_secret => $oauth_consumer_secret,
      effective_user  => 'admin',
      ssl_ca          => $certs::iop::client_ca_cert,
      url             => 'https://localhost:24443',
      require         => [
        Class['iop::core_gateway'],
      ],
    }
  }
}
